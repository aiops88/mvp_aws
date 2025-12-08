#!/bin/bash
set -e

PARAMS_FILE="parameters/params.json"

echo "=== 🔍 Validando credenciales AWS ==="
aws sts get-caller-identity --output text > /dev/null || { echo "❌ Credenciales inválidas"; exit 1; }

echo "=== 📋 Leyendo parámetros desde $PARAMS_FILE ==="
AWS_REGION=$(jq -r '.[] | select(.ParameterKey=="AWSRegion") | .ParameterValue' $PARAMS_FILE)
PROJECT_NAME=$(jq -r '.[] | select(.ParameterKey=="ProjectName") | .ParameterValue' $PARAMS_FILE)

function deploy_stack() {
  local template=$1
  local stack=$2
  echo "=== 🚀 Desplegando $stack ==="
  aws cloudformation deploy \
    --template-file $template \
    --stack-name $stack \
    --parameter-overrides file://$PARAMS_FILE \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --region $AWS_REGION
}

function check_stack_status() {
  local stack=$1
  echo "=== ✅ Verificando $stack ==="
  aws cloudformation wait stack-deploy-complete --stack-name $stack --region $AWS_REGION
  echo "✓ $stack desplegado exitosamente"
}

# FASE 1: Infraestructura Base
echo "🔧 FASE 1: Infraestructura Base"
deploy_stack infra/cloudformation/iam.yml "$PROJECT_NAME-iam"
check_stack_status "$PROJECT_NAME-iam"

deploy_stack infra/cloudformation/vpc.yml "$PROJECT_NAME-vpc" 
check_stack_status "$PROJECT_NAME-vpc"

deploy_stack infra/cloudformation/infra-ecr.yml "$PROJECT_NAME-ecr"
check_stack_status "$PROJECT_NAME-ecr"

# FASE 2: Datos y Cache (SOLO SI EXISTEN TEMPLATES COMPLETOS)
echo "🔧 FASE 2: Datos y Cache"
if [[ -f "infra/cloudformation/rds-complete.yml" ]]; then
  deploy_stack infra/cloudformation/rds-complete.yml "$PROJECT_NAME-rds"
  check_stack_status "$PROJECT_NAME-rds"
fi

if [[ -f "infra/cloudformation/elasticache-complete.yml" ]]; then
  deploy_stack infra/cloudformation/elasticache-complete.yml "$PROJECT_NAME-cache"
  check_stack_status "$PROJECT_NAME-cache"
fi

# FASE 3: Aplicación
echo "🔧 FASE 3: Aplicación"
deploy_stack infra/cloudformation/infra-app.yml "$PROJECT_NAME-app"
check_stack_status "$PROJECT_NAME-app"

# FASE 4: Load Balancer (SOLO SI EXISTE)
echo "🔧 FASE 4: Load Balancer"
if [[ -f "infra/cloudformation/alb-complete.yml" ]]; then
  deploy_stack infra/cloudformation/alb-complete.yml "$PROJECT_NAME-alb"
  check_stack_status "$PROJECT_NAME-alb"
fi

# FASE 5: CI/CD
echo "🔧 FASE 5: CI/CD Pipeline"
deploy_stack infra/cloudformation/pipeline.yml "$PROJECT_NAME-pipeline"
check_stack_status "$PROJECT_NAME-pipeline"

echo "🎉 ✅ Despliegue completo y verificado"
echo "📊 Próximos pasos:"
echo "  1. Subir imagen inicial: docker push <ecr-uri>:latest"
echo "  2. Verificar pipeline: https://console.aws.amazon.com/codepipeline/"
echo "  3. Monitorear ECS service: https://console.aws.amazon.com/ecs/"
