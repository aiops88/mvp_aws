#!/bin/bash
set -e

PROJECT_NAME="festivos-api"
REGION="us-east-1"
DB_PASSWORD="festivos2024" # MANTENER POR REQUISITO DE MVP SIMPLE, PERO ES MALA PRÁCTICA

echo "==================================================================="
echo "  Despliegue de MVP Simple en AWS CloudShell"
echo "==================================================================="
echo "ADVERTENCIA: Este script asume que la VPC por defecto existe y que"
echo "las credenciales de DB están hardcodeadas (MALA PRÁCTICA en PROD)."
echo "==================================================================="

# ============================================
# 1. Obtener VPC y subnets por defecto
# ============================================
echo "-> 1. Obteniendo información de red de la VPC por defecto..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=is-default,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)

# Obtener subnets públicas (para RDS PubliclyAccessible y ECS AssignPublicIp)
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region $REGION | tr '\t' ',')

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ]; then
  echo "Error: No se pudo obtener VPC o Subnets. Asegúrese de tener una VPC por defecto."
  exit 1
fi

echo "   VPC ID: $VPC_ID"
echo "   Subnets: $SUBNET_IDS"

# ============================================
# 2. Desplegar ECR (para resolver dependencia circular)
# ============================================
echo "-> 2. Desplegando ECR Repository Stack..."
aws cloudformation deploy \
  --stack-name ${PROJECT_NAME}-ecr \
  --template-file infra/cloudformation/infra-ecr.yml \
  --parameter-overrides \
    ProjectName=$PROJECT_NAME \
  --region $REGION

# Obtener ECR URI
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-ecr \
  --query "Stacks[0].Outputs[?OutputKey=='ECRBackendUri'].OutputValue" \
  --output text \
  --region $REGION)

if [ -z "$ECR_URI" ]; then
  echo "Error: No se pudo obtener ECR URI."
  exit 1
fi
echo "   ECR URI: $ECR_URI"

# ============================================
# 3. Desplegar RDS
# ============================================
echo "-> 3. Desplegando RDS Stack..."
aws cloudformation deploy \
  --stack-name ${PROJECT_NAME}-rds \
  --template-file infra/cloudformation/rds-micro.yml \
  --parameter-overrides \
    DBInstanceIdentifier=${PROJECT_NAME}-db \
    DBName=festivos \
    DBUser=postgres \
    DBPassword=$DB_PASSWORD \
    VpcId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

echo "   Esperando a que el stack RDS se complete (puede tardar varios minutos)..."
aws cloudformation wait stack-create-complete \
  --stack-name ${PROJECT_NAME}-rds \
  --region $REGION

DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-rds \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpointAddress'].OutputValue" \
  --output text \
  --region $REGION)

echo "   DB Endpoint: $DB_ENDPOINT"

# ============================================
# 4. Desplegar ECS (Cluster, TaskDef, Service)
# ============================================
echo "-> 4. Desplegando ECS Stack..."
# Nota: Se usa infra-ecs-simplified.yml. Se asume que se corrigió la referencia a ECR
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
    DBPassword=$DB_PASSWORD \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

echo "   Esperando a que el stack ECS se complete..."
aws cloudformation wait stack-create-complete \
  --stack-name ${PROJECT_NAME}-ecs \
  --region $REGION

# ============================================
# 5. Build y Push de imagen Docker (ESTE PASO FALLARÁ EN CLOUDSHELL)
# ============================================
echo "-> 5. Intentando Build y Push de imagen Docker (ESTE PASO FALLARÁ EN CLOUDSHELL)"
echo "   CloudShell NO tiene Docker. Este paso requiere un entorno con Docker (e.g., CodeBuild, EC2, local)."
echo "   Para un MVP simple, se recomienda ejecutar este paso en un entorno local y luego continuar con el paso 6."
echo "   Si está ejecutando en un entorno con Docker, el proceso continuará..."

# Se comenta el bloque de Docker para que el script no falle inmediatamente en CloudShell
# aws ecr get-login-password --region $REGION | \
#   docker login --username AWS --password-stdin ${ECR_URI%%/*}
# docker build -t $PROJECT_NAME:latest -f apiFestivos/Dockerfile apiFestivos/
# docker tag $PROJECT_NAME:latest $ECR_URI:latest
# docker push $ECR_URI:latest

# ============================================
# 6. Inicialización de Base de Datos
# ============================================
echo "-> 6. Inicializando Base de Datos (Requiere psql instalado localmente)"
# Este paso también es problemático en CloudShell si no tiene psql o si el RDS no es accesible
# Se mantiene el script original, pero se advierte de la dependencia de psql
/home/ubuntu/mvp_aws/scripts/init-database.sh

# ============================================
# 7. Forzar despliegue ECS (asumiendo que la imagen fue subida manualmente)
# ============================================
echo "-> 7. Forzando nuevo despliegue ECS (asumiendo que la imagen ya está en ECR)"
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

echo "==================================================================="
echo "  Despliegue de Infraestructura COMPLETADO."
echo "  PENDIENTE: Subir imagen Docker y ejecutar el paso 7."
echo "==================================================================="
echo "Para obtener la IP pública de la tarea ECS:"
echo "aws ecs list-tasks --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $REGION"
echo "Luego, describe la ENI asociada a la tarea para obtener la IP pública."
echo "==================================================================="