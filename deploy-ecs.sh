#!/bin/bash
set -e

PROJECT_NAME="festivos-api"
REGION="us-east-1"

echo "🚀 Desplegando infraestructura ECS para $PROJECT_NAME"

# ============================================
# 1. Obtener VPC y Subnets por defecto
# ============================================
echo "Obteniendo información de red..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=is-default,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC_ID Name=map-public-ip-on-launch,Values=true \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region $REGION | tr '\t' ',')

echo "VPC: $VPC_ID"
echo "Subnets: $SUBNET_IDS"

# ============================================
# 2. Desplegar RDS (si no existe)
# ============================================
echo " Verificando base de datos..."
if ! aws cloudformation describe-stacks --stack-name ${PROJECT_NAME}-rds --region $REGION &>/dev/null; then

  echo "Creando base de datos RDS..."
  
  # Convertir SubnetIds en formato compatible con List<AWS::EC2::Subnet::Id>
  SUBNETS_OVERRIDE=""
  for subnet in ${SUBNET_IDS//,/ }; do
    SUBNETS_OVERRIDE+="SubnetIds=$subnet "
  done

  aws cloudformation deploy \
    --stack-name ${PROJECT_NAME}-rds \
    --template-file infra/cloudformation/rds-micro.yml \
    --parameter-overrides \
      DBInstanceIdentifier=${PROJECT_NAME}-db \
      DBName=festivos \
      DBUser=postgres \
      DBPassword=festivos2024 \
      VpcId=$VPC_ID \
      $SUBNETS_OVERRIDE \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

  echo "⏳ Esperando RDS (esto puede tomar 5-10 minutos)..."
  aws cloudformation wait stack-create-complete \
    --stack-name ${PROJECT_NAME}-rds \
    --region $REGION
fi

DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-rds \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpointAddress'].OutputValue" \
  --output text \
  --region $REGION)

# ============================================
# 3. Desplegar ECS
# ============================================
echo "🐳 Desplegando infraestructura ECS..."
aws cloudformation deploy \
  --stack-name ${PROJECT_NAME}-ecs \
  --template-file infra/cloudformation/infra-ecs-simplified.yml \
  --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    VPCId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
    DBEndpoint=$DB_ENDPOINT \
    DBName=festivos \
    DBUser=postgres \
    DBPassword=festivos2024 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

echo "⏳ Esperando ECS..."
aws cloudformation wait stack-create-complete \
  --stack-name ${PROJECT_NAME}-ecs \
  --region $REGION

# ============================================
# 4. Build y Push de imagen Docker
# ============================================
echo "🔨 Construyendo imagen Docker..."
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text \
  --region $REGION)

echo "📦 ECR URI: $ECR_URI"

# Login a ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ECR_URI%%/*}

# Build
docker build -t $PROJECT_NAME:latest -f apiFestivos/Dockerfile apiFestivos/

# Tag y Push
docker tag $PROJECT_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "✅ Imagen subida: $ECR_URI:latest"

# ============================================
# 5. Forzar nuevo despliegue del servicio
# ============================================
echo "🔄 Actualizando servicio ECS..."
CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECSClusterName'].OutputValue" \
  --output text \
  --region $REGION)

SERVICE_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECSServiceName'].OutputValue" \
  --output text \
  --region $REGION)

aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment \
  --region $REGION

echo ""
echo "✅ ¡Despliegue completado!"
echo ""
echo "📊 Para ver logs:"
echo "   aws logs tail /ecs/$PROJECT_NAME --follow --region $REGION"
echo ""
echo "🔍 Para obtener IP pública de la tarea:"
echo "   aws ecs list-tasks --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $REGION"
echo ""
echo "💰 Costo estimado: ~\$15-20/mes (ECS Fargate + RDS)"