#!/bin/bash

echo "🧹 Limpiando archivos obsoletos..."

# Eliminar archivos obsoletos
echo "🗑️  Eliminando archivos..."

# Templates CloudFormation obsoletos
rm -f infra/cloudformation/apprunner.yml
rm -f infra/cloudformation/s3-bucket.yml
rm -f infra/cloudformation/infra-app.yml
rm -f infra/cloudformation/infra-ecr.yml
rm -f bd/rds-aurora.yml

# Templates antiguos
rm -rf templates/

# Scripts obsoletos
rm -f deploy-mvp.sh
rm -rf CI/

# GitHub Actions antiguo
rm -f .github/workflows/deploy.yml

# Dockerfile raíz DUPLICADO (el bueno está en apiFestivos/)
rm -f Dockerfile

# Carpeta src vacía
rm -rf apiFestivos/src/

echo "✅ Limpieza completada"