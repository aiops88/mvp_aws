# 🎉 API de Festivos - Arquitectura AWS Serverless

API REST en Spring Boot para consultar festivos por país y año, desplegada en AWS con arquitectura serverless usando ECS Fargate, RDS PostgreSQL y CloudFormation como IaC.

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Arquitectura](#-arquitectura)
- [Tecnologías](#-tecnologías)
- [Prerequisitos](#-prerequisitos)
- [Despliegue en AWS](#-despliegue-en-aws)
- [Endpoints de la API](#-endpoints-de-la-api)
- [Desarrollo Local](#-desarrollo-local)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Costos Estimados](#-costos-estimados)
- [Troubleshooting](#-troubleshooting)

---

## ✨ Características

- **Consulta de Festivos**: Por país, año y fecha específica
- **Cálculo Inteligente**: Soporte para festivos fijos, móviles (Pascua) y Ley de Puente Festivo
- **API RESTful**: Endpoints documentados con Swagger/OpenAPI
- **Alta Disponibilidad**: Arquitectura Multi-AZ con autoescalado
- **Infraestructura como Código**: Despliegue reproducible con CloudFormation
- **Monitoreo Integrado**: CloudWatch Logs y métricas en tiempo real

---

## 🏗️ Arquitectura

```
┌─────────────┐
│   Cliente   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────────────────┐
│         ECS Fargate (Auto Scaling)      │
│  ┌─────────────┐    ┌─────────────┐    │
│  │  Task 1     │    │  Task 2     │    │
│  │  Spring API │    │  Spring API │    │
│  │  Port 8080  │    │  Port 8080  │    │
│  └─────────────┘    └─────────────┘    │
└────────────┬────────────────────────────┘
             │
             ▼
    ┌────────────────┐
    │  RDS PostgreSQL │
    │   Multi-AZ      │
    │   db.t3.micro   │
    └────────────────┘
```

### Componentes Principales

1. **Amazon ECS Fargate**: Contenedores serverless con Spring Boot
2. **Amazon RDS PostgreSQL**: Base de datos relacional Multi-AZ
3. **Amazon ECR**: Registro privado de imágenes Docker
4. **CloudWatch**: Logs centralizados y monitoreo
5. **VPC por Defecto**: Red con subnets públicas para el MVP

---

## 🛠️ Tecnologías

### Backend
- **Java 17** con Spring Boot 3.5.0
- **Maven** para gestión de dependencias
- **JPA/Hibernate** para persistencia
- **PostgreSQL** como base de datos

### Infraestructura
- **AWS ECS Fargate** (Serverless Compute)
- **AWS RDS** (PostgreSQL 14.17)
- **AWS ECR** (Container Registry)
- **CloudFormation** (IaC)
- **Docker** (Containerización)

### CI/CD
- Maven para compilación
- Docker multi-stage builds
- CloudFormation para despliegue
- Health checks automatizados

---

## 📦 Prerequisitos

### Herramientas Requeridas

```bash
# AWS CLI configurado
aws --version

# Docker instalado (para build local)
docker --version

# PostgreSQL client (para init DB)
psql --version

# Git
git --version
```

### Credenciales AWS

```bash
# Configurar AWS CLI
aws configure
# AWS Access Key ID: [tu-access-key]
# AWS Secret Access Key: [tu-secret-key]
# Default region: us-east-1
# Default output format: json
```

### Permisos IAM Necesarios

Tu usuario AWS debe tener permisos para:
- CloudFormation (crear/actualizar stacks)
- ECS (crear clusters, servicios, task definitions)
- ECR (crear repositorios, push de imágenes)
- RDS (crear instancias)
- EC2 (gestionar VPC, Security Groups, subnets)
- IAM (crear roles y policies)
- CloudWatch (crear log groups)

---

## 🚀 Despliegue en AWS

### Opción 1: Despliegue Completo (Recomendado)

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd festivos-api

# 2. Configurar permisos de ejecución
chmod +x .github/workflows/deploy-ecs.yml

# 3. Ejecutar despliegue completo
bash .github/workflows/deploy-ecs.yml
```

**⏱️ Tiempo estimado**: 15-20 minutos

Este script ejecuta automáticamente:
1. ✅ Configuración de red (VPC y subnets)
2. ✅ Creación de repositorio ECR
3. ✅ Despliegue de base de datos RDS
4. ✅ Creación de cluster ECS y servicio
5. ✅ Build y push de imagen Docker
6. ✅ Inicialización de base de datos

---

### Opción 2: Despliegue Manual por Componentes

#### Paso 1: Desplegar ECR

```bash
aws cloudformation deploy \
  --stack-name festivos-api-ecr \
  --template-file infra/cloudformation/infra-ecr.yml \
  --parameter-overrides ProjectName=festivos-api \
  --region us-east-1
```

#### Paso 2: Obtener URI del ECR

```bash
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name festivos-api-ecr \
  --query "Stacks[0].Outputs[?OutputKey=='ECRBackendUri'].OutputValue" \
  --output text \
  --region us-east-1)

echo "ECR URI: $ECR_URI"
```

#### Paso 3: Build y Push de Imagen Docker

```bash
# Login en ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${ECR_URI%%/*}

# Build de imagen
docker build -t festivos-api:latest -f apiFestivos/Dockerfile apiFestivos/

# Tag y push
docker tag festivos-api:latest $ECR_URI:latest
docker push $ECR_URI:latest
```

#### Paso 4: Desplegar Base de Datos RDS

```bash
# Obtener VPC y subnets por defecto
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=is-default,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region us-east-1)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region us-east-1 | tr '\t' ',')

# Desplegar RDS
aws cloudformation deploy \
  --stack-name festivos-api-rds \
  --template-file infra/cloudformation/rds-micro.yml \
  --parameter-overrides \
    DBInstanceIdentifier=festivos-api-db \
    DBName=festivos \
    DBUser=postgres \
    DBPassword=festivos2024 \
    VpcId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Esperar a que se complete (5-10 minutos)
aws cloudformation wait stack-create-complete \
  --stack-name festivos-api-rds \
  --region us-east-1
```

#### Paso 5: Obtener Endpoint de RDS

```bash
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name festivos-api-rds \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpointAddress'].OutputValue" \
  --output text \
  --region us-east-1)

echo "DB Endpoint: $DB_ENDPOINT"
```

#### Paso 6: Inicializar Base de Datos

```bash
# Instalar PostgreSQL client si no está instalado
# Ubuntu/Debian: sudo apt-get install postgresql-client
# MacOS: brew install postgresql

# Conectar y ejecutar script de inicialización
PGPASSWORD=festivos2024 psql \
  -h $DB_ENDPOINT \
  -U postgres \
  -d festivos \
  -f bd/init.sql
```

#### Paso 7: Desplegar ECS Fargate

```bash
aws cloudformation deploy \
  --stack-name festivos-api-ecs \
  --template-file infra/cloudformation/infra-ecs-simplified.yml \
  --parameter-overrides \
    ProjectName=festivos-api \
    VPCId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
    DBEndpoint=$DB_ENDPOINT \
    DBName=festivos \
    DBUser=postgres \
    DBPassword=festivos2024 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Esperar a que se complete
aws cloudformation wait stack-create-complete \
  --stack-name festivos-api-ecs \
  --region us-east-1
```

#### Paso 8: Obtener IP Pública de la API

```bash
# Obtener nombre del cluster y servicio
CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name festivos-api-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECSClusterName'].OutputValue" \
  --output text \
  --region us-east-1)

SERVICE_NAME=$(aws cloudformation describe-stacks \
  --stack-name festivos-api-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='ECSServiceName'].OutputValue" \
  --output text \
  --region us-east-1)

# Listar tareas
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region us-east-1 \
  --query "taskArns[0]" \
  --output text)

# Obtener detalles de la tarea
TASK_DETAILS=$(aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region us-east-1)

# Obtener ENI ID
ENI_ID=$(echo $TASK_DETAILS | jq -r '.tasks[0].attachments[0].details[] | select(.name=="networkInterfaceId") | .value')

# Obtener IP pública
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --region us-east-1 \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text)

echo "🎉 API desplegada en: http://$PUBLIC_IP:8080"
```

---

## 📡 Endpoints de la API

### Base URL
```
http://<PUBLIC_IP>:8080
```

### Health Check
```bash
curl http://<PUBLIC_IP>:8080/actuator/health
```

### Listar Países
```bash
curl http://<PUBLIC_IP>:8080/api/paises/listar
```

### Listar Festivos de Colombia 2024
```bash
curl http://<PUBLIC_IP>:8080/api/festivos/listar/1/2024
```

### Verificar si una Fecha es Festivo
```bash
# Formato: /api/festivos/verificar/{idPais}/{año}/{mes}/{dia}
curl http://<PUBLIC_IP>:8080/api/festivos/verificar/1/2024/1/1
```

### Documentación Swagger
```
http://<PUBLIC_IP>:8080/swagger-ui.html
```

---

## 💻 Desarrollo Local

### Con Docker Compose

```bash
# Levantar servicios
docker-compose up -d

# Ver logs
docker-compose logs -f api-festivos

# Acceder a la API
curl http://localhost:8080/api/festivos/listar
```

### Sin Docker (Requiere PostgreSQL Local)

```bash
# 1. Crear base de datos
psql -U postgres -c "CREATE DATABASE festivos;"

# 2. Ejecutar scripts SQL
psql -U postgres -d festivos -f bd/DDL\ -\ Festivos.sql
psql -U postgres -d festivos -f bd/DML\ -\ Festivos.sql

# 3. Configurar application.properties
cd apiFestivos/presentacion/src/main/resources
# Editar application.properties con tus credenciales locales

# 4. Compilar y ejecutar
cd apiFestivos
mvn clean package
mvn spring-boot:run
```

### Ejecutar Tests

```bash
cd apiFestivos
mvn test
```

---

## 📁 Estructura del Proyecto

```
festivos-api/
├── .github/workflows/
│   └── deploy-ecs.yml          # Script de despliegue completo
├── apiFestivos/
│   ├── aplicacion/              # Capa de aplicación (servicios)
│   ├── core/                    # Interfaces de servicios
│   ├── dominio/                 # Entidades y DTOs
│   ├── infraestructura/         # Repositorios JPA
│   ├── presentacion/            # Controladores REST
│   ├── Dockerfile               # Imagen Docker multi-stage
│   └── pom.xml                  # Configuración Maven
├── bd/
│   ├── init.sql                 # Script de inicialización completo
│   ├── DDL - Festivos.sql       # Definición de tablas
│   └── DML - Festivos.sql       # Datos de prueba
├── infra/cloudformation/
│   ├── infra-ecr.yml           # Repositorios ECR
│   ├── rds-micro.yml           # Base de datos RDS
│   └── infra-ecs-simplified.yml # Cluster ECS y servicio
├── scripts/
│   ├── deploy-all.sh           # Despliegue automatizado
│   └── init-database.sh        # Inicialización de DB
├── docker-compose.yml          # Desarrollo local
├── Makefile                    # Comandos útiles
└── README.md                   # Este archivo
```

---

## 💰 Costos Estimados

### Infraestructura AWS (Mensual)

| Servicio | Configuración | Costo Mensual |
|----------|--------------|---------------|
| **ECS Fargate** | 0.5 vCPU, 1GB RAM, 2 tareas | ~$25-30 |
| **RDS PostgreSQL** | db.t3.micro, 20GB, Single-AZ | ~$15-20 |
| **ECR** | 1GB almacenamiento | ~$0.10 |
| **CloudWatch Logs** | 5GB/mes | ~$2.50 |
| **Data Transfer** | 10GB salida | ~$0.90 |
| **TOTAL ESTIMADO** | | **~$45-55/mes** |

### Notas sobre Costos
- ✅ Eligible para **AWS Free Tier** (primeros 12 meses)
- ⚠️ RDS en Single-AZ para reducir costos (no recomendado para producción)
- 💡 Considera **Auto Scaling** para optimizar costos según demanda
- 💡 Para producción, RDS Multi-AZ agrega ~$15/mes adicionales

---

## 🐛 Troubleshooting

### Error: "No se puede conectar a RDS"

```bash
# Verificar Security Group del RDS
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*rds*" \
  --region us-east-1

# Asegurar que permite tráfico desde 172.31.0.0/16 (VPC por defecto)
```

### Error: "ECS Task no inicia"

```bash
# Ver logs del servicio
CLUSTER_NAME=festivos-api-cluster
SERVICE_NAME=festivos-api-service

aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region us-east-1

# Ver logs de CloudWatch
aws logs tail /ecs/festivos-api --follow --region us-east-1
```

### Error: "Imagen Docker no encontrada en ECR"

```bash
# Verificar que la imagen existe
aws ecr describe-images \
  --repository-name festivos-api-backend \
  --region us-east-1

# Si no existe, hacer push nuevamente
docker push <ECR_URI>:latest
```

### Error: "Base de datos no inicializada"

```bash
# Reconectar y ejecutar init.sql
PGPASSWORD=festivos2024 psql \
  -h <DB_ENDPOINT> \
  -U postgres \
  -d festivos \
  -f bd/init.sql
```

### Health Check Fallando

```bash
# Verificar que el puerto 8080 está expuesto
curl http://<PUBLIC_IP>:8080/actuator/health

# Si falla, verificar Security Group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*ecs*" \
  --region us-east-1

# Debe permitir tráfico TCP en puerto 8080 desde 0.0.0.0/0
```

---

## 🔐 Consideraciones de Seguridad

### ⚠️ IMPORTANTE - NO USAR EN PRODUCCIÓN TAL CUAL

Este proyecto es un **MVP educativo**. Para producción, implementar:

1. **Secrets Manager**: Mover credenciales de DB a AWS Secrets Manager
2. **Load Balancer**: Agregar ALB para balanceo de carga y SSL/TLS
3. **WAF**: Implementar AWS WAF para protección contra ataques
4. **VPC Privada**: Mover RDS a subnets privadas
5. **Autenticación**: Implementar OAuth2/JWT para la API
6. **Rate Limiting**: Proteger contra abuso de endpoints
7. **Multi-AZ**: Habilitar Multi-AZ en RDS para alta disponibilidad

---

## 📝 Limpieza de Recursos

Para evitar costos, eliminar todos los recursos creados:

```bash
# Eliminar stack ECS
aws cloudformation delete-stack --stack-name festivos-api-ecs --region us-east-1

# Eliminar stack RDS
aws cloudformation delete-stack --stack-name festivos-api-rds --region us-east-1

# Eliminar imágenes de ECR
aws ecr batch-delete-image \
  --repository-name festivos-api-backend \
  --image-ids imageTag=latest \
  --region us-east-1

# Eliminar stack ECR
aws cloudformation delete-stack --stack-name festivos-api-ecr --region us-east-1

# Verificar que todo se eliminó
aws cloudformation list-stacks \
  --stack-status-filter DELETE_COMPLETE \
  --region us-east-1
```

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crear una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add: AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver archivo `LICENSE` para más detalles.

---

## 👥 Autor

**Airy Nieves Cárdenas**
**Diciembre 2025**

---

## 🙏 Agradecimientos

- Spring Boot Community
- AWS Documentation
- PostgreSQL Project

---

## 📚 Referencias

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

**¿Preguntas o problemas?** Abre un issue en GitHub o contacta al equipo de desarrollo.
