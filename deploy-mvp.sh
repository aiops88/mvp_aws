#!/bin/bash

# Script de Despliegue Automatizado para Infraestructura MVP (AWS Free Tier)
# Este script asume que estás en el directorio raíz del repositorio mvp_aws.

set -e # Detener la ejecución si un comando falla

echo "--- 1. Validando y configurando entorno ---"

# 1.1. Verificar si jq está instalado (necesario para el script de RDS)
if ! command -v jq &> /dev/null
then
    echo "jq no está instalado. Instalando..."
    sudo apt update && sudo apt install jq -y
fi

# 1.2. Obtener IDs de red (VPC por defecto y Subnets públicas)
echo "Obteniendo IDs de red de la VPC por defecto..."
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query "Vpcs[0].VpcId" --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=map-public-ip-on-launch,Values=true --query "Subnets[*].SubnetId" --output text | tr '\t' ',')

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ]; then
    echo "ERROR: No se pudo encontrar la VPC por defecto o las subredes públicas. Asegúrate de que existen."
    exit 1
fi

echo "VPC ID: $VPC_ID"
echo "Subnet IDs: $SUBNET_IDS"

# 1.3. Verificar si el archivo de parámetros existe
if [ ! -f "parameters/params.json" ]; then
    echo "ERROR: El archivo parameters/params.json no se encuentra. Asegúrate de que existe y contiene los parámetros correctos."
    exit 1
fi

echo "--- 2. Despliegue de Infraestructura (CloudFormation) ---"

# 2.1. Despliegue de S3 (Almacenamiento de Objetos)
echo "Desplegando Stack de S3 (mvp-s3-stack)..."
aws cloudformation deploy \
  --stack-name mvp-s3-stack \
  --template-file infra/cloudformation/s3-bucket.yml \
  --parameter-overrides file://parameters/params.json \
  --capabilities CAPABILITY_NAMED_IAM

# 2.2. Despliegue de App Runner y ECR (Cómputo y Repositorio)
echo "Desplegando Stack de App Runner y ECR (mvp-apprunner-stack)..."
aws cloudformation deploy \
  --stack-name mvp-apprunner-stack \
  --template-file infra/cloudformation/apprunner.yml \
  --parameter-overrides file://parameters/params.json \
  --capabilities CAPABILITY_NAMED_IAM

# 2.3. Despliegue de RDS (Base de Datos)
echo "Desplegando Stack de RDS (mvp-rds-stack)..."
aws cloudformation deploy \
  --stack-name mvp-rds-stack \
  --template-file infra/cloudformation/rds-micro.yml \
  --parameter-overrides file://parameters/params.json VpcId="$VPC_ID" SubnetIds="$SUBNET_IDS" \
  --capabilities CAPABILITY_NAMED_IAM

echo "--- 3. Despliegue de Infraestructura Completado ---"
echo "Los stacks de CloudFormation se están creando. Puedes monitorear su progreso en la consola de AWS."
echo "Una vez que todos los stacks estén en estado CREATE_COMPLETE, procede al Paso 4."

echo "--- 4. Despliegue de Código (GitHub Actions) ---"
echo "Para desplegar el código, haz commit y push de tus cambios a la rama 'main'."
echo "El workflow de GitHub Actions se encargará de construir la imagen y actualizar el servicio App Runner."
echo "Comandos a ejecutar:"
echo "git add ."
echo "git commit -m 'feat: Infraestructura MVP Free Tier desplegada'"
echo "git push origin main"