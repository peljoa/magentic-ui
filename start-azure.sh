#!/bin/bash
# Magentic-UI Azure AI Foundry Startup Script
# This script generates config.yaml from environment variables and starts Magentic-UI

echo "🚀 Starting Magentic-UI with Azure AI Foundry configuration..."

# Generate config.yaml from template and environment variables
./generate-config.sh

# Check if config generation was successful
if [ $? -ne 0 ]; then
    echo "❌ Failed to generate configuration. Exiting."
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Start Magentic-UI
echo "🌟 Launching Magentic-UI on http://127.0.0.1:8088"
python -m magentic_ui.backend.cli --port 8088 --config config.yaml
