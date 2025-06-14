#!/bin/bash
# Azure AI Foundry Configuration Generator
# This script generates config.yaml from config.template.yaml using environment variables

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "📝 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Check required environment variables
if [ -z "$AZURE_OPENAI_ENDPOINT" ] || [ -z "$AZURE_OPENAI_DEPLOYMENT" ] || [ -z "$AZURE_OPENAI_MODEL" ]; then
    echo "❌ Error: Required environment variables are not set."
    echo "Please set: AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT, AZURE_OPENAI_MODEL"
    echo ""
    echo "You can either:"
    echo "1. Create a .env file with your values (see .env.example)"
    echo "2. Export the variables manually:"
    echo "   export AZURE_OPENAI_ENDPOINT='https://your-resource.cognitiveservices.azure.com/'"
    echo "   export AZURE_OPENAI_DEPLOYMENT='your-deployment-name'"
    echo "   export AZURE_OPENAI_MODEL='gpt-4o'"
    exit 1
fi

echo "🔧 Generating config.yaml from template..."
echo "📍 Endpoint: $AZURE_OPENAI_ENDPOINT"
echo "🔧 Deployment: $AZURE_OPENAI_DEPLOYMENT"
echo "🤖 Model: $AZURE_OPENAI_MODEL"

# Generate config.yaml from template
sed \
    -e "s|AZURE_OPENAI_ENDPOINT_PLACEHOLDER|$AZURE_OPENAI_ENDPOINT|g" \
    -e "s|AZURE_OPENAI_DEPLOYMENT_PLACEHOLDER|$AZURE_OPENAI_DEPLOYMENT|g" \
    -e "s|AZURE_OPENAI_MODEL_PLACEHOLDER|$AZURE_OPENAI_MODEL|g" \
    config.template.yaml > config.yaml

echo "✅ config.yaml generated successfully!"
echo ""
