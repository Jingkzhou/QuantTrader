#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[start_all] starting all services via docker-compose"
docker-compose up -d --build

echo "[start_all] done"
echo "[start_all] check logs with: docker-compose logs -f"
