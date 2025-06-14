#!/bin/bash

# Azure Developer CLI + Terraform Validation Script
# This script validates the azd + Terraform configuration without deploying

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Validating azd + Terraform Configuration${NC}"
echo "=============================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}1. Checking prerequisites...${NC}"

if ! command_exists azd; then
    echo -e "${RED}❌ Azure Developer CLI (azd) is not installed${NC}"
    echo "   Install: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd"
    exit 1
else
    echo -e "${GREEN}✅ Azure Developer CLI (azd) installed${NC}"
    azd version
fi

if ! command_exists az; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    echo "   Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
else
    echo -e "${GREEN}✅ Azure CLI installed${NC}"
fi

if ! command_exists terraform; then
    echo -e "${YELLOW}⚠️  Terraform not installed (optional for validation)${NC}"
else
    echo -e "${GREEN}✅ Terraform installed${NC}"
    terraform version
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker installed${NC}"
fi

# Check project structure
echo -e "${YELLOW}2. Checking project structure...${NC}"

required_files=(
    "azure.yaml"
    ".env.example"
    "terraform/main.tf"
    "terraform/variables.tf"
    "terraform/outputs.tf"
    "terraform/terraform.tfvars.tmpl"
    "Dockerfile"
    "Dockerfile.vnc"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file exists${NC}"
    else
        echo -e "${RED}❌ $file missing${NC}"
        exit 1
    fi
done

# Validate azure.yaml syntax
echo -e "${YELLOW}3. Validating azure.yaml...${NC}"
if azd config show >/dev/null 2>&1; then
    echo -e "${GREEN}✅ azure.yaml syntax is valid${NC}"
else
    echo -e "${RED}❌ azure.yaml has syntax errors${NC}"
    exit 1
fi

# Check if terraform provider is set to terraform
if grep -q "provider: terraform" azure.yaml; then
    echo -e "${GREEN}✅ Terraform provider configured in azure.yaml${NC}"
else
    echo -e "${RED}❌ Terraform provider not configured in azure.yaml${NC}"
    exit 1
fi

# Validate Terraform syntax
echo -e "${YELLOW}4. Validating Terraform configuration...${NC}"
if command_exists terraform; then
    cd terraform
    if terraform init -backend=false >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Terraform initialization successful${NC}"
    else
        echo -e "${RED}❌ Terraform initialization failed${NC}"
        exit 1
    fi
    
    if terraform validate >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Terraform configuration is valid${NC}"
    else
        echo -e "${RED}❌ Terraform configuration has errors${NC}"
        terraform validate
        exit 1
    fi
    cd ..
else
    echo -e "${YELLOW}⚠️  Skipping Terraform validation (terraform not installed)${NC}"
fi

# Check environment file
echo -e "${YELLOW}5. Checking environment configuration...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    
    # Source and check for required variables
    set -a
    source .env 2>/dev/null || true
    set +a
    
    if [ -n "$OPENAI_API_KEY" ]; then
        echo -e "${GREEN}✅ OPENAI_API_KEY is set${NC}"
    else
        echo -e "${YELLOW}⚠️  OPENAI_API_KEY not set in .env${NC}"
    fi
    
    if [ -n "$AZURE_ENV_NAME" ]; then
        echo -e "${GREEN}✅ AZURE_ENV_NAME is set to: $AZURE_ENV_NAME${NC}"
    else
        echo -e "${YELLOW}⚠️  AZURE_ENV_NAME not set, will use default 'dev'${NC}"
    fi
    
    if [ -n "$AZURE_LOCATION" ]; then
        echo -e "${GREEN}✅ AZURE_LOCATION is set to: $AZURE_LOCATION${NC}"
    else
        echo -e "${YELLOW}⚠️  AZURE_LOCATION not set, will use default 'westeurope'${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    echo -e "${BLUE}   Run: cp .env.example .env${NC}"
    echo -e "${BLUE}   Then edit .env with your API keys${NC}"
fi

# Check Azure login
echo -e "${YELLOW}6. Checking Azure authentication...${NC}"
if az account show >/dev/null 2>&1; then
    SUBSCRIPTION=$(az account show --query name -o tsv)
    echo -e "${GREEN}✅ Logged in to Azure${NC}"
    echo -e "${BLUE}   Subscription: $SUBSCRIPTION${NC}"
else
    echo -e "${YELLOW}⚠️  Not logged in to Azure${NC}"
    echo -e "${BLUE}   Run: azd auth login${NC}"
fi

# Check Docker status
echo -e "${YELLOW}7. Checking Docker status...${NC}"
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker is running${NC}"
else
    echo -e "${RED}❌ Docker is not running${NC}"
    echo -e "${BLUE}   Please start Docker Desktop${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Validation completed!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Ensure you have a valid .env file with your API keys"
echo "2. Login to Azure: azd auth login"
echo "3. Deploy: ./azd-deploy.sh deploy"
echo "   or: azd up"
