# 🛒 Infraestructura en AWS - E-Commerce Escalable  
Diagrama de Arquitectura de Aplicación: https://claude.ai/public/artifacts/4b178b01-b748-4162-b8cf-fbe39ab9e34e?fullscreen=false
Este repositorio contiene los **templates de AWS CloudFormation** y configuraciones relacionadas con la **infraestructura del e-commerce**, incluyendo red, seguridad, cómputo, CI/CD y monitoreo.  

El diseño sigue principios de **escalabilidad, alta disponibilidad, seguridad y optimización de costos**, utilizando **Infraestructura como Código (IaC)** para garantizar despliegues reproducibles, automatizados y fáciles de mantener.  

---

## 📌 Estructura del Proyecto  
```
infra/
├── templates/
│ ├── vpc.yml # Red VPC, subnets públicas/privadas, ruteo
│ ├── infra-app.yml # Seguridad, SGs, roles
│ └── ecs-ecr-iam.yml # ECS Cluster, repositorios ECR, roles IAM
└── README_infra.md # Guía detallada de despliegue
```

---

## 📌 Despliegue de Stacks  

- ***Comandos para ejecutar la infraestructura (CloudFormation) manualmente desde local***

1. Desplegar la **VPC**  
```
   aws cloudformation deploy \
     --stack-name ecommerce-stack-vpc \
     --template-file templates/vpc.yml \
     --capabilities CAPABILITY_NAMED_IAM \
     --region us-east-2
Desplegar la Seguridad (SGs, roles básicos)

aws cloudformation deploy \
  --stack-name ecommerce-stack-security \
  --template-file templates/infra-app.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-2
Desplegar ECS, ECR e IAM

aws cloudformation deploy \
  --stack-name ecommerce-stack-ecs-ecr-iam \
  --template-file templates/ecs-ecr-iam.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-2
```

---

## 📌 Despliegue de Stacks  

### **Despliegue Automatizado (Recomendado)**
```bash
# Ejecutar script completo
./scripts/deploy.sh
```
```
# O despliegue por fases
aws cloudformation deploy \
  --stack-name proyectofestivos-vpc \
  --template-file infra/cloudformation/vpc.yml \
  --parameter-overrides file://parameters/params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
Orden de Despliegue Manual
```
```
VPC + Security Groups

cloudformation deploy \
  --stack-name proyectofestivos-vpc \
  --template-file infra/cloudformation/vpc.yml \
  --parameter-overrides file://parameters/params.json \
  --region us-east-1
```
```
IAM Roles

cloudformation deploy \
  --stack-name proyectofestivos-iam \
  --template-file infra/cloudformation/iam.yml \
  --parameter-overrides file://parameters/params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```
```
Base de Datos + Cache

cloudformation deploy \
  --stack-name proyectofestivos-data \
  --template-file infra/cloudformation/rds-aurora.yml \
  --parameter-overrides file://parameters/params.json \
  --region us-east-1

aws cloudformation deploy \
  --stack-name proyectofestivos-cache \
  --template-file infra/cloudformation/elasticache.yml \
  --parameter-overrides file://parameters/params.json \
  --region us-east-1
```
```
Load Balancer + ECS

cloudformation deploy \
  --stack-name proyectofestivos-alb \
  --template-file infra/cloudformation/alb-autoscaling.yml \
  --parameter-overrides file://parameters/params.json \
  --region us-east-1

aws cloudformation deploy \
  --stack-name proyectofestivos-app \
  --template-file infra/cloudformation/infra-app.yml \
  --parameter-overrides file://parameters/params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```
## Monitoreo + CI/CD

bashaws cloudformation deploy \
  --stack-name proyectofestivos-monitoring \
  --template-file infra/cloudformation/monitoring.yml \
  --parameter-overrides file://parameters/params.json \
  --region us-east-1

aws cloudformation deploy \
  --stack-name proyectofestivos-pipeline \
  --template-file infra/cloudformation/pipeline.yml \
  --parameter-overrides file://parameters/params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

## 🔄 CI/CD (Integración y Despliegue Continuo)
Pipeline Automatizado con AWS CodePipeline

CodeConnections para integración con GitHub repository
Construcción de imágenes Docker multi-stage optimizadas
Publicación automática en Amazon ECR con versionado semántico
Despliegue automático en Amazon ECS (Fargate) con Blue/Green
Despliegue de infraestructura con CloudFormation IaC
Soporte multi-ambiente: dev, staging y prod con promoción controlada

Pipelines Alternativos Soportados

GitHub Actions: Para proyectos con workflows en GitHub
Jenkins: Para entornos híbridos con integración on-premises
GitLab CI: Para repositorios en GitLab con runners en AWS

##Proceso de CI/CD
    A[Git Push] --> B[CodePipeline]
    B --> C[CodeBuild]
    C --> D[Docker Build]
    D --> E[ECR Push]
    E --> F[ECS Deploy]
    F --> G[Health Check]
    G --> H[Production]

Etapas del Pipeline

Source: Trigger automático desde GitHub
Build: Compilación Maven + Docker multi-stage
Test: JUnit + SonarQube + Security Scanning
Package: Push a ECR con tags automáticos
Deploy: Despliegue ECS con health checks
Verify: Validación automática post-deployment


## 📊 Monitoreo y Observabilidad
Amazon CloudWatch Centralizado

Logs centralizados de ECS Tasks, ALB, Aurora y ElastiCache
Métricas personalizadas de CPU, memoria, latencia y throughput
Alarmas configuradas para alta latencia, errores 5xx y baja disponibilidad
Trazabilidad de peticiones entre microservicios con X-Ray
Dashboards ejecutivos para stakeholders no técnicos

Dashboards en CloudWatch para Métricas Clave

Estado de ECS Services y tareas en tiempo real
Salud de instancias detrás del Load Balancer
Consumo y performance de base de datos Aurora
Hit ratio y latencia de ElastiCache Redis
Throughput y errores del Application Load Balancer

Alertas Proactivas

CPU > 80%: Auto-scaling automático + notificación
Latencia > 2s: Escalado inmediato + investigación
Errores 5xx > 5%: Rollback automático + escalado
DB Connections > 80%: Alertas preventivas
Cache Miss > 30%: Optimización de consultas

Métricas de Negocio

Requests/segundo por endpoint de festivos
Tiempo de respuesta por tipo de consulta
Disponibilidad SLA (objetivo: 99.9%)
Errores por país/región para análisis geográfico


## 🔒 Seguridad
Gestión de Accesos con IAM

Roles y Policies bajo principio de privilegio mínimo
Separación de roles por servicio (ECS, ECR, RDS, ElastiCache, CI/CD)
Cross-account roles para separación de entornos
MFA requerido para acciones administrativas críticas

## AWS Secrets Manager

Manejo centralizado de contraseñas y secretos cifrados
Rotación automática de credenciales de base de datos
Integración nativa con ECS para inyección segura
Auditoría completa de acceso a secretos

## Network Security

Subnets públicas/privadas para aislar componentes por capas
Security Groups segmentados:

Frontend (ALB): Solo HTTP/HTTPS desde internet
Backend (ECS): Solo tráfico desde ALB
Base de datos: Solo conexiones desde ECS
Cache: Solo conexiones desde ECS

NACLs restrictivas como segunda capa de defensa
VPC Flow Logs para análisis de tráfico y detección de anomalías

## Cifrado y Protección

Cifrado en tránsito: HTTPS con TLS 1.2+ end-to-end
Cifrado en reposo: Aurora, ElastiCache y ECR con KMS
AWS WAF + Shield: Protección contra ataques comunes

SQL Injection prevention
XSS filtering
DDoS mitigation automática


Security scanning de imágenes Docker en ECR

## Compliance y Auditoría

CloudTrail para auditoría de todas las acciones API
Config Rules para compliance continuo
GuardDuty para detección de amenazas
Security Hub para postura de seguridad centralizada


## 🎯 Requisitos del Reto
🔹 Escalabilidad

ECS Fargate Auto Scaling: Escala de 2 a 10 tareas automáticamente basado en CPU/memoria
Aurora Serverless v2: Escalado automático de capacidad de base de datos (0.5-4 ACUs)
ElastiCache Redis: Distribución de carga de consultas frecuentes
Application Load Balancer: Distribución inteligente de tráfico entre instancias

🔹 Alta Disponibilidad

Multi-AZ Deployment: Todos los componentes desplegados en múltiples zonas de disponibilidad
Aurora Multi-AZ: Failover automático en <30 segundos
ECS Service: Mantenimiento automático del número deseado de tareas
ALB Health Checks: Detección y remoción automática de instancias no saludables
ElastiCache con Replication: Failover automático del cache

🔹 Rendimiento Óptimo

ElastiCache Redis: Cache de consultas de festivos reduce latencia de DB en 80%
Aurora PostgreSQL: Optimizado para cargas de trabajo transaccionales
ECS Fargate: Recursos dedicados sin overhead de EC2
ALB: Balanceo de carga optimizado con algoritmos avanzados
Connection Pooling: Gestión eficiente de conexiones de base de datos

🔹 Arquitectura Serverless y Administrada

ECS Fargate: Contenedores sin gestión de servidores
Aurora Serverless v2: Base de datos completamente administrada
ElastiCache: Cache administrado sin configuración manual
Application Load Balancer: Balanceo administrado
CodePipeline/CodeBuild: CI/CD completamente administrado
CloudWatch: Monitoreo administrado sin agentes

🔹 Observabilidad Completa

CloudWatch Dashboards: Métricas en tiempo real de todos los componentes
Alarmas Proactivas: Detección temprana de problemas
Logs Centralizados: Agregación y búsqueda unificada
Health Checks Multi-Nivel: Validación end-to-end
Trazabilidad Distribuida: Seguimiento de requests entre servicios

🔹 Seguridad Robusta

Defense in Depth: Múltiples capas de seguridad
Zero Trust Network: Verificación explícita en cada capa
Secrets Management: Gestión segura de credenciales
Compliance: Adherencia a mejores prácticas de seguridad
Threat Detection: Monitoreo proactivo de amenazas

🔹 Costos Optimizados

Pago por Uso: Fargate, Aurora Serverless, ElastiCache bajo demanda
Auto Scaling: Evita sobre-provisionamiento (ahorro ~40%)
Reserved Instances: Para componentes base con descuentos
Lifecycle Policies: Limpieza automática de recursos no utilizados
Estimación Total: $222-402/mes para tráfico de producción


## ✅ Requisitos Previos
Herramientas Necesarias

AWS CLI configurado con credenciales administrativas
Docker instalado para desarrollo y testing local
Git para control de versiones y integración CI/CD
jq para procesamiento de JSON en scripts

Permisos AWS Requeridos

Crear recursos: IAM, VPC, ECS, ECR, RDS, ElastiCache, CloudWatch
Gestionar pipelines: CodePipeline, CodeBuild, CodeDeploy
Administrar seguridad: Secrets Manager, KMS, WAF
Monitoreo: CloudWatch, X-Ray, CloudTrail

Configuración Inicial

Región: us-east-1 (configurable en params.json)
GitHub Repository con conexión CodeStar configurada
Dominios: Para certificados SSL (opcional)
Notificaciones: Email para alarmas críticas


🚀 Próximos Pasos

Clonar repositorio: git clone <repo-url>
Configurar parámetros: Editar parameters/params.json
Ejecutar despliegue: ./scripts/deploy.sh
Verificar pipeline: AWS Console → CodePipeline
Monitorear aplicación: CloudWatch Dashboard
Probar API: ALB DNS → /api/festivos/listar
Revisar costos: AWS Cost Explorer


📞 Soporte y Troubleshooting
Recursos de Monitoreo

Pipeline Status: CodePipeline Console
Application Logs: CloudWatch Logs Groups
Infrastructure Health: CloudWatch Dashboards
Cost Analysis: AWS Cost Explorer

Documentación Técnica

API Endpoints: /api/festivos/* documentados en Swagger
Database Schema: Scripts SQL en /bd/ directory
Docker Images: Multi-stage optimizadas en ECR
Health Checks: /actuator/health endpoint

Para issues de infraestructura, consultar los logs de CloudFormation y CloudWatch

## Estimación básica de costos (ejemplo mensual en us-east-1)
Esto es solo un escenario base con tráfico moderado y autoescalado activado.
ECS Fargate
- 2 servicios (frontend + backend), cada uno con 2 tasks mínimos (0.5 vCPU + 1GB RAM).
- ~$50–60 USD/mes (depende del uso real)
Application Load Balancer (ALB)
- ~$18 USD/mes (fijo).
VPC + NAT Gateway
- NAT Gateway ~ $32 USD/mes (1 unidad).
VPC y subnets no tienen costo adicional directo.
ECR (almacenamiento de imágenes)
~ $1–2 USD/mes (por 1–2 GB).
CloudWatch Logs y métricas
~ $10–20 USD/mes (depende del volumen de logs).
S3 (para artefactos/estáticos)
~ $1–5 USD/mes.

📌 Total estimado: entre $110–140 USD/mes en un escenario base.
Con picos altos y más tasks escaladas en ECS, el costo puede crecer proporcionalmente
