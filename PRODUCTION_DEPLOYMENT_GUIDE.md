# Magentic-UI Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying Magentic-UI to production with MSAL authentication, security hardening, and monitoring.

## Deployment Architecture

```mermaid
graph TB
    subgraph "Internet"
        A[Users]
    end
    
    subgraph "Azure Cloud"
        B[Azure Front Door]
        C[Azure App Service]
        D[Azure Container Instances]
        E[Azure Database for PostgreSQL]
        F[Azure Active Directory]
        G[Azure Key Vault]
        H[Azure Monitor]
    end
    
    subgraph "Application Components"
        I[Load Balancer]
        J[Frontend Container]
        K[Backend API Container]
        L[Background Workers]
    end
    
    A --> B
    B --> I
    I --> J
    I --> K
    K --> L
    K --> E
    J --> F
    K --> F
    K --> G
    
    C --> J
    C --> K
    D --> L
    
    H --> C
    H --> D
    H --> E
    
    style A fill:#e1f5fe
    style F fill:#fff3e0
    style E fill:#e8f5e8
    style H fill:#fce4ec
```

## Pre-Deployment Checklist

### 1. Azure Resources Setup

- [ ] Azure Active Directory tenant configured
- [ ] App Registration created with proper permissions
- [ ] Azure App Service or Container Instances provisioned
- [ ] Azure Database for PostgreSQL configured
- [ ] Azure Key Vault for secrets management
- [ ] Azure Monitor and Application Insights enabled
- [ ] Domain name and SSL certificate configured

### 2. Environment Configuration

- [ ] Production environment variables set
- [ ] Database migrations ready
- [ ] SSL/TLS certificates configured
- [ ] CDN configuration (optional)
- [ ] Backup and disaster recovery plan

### 3. Security Verification

- [ ] Security scan completed
- [ ] Dependency vulnerabilities checked
- [ ] CORS policies configured
- [ ] Rate limiting implemented
- [ ] Authentication flow tested
- [ ] Authorization controls verified

## Step-by-Step Deployment

### Step 1: Azure Active Directory Setup

1. **Create App Registration**:
```bash
# Using Azure CLI
az ad app create \
    --display-name "Magentic-UI Production" \
    --web-redirect-uris "https://your-domain.com/auth/callback" \
    --web-home-page-url "https://your-domain.com"
```

2. **Configure API Permissions**:
```bash
# Add Microsoft Graph permissions
az ad app permission add \
    --id {app-id} \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope

# Grant admin consent
az ad app permission admin-consent --id {app-id}
```

3. **Create Client Secret**:
```bash
az ad app credential reset \
    --id {app-id} \
    --append \
    --credential-description "Production Secret"
```

### Step 2: Azure Infrastructure Deployment

#### Option A: Azure App Service

```bash
# Create resource group
az group create --name magentic-ui-prod --location eastus

# Create App Service plan
az appservice plan create \
    --name magentic-ui-plan \
    --resource-group magentic-ui-prod \
    --sku P1V2 \
    --is-linux

# Create web app
az webapp create \
    --resource-group magentic-ui-prod \
    --plan magentic-ui-plan \
    --name magentic-ui-prod \
    --deployment-container-image-name magentic-ui:latest
```

#### Option B: Azure Container Instances

```bash
# Create container group
az container create \
    --resource-group magentic-ui-prod \
    --name magentic-ui-container \
    --image magentic-ui:latest \
    --dns-name-label magentic-ui-prod \
    --ports 80 443 \
    --cpu 2 \
    --memory 4
```

### Step 3: Database Setup

```bash
# Create PostgreSQL server
az postgres server create \
    --resource-group magentic-ui-prod \
    --name magentic-ui-db \
    --location eastus \
    --admin-user pgadmin \
    --admin-password {secure-password} \
    --sku-name GP_Gen5_2

# Create database
az postgres db create \
    --resource-group magentic-ui-prod \
    --server-name magentic-ui-db \
    --name magentic_ui

# Configure firewall rules
az postgres server firewall-rule create \
    --resource-group magentic-ui-prod \
    --server magentic-ui-db \
    --name AllowAzureServices \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0
```

### Step 4: Key Vault Configuration

```bash
# Create Key Vault
az keyvault create \
    --name magentic-ui-kv \
    --resource-group magentic-ui-prod \
    --location eastus

# Add secrets
az keyvault secret set \
    --vault-name magentic-ui-kv \
    --name "azure-client-secret" \
    --value "{client-secret}"

az keyvault secret set \
    --vault-name magentic-ui-kv \
    --name "jwt-secret-key" \
    --value "{jwt-secret}"

az keyvault secret set \
    --vault-name magentic-ui-kv \
    --name "database-url" \
    --value "postgresql://pgadmin:{password}@magentic-ui-db.postgres.database.azure.com/magentic_ui"
```

### Step 5: Application Configuration

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  frontend:
    image: magentic-ui-frontend:latest
    ports:
      - "80:80"
      - "443:443"
    environment:
      - NODE_ENV=production
      - REACT_APP_API_URL=https://your-domain.com/api
      - REACT_APP_AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
      - REACT_APP_AZURE_TENANT_ID=${AZURE_TENANT_ID}
    depends_on:
      - backend

  backend:
    image: magentic-ui-backend:latest
    ports:
      - "8000:8000"
    environment:
      - ENVIRONMENT=production
      - DATABASE_URL=${DATABASE_URL}
      - AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
      - AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
      - AZURE_TENANT_ID=${AZURE_TENANT_ID}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - CORS_ORIGINS=https://your-domain.com
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - frontend
      - backend
```

### Step 6: SSL/TLS Configuration

Create `nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream frontend {
        server frontend:80;
    }
    
    upstream backend {
        server backend:8000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS Server
    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header Strict-Transport-Security "max-age=63072000" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval'" always;

        # API routes
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket support
        location /api/ws/ {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Frontend routes
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

### Step 7: Database Migration

```bash
# Run database migrations
docker exec -it magentic-ui-backend python -m alembic upgrade head

# Create initial admin user (if needed)
docker exec -it magentic-ui-backend python -c "
from backend.auth.models import User, UserRole
from backend.web.deps import get_db
user = User(
    email='admin@yourcompany.com',
    name='System Administrator',
    roles=[UserRole.ADMIN]
)
# Save user to database
"
```

### Step 8: Monitoring Setup

Create Azure Monitor alerts:

```bash
# Create action group for notifications
az monitor action-group create \
    --resource-group magentic-ui-prod \
    --name "magentic-ui-alerts" \
    --short-name "magui-alerts"

# Create metric alert for high CPU usage
az monitor metrics alert create \
    --name "High CPU Usage" \
    --resource-group magentic-ui-prod \
    --scopes /subscriptions/{subscription-id}/resourceGroups/magentic-ui-prod/providers/Microsoft.Web/sites/magentic-ui-prod \
    --condition "avg Percentage CPU > 80" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action magentic-ui-alerts

# Create availability test
az monitor app-insights web-test create \
    --resource-group magentic-ui-prod \
    --app-insights magentic-ui-insights \
    --name "Homepage Availability" \
    --location "East US" \
    --url "https://your-domain.com" \
    --frequency 300
```

## Environment Variables

Create `.env.production`:

```bash
# Application
ENVIRONMENT=production
DEBUG=false
API_DOCS=false

# Azure AD
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
AZURE_TENANT_ID=your-tenant-id
AZURE_REDIRECT_URI=https://your-domain.com/auth/callback
AZURE_POST_LOGOUT_URI=https://your-domain.com

# JWT
JWT_SECRET_KEY=your-super-secure-secret-key
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS=90

# Database
DATABASE_URL=postgresql://user:pass@host:port/dbname
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=30

# Security
CORS_ORIGINS=https://your-domain.com
RATE_LIMIT_PER_MINUTE=100
SECURE_COOKIES=true
SESSION_TIMEOUT_MINUTES=30

# External Services
AZURE_OPENAI_ENDPOINT=https://your-openai.openai.azure.com/
AZURE_OPENAI_API_KEY=your-openai-key
AZURE_OPENAI_API_VERSION=2024-02-15-preview

# Monitoring
APPLICATIONINSIGHTS_CONNECTION_STRING=your-connection-string
LOG_LEVEL=INFO
```

## Security Hardening

### 1. Application Security

```python
# backend/web/security.py
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# HTTPS redirect
if settings.ENVIRONMENT == "production":
    app.add_middleware(HTTPSRedirectMiddleware)

# Trusted hosts
app.add_middleware(
    TrustedHostMiddleware, 
    allowed_hosts=["your-domain.com", "*.your-domain.com"]
)
```

### 2. Database Security

```sql
-- Create dedicated database user
CREATE USER magentic_ui_app WITH PASSWORD 'secure_password';

-- Grant minimal required permissions
GRANT CONNECT ON DATABASE magentic_ui TO magentic_ui_app;
GRANT USAGE ON SCHEMA public TO magentic_ui_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO magentic_ui_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO magentic_ui_app;

-- Enable row-level security
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_sessions ON sessions FOR ALL TO magentic_ui_app USING (user_id = current_setting('app.user_id'));
```

## Backup and Disaster Recovery

### 1. Database Backup

```bash
# Create automated backup script
#!/bin/bash
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATABASE_URL="postgresql://user:pass@host:port/dbname"

# Create backup
pg_dump $DATABASE_URL | gzip > "$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

# Upload to Azure Blob Storage
az storage blob upload \
    --account-name yourstorageaccount \
    --container-name backups \
    --file "$BACKUP_DIR/backup_$TIMESTAMP.sql.gz" \
    --name "database/backup_$TIMESTAMP.sql.gz"

# Cleanup old local backups (keep last 7 days)
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete
```

### 2. Application Backup

```bash
# Backup configuration and secrets
kubectl create secret generic app-config \
    --from-env-file=.env.production \
    --dry-run=client -o yaml > config-backup.yaml

# Store in version control (encrypted)
git-crypt add config-backup.yaml
git add config-backup.yaml
git commit -m "Backup production configuration"
```

## Health Checks and Monitoring

### 1. Application Health Checks

```python
# backend/web/health.py
from fastapi import APIRouter
from datetime import datetime
import psutil
import asyncpg

router = APIRouter()

@router.get("/health")
async def health_check():
    """Comprehensive health check"""
    checks = {
        "timestamp": datetime.utcnow().isoformat(),
        "status": "healthy",
        "checks": {}
    }
    
    # Database connectivity
    try:
        # Test database connection
        checks["checks"]["database"] = "healthy"
    except Exception as e:
        checks["checks"]["database"] = f"unhealthy: {str(e)}"
        checks["status"] = "unhealthy"
    
    # System resources
    checks["checks"]["cpu_usage"] = f"{psutil.cpu_percent()}%"
    checks["checks"]["memory_usage"] = f"{psutil.virtual_memory().percent}%"
    checks["checks"]["disk_usage"] = f"{psutil.disk_usage('/').percent}%"
    
    # Azure AD connectivity
    try:
        # Test Azure AD endpoint
        checks["checks"]["azure_ad"] = "healthy"
    except Exception as e:
        checks["checks"]["azure_ad"] = f"unhealthy: {str(e)}"
    
    return checks

@router.get("/ready")
async def readiness_check():
    """Kubernetes readiness probe"""
    return {"status": "ready"}

@router.get("/live")
async def liveness_check():
    """Kubernetes liveness probe"""
    return {"status": "alive"}
```

### 2. Monitoring Dashboards

Create Azure Monitor workbook with:

- Application performance metrics
- Authentication success/failure rates
- Database performance
- Error rates and response times
- User activity patterns
- Security events

## Deployment Scripts

### deploy.sh

```bash
#!/bin/bash
set -e

echo "Starting Magentic-UI production deployment..."

# Pull latest images
docker-compose -f docker-compose.prod.yml pull

# Stop existing containers
docker-compose -f docker-compose.prod.yml down

# Start new containers
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 30

# Run health checks
curl -f http://localhost/api/health || exit 1

# Run database migrations
docker-compose -f docker-compose.prod.yml exec -T backend python -m alembic upgrade head

echo "Deployment completed successfully!"

# Send notification
curl -X POST "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK" \
     -H 'Content-type: application/json' \
     --data '{"text":"Magentic-UI deployed successfully to production!"}'
```

### rollback.sh

```bash
#!/bin/bash
set -e

BACKUP_TAG=${1:-"previous"}

echo "Rolling back to version: $BACKUP_TAG"

# Stop current containers
docker-compose -f docker-compose.prod.yml down

# Pull backup images
docker pull magentic-ui-frontend:$BACKUP_TAG
docker pull magentic-ui-backend:$BACKUP_TAG

# Tag as latest
docker tag magentic-ui-frontend:$BACKUP_TAG magentic-ui-frontend:latest
docker tag magentic-ui-backend:$BACKUP_TAG magentic-ui-backend:latest

# Start containers
docker-compose -f docker-compose.prod.yml up -d

echo "Rollback completed!"
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**:
   - Check Azure AD app registration
   - Verify client secret expiration
   - Confirm redirect URIs

2. **Database Connection Issues**:
   - Check firewall rules
   - Verify connection string
   - Test database connectivity

3. **High Memory Usage**:
   - Monitor application logs
   - Check for memory leaks
   - Adjust container resources

4. **Slow Response Times**:
   - Check database query performance
   - Monitor network latency
   - Review application profiling

### Debug Commands

```bash
# Check application logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Connect to database
docker-compose -f docker-compose.prod.yml exec backend psql $DATABASE_URL

# Monitor system resources
docker stats

# Check container health
docker-compose -f docker-compose.prod.yml ps
```

## Post-Deployment Checklist

- [ ] All services are running and healthy
- [ ] Authentication flow works end-to-end
- [ ] Database connections are stable
- [ ] SSL certificates are valid
- [ ] Monitoring alerts are configured
- [ ] Backup procedures are tested
- [ ] Security scan passes
- [ ] Performance benchmarks meet requirements
- [ ] Documentation is updated
- [ ] Team is notified of deployment

## Maintenance Schedule

### Daily
- Monitor application health
- Review error logs
- Check security alerts

### Weekly
- Review performance metrics
- Update security patches
- Test backup procedures

### Monthly
- Security vulnerability scan
- Performance optimization review
- Disaster recovery test
- Documentation updates

This deployment guide ensures a secure, scalable, and maintainable production deployment of Magentic-UI with comprehensive monitoring and security measures.
