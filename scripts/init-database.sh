#!/bin/bash
set -e

PROJECT_NAME="festivos-api"
REGION="us-east-1"

echo "🗄️  Inicializando base de datos..."

# Obtener endpoint de RDS
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-rds \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpointAddress'].OutputValue" \
  --output text \
  --region $REGION)

echo "📍 Conectando a: $DB_ENDPOINT"

# Ejecutar script SQL
PGPASSWORD=festivos2024 psql \
  -h $DB_ENDPOINT \
  -U postgres \
  -d festivos \
  -f bd/init.sql

echo "✅ Base de datos inicializada correctamente"