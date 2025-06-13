# Docker Compose Setup for Magentic-UI

This directory contains Docker Compose configuration to run Magentic-UI with all its dependencies.

## Quick Start

1. **Copy the environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the `.env` file:**
   ```bash
   nano .env
   ```
   
   Replace `your_openai_api_key_here` with your actual OpenAI API key:
   ```env
   OPENAI_API_KEY=sk-your-actual-openai-api-key-here
   ```

3. **Start the services:**
   ```bash
   docker-compose up -d
   ```

4. **Access the application:**
   - Main UI: http://localhost:8081
   - VNC Browser (if enabled): http://localhost:6080

## Environment Variables

The following environment variables can be configured in your `.env` file:

### Required
- `OPENAI_API_KEY`: Your OpenAI API key

### Optional
- `ANTHROPIC_API_KEY`: Your Anthropic API key (for Claude models)
- `AZURE_OPENAI_ENDPOINT`: Azure OpenAI endpoint URL
- `AZURE_OPENAI_API_KEY`: Azure OpenAI API key
- `DATABASE_URL`: Database connection string (defaults to SQLite)
- `PORT`: Port for the UI (default: 8081)
- `HOST`: Host address (default: 0.0.0.0)
- `VNC_PASSWORD`: Password for VNC access (default: magentic)

## Services

### magentic-ui
The main application service that runs the Magentic-UI backend and web interface.

- **Ports:** 8081 (configurable via PORT env var)
- **Volumes:** 
  - `./data:/app/data` - Data persistence
  - Docker socket for container management

### vnc-browser (Optional)
A VNC-enabled browser service for web browsing capabilities.

- **Ports:** 
  - 6080 - noVNC web interface
  - 5900 - VNC port
- **Access:** http://localhost:6080

## Management Commands

### Start services
```bash
docker-compose up -d
```

### Stop services
```bash
docker-compose down
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f magentic-ui
```

### Rebuild after changes
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Update services
```bash
docker-compose pull
docker-compose up -d
```

## Data Persistence

Application data is stored in the `./data` directory and persisted between container restarts.

## Troubleshooting

### Check service status
```bash
docker-compose ps
```

### Access container shell
```bash
# Main application
docker-compose exec magentic-ui bash

# Browser service
docker-compose exec vnc-browser bash
```

### Check application logs
```bash
docker-compose logs magentic-ui
```

### Restart a specific service
```bash
docker-compose restart magentic-ui
```

## Security Notes

- Keep your `.env` file secure and never commit it to version control
- The `.env.example` file is provided as a template
- Consider using Docker secrets in production environments
- The VNC service is optional and can be disabled by commenting out the vnc-browser service in docker-compose.yml
