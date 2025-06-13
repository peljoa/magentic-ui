#!/bin/bash

# Magentic-UI Docker Compose Startup Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧙‍♂️ Magentic-UI Docker Setup${NC}"
echo "=================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose is not available. Please install Docker Compose.${NC}"
    exit 1
fi

# Use docker compose if available, otherwise fall back to docker-compose
COMPOSE_CMD="docker-compose"
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${YELLOW}📝 Please edit .env file and add your API keys:${NC}"
        echo -e "${BLUE}   nano .env${NC}"
        echo -e "${YELLOW}   Then run this script again.${NC}"
        exit 1
    else
        echo -e "${RED}❌ .env.example file not found. Please create .env file manually.${NC}"
        exit 1
    fi
fi

# Check if OPENAI_API_KEY is set
if ! grep -q "OPENAI_API_KEY=sk-" .env 2>/dev/null; then
    echo -e "${YELLOW}⚠️  OPENAI_API_KEY not properly set in .env file.${NC}"
    echo -e "${YELLOW}   Please edit .env and set your OpenAI API key:${NC}"
    echo -e "${BLUE}   OPENAI_API_KEY=sk-your-actual-api-key-here${NC}"
    exit 1
fi

# Create data directory if it doesn't exist
mkdir -p data

echo -e "${GREEN}✅ Pre-flight checks passed${NC}"
echo ""

# Parse command line arguments
COMMAND=${1:-up}

case $COMMAND in
    "up"|"start")
        echo -e "${BLUE}🚀 Starting Magentic-UI services...${NC}"
        $COMPOSE_CMD up -d
        echo ""
        echo -e "${GREEN}✅ Services started successfully!${NC}"
        echo -e "${BLUE}🌐 Access the UI at: http://localhost:8081${NC}"
        echo -e "${BLUE}🖥️  VNC Browser at: http://localhost:6080${NC}"
        echo ""
        echo -e "${YELLOW}📝 To view logs: $COMPOSE_CMD logs -f${NC}"
        echo -e "${YELLOW}🛑 To stop: $COMPOSE_CMD down${NC}"
        ;;
    "down"|"stop")
        echo -e "${YELLOW}🛑 Stopping services...${NC}"
        $COMPOSE_CMD down
        echo -e "${GREEN}✅ Services stopped${NC}"
        ;;
    "restart")
        echo -e "${YELLOW}🔄 Restarting services...${NC}"
        $COMPOSE_CMD restart
        echo -e "${GREEN}✅ Services restarted${NC}"
        ;;
    "logs")
        $COMPOSE_CMD logs -f
        ;;
    "build")
        echo -e "${BLUE}🔨 Building services...${NC}"
        $COMPOSE_CMD build --no-cache
        echo -e "${GREEN}✅ Build complete${NC}"
        ;;
    "status")
        $COMPOSE_CMD ps
        ;;
    "shell")
        SERVICE=${2:-magentic-ui}
        echo -e "${BLUE}🐚 Opening shell in $SERVICE...${NC}"
        $COMPOSE_CMD exec $SERVICE bash
        ;;
    *)
        echo -e "${BLUE}Usage: $0 [command]${NC}"
        echo ""
        echo "Commands:"
        echo "  up, start    - Start all services (default)"
        echo "  down, stop   - Stop all services"
        echo "  restart      - Restart all services"
        echo "  logs         - Show logs"
        echo "  build        - Rebuild images"
        echo "  status       - Show service status"
        echo "  shell [svc]  - Open shell in service (default: magentic-ui)"
        echo ""
        echo "Examples:"
        echo "  $0 up"
        echo "  $0 logs"
        echo "  $0 shell magentic-ui"
        ;;
esac
