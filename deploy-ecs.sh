#!/bin/bash
set -e

PROJECT_NAME="festivos-api"
REGION="us-east-1"

echo "Desplegando infraestructura ECS para $PROJECT_NAME"

# ============================================
# 1. Obtener VPC y subnets públicas cubriendo al menos 2 AZs
# ============================================
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=is-default,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)

# Obtener subnets públicas por AZ
readarray -t SUBNETS_ARRAY < <(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
  --query "Subnets[].[SubnetId,AvailabilityZone]" \
  --output text \
  --region $REGION)

# Agrupar subnets por AZ para asegurarnos que cubrimos al menos 2 AZs
declare -A AZ_SUBNETS
for line in "${SUBNETS_ARRAY[@]}"; do
  SUBNET=$(echo $line | awk '{print $1}')
  AZ=$(echo $line | awk '{print $2}')
  AZ_SUBNETS[$AZ]+="$SUBNET,"
done

SELECTED_SUBNETS=""
COUNT=0
for az in "${!AZ_SUBNETS[@]}"; do
  SUBNET_ID=$(echo ${AZ_SUBNETS[$az]} | sed 's/,$//')
  SELECTED_SUBNETS+="$SUBNET_ID,"
  COUNT=$((COUNT+1))
  if [[ $COUNT -ge 2 ]]; then
    break
  fi
done
SUBNET_IDS=$(echo $SELECTED_SUBNETS | sed 's/,$//')

echo "VPC: $VPC_ID"
echo "Subnets seleccionadas para RDS y ECS: $SUBNET_IDS"

# ============================================
# 2. Función para eliminar stack si existe
# ============================================
delete_stack_if_exists() {
  local stack_name=$1
  if aws cloudformation describe-stacks --stack-name "$stack_name" --region $REGION &>/dev/null; then
    echo "Eliminando stack existente: $stack_name"
    aws cloudformation delete-stack --stack-name "$stack_name" --region $REGION
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region $REGION
    echo "Stack $stack_name eliminado"
  fi
}

# ============================================
# 3. Desplegar RDS
# ============================================
delete_stack_if_exists "${PROJECT_NAME}-rds"

echo "Creando base de datos RDS..."
aws cloudformation deploy \
  --stack-name ${PROJECT_NAME}-rds \
  --template-file infra/cloudformation/rds-micro.yml \
  --parameter-overrides \
    DBInstanceIdentifier=${PROJECT_NAME}-db \
    DBName=festivos \
    DBUser=postgres \
    DBPassword=festivos2024 \
    VpcId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

aws cloudformation wait stack-create-complete \
  --stack-name ${PROJECT_NAME}-rds \
  --region $REGION

DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-rds \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpointAddress'].OutputValue" \
  --output text \
  --region $REGION)

# ============================================
# 4. Desplegar ECR y ECS
# ============================================
delete_stack_if_exists "${PROJECT_NAME}-ecs"

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

aws cloudformation wait stack-create-complete \
  --stack-name ${PROJECT_NAME}-ecs \
  --region $REGION

# ============================================
# 5. Build y Push Docker
# ============================================
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text \
  --region $REGION)

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ECR_URI%%/*}

docker build -t $PROJECT_NAME:latest -f apiFestivos/Dockerfile apiFestivos/
docker tag $PROJECT_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

# ============================================
# 6. Forzar despliegue ECS
# ============================================
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

echo "Despliegue completado correctamente"