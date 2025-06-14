# Magentic-UI Azure Deployment with Terraform

This directory contains Terraform configuration to deploy Magentic-UI to Azure using cost-effective services while following Azure best practices.

## 📋 Architecture Overview

The deployment creates the following Azure resources:

- **Azure Container Instances (ACI)** - Cost-effective containerized hosting
- **Azure Container Registry (ACR)** - Private Docker image storage
- **Azure Storage Account** - Persistent data storage with Azure Files
- **Azure Key Vault** - Secure secrets management
- **Azure Virtual Network** - Secure networking
- **Log Analytics Workspace** - Monitoring and logging
- **Application Insights** - Application performance monitoring
- **Network Security Group** - Network security rules

## 💰 Cost Optimization Features

- **Azure Container Instances** instead of expensive AKS or App Service
- **Basic SKU** for Container Registry and Key Vault
- **Standard LRS** storage replication (lowest cost)
- **30-day** log retention to minimize storage costs
- **Configurable CPU/Memory** allocation to match workload needs
- **Optional VNC browser** container that can be disabled

## 🛠️ Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Terraform** - [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. **Docker** - [Install Docker](https://docs.docker.com/get-docker/)
4. **Active Azure Subscription** with appropriate permissions

## 🚀 Quick Start

### 1. Login to Azure
```bash
az login
```

### 2. Configure Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy Using Script
```bash
# From the project root directory
./deploy.sh deploy
```

The deployment script will:
- ✅ Check prerequisites
- ✅ Initialize Terraform
- ✅ Plan and apply infrastructure
- ✅ Build and push Docker images
- ✅ Start the containers
- ✅ Display access URLs

## 📝 Configuration

### Required Variables

Edit `terraform/terraform.tfvars`:

```hcl
# Required: OpenAI API Key
openai_api_key = "sk-your-openai-api-key"

# Environment and location
environment = "dev"
location    = "West Europe"
```

### Optional Variables

```hcl
# Azure OpenAI (if using Azure OpenAI instead of OpenAI)
azure_openai_endpoint = "https://your-resource.openai.azure.com/"
azure_openai_api_key  = "your-azure-openai-api-key"

# Anthropic API (optional)
anthropic_api_key = "your-anthropic-api-key"

# Resource allocation
container_cpu    = 1.0  # CPU cores
container_memory = 2.0  # Memory in GB

# VNC browser settings
enable_vnc_browser = true
vnc_password      = "secure-password"

# Security
allowed_ip_ranges = ["your.ip.address/32"]  # Restrict access
```

## 🔧 Manual Deployment Steps

If you prefer manual deployment:

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Plan Deployment
```bash
terraform plan -out=tfplan
```

### 3. Apply Infrastructure
```bash
terraform apply tfplan
```

### 4. Build and Push Images
```bash
# Login to ACR
az acr login --name $(terraform output -raw container_registry_login_server | cut -d'.' -f1)

# Build and push from project root
cd ..
docker build -t $(cd terraform && terraform output -raw container_registry_login_server)/magentic-ui:latest -f docker/Dockerfile .
docker build -t $(cd terraform && terraform output -raw container_registry_login_server)/magentic-ui-vnc:latest -f docker/Dockerfile.browser .

docker push $(cd terraform && terraform output -raw container_registry_login_server)/magentic-ui:latest
docker push $(cd terraform && terraform output -raw container_registry_login_server)/magentic-ui-vnc:latest
```

### 5. Restart Containers
```bash
cd terraform
az container restart --resource-group $(terraform output -raw resource_group_name) --name cg-magentic-ui-$(terraform output -raw environment)
```

## 🌐 Accessing Your Deployment

After deployment, you can access:

- **Magentic-UI**: `http://your-fqdn:8081`
- **VNC Browser** (if enabled): `http://your-fqdn:6080`

Get the exact URLs:
```bash
cd terraform
terraform output magentic_ui_url
terraform output vnc_browser_url
```

## 📊 Monitoring

The deployment includes:

- **Application Insights** for application telemetry
- **Log Analytics** for container logs and metrics
- **Metric Alerts** for CPU and memory usage
- **Diagnostic Settings** for container group monitoring

Access monitoring in the Azure Portal:
1. Go to your Resource Group
2. Click on Application Insights resource
3. Explore metrics, logs, and performance data

## 🔄 Management Commands

### Update Deployment
```bash
./deploy.sh update
```

### Show Deployment Info
```bash
./deploy.sh info
```

### Destroy Infrastructure
```bash
./deploy.sh destroy
```

## 🔐 Security Best Practices

### 1. Secure Secrets Management
- All secrets stored in Azure Key Vault
- Container identity has minimal required permissions
- Secrets accessed via Key Vault references

### 2. Network Security
- Virtual Network with dedicated subnet
- Network Security Group with minimal required rules
- Consider using Azure Private Endpoints for production

### 3. Access Control
- Restrict `allowed_ip_ranges` in terraform.tfvars
- Use strong VNC password
- Enable Azure AD authentication for production

### 4. Monitoring
- Application Insights for application monitoring
- Log Analytics for infrastructure monitoring
- Metric alerts for proactive monitoring

## 💡 Cost Management

### Estimated Monthly Costs (West Europe)
- **Container Instances**: ~$30-50/month (1 vCPU, 2GB RAM)
- **Storage Account**: ~$1-5/month (depends on usage)
- **Container Registry**: ~$5/month (Basic SKU)
- **Key Vault**: ~$1-2/month
- **Networking**: ~$1-3/month
- **Monitoring**: ~$5-10/month

**Total estimated cost: ~$43-75/month**

### Cost Optimization Tips
1. **Stop containers when not in use**:
   ```bash
   az container stop --resource-group <rg-name> --name <container-name>
   ```

2. **Use spot instances** for dev/test environments

3. **Reduce container specifications** if performance allows

4. **Disable VNC browser** if not needed:
   ```hcl
   enable_vnc_browser = false
   ```

## 🐛 Troubleshooting

### Common Issues

1. **Container fails to start**
   - Check container logs: `az container logs --resource-group <rg> --name <container>`
   - Verify API keys are correctly set in Key Vault

2. **Image not found**
   - Ensure Docker images are pushed to ACR
   - Check ACR access permissions

3. **Key Vault access denied**
   - Verify container identity has access policy
   - Check Key Vault firewall settings

4. **High costs**
   - Review container resource allocation
   - Monitor usage with Azure Cost Management

### Get Support
- Check container logs via Azure Portal
- Use `terraform output` to get resource information
- Monitor costs in Azure Cost Management

## 🔄 Updating Magentic-UI

To update to a new version:

1. Pull latest changes
2. Run update script:
   ```bash
   ./deploy.sh update
   ```

This will rebuild and push new Docker images, then restart containers.

## 🧹 Cleanup

To remove all Azure resources:

```bash
./deploy.sh destroy
```

⚠️ **Warning**: This will permanently delete all data and resources!

## 📚 Additional Resources

- [Magentic-UI Documentation](../README.md)
- [Azure Container Instances Documentation](https://docs.microsoft.com/en-us/azure/container-instances/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Cost Management](https://docs.microsoft.com/en-us/azure/cost-management-billing/)
