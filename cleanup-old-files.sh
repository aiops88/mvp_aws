#!/bin/bash

echo "🧹 Limpiando archivos obsoletos..."

# Crear backup por si acaso
echo "📦 Creando backup..."
mkdir -p backup-$(date +%Y%m%d)
cp -r infra templates .github CI Dockerfile deploy-mvp.sh backup-$(date +%Y%m%d)/ 2>/dev/null || true

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
rm -f CI/buildspec.yml
rm -rf CI/

# GitHub Actions antiguo
rm -f .github/workflows/deploy.yml

# Dockerfile raíz (duplicado)
rm -f Dockerfile

echo "✅ Limpieza completada"
echo ""
echo "📂 Estructura final:"
tree -L 2 -I 'target|node_modules|backup*'

echo ""
echo "⚠️  IMPORTANTE: Los backups están en backup-$(date +%Y%m%d)/"
echo "   Si todo funciona bien, puedes eliminarlos después."