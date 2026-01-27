#!/bin/bash
set -e

echo "Build script started..."

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running."
  exit 1
fi

echo " Building QuantTrader Core Engine (Rust)..."
cd quantum-engine
docker build -f deploy/Dockerfile.rust -t quanttrader/core:latest .

echo " Building QuantTrader AI Brain (Python)..."
docker build -f deploy/Dockerfile.python -t quanttrader/brain:latest .

echo " Building QuantTrader Dashboard (React)..."
docker build -f deploy/Dockerfile.dashboard -t quanttrader/dashboard:latest .

cd ..
echo " All images built successfully!"
docker images | grep quanttrader
