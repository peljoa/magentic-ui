#!/bin/bash

# GitHub Secrets and Variables Setup Script for Azure Deployment
# This script helps configure the required GitHub repository secrets and variables
# for the Azure deployment workflow to work properly.

set -e

# Configuration file paths
CONFIG_FILE=".github-secrets-config.json"
ENV_FILE=".github-secrets.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed."
        print_status "Please install it from: https://cli.github.com/"
        print_status "Or use: brew install gh"
        exit 1
    fi
    
    # Check if user is logged in
    if ! gh auth status &> /dev/null; then
        print_error "You are not logged in to GitHub CLI."
        print_status "Please run: gh auth login"
        exit 1
    fi
}

# Get repository information
get_repo_info() {
    # Try to get the origin remote first (your fork)
    if REPO=$(git remote get-url origin 2>/dev/null | sed -E 's|https://github.com/||; s|git@github.com:||; s|\.git$||'); then
        print_status "Repository: $REPO"
    elif ! REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        print_error "Could not determine repository. Make sure you're in a Git repository with a GitHub remote."
        exit 1
    else
        print_status "Repository: $REPO"
    fi
    
    # Check if user has admin access
    if ! gh api "repos/$REPO" --jq '.permissions.admin' 2>/dev/null | grep -q "true"; then
        print_error "You don't have admin rights to this repository: $REPO"
        print_error "You need admin access to set repository secrets and variables."
        print_status "Options:"
        print_status "  1. Ask a repository admin to run this script"
        print_status "  2. Fork the repository to your own account"
        print_status "  3. Use the generated config files manually in GitHub UI"
        print_status "  4. Make sure you're working with your fork, not the upstream repo"
        exit 1
    fi
}

# Save configuration to files
save_config() {
    print_status "Saving configuration to files..."
    
    # Create JSON config file
    cat > "$CONFIG_FILE" << EOF
{
  "repository": "$REPO",
  "variables": {
    "AZURE_CLIENT_ID": "$AZURE_CLIENT_ID",
    "AZURE_TENANT_ID": "$AZURE_TENANT_ID",
    "AZURE_SUBSCRIPTION_ID": "$AZURE_SUBSCRIPTION_ID",
    "AZURE_ENV_NAME": "$AZURE_ENV_NAME",
    "AZURE_LOCATION": "$AZURE_LOCATION",
    "ENABLE_VNC_BROWSER": "$ENABLE_VNC_BROWSER",
    "CONTAINER_CPU_CORES": "$CONTAINER_CPU_CORES",
    "CONTAINER_MEMORY_GB": "$CONTAINER_MEMORY_GB",
    "VNC_CONTAINER_CPU_CORES": "$VNC_CONTAINER_CPU_CORES",
    "VNC_CONTAINER_MEMORY_GB": "$VNC_CONTAINER_MEMORY_GB"
  },
  "secrets": {
    "OPENAI_API_KEY": "$OPENAI_API_KEY",
    "AZURE_OPENAI_ENDPOINT": "$AZURE_OPENAI_ENDPOINT",
    "AZURE_OPENAI_API_KEY": "$AZURE_OPENAI_API_KEY",
    "ANTHROPIC_API_KEY": "$ANTHROPIC_API_KEY",
    "VNC_PASSWORD": "$VNC_PASSWORD",
    "AZURE_CLIENT_SECRET": "$AZURE_CLIENT_SECRET"
  }
}
EOF

    # Create .env file (for manual reference)
    cat > "$ENV_FILE" << EOF
# GitHub Repository Configuration for Azure Deployment
# DO NOT COMMIT THIS FILE - IT CONTAINS SENSITIVE INFORMATION

# Repository Variables (public configuration)
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_ENV_NAME=$AZURE_ENV_NAME
AZURE_LOCATION=$AZURE_LOCATION
ENABLE_VNC_BROWSER=$ENABLE_VNC_BROWSER
CONTAINER_CPU_CORES=$CONTAINER_CPU_CORES
CONTAINER_MEMORY_GB=$CONTAINER_MEMORY_GB
VNC_CONTAINER_CPU_CORES=$VNC_CONTAINER_CPU_CORES
VNC_CONTAINER_MEMORY_GB=$VNC_CONTAINER_MEMORY_GB

# Repository Secrets (sensitive data)
OPENAI_API_KEY=$OPENAI_API_KEY
AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY=$AZURE_OPENAI_API_KEY
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
VNC_PASSWORD=$VNC_PASSWORD
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET
EOF

    print_status "✓ Configuration saved to: $CONFIG_FILE"
    print_status "✓ Environment file saved to: $ENV_FILE"
    print_warning "IMPORTANT: These files contain sensitive information!"
    print_warning "Make sure they are in your .gitignore to prevent accidental commits."
}

# Load configuration from file
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    print_status "Loading existing configuration from: $CONFIG_FILE"
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_error "jq is required to load configuration. Install it with: brew install jq"
        return 1
    fi
    
    # Load variables
    AZURE_CLIENT_ID=$(jq -r '.variables.AZURE_CLIENT_ID // ""' "$CONFIG_FILE")
    AZURE_TENANT_ID=$(jq -r '.variables.AZURE_TENANT_ID // ""' "$CONFIG_FILE")
    AZURE_SUBSCRIPTION_ID=$(jq -r '.variables.AZURE_SUBSCRIPTION_ID // ""' "$CONFIG_FILE")
    AZURE_ENV_NAME=$(jq -r '.variables.AZURE_ENV_NAME // ""' "$CONFIG_FILE")
    AZURE_LOCATION=$(jq -r '.variables.AZURE_LOCATION // "westeurope"' "$CONFIG_FILE")
    ENABLE_VNC_BROWSER=$(jq -r '.variables.ENABLE_VNC_BROWSER // "true"' "$CONFIG_FILE")
    CONTAINER_CPU_CORES=$(jq -r '.variables.CONTAINER_CPU_CORES // "1.0"' "$CONFIG_FILE")
    CONTAINER_MEMORY_GB=$(jq -r '.variables.CONTAINER_MEMORY_GB // "2.0"' "$CONFIG_FILE")
    VNC_CONTAINER_CPU_CORES=$(jq -r '.variables.VNC_CONTAINER_CPU_CORES // "0.5"' "$CONFIG_FILE")
    VNC_CONTAINER_MEMORY_GB=$(jq -r '.variables.VNC_CONTAINER_MEMORY_GB // "1.0"' "$CONFIG_FILE")
    
    # Load secrets
    OPENAI_API_KEY=$(jq -r '.secrets.OPENAI_API_KEY // ""' "$CONFIG_FILE")
    AZURE_OPENAI_ENDPOINT=$(jq -r '.secrets.AZURE_OPENAI_ENDPOINT // ""' "$CONFIG_FILE")
    AZURE_OPENAI_API_KEY=$(jq -r '.secrets.AZURE_OPENAI_API_KEY // ""' "$CONFIG_FILE")
    ANTHROPIC_API_KEY=$(jq -r '.secrets.ANTHROPIC_API_KEY // ""' "$CONFIG_FILE")
    VNC_PASSWORD=$(jq -r '.secrets.VNC_PASSWORD // ""' "$CONFIG_FILE")
    AZURE_CLIENT_SECRET=$(jq -r '.secrets.AZURE_CLIENT_SECRET // ""' "$CONFIG_FILE")
    
    return 0
}

# Prompt for missing values
prompt_for_values() {
    echo
    print_header "=== REQUIRED AZURE VARIABLES ==="
    echo
    
    # Required Azure variables
    if [ -z "$AZURE_CLIENT_ID" ]; then
        read -p "Azure Client ID: " AZURE_CLIENT_ID
    else
        read -p "Azure Client ID [$AZURE_CLIENT_ID]: " input
        AZURE_CLIENT_ID=${input:-$AZURE_CLIENT_ID}
    fi
    
    if [ -z "$AZURE_TENANT_ID" ]; then
        read -p "Azure Tenant ID: " AZURE_TENANT_ID
    else
        read -p "Azure Tenant ID [$AZURE_TENANT_ID]: " input
        AZURE_TENANT_ID=${input:-$AZURE_TENANT_ID}
    fi
    
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        read -p "Azure Subscription ID: " AZURE_SUBSCRIPTION_ID
    else
        read -p "Azure Subscription ID [$AZURE_SUBSCRIPTION_ID]: " input
        AZURE_SUBSCRIPTION_ID=${input:-$AZURE_SUBSCRIPTION_ID}
    fi
    
    if [ -z "$AZURE_ENV_NAME" ]; then
        read -p "Azure Environment Name (e.g., 'magentic-ui-prod'): " AZURE_ENV_NAME
    else
        read -p "Azure Environment Name [$AZURE_ENV_NAME]: " input
        AZURE_ENV_NAME=${input:-$AZURE_ENV_NAME}
    fi
    
    echo
    print_header "=== OPTIONAL AZURE VARIABLES ==="
    echo
    
    # Optional Azure variables with defaults
    read -p "Azure Location [$AZURE_LOCATION]: " input
    AZURE_LOCATION=${input:-$AZURE_LOCATION}
    
    read -p "Enable VNC Browser [$ENABLE_VNC_BROWSER]: " input
    ENABLE_VNC_BROWSER=${input:-$ENABLE_VNC_BROWSER}
    
    read -p "Container CPU Cores [$CONTAINER_CPU_CORES]: " input
    CONTAINER_CPU_CORES=${input:-$CONTAINER_CPU_CORES}
    
    read -p "Container Memory GB [$CONTAINER_MEMORY_GB]: " input
    CONTAINER_MEMORY_GB=${input:-$CONTAINER_MEMORY_GB}
    
    read -p "VNC Container CPU Cores [$VNC_CONTAINER_CPU_CORES]: " input
    VNC_CONTAINER_CPU_CORES=${input:-$VNC_CONTAINER_CPU_CORES}
    
    read -p "VNC Container Memory GB [$VNC_CONTAINER_MEMORY_GB]: " input
    VNC_CONTAINER_MEMORY_GB=${input:-$VNC_CONTAINER_MEMORY_GB}
    
    echo
    print_header "=== API KEYS AND SECRETS ==="
    echo
    
    # API Keys and secrets
    if [ -z "$OPENAI_API_KEY" ]; then
        read -s -p "OpenAI API Key: " OPENAI_API_KEY
        echo
    else
        read -s -p "OpenAI API Key [****existing****]: " input
        echo
        if [ -n "$input" ]; then
            OPENAI_API_KEY="$input"
        fi
    fi
    
    if [ -z "$AZURE_OPENAI_ENDPOINT" ]; then
        read -p "Azure OpenAI Endpoint: " AZURE_OPENAI_ENDPOINT
    else
        read -p "Azure OpenAI Endpoint [$AZURE_OPENAI_ENDPOINT]: " input
        AZURE_OPENAI_ENDPOINT=${input:-$AZURE_OPENAI_ENDPOINT}
    fi
    
    if [ -z "$AZURE_OPENAI_API_KEY" ]; then
        read -s -p "Azure OpenAI API Key: " AZURE_OPENAI_API_KEY
        echo
    else
        read -s -p "Azure OpenAI API Key [****existing****]: " input
        echo
        if [ -n "$input" ]; then
            AZURE_OPENAI_API_KEY="$input"
        fi
    fi
    
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        read -s -p "Anthropic API Key: " ANTHROPIC_API_KEY
        echo
    else
        read -s -p "Anthropic API Key [****existing****]: " input
        echo
        if [ -n "$input" ]; then
            ANTHROPIC_API_KEY="$input"
        fi
    fi
    
    if [ -z "$VNC_PASSWORD" ]; then
        read -s -p "VNC Password: " VNC_PASSWORD
        echo
    else
        read -s -p "VNC Password [****existing****]: " input
        echo
        if [ -n "$input" ]; then
            VNC_PASSWORD="$input"
        fi
    fi
    
    echo
    print_header "=== CLIENT CREDENTIALS (Optional - only if not using federated auth) ==="
    echo
    print_warning "Leave blank if using federated credentials (recommended)"
    
    if [ -z "$AZURE_CLIENT_SECRET" ]; then
        read -s -p "Azure Client Secret (optional): " AZURE_CLIENT_SECRET
        echo
    else
        read -s -p "Azure Client Secret [****existing****]: " input
        echo
        if [ -n "$input" ]; then
            AZURE_CLIENT_SECRET="$input"
        fi
    fi
}

# Function to set a repository variable
set_repo_variable() {
    local name=$1
    local value=$2
    local description=$3
    
    if [ -z "$value" ]; then
        print_warning "Skipping $name (no value provided)"
        return 0
    fi
    
    print_status "Setting repository variable: $name"
    if gh variable set "$name" --body "$value" --repo "$REPO" 2>/dev/null; then
        print_status "✓ Successfully set $name"
        return 0
    else
        print_error "Failed to set variable $name"
        return 1
    fi
}

# Function to set a repository secret
set_repo_secret() {
    local name=$1
    local value=$2
    local description=$3
    
    if [ -z "$value" ]; then
        print_warning "Skipping $name (no value provided)"
        return 0
    fi
    
    print_status "Setting repository secret: $name"
    if echo "$value" | gh secret set "$name" --repo "$REPO" 2>/dev/null; then
        print_status "✓ Successfully set $name"
        return 0
    else
        print_error "Failed to set secret $name"
        return 1
    fi
}

# Apply configuration to GitHub
apply_config() {
    local has_errors=false
    
    echo
    print_header "Setting up repository variables..."
    echo
    
    # Set repository variables
    set_repo_variable "AZURE_CLIENT_ID" "$AZURE_CLIENT_ID" "Azure service principal client ID" || has_errors=true
    set_repo_variable "AZURE_TENANT_ID" "$AZURE_TENANT_ID" "Azure tenant ID" || has_errors=true
    set_repo_variable "AZURE_SUBSCRIPTION_ID" "$AZURE_SUBSCRIPTION_ID" "Azure subscription ID" || has_errors=true
    set_repo_variable "AZURE_ENV_NAME" "$AZURE_ENV_NAME" "Azure environment name" || has_errors=true
    set_repo_variable "AZURE_LOCATION" "$AZURE_LOCATION" "Azure deployment region" || has_errors=true
    set_repo_variable "ENABLE_VNC_BROWSER" "$ENABLE_VNC_BROWSER" "Enable VNC browser access" || has_errors=true
    set_repo_variable "CONTAINER_CPU_CORES" "$CONTAINER_CPU_CORES" "CPU cores for main container" || has_errors=true
    set_repo_variable "CONTAINER_MEMORY_GB" "$CONTAINER_MEMORY_GB" "Memory for main container" || has_errors=true
    set_repo_variable "VNC_CONTAINER_CPU_CORES" "$VNC_CONTAINER_CPU_CORES" "CPU cores for VNC container" || has_errors=true
    set_repo_variable "VNC_CONTAINER_MEMORY_GB" "$VNC_CONTAINER_MEMORY_GB" "Memory for VNC container" || has_errors=true
    
    echo
    print_header "Setting up repository secrets..."
    echo
    
    # Set repository secrets
    set_repo_secret "OPENAI_API_KEY" "$OPENAI_API_KEY" "OpenAI API key" || has_errors=true
    set_repo_secret "AZURE_OPENAI_ENDPOINT" "$AZURE_OPENAI_ENDPOINT" "Azure OpenAI endpoint" || has_errors=true
    set_repo_secret "AZURE_OPENAI_API_KEY" "$AZURE_OPENAI_API_KEY" "Azure OpenAI API key" || has_errors=true
    set_repo_secret "ANTHROPIC_API_KEY" "$ANTHROPIC_API_KEY" "Anthropic API key" || has_errors=true
    set_repo_secret "VNC_PASSWORD" "$VNC_PASSWORD" "VNC access password" || has_errors=true
    
    # Set client credentials if provided
    if [ -n "$AZURE_CLIENT_SECRET" ]; then
        set_repo_secret "AZURE_CLIENT_SECRET" "$AZURE_CLIENT_SECRET" "Azure client secret" || has_errors=true
    fi
    
    if [ "$has_errors" = true ]; then
        echo
        print_error "Some operations failed. Configuration has been saved to files."
        print_status "You can manually set the failed items in GitHub UI or re-run this script."
        return 1
    fi
    
    return 0
}

# Function to create environment if it doesn't exist
create_environment() {
    local env_name=$1
    print_status "Creating environment: $env_name"
    
    # Note: Environment creation via CLI might not be available in all GitHub plans
    # This is mainly for documentation purposes
    print_warning "Note: You may need to create environments manually in GitHub UI"
    print_status "Go to: Settings → Environments → New environment"
    print_status "Create environments: 'production' and 'development'"
}

# Main setup function
main() {
    print_header "GitHub Repository Setup for Azure Deployment"
    echo
    
    check_gh_cli
    get_repo_info
    echo
    
    print_header "This script will help you configure the following:"
    echo "  • Repository Variables (public configuration)"
    echo "  • Repository Secrets (sensitive data)"
    echo "  • Environment setup guidance"
    echo
    
    # Check if config file exists
    if load_config; then
        print_status "Found existing configuration file."
        echo
        read -p "Use existing configuration? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_status "Starting fresh configuration..."
            # Clear variables for fresh start
            unset AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_ENV_NAME
            unset AZURE_LOCATION ENABLE_VNC_BROWSER CONTAINER_CPU_CORES CONTAINER_MEMORY_GB
            unset VNC_CONTAINER_CPU_CORES VNC_CONTAINER_MEMORY_GB
            unset OPENAI_API_KEY AZURE_OPENAI_ENDPOINT AZURE_OPENAI_API_KEY
            unset ANTHROPIC_API_KEY VNC_PASSWORD AZURE_CLIENT_SECRET
        else
            print_status "Using existing configuration. You can update any values by entering new ones."
        fi
    else
        read -p "Continue with setup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Setup cancelled."
            exit 0
        fi
    fi
    
    prompt_for_values
    
    echo
    save_config
    
    echo
    read -p "Apply configuration to GitHub now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if apply_config; then
            echo
            print_header "=== SETUP COMPLETE ==="
            echo
            print_status "✓ Repository variables configured"
            print_status "✓ Repository secrets configured"
        else
            echo
            print_header "=== SETUP COMPLETED WITH ERRORS ==="
            echo
            print_warning "Some operations failed, but configuration is saved."
        fi
    else
        echo
        print_header "=== CONFIGURATION SAVED ==="
        echo
        print_status "Configuration saved but not applied to GitHub."
        print_status "Run this script again to apply the configuration."
    fi
    
    echo
    print_warning "NEXT STEPS:"
    echo "1. Create GitHub environments (if not already done):"
    echo "   • Go to: https://github.com/$REPO/settings/environments"
    echo "   • Create 'production' environment"
    echo "   • Create 'development' environment"
    echo
    echo "2. Set up Azure federated credentials (recommended):"
    echo "   • Configure workload identity federation in Azure"
    echo "   • Link to your GitHub repository and environments"
    echo
    echo "3. Test your deployment:"
    echo "   • Push to main/develop branch or trigger workflow manually"
    echo "   • Monitor the Actions tab for deployment status"
    echo
    print_status "Configuration files:"
    print_status "  • $CONFIG_FILE (JSON format)"
    print_status "  • $ENV_FILE (environment variables)"
    echo
    print_warning "IMPORTANT: Add these files to .gitignore to prevent accidental commits!"
}

# Run the main function
main "$@"
