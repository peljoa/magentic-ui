# Azure AI Foundry Setup Guide for Magentic-UI

This guide walks you through setting up Magentic-UI with Azure AI Foundry for secure, enterprise-ready AI agent deployment.

## Prerequisites

1. **Azure Account** with an active subscription
2. **Azure AI Foundry** project and deployed models
3. **Azure CLI** installed and configured
4. **Docker** installed and running
5. **Python 3.11+** and dependencies installed

## Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo>
cd magentic-ui
pip install -e .
```

### 2. Azure Authentication
```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "your-subscription-name"
```

### 3. Configure Environment Variables

**Option A: Using .env file (Recommended)**
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your Azure details
# AZURE_OPENAI_ENDPOINT=https://your-resource.cognitiveservices.azure.com/
# AZURE_OPENAI_DEPLOYMENT=your-deployment-name
# AZURE_OPENAI_MODEL=gpt-4o
```

**Option B: Export environment variables**
```bash
export AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/"
export AZURE_OPENAI_DEPLOYMENT="your-deployment-name"
export AZURE_OPENAI_MODEL="gpt-4o"
```

### 4. Start Magentic-UI
```bash
# Using the startup script (easiest) - generates config.yaml from environment variables
./start-azure.sh

# Or manually generate config and start
./generate-config.sh
python -m magentic_ui.backend.cli --port 8088 --config config.yaml
```

### 5. Access the Application
Open your browser to: http://127.0.0.1:8088

## Finding Your Azure Configuration Values

### Azure AI Services Endpoint
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Azure AI Services resource
3. Click on "Keys and Endpoint"
4. Copy the "Endpoint" URL

### Deployment Name
1. In your Azure AI Services resource
2. Go to "Model deployments" 
3. Note the "Deployment name" of your model

### Model Name
- Common models: `gpt-4o`, `gpt-4`, `gpt-35-turbo`
- This should match what you deployed

## Configuration Files

### config.template.yaml
Template file with placeholders for Azure values:

```yaml
model_config: &client
  provider: AzureOpenAIChatCompletionClient
  config:
    model: AZURE_OPENAI_MODEL_PLACEHOLDER
    azure_endpoint: "AZURE_OPENAI_ENDPOINT_PLACEHOLDER"
    azure_deployment: "AZURE_OPENAI_DEPLOYMENT_PLACEHOLDER"
    api_version: "2024-10-21"
    model_info:
      vision: true
      function_calling: true
      json_output: true
      family: "openai"
      structured_output: true
```

### config.yaml (Generated)
The actual configuration file is generated from the template using:
```bash
./generate-config.sh
```

This replaces placeholders with your environment variables and creates a working config.yaml.

**Important**: config.yaml is automatically added to .gitignore since it contains sensitive Azure endpoints.

### Authentication Methods

**DefaultAzureCredential (Recommended)**
- Uses Azure CLI login
- Works with managed identities in production
- No API keys needed

**API Key Authentication**
If you prefer API keys, modify config.yaml:
```yaml
config:
  model: "${AZURE_OPENAI_MODEL}"
  azure_endpoint: "${AZURE_OPENAI_ENDPOINT}"
  azure_deployment: "${AZURE_OPENAI_DEPLOYMENT}"
  api_key: "${AZURE_OPENAI_API_KEY}"
```

## Security Best Practices

1. **Never commit sensitive values** to version control
2. **Use .env files** for local development (already in .gitignore)
3. **Use Azure Key Vault** for production deployments
4. **Use managed identities** when running in Azure
5. **Rotate API keys** regularly if using key-based auth

## Troubleshooting

### Common Issues

**Authentication Errors**
```bash
# Re-authenticate with Azure
az login --use-device-code
```

**"model_info is required" Error**
If you see: `ValueError: model_info is required when model name is not a valid OpenAI model`

This happens when Azure models aren't recognized by AutoGen. The `generate-config.sh` script automatically includes the required model_info section. If you're manually creating config.yaml, ensure it includes:
```yaml
model_info:
  vision: true
  function_calling: true
  json_output: true
  family: "openai"
  structured_output: true
```

**"Request URL is missing protocol" Error**
If you see: `httpx.UnsupportedProtocol: Request URL is missing an 'http://' or 'https://' protocol`

This typically means:
1. Environment variables aren't being loaded correctly
2. The config.yaml file has placeholder values instead of actual endpoints
3. Solution: Use `./generate-config.sh` to properly generate config.yaml from your environment variables

**Docker Not Running**
```bash
# Start Docker Desktop on macOS
open -a Docker
```

**Port Already in Use**
```bash
# Kill existing processes on port 8088
lsof -ti:8088 | xargs kill -9
```

**Environment Variables Not Set**
```bash
# Verify environment variables are set
echo $AZURE_OPENAI_ENDPOINT
echo $AZURE_OPENAI_DEPLOYMENT
echo $AZURE_OPENAI_MODEL
```

### Logs and Debugging

Check the application logs for detailed error messages:
```bash
# Run with verbose logging
python -m magentic_ui.backend.cli --port 8088 --config config.yaml --reload
```

## Production Deployment

For production deployments, consider:

1. **Azure Container Instances** - See `terraform/` directory
2. **Azure Key Vault** - For secure secret management
3. **Application Insights** - For monitoring and logging
4. **Virtual Networks** - For network security
5. **Managed Identities** - For secure Azure service access

## Support

- Check `TROUBLESHOOTING.md` for common issues
- Review logs for detailed error messages
- Ensure Azure quotas are sufficient for your deployment
- Verify your Azure AI Services resource has the required models deployed
