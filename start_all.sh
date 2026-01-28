#!/usr/bin/env bash
set -e

# Get the absolute path to the repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_step() {
    echo -e "${BLUE}[STEP] $1${NC}"
}

error_handler() {
    echo -e "${RED}[ERROR] Script failed at line $1${NC}"
    # Kill any background processes we started
    cleanup
}

cleanup() {
    log_info "Stopping all services..."
    # Kill all child processes of this script
    pkill -P $$ || true
    exit 0
}

trap 'error_handler ${LINENO}' ERR
trap cleanup SIGINT SIGTERM EXIT

# 0. Load Environment Variables
log_step "Loading environment variables..."
if [ -f "${REPO_ROOT}/quantum-engine/.env" ]; then
    set -a
    source "${REPO_ROOT}/quantum-engine/.env"
    set +a
    log_info "Loaded .env from quantum-engine/.env"
    
    # Export DATABASE_URL for sqlx (Rust) to perform compile-time checks or online verification
    export DATABASE_URL="${TIMESCALE_URL}"

    # Check Connectivity
    log_info "Checking database connectivity..."
    if ! nc -z localhost 5432; then
        echo -e "${RED}Error: PostgreSQL (TimescaleDB) is not reachable at localhost:5432${NC}"
        echo -e "${RED}Please ensure your local database is running before starting the application.${NC}"
        exit 1
    fi

    log_info "Checking Redis connectivity..."
    if ! nc -z localhost 6379; then
        echo -e "${RED}Error: Redis is not reachable at localhost:6379${NC}"
        echo -e "${RED}Please ensure your local Redis is running before starting the application.${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: quantum-engine/.env not found!${NC}"
    exit 1
fi

# 1. SQLX Preparation (Skipped for Local/Docker-less)
# We export DATABASE_URL above so sqlx can connect directly to the local DB during compilation.
# We do NOT run prepare_sqlx.sh because it requires Docker.
log_info "Skipping sqlx prepare (assuming local DB is reachable via DATABASE_URL)..."

# 2. Start Core Engine (Rust)
log_step "Starting Core Engine..."
cd "${REPO_ROOT}/quantum-engine/core_engine"
# Use cargo run. Add --release if performance is needed, but debug is faster to compile for dev.
cargo run & 
CORE_PID=$!
log_info "Core Engine started with PID $CORE_PID"

# 3. Start Dashboard (React/Vite)
log_step "Starting Dashboard..."
cd "${REPO_ROOT}/quantum-engine/dashboard"
npm run dev -- --host &
DASH_PID=$!
log_info "Dashboard started with PID $DASH_PID"

# 4. Start AI Brain (Python)
log_step "Starting AI Brain..."
cd "${REPO_ROOT}/quantum-engine/ai_brain"

# Check for venv
if [ -d "venv" ]; then
    log_info "Activating Python virtual environment..."
    source venv/bin/activate
fi

# We assume necessary dependencies are installed in the environment (venv or global)
python3 src/main.py &
BRAIN_PID=$!
log_info "AI Brain started with PID $BRAIN_PID"

log_info "All services are running!"
log_info "Core Engine API: http://localhost:${CORE_API_PORT:-3001}"
log_info "Dashboard: http://localhost:5173"
log_info "Redis: ${REDIS_URL}"
log_info "TimescaleDB: ${TIMESCALE_URL}"

# Wait for any process to exit
wait
