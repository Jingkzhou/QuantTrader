#!/bin/bash
set -e

# Initialize build flags
BUILD_CORE=false
BUILD_BRAIN=false
BUILD_DASHBOARD=false
BUILD_DEPS=false

# Helper function for usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --all        Build and package everything (default if no args)"
    echo "  --core       Build Core Engine only"
    echo "  --brain      Build AI Brain only"
    echo "  --dashboard  Build Dashboard only"
    echo "  --deps       Package external dependencies (Redis, TimescaleDB, Grafana)"
    echo "  --changed    Auto-detect changed modules (git diff)"
    echo "  --help       Show this help"
    exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
    BUILD_CORE=true
    BUILD_BRAIN=true
    BUILD_DASHBOARD=true
    BUILD_DEPS=true
else
    for arg in "$@"; do
        case $arg in
            --all)
                BUILD_CORE=true
                BUILD_BRAIN=true
                BUILD_DASHBOARD=true
                BUILD_DEPS=true
                ;;
            --core)      BUILD_CORE=true ;;
            --brain)     BUILD_BRAIN=true ;;
            --dashboard) BUILD_DASHBOARD=true ;;
            --deps)      BUILD_DEPS=true ;;
            --changed)
                echo "Detecting changes..."
                if git diff --name-only HEAD | grep -qE "^quantum-engine/core_engine/|^quantum-engine/deploy/Dockerfile.rust"; then
                    echo " -> Changes detected in Core Engine"
                    BUILD_CORE=true
                fi
                if git diff --name-only HEAD | grep -qE "^quantum-engine/ai_brain/|^quantum-engine/deploy/Dockerfile.python"; then
                    echo " -> Changes detected in AI Brain"
                    BUILD_BRAIN=true
                fi
                if git diff --name-only HEAD | grep -qE "^quantum-engine/dashboard/|^quantum-engine/deploy/Dockerfile.dashboard"; then
                    echo " -> Changes detected in Dashboard"
                    BUILD_DASHBOARD=true
                fi
                ;;
            --help) usage ;;
            *) echo "Unknown argument: $arg"; usage ;;
        esac
    done
fi

echo "Build Configuration:"
echo "  Core:      $BUILD_CORE"
echo "  Brain:     $BUILD_BRAIN"
echo "  Dashboard: $BUILD_DASHBOARD"
echo "  Deps:      $BUILD_DEPS"
echo "-----------------------------------"

# Check docker
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running."
  exit 1
fi

# Prepare Dist Directories
DIST_DIR="dist"
IMAGES_DIR="$DIST_DIR/images"
mkdir -p "$IMAGES_DIR"

# --- CORE ENGINE ---
if [ "$BUILD_CORE" = true ]; then
    # Check and generate sqlx-data.json if needed (Only needed for Core)
    if [ ! -f "quantum-engine/core_engine/sqlx-data.json" ] && [ ! -d "quantum-engine/core_engine/.sqlx" ]; then
        echo "sqlx data not found. Running prepare_sqlx.sh..."
        ./prepare_sqlx.sh
    fi

    echo " Building QuantTrader Core Engine (Rust)..."
    cd quantum-engine
    docker build -f deploy/Dockerfile.rust -t quanttrader/core:latest .
    cd ..
    
    echo " Exporting Core Engine..."
    docker save -o "$IMAGES_DIR/core.tar" quanttrader/core:latest
fi

# --- AI BRAIN ---
if [ "$BUILD_BRAIN" = true ]; then
    echo " Building QuantTrader AI Brain (Python)..."
    cd quantum-engine
    docker build -f deploy/Dockerfile.python -t quanttrader/brain:latest .
    cd ..
    
    echo " Exporting AI Brain..."
    docker save -o "$IMAGES_DIR/brain.tar" quanttrader/brain:latest
fi

# --- DASHBOARD ---
if [ "$BUILD_DASHBOARD" = true ]; then
    echo " Building QuantTrader Dashboard (React)..."
    cd quantum-engine
    docker build -f deploy/Dockerfile.dashboard -t quanttrader/dashboard:latest .
    cd ..
    
    echo " Exporting Dashboard..."
    docker save -o "$IMAGES_DIR/dashboard.tar" quanttrader/dashboard:latest
fi

# --- DEPENDENCIES ---
if [ "$BUILD_DEPS" = true ]; then
    echo " Pulling External Dependencies..."
    docker pull timescale/timescaledb:latest-pg14
    docker pull redis:alpine
    docker pull grafana/grafana
    
    echo " Exporting Dependencies..."
    docker save -o "$IMAGES_DIR/dependencies.tar" \
        timescale/timescaledb:latest-pg14 \
        redis:alpine \
        grafana/grafana
fi

# --- CONFIG & SCRIPTS (Always generate/update these) ---
echo " Generating Production Config & Scripts..."

# docker-compose.yml
cat > "$DIST_DIR/docker-compose.yml" <<EOF
version: "3.8"
services:
  timescaledb:
    image: timescale/timescaledb:latest-pg14
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - ./data/db:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"

  dashboard:
    image: quanttrader/dashboard:latest
    ports:
      - "5173:80"
    depends_on:
      - core_engine

  core_engine:
    image: quanttrader/core:latest
    ports:
      - "3001:3001"
    environment:
      - TIMESCALE_URL=postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@timescaledb:5432/\${POSTGRES_DB}
      - REDIS_URL=redis://redis:6379
    depends_on:
      - timescaledb
      - redis

  ai_brain:
    image: quanttrader/brain:latest
    environment:
      - TIMESCALE_URL=postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@timescaledb:5432/\${POSTGRES_DB}
    depends_on:
      - timescaledb
EOF

# Copy .env if exists
if [ -f .env ]; then
    cp .env "$DIST_DIR/"
else
    echo "WARNING: .env file not found! Please create one in the dist folder manually."
fi

# install.bat - Loop through images folder
cat > "$DIST_DIR/install.bat" <<EOF
@echo off
echo Loading Docker Images from images folder...
if not exist "images" (
    echo Error: 'images' folder not found!
    pause
    exit /b
)
cd images
for %%f in (*.tar) do (
    echo Loading %%f ...
    docker load -i "%%f"
)
cd ..
echo Done!
pause
EOF

# start.bat
cat > "$DIST_DIR/start.bat" <<EOF
@echo off
echo Starting QuantTrader Services...
docker-compose up -d
echo Services started!
pause
EOF

# view_logs.bat
cat > "$DIST_DIR/view_logs.bat" <<EOF
@echo off
docker-compose logs -f
EOF

echo "=== SUCCESS === "
echo "Artifacts generated in: $(pwd)/$DIST_DIR"
if [ "$BUILD_CORE" = true ] || [ "$BUILD_BRAIN" = true ] || [ "$BUILD_DASHBOARD" = true ] || [ "$BUILD_DEPS" = true ]; then
    echo "Updated images:"
    [ "$BUILD_CORE" = true ] && echo " - core.tar"
    [ "$BUILD_BRAIN" = true ] && echo " - brain.tar"
    [ "$BUILD_DASHBOARD" = true ] && echo " - dashboard.tar"
    [ "$BUILD_DEPS" = true ] && echo " - dependencies.tar"
else
    echo "No images updated (use --all, --changed or specific flags to build)."
fi
echo "Ready for incremental deployment!"
