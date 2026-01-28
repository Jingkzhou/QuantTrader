#!/usr/bin/env bash
set -e

# Get the absolute path to the repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check and generate sqlx-data.json if needed
# Check and generate sqlx data if needed
if [ ! -f "${REPO_ROOT}/quantum-engine/core_engine/sqlx-data.json" ] && [ ! -d "${REPO_ROOT}/quantum-engine/core_engine/.sqlx" ]; then
    echo "sqlx data not found. Running prepare_sqlx.sh..."
    "${REPO_ROOT}/prepare_sqlx.sh"
fi

# Execute the actual start script located in quantum-engine/deploy/scripts/
# The called script handles its own working directory resolution
exec "${REPO_ROOT}/quantum-engine/deploy/scripts/start_all.sh" "$@"
