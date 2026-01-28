@echo off
setlocal EnableDelayedExpansion

REM Get the absolute path to the repo root (directory of this script)
set "REPO_ROOT=%~dp0"
cd /d "%REPO_ROOT%"

echo [STEP] Loading environment variables...
if exist "quantum-engine\.env" (
    REM Read .env file, ignoring comments (#) and empty lines
    for /f "eol=# tokens=1* delims==" %%A in (quantum-engine\.env) do (
        set "%%A=%%B"
    )
    echo [INFO] Loaded .env from quantum-engine\.env
    
    REM Export DATABASE_URL for sqlx (Rust)
    REM TIMESCALE_URL is loaded from .env above
    set "DATABASE_URL=!TIMESCALE_URL!"
) else (
    echo [ERROR] quantum-engine\.env not found!
    pause
    exit /b 1
)

echo [INFO] Checking connectivity...

REM Check PostgreSQL (TimescaleDB) Port 5432
powershell -Command "if (-not (Test-NetConnection localhost -Port 5432 -InformationLevel Quiet)) { exit 1 }"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] PostgreSQL (TimescaleDB) is not reachable at localhost:5432
    echo [ERROR] Please ensure your local database is running.
    pause
    exit /b 1
)
echo [INFO] Database connection OK.

REM Check Redis Port 6379
powershell -Command "if (-not (Test-NetConnection localhost -Port 6379 -InformationLevel Quiet)) { exit 1 }"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Redis is not reachable at localhost:6379
    echo [ERROR] Please ensure your local Redis is running.
    pause
    exit /b 1
)
echo [INFO] Redis connection OK.

REM Skip prepare_sqlx as we assume DATABASE_URL is reachable for online verification
echo [INFO] Skipping sqlx prepare (using local DB)...

REM Start Core Engine (Rust) in a new window
echo [STEP] Starting Core Engine...
start "QuantTrader Core Engine" /D "quantum-engine\core_engine" cmd /k "cargo run"

REM Start Dashboard (React) in a new window
echo [STEP] Starting Dashboard...
start "QuantTrader Dashboard" /D "quantum-engine\dashboard" cmd /k "npm run dev -- --host"

REM Start AI Brain (Python) in a new window
echo [STEP] Starting AI Brain...
start "QuantTrader AI Brain" /D "quantum-engine\ai_brain" cmd /k "if exist venv\Scripts\activate.bat (call venv\Scripts\activate.bat) & python src\main.py"

echo [INFO] All services launched in separate windows.
echo [INFO] Core Engine API: http://localhost:3001
echo [INFO] Dashboard: http://localhost:5173
echo.
echo Press any key to exit this launcher (services will keep running)...
pause >nul
