#!/usr/bin/env bash
set -e

# Get the absolute path to the repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute the actual start script located in quantum-engine/deploy/scripts/
# The called script handles its own working directory resolution
exec "${REPO_ROOT}/quantum-engine/deploy/scripts/start_all.sh" "$@"
