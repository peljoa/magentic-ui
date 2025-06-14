# syntax=docker/dockerfile:1

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
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY pyproject.toml uv.lock* ./

# Install uv for faster package installation
RUN pip install uv

# Install Python dependencies
RUN uv pip install --system -e .

# Create data directory for persistence
RUN mkdir -p /app/data

# Copy the application code
COPY . .

# Install the package in development mode
RUN uv pip install --system -e .

# Expose the application port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8081/ || exit 1

# Start the application
CMD ["magentic", "ui", "--host", "0.0.0.0", "--port", "8081"]
