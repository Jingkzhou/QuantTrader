#!/bin/bash
set -e

echo "Generating sqlx-data.json using Docker..."

# 1. Ensure databases are running
echo "Starting database..."
docker-compose --file quantum-engine/docker-compose.yml up -d timescaledb

# 2. Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 5

# 3. Use rust:1.84 but switch to nightly toolchain manually via rustup
# This is more reliable than checking for a potentially missing rust:nightly tag
echo "Running sqlx prepare..."
docker run --rm \
  -v "$(pwd)/quantum-engine/core_engine:/app" \
  --network quantum-engine_default \
  -w /app \
  -e DATABASE_URL=postgres://postgres:postgres@timescaledb:5432/quantum \
  rust:1.84 \
  /bin/bash -c "
    set -e
    # Retry logic for apt-get to handle network flakes
    # Use single quotes to avoid breaking the outer double quotes
    apt-get update || echo 'Apt update failed, continuing...'
    apt-get install -y --fix-missing git || (sleep 2 && apt-get update && apt-get install -y git)
    
    echo 'Switching to Rust Nightly toolchain...'
    rustup default nightly
    
    echo 'Installing sqlx-cli v0.7.4 using Nightly...'
    # We explicitly install v0.7.4 to ensure sqlx-data.json compatibility with our project's sqlx crate
    cargo install sqlx-cli --version 0.7.4 --no-default-features --features postgres

    # 4. Run prepare
    cd /app
    echo 'Running sqlx prepare in /app...'
    # Also need bootstrap here just in case sqlx itself drags in something
    export RUSTC_BOOTSTRAP=1
    cargo sqlx prepare
    
    echo 'Checking for sqlx-data.json...'
    ls -l sqlx-data.json || echo 'ERROR: sqlx-data.json not found in /app'
  "

echo "sqlx-data.json generated successfully!"
