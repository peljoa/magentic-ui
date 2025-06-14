# Magentic-UI Azure Deployment with Azure Developer CLI (azd)

This guide shows how to deploy Magentic-UI to Azure using the Azure Developer CLI (azd) for a streamlined development and deployment experience.

## 🚀 Why Azure Developer CLI?

Azure Developer CLI (azd) provides:
- **🏗️ Infrastructure as Code** - Terraform templates for reproducible deployments
- **🔄 Integrated CI/CD** - Built-in GitHub Actions integration
- **📊 Monitoring** - Easy access to application logs and metrics
- **🛠️ Developer-friendly** - Simple commands for common tasks
- **💰 Cost-effective** - Uses Azure Container Instances for reliable hosting

## 📋 Architecture Overview

The deployment creates:

- **Azure Container Instances** - Reliable, cost-effective container hosting
- **Azure Container Registry** - Private Docker image storage
- **Azure Storage Account** - Persistent data storage with Azure Files
- **Azure Key Vault** - Secure secrets management
- **Log Analytics Workspace** - Centralized logging and monitoring
- **Application Insights** - Application performance monitoring
- **Virtual Network** - Secure networking with private endpoints

## 🛠️ Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Azure Developer CLI** - [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
3. **Docker** - [Install Docker](https://docs.docker.com/get-docker/)
4. **Active Azure Subscription** with appropriate permissions

## 🚀 Quick Start

### 1. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with your API keys
nano .env
```

Required variables in `.env`:
```bash
# Required: OpenAI API Key
OPENAI_API_KEY=sk-your-openai-api-key

# Optional: Azure OpenAI (if using Azure OpenAI instead)
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-azure-openai-api-key

# Optional: Anthropic API
ANTHROPIC_API_KEY=your-anthropic-api-key

# Deployment settings
AZURE_ENV_NAME=dev
AZURE_LOCATION=westeurope
ENABLE_VNC_BROWSER=true
```

### 2. Deploy to Azure

```bash
# One-command deployment
./azd-deploy.sh deploy
```

This will:
- ✅ Check prerequisites
- ✅ Login to Azure (if needed)
- ✅ Initialize the azd project
- ✅ Deploy infrastructure (Bicep templates)
- ✅ Build and deploy containers
- ✅ Display access URLs

## 🔧 Management Commands

### Deploy Everything
```bash
./azd-deploy.sh deploy
# or
azd up
```

### Deploy Only Application Changes
```bash
./azd-deploy.sh app
# or
azd deploy
```

### View Application Logs
```bash
./azd-deploy.sh logs
# or
azd monitor
```

### Show Environment Information
```bash
./azd-deploy.sh info
# or
azd env show
```

### Destroy All Resources
```bash
./azd-deploy.sh destroy
# or
azd down
```

## 🌐 Accessing Your Deployment

After deployment, you can access:

- **Magentic-UI**: Displayed in deployment output
- **VNC Browser** (if enabled): Also displayed in deployment output
- **Azure Portal**: Monitor resources and costs

Get URLs anytime:
```bash
azd env get-values | grep URI
```

## 💰 Cost Management

### Estimated Monthly Costs
- **Container Instances**: ~$25-50/month (always-on containers)
- **Storage Account**: ~$1-5/month
- **Container Registry**: ~$5/month (Basic SKU)
- **Key Vault**: ~$1-2/month
- **Monitoring**: ~$5-10/month
- **Virtual Network**: ~$5-8/month

**Total estimated cost: ~$43-75/month**

### Cost Optimization Features
- **Basic SKUs** - Cost-effective service tiers for non-production workloads
- **Efficient resource allocation** - Right-sized containers for workload
- **Configurable resources** - Adjust CPU/memory as needed
- **Shared infrastructure** - Multiple containers in same container group

## 🔐 Security Best Practices

### 1. Secrets Management
- All secrets stored securely in Azure Key Vault
- Environment variables loaded from `.env` file
- No secrets in code or configuration files

### 2. Network Security
- Container Apps with ingress controls
- Private container registry access
- HTTPS-only communication

### 3. Access Control
- Azure RBAC for resource management
- Managed identities for service-to-service auth
- Key Vault access policies

## 📊 Monitoring and Debugging

### View Application Logs
```bash
azd monitor --logs
```

### Access Application Insights
```bash
azd monitor --overview
```

### Debug Container Issues
```bash
# View container logs
az containerapp logs show --name <app-name> --resource-group <rg-name>

# View container environment
azd env show
```

## 🔄 CI/CD Integration

### Setup GitHub Actions
```bash
# Initialize GitHub Actions workflow
azd pipeline config

# Commit and push to trigger deployment
git add .
git commit -m "Add Azure deployment"
git push
```

This creates a GitHub Actions workflow that:
- Triggers on push to main branch
- Builds and deploys automatically
- Uses Azure service principal for authentication

### Manual GitHub Setup
If you prefer manual setup, azd can generate the workflow files:
```bash
azd pipeline config --provider github
```

## 🐛 Troubleshooting

### Common Issues

1. **Environment file missing**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

2. **Azure login issues**
   ```bash
   azd auth login
   az login
   ```

3. **Container startup failures**
   ```bash
   # Check container logs
   azd monitor --logs
   
   # Verify environment variables
   azd env show
   ```

4. **Permission errors**
   - Ensure you have Contributor access to the Azure subscription
   - Check that service principal has correct permissions

5. **Build failures**
   ```bash
   # Check Docker is running
   docker version
   
   # Rebuild and redeploy
   azd deploy --force
   ```

### Get Support
- **View logs**: `azd monitor --logs`
- **Check environment**: `azd env show`
- **Azure portal**: Monitor resources and costs
- **GitHub Issues**: Report bugs or get help

## 🔄 Updating Magentic-UI

To update to a new version:

1. **Pull latest changes**:
   ```bash
   git pull origin main
   ```

2. **Deploy updates**:
   ```bash
   ./azd-deploy.sh app
   ```

3. **For infrastructure changes**:
   ```bash
   ./azd-deploy.sh deploy
   ```

## 🧹 Cleanup

To remove all Azure resources:

```bash
./azd-deploy.sh destroy
```

⚠️ **Warning**: This permanently deletes all data and resources!

## 📁 Project Structure

```
.
├── azure.yaml                 # azd project configuration
├── .env.example              # Environment variables template
├── azd-deploy.sh             # Deployment script
├── Dockerfile                # Main application container
├── Dockerfile.vnc            # VNC browser container
├── terraform/                # Infrastructure as Code (Terraform)
│   ├── main.tf              # Main deployment template
│   ├── variables.tf         # Variable definitions
│   ├── outputs.tf           # Output values
│   ├── containers.tf        # Container definitions
│   ├── secrets.tf           # Key Vault secrets
│   ├── monitoring.tf        # Monitoring resources
│   └── terraform.tfvars.tmpl # Variables template for azd
└── ...
```

## 🆚 Comparison: azd + Terraform vs Pure Terraform

| Feature | azd + Terraform | Pure Terraform |
|---------|-----------------|----------------|
| **Learning Curve** | Lower | Higher |
| **Azure Integration** | Seamless | Manual setup |
| **Deployment Speed** | Faster | Slower |
| **CI/CD Setup** | Built-in | Manual |
| **Monitoring** | Integrated | External tools |
| **Developer Experience** | Streamlined | Complex |
| **Infrastructure** | Container Instances | Container Instances |

## 📚 Additional Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Azure Container Instances Documentation](https://docs.microsoft.com/en-us/azure/container-instances/)
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Magentic-UI Documentation](../README.md)

## 🤝 Contributing

To contribute to the Azure deployment configuration:

1. Make changes to Terraform templates in `terraform/`
2. Test with `azd up`
3. Submit a pull request

For infrastructure changes, please test thoroughly and document any breaking changes.
