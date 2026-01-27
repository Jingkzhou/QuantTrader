#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[start_all] starting infrastructure (forcing build)"
docker-compose up -d --build

# Handle Mac PATH issues for cargo
CARGO_BIN="$HOME/.cargo/bin/cargo"
if ! command -v cargo >/dev/null 2>&1 && [ -x "$CARGO_BIN" ]; then
  PATH="$HOME/.cargo/bin:$PATH"
fi

if command -v cargo >/dev/null 2>&1; then
  echo "[start_all] starting core_engine (port 3001)"
  (cd core_engine && nohup cargo run >/tmp/quantum-engine-core.log 2>&1 & echo $! > /tmp/quantum-engine-core.pid)
else
  echo "[start_all] cargo not found; core_engine not started" >&2
fi

PYTHON_BIN="python3"
if [ -x "ai_brain/venv/bin/python" ]; then
  PYTHON_BIN="ai_brain/venv/bin/python"
fi

echo "[start_all] starting ai_brain"
nohup "$PYTHON_BIN" ai_brain/src/main.py >/tmp/quantum-engine-ai.log 2>&1 & echo $! > /tmp/quantum-engine-ai.pid

# Dashboard is now started via docker-compose
# if command -v npm >/dev/null 2>&1; then
#   echo "[start_all] starting dashboard"
#   (cd dashboard && nohup npm run dev -- --port 5173 --host >/tmp/quantum-engine-dashboard.log 2>&1 & echo $! > /tmp/quantum-engine-dashboard.pid)
# else
#   echo "[start_all] npm not found; dashboard not started" >&2
# fi

echo "[start_all] done"
echo "[start_all] core_engine log: /tmp/quantum-engine-core.log"
echo "[start_all] ai_brain log: /tmp/quantum-engine-ai.log"
echo "[start_all] dashboard log: /tmp/quantum-engine-dashboard.log"
