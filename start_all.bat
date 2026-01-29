@echo off
setlocal EnableDelayedExpansion

REM Add PostgreSQL bin to PATH at the start to ensure DLLs are always found
if exist "D:\pgsql\bin" (
    set "PATH=D:\pgsql\bin;%PATH%"
)

REM Get the absolute path to the repo root (directory of this script)
set "REPO_ROOT=%~dp0"
cd /d "%REPO_ROOT%"

REM Git Pull with provided credentials
echo [STEP] Pulling latest code...
REM Password contains special chars, so we use URL encoding for safety in batch
REM ! -> %21, @ -> %40 (though @ is usually fine in URL if not delimiter)
REM Password: 1qaz2wsx!@QW
set "GIT_USER=17710388869"
set "GIT_PASS=1qaz2wsx%%21%%40QW"
git pull https://%GIT_USER%:%GIT_PASS%@gitee.com/MondayQuizlet/QuantTrader.git
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] Git pull failed. Continuing with existing code...
) else (
    echo [INFO] Code updated successfully.
)

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
    echo [WARN] PostgreSQL is not reachable at localhost:5432. Attempting to start...
    
    REM Kill any ghost postgres processes that might be locking files (先杀后启动)
    echo [INFO] Cleaning up any ghost postgres processes...
    taskkill /f /im postgres.exe >nul 2>&1
    taskkill /f /im pg_ctl.exe >nul 2>&1

    REM Check for stale PID file
    if exist "D:\pgsql\data\postmaster.pid" (
        echo [INFO] Found stale postmaster.pid, removing it...
        del /f "D:\pgsql\data\postmaster.pid"
    )

    if exist "D:\pgsql\bin\pg_ctl.exe" (
        echo [INFO] Starting database from D:\pgsql\bin...
        pushd "D:\pgsql\bin"
        .\pg_ctl.exe start -D "D:\pgsql\data" -w
        popd
    ) else (
        echo [ERROR] D:\pgsql\bin\pg_ctl.exe not found! Cannot auto-start database.
    )

    REM Re-check PostgreSQL
    powershell -Command "if (-not (Test-NetConnection localhost -Port 5432 -InformationLevel Quiet)) { exit 1 }"
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] PostgreSQL / TimescaleDB is not reachable at localhost:5432
        echo [ERROR] Please ensure your local database is running.
        echo [TIP] If the error is 0xC0000135, please install Visual C++ Redistributable.
        pause
        exit /b 1
    )
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

echo [INFO] checking ports...

REM Kill process on Port 3001 (Core Engine)
echo [STEP] Cleaning up Port 3001...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":3001" ^| findstr "LISTENING"') do (
    echo Killing PID %%a on port 3001...
    taskkill /f /pid %%a >nul 2>&1
)

REM Kill process on Port 5173 (Dashboard)
echo [STEP] Cleaning up Port 5173...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5173" ^| findstr "LISTENING"') do (
    echo Killing PID %%a on port 5173...
    taskkill /f /pid %%a >nul 2>&1
)

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
