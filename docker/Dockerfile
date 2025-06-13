FROM python:3.12-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    ffmpeg \
    exiftool \
    curl \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy the entire project
COPY . .

# Install pysqlite3-binary to fix sqlite3 version compatibility
RUN pip install pysqlite3-binary

# Install the package and dependencies
RUN pip install -e .

# Create data directory for persistence
RUN mkdir -p /app/data

# Expose the port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8081/ || exit 1

# Start the application
CMD ["magentic", "ui", "--host", "0.0.0.0", "--port", "8081"]
