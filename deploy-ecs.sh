#!/bin/bash
set -e

PROJECT_NAME="festivos-api"
REGION="us-east-1"

echo "🚀 Desplegando infraestructura completa para $PROJECT_NAME"

# ============================================
# 1. Obtener VPC y Subnets por defecto
# ============================================
echo "🔹 Obteniendo información de red..."
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

echo "✅ VPC: $VPC_ID"
echo "✅ Subnets: $SUBNET_IDS"

# ============================================
# 2. Desplegar stack ECR
# ============================================
echo "🐳 Desplegando stack ECR..."
aws cloudformation deploy \
  --stack-name ${PROJECT_NAME}-ecr \
  --template-file infra/cloudformation/infra-ecr.yml \
  --parameter-overrides ProjectName=$PROJECT_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

echo "⏳ Esperando creación de repositorios ECR..."
aws cloudformation wait stack-create-complete \
  --stack-name ${PROJECT_NAME}-ecr \
  --region $REGION

# Obtener URI del repo backend
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-ecr \
  --query "Stacks[0].Outputs[?OutputKey=='ECRBackendUri'].OutputValue" \
  --output text \
  --region $REGION)

echo "📦 URI repositorio backend: $ECR_URI"

# ============================================
# 3. Build y push de imagen Docker
# ============================================
echo "🔨 Construyendo imagen Docker..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ECR_URI%%/*}

docker build -t $PROJECT_NAME:latest -f apiFestivos/Dockerfile apiFestivos/
docker tag $PROJECT_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest
echo "✅ Imagen subida: $ECR_URI:latest"

# ============================================
# 4. Desplegar ECS (cluster, task definition, service)
# ============================================
echo "🚀 Desplegando stack ECS..."
aws cloudformation deploy \
  --stack-name ${PROJECT_NAME}-ecs \
  --template-file infra/cloudformation/infra-ecs-simplified.yml \
  --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    VPCId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
    DBEndpoint=${DB_ENDPOINT:-""} \
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
# 5. Forzar nuevo despliegue del servicio
# ============================================
echo "🔄 Actualizando servicio ECS para usar nueva imagen..."

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
echo "✅ Despliegue completo."
echo "📊 Para ver logs: aws logs tail /ecs/$PROJECT_NAME --follow --region $REGION"
echo "🔍 Para obtener IP pública de la tarea: aws ecs list-tasks --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $REGION"
echo "💰 Costo estimado: ~\$15-20/mes (ECS Fargate + RDS)"
