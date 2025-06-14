#!/bin/bash

# Magentic-UI Azure Developer CLI Deployment Script
# This script automates the deployment of Magentic-UI to Azure using azd

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧙‍♂️ Magentic-UI Azure Developer CLI Deployment${NC}"
echo "=================================================="

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
        echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if Azure Developer CLI is installed
    if ! command -v azd &> /dev/null; then
        echo -e "${RED}❌ Azure Developer CLI (azd) is not installed. Please install it first.${NC}"
        echo "   https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed. Please install it first.${NC}"
        echo "   https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Check environment file
check_environment() {
    echo -e "${YELLOW}Checking environment configuration...${NC}"
    
    if [ ! -f ".env" ]; then
        echo -e "${RED}❌ .env file not found${NC}"
        echo -e "${YELLOW}Please copy .env.example to .env and fill in your values${NC}"
        cp .env.example .env
        echo -e "${YELLOW}📝 Please edit .env file and add your API keys:${NC}"
        echo -e "${BLUE}   nano .env${NC}"
        echo -e "${YELLOW}   Then run this script again.${NC}"
        exit 1
    fi
    
    # Source the .env file
    set -a
    source .env
    set +a
    
    # Check if OPENAI_API_KEY is set
    if [ -z "$OPENAI_API_KEY" ]; then
        echo -e "${RED}❌ OPENAI_API_KEY is required in .env file${NC}"
        echo -e "${YELLOW}   Please edit .env and set your OpenAI API key${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Environment configuration check passed${NC}"
}

# Login to Azure
azure_login() {
    echo -e "${YELLOW}Checking Azure login status...${NC}"
    
    if ! az account show &> /dev/null; then
        echo -e "${YELLOW}Please login to Azure...${NC}"
        azd auth login
    else
        echo -e "${GREEN}✅ Already logged in to Azure${NC}"
    fi
    
    # Show current subscription
    SUBSCRIPTION=$(az account show --query name -o tsv)
    echo -e "${BLUE}Current subscription: ${SUBSCRIPTION}${NC}"
}

# Initialize azd project
azd_init() {
    echo -e "${YELLOW}Initializing Azure Developer CLI project with Terraform...${NC}"
    
    if [ ! -f ".azure/config.json" ]; then
        azd init --template .
    fi
    
    # Set environment variables for azd
    azd env set OPENAI_API_KEY "$OPENAI_API_KEY"
    azd env set AZURE_OPENAI_ENDPOINT "${AZURE_OPENAI_ENDPOINT:-}"
    azd env set AZURE_OPENAI_API_KEY "${AZURE_OPENAI_API_KEY:-}"
    azd env set ANTHROPIC_API_KEY "${ANTHROPIC_API_KEY:-}"
    azd env set VNC_PASSWORD "${VNC_PASSWORD:-magentic123!}"
    
    # Set deployment configuration
    azd env set ENABLE_VNC_BROWSER "${ENABLE_VNC_BROWSER:-true}"
    azd env set CONTAINER_CPU_CORES "${CONTAINER_CPU_CORES:-1.0}"
    azd env set CONTAINER_MEMORY_GB "${CONTAINER_MEMORY_GB:-2.0}"
    azd env set VNC_CONTAINER_CPU_CORES "${VNC_CONTAINER_CPU_CORES:-0.5}"
    azd env set VNC_CONTAINER_MEMORY_GB "${VNC_CONTAINER_MEMORY_GB:-1.0}"
    
    # Set Terraform variables for azd integration
    azd env set TF_VAR_environmentName "${AZURE_ENV_NAME:-dev}"
    azd env set TF_VAR_location "${AZURE_LOCATION:-westeurope}"
    azd env set TF_VAR_openai_api_key "$OPENAI_API_KEY"
    azd env set TF_VAR_azure_openai_endpoint "${AZURE_OPENAI_ENDPOINT:-}"
    azd env set TF_VAR_azure_openai_api_key "${AZURE_OPENAI_API_KEY:-}"
    azd env set TF_VAR_anthropic_api_key "${ANTHROPIC_API_KEY:-}"
    azd env set TF_VAR_vnc_password "${VNC_PASSWORD:-magentic123!}"
    azd env set TF_VAR_enable_vnc_browser "${ENABLE_VNC_BROWSER:-true}"
    azd env set TF_VAR_container_cpu "${CONTAINER_CPU_CORES:-1.0}"
    azd env set TF_VAR_container_memory "${CONTAINER_MEMORY_GB:-2.0}"
    azd env set TF_VAR_vnc_container_cpu "${VNC_CONTAINER_CPU_CORES:-0.5}"
    azd env set TF_VAR_vnc_container_memory "${VNC_CONTAINER_MEMORY_GB:-1.0}"
    
    echo -e "${GREEN}✅ Azure Developer CLI project initialized with Terraform${NC}"
}

# Deploy with azd
azd_deploy() {
    echo -e "${YELLOW}Deploying with Azure Developer CLI...${NC}"
    
    # Set environment name if not already set
    if [ -z "$AZURE_ENV_NAME" ]; then
        export AZURE_ENV_NAME="dev"
    fi
    
    # Set location if not already set
    if [ -z "$AZURE_LOCATION" ]; then
        export AZURE_LOCATION="westeurope"
    fi
    
    # Deploy infrastructure and application
    azd up --environment "$AZURE_ENV_NAME" --location "$AZURE_LOCATION"
    
    echo -e "${GREEN}✅ Deployment completed successfully${NC}"
}

# Show deployment information
show_deployment_info() {
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Information:${NC}"
    echo "================================"
    
    # Get deployment outputs
    WEB_URI=$(azd env get-values | grep SERVICE_WEB_URI | cut -d'=' -f2 | tr -d '"')
    VNC_URI=$(azd env get-values | grep SERVICE_VNC_BROWSER_URI | cut -d'=' -f2 | tr -d '"')
    RESOURCE_GROUP=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')
    
    if [ ! -z "$WEB_URI" ]; then
        echo -e "${YELLOW}Magentic-UI URL:${NC} $WEB_URI"
    fi
    
    if [ ! -z "$VNC_URI" ] && [ "$VNC_URI" != "null" ]; then
        echo -e "${YELLOW}VNC Browser URL:${NC} $VNC_URI"
    fi
    
    if [ ! -z "$RESOURCE_GROUP" ]; then
        echo -e "${YELLOW}Resource Group:${NC} $RESOURCE_GROUP"
    fi
    
    echo ""
    echo -e "${BLUE}💡 Next Steps:${NC}"
    echo "1. Access Magentic-UI at the URL above"
    echo "2. Configure your API keys in the UI settings if needed"
    echo "3. Monitor your deployment in the Azure portal"
    echo ""
    echo -e "${YELLOW}⚠️  Important Security Notes:${NC}"
    echo "- Change the default VNC password in .env file"
    echo "- Consider restricting IP access"
    echo "- Monitor your Azure costs regularly"
    echo ""
    echo -e "${BLUE}🔧 Management Commands:${NC}"
    echo "- azd deploy   - Deploy code changes"
    echo "- azd down     - Delete all resources"
    echo "- azd monitor  - View application logs and metrics"
    echo "- azd env show - Show environment variables"
}

# Function to deploy only the application (not infrastructure)
deploy_app() {
    echo -e "${YELLOW}Deploying application changes...${NC}"
    azd deploy
    echo -e "${GREEN}✅ Application deployment completed${NC}"
}

# Function to destroy infrastructure
destroy() {
    echo -e "${RED}⚠️  This will destroy all Azure resources created by azd${NC}"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        azd down --force --purge
        echo -e "${GREEN}✅ Infrastructure destroyed${NC}"
    else
        echo -e "${YELLOW}Destruction cancelled${NC}"
    fi
}

# Function to show logs
show_logs() {
    echo -e "${YELLOW}Opening Azure Monitor...${NC}"
    azd monitor --overview
}

# Function to show environment info
show_env_info() {
    echo -e "${BLUE}📋 Environment Information:${NC}"
    echo "================================"
    azd env show
    echo ""
    echo -e "${BLUE}🔗 Useful URLs:${NC}"
    azd env get-values | grep -E "(URI|URL)" | while read line; do
        key=$(echo $line | cut -d'=' -f1)
        value=$(echo $line | cut -d'=' -f2 | tr -d '"')
        if [ ! -z "$value" ] && [ "$value" != "null" ]; then
            echo -e "${YELLOW}$key:${NC} $value"
        fi
    done
}

# Main deployment function
deploy() {
    check_prerequisites
    check_environment
    azure_login
    azd_init
    azd_deploy
    show_deployment_info
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy" | "up")
        deploy
        ;;
    "app" | "deploy-app")
        check_environment
        deploy_app
        ;;
    "destroy" | "down")
        destroy
        ;;
    "logs" | "monitor")
        show_logs
        ;;
    "info" | "show")
        show_env_info
        ;;
    "init")
        check_prerequisites
        azure_login
        azd_init
        echo -e "${GREEN}✅ Project initialized. You can now run './azd-deploy.sh deploy'${NC}"
        ;;
    *)
        echo "Usage: $0 {deploy|app|destroy|logs|info|init}"
        echo ""
        echo "Commands:"
        echo "  deploy    - Full deployment (infrastructure + application)"
        echo "  up        - Alias for deploy"
        echo "  app       - Deploy only application changes"
        echo "  destroy   - Destroy all Azure resources"
        echo "  down      - Alias for destroy"
        echo "  logs      - View application logs and monitoring"
        echo "  monitor   - Alias for logs"
        echo "  info      - Show environment information"
        echo "  show      - Alias for info"
        echo "  init      - Initialize azd project only"
        echo ""
        echo "Environment variables (set in .env file):"
        echo "  OPENAI_API_KEY        - Required: Your OpenAI API key"
        echo "  AZURE_OPENAI_ENDPOINT - Optional: Azure OpenAI endpoint"
        echo "  AZURE_OPENAI_API_KEY  - Optional: Azure OpenAI API key"
        echo "  ANTHROPIC_API_KEY     - Optional: Anthropic API key"
        echo "  AZURE_ENV_NAME        - Environment name (default: dev)"
        echo "  AZURE_LOCATION        - Azure region (default: westeurope)"
        echo "  ENABLE_VNC_BROWSER    - Enable VNC browser (default: true)"
        exit 1
        ;;
esac
