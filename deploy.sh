#!/bin/bash

# Magentic-UI Azure Deployment Script
# This script automates the deployment of Magentic-UI to Azure using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧙‍♂️ Magentic-UI Azure Deployment Script${NC}"
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
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
        echo "   https://learn.hashicorp.com/tutorials/terraform/install-cli"
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

# Login to Azure
azure_login() {
    echo -e "${YELLOW}Checking Azure login status...${NC}"
    
    if ! az account show &> /dev/null; then
        echo -e "${YELLOW}Please login to Azure...${NC}"
        az login
    else
        echo -e "${GREEN}✅ Already logged in to Azure${NC}"
    fi
    
    # Show current subscription
    SUBSCRIPTION=$(az account show --query name -o tsv)
    echo -e "${BLUE}Current subscription: ${SUBSCRIPTION}${NC}"
}

# Initialize Terraform
terraform_init() {
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    cd terraform
    terraform init
    echo -e "${GREEN}✅ Terraform initialized${NC}"
}

# Plan Terraform deployment
terraform_plan() {
    echo -e "${YELLOW}Planning Terraform deployment...${NC}"
    
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${RED}❌ terraform.tfvars file not found${NC}"
        echo -e "${YELLOW}Please copy terraform.tfvars.example to terraform.tfvars and fill in your values${NC}"
        exit 1
    fi
    
    terraform plan -out=tfplan
    echo -e "${GREEN}✅ Terraform plan completed${NC}"
}

# Apply Terraform deployment
terraform_apply() {
    echo -e "${YELLOW}Applying Terraform deployment...${NC}"
    terraform apply tfplan
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
}

# Build and push Docker images
build_and_push_images() {
    echo -e "${YELLOW}Building and pushing Docker images...${NC}"
    
    # Get ACR details from Terraform output
    ACR_NAME=$(terraform output -raw container_registry_login_server | cut -d'.' -f1)
    ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server)
    
    # Login to ACR
    echo -e "${YELLOW}Logging in to Azure Container Registry...${NC}"
    az acr login --name $ACR_NAME
    
    # Go back to project root
    cd ..
    
    # Build main Magentic-UI image
    echo -e "${YELLOW}Building main Magentic-UI Docker image...${NC}"
    docker build -t $ACR_LOGIN_SERVER/magentic-ui:latest -f docker/Dockerfile .
    
    # Build VNC browser image
    echo -e "${YELLOW}Building VNC browser Docker image...${NC}"
    docker build -t $ACR_LOGIN_SERVER/magentic-ui-vnc:latest -f docker/Dockerfile.browser .
    
    # Push images
    echo -e "${YELLOW}Pushing Docker images to ACR...${NC}"
    docker push $ACR_LOGIN_SERVER/magentic-ui:latest
    docker push $ACR_LOGIN_SERVER/magentic-ui-vnc:latest
    
    echo -e "${GREEN}✅ Docker images built and pushed successfully${NC}"
}

# Restart container group to pull new images
restart_containers() {
    echo -e "${YELLOW}Restarting container group...${NC}"
    
    cd terraform
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    CONTAINER_GROUP_NAME="cg-magentic-ui-$(terraform output -raw environment || echo "dev")"
    
    az container restart --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP_NAME
    echo -e "${GREEN}✅ Container group restarted${NC}"
}

# Show deployment information
show_deployment_info() {
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Information:${NC}"
    echo "================================"
    
    cd terraform
    echo -e "${YELLOW}Magentic-UI URL:${NC} $(terraform output -raw magentic_ui_url)"
    
    VNC_URL=$(terraform output -raw vnc_browser_url 2>/dev/null || echo "Not enabled")
    if [ "$VNC_URL" != "Not enabled" ] && [ "$VNC_URL" != "null" ]; then
        echo -e "${YELLOW}VNC Browser URL:${NC} $VNC_URL"
    fi
    
    echo -e "${YELLOW}Resource Group:${NC} $(terraform output -raw resource_group_name)"
    echo -e "${YELLOW}Container Registry:${NC} $(terraform output -raw container_registry_login_server)"
    echo -e "${YELLOW}Key Vault:${NC} $(terraform output -raw key_vault_name)"
    echo ""
    echo -e "${BLUE}💡 Next Steps:${NC}"
    echo "1. Access Magentic-UI at the URL above"
    echo "2. Configure your API keys in the UI settings if needed"
    echo "3. Monitor your deployment in the Azure portal"
    echo ""
    echo -e "${YELLOW}⚠️  Important Security Notes:${NC}"
    echo "- Change the default VNC password"
    echo "- Consider restricting IP access in terraform.tfvars"
    echo "- Monitor your Azure costs regularly"
}

# Main deployment function
deploy() {
    check_prerequisites
    azure_login
    terraform_init
    terraform_plan
    terraform_apply
    build_and_push_images
    restart_containers
    show_deployment_info
}

# Function to destroy infrastructure
destroy() {
    echo -e "${RED}⚠️  This will destroy all Azure resources created by Terraform${NC}"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        cd terraform
        terraform destroy
        echo -e "${GREEN}✅ Infrastructure destroyed${NC}"
    else
        echo -e "${YELLOW}Destruction cancelled${NC}"
    fi
}

# Function to update deployment (rebuild and restart containers)
update() {
    echo -e "${YELLOW}Updating Magentic-UI deployment...${NC}"
    build_and_push_images
    restart_containers
    echo -e "${GREEN}✅ Deployment updated${NC}"
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "destroy")
        destroy
        ;;
    "update")
        update
        ;;
    "info")
        cd terraform
        show_deployment_info
        ;;
    *)
        echo "Usage: $0 {deploy|destroy|update|info}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Deploy Magentic-UI to Azure (default)"
        echo "  destroy - Destroy all Azure resources"
        echo "  update  - Update deployment with new Docker images"
        echo "  info    - Show deployment information"
        exit 1
        ;;
esac
