@echo off
setlocal EnableDelayedExpansion

REM Add PostgreSQL bin to PATH at the start to ensure DLLs are always found
if exist "D:\pgsql\bin" (
    set "PATH=D:\pgsql\bin;%PATH%"
)

REM Get the absolute path to the repo root (directory of this script)
set "REPO_ROOT=%~dp0"
cd /d "%REPO_ROOT%"

REM ---------------------------------------------------------------------------
REM MAIN LOOP: Start / Restart point
REM ---------------------------------------------------------------------------
:MAIN_LOOP

REM ---------------------------------------------------------------------------
REM Log Rotation & Cleanup (Max 500MB)
REM ---------------------------------------------------------------------------
REM ---------------------------------------------------------------------------
REM Log Rotation & Cleanup (Max 500MB)
REM ---------------------------------------------------------------------------
echo [STEP] Rotating and cleaning up logs...
REM Define rotation script content to avoid complex inline escaping issues
(
echo $logDir = '.';
echo $archiveDir = 'logs_archive';
echo if ^(!^(Test-Path $archiveDir^)^) { New-Item -ItemType Directory -Path $archiveDir ^| Out-Null };
echo $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss';
echo $logs = @^('core_engine.log', 'dashboard.log', 'ai_brain.log'^);
echo foreach ^($log in $logs^) {
echo     if ^(Test-Path $log^) {
echo         try {
echo             Move-Item $log $archiveDir\$log.$timestamp.bak -ErrorAction Stop;
echo             Write-Host "Archived: $log";
echo         } catch { Write-Warning "Could not archive $log" }
echo     }
echo };
echo $limit = 500 * 1024 * 1024;
echo $files = Get-ChildItem $archiveDir ^| Sort-Object CreationTime;
echo $currentSize = ^($files ^| Measure-Object -Property Length -Sum^).Sum;
echo if ^($currentSize -eq $null^) { $currentSize = 0 };
echo Write-Host "Current Archive Size: " ^([math]::Round^($currentSize / 1MB, 2^)^) "MB";
echo foreach ^($file in $files^) {
echo     if ^($currentSize -le $limit^) { break };
echo     try {
echo         $currentSize -= $file.Length;
echo         Remove-Item $file.FullName -Force;
echo         Write-Host "Cleaned up old log: " $file.Name;
echo     } catch { }
echo }
) > rotate_logs.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File rotate_logs.ps1
del rotate_logs.ps1
echo [INFO] Log rotation complete.

REM ---------------------------------------------------------------------------

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
        REM Use start /WAIT /MIN to launch pg_ctl in a separate process but wait for it to complete (it waits for DB up due to -w)
        REM This ensures the main script waits for readiness, but the DB process is detached from this console.
        start /WAIT /MIN "PostgreSQL" "D:\pgsql\bin\pg_ctl.exe" start -D "D:\pgsql\data" -w
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

REM Start Core Engine (Rust) in background
echo [STEP] Starting Core Engine...
cd "%REPO_ROOT%\quantum-engine\core_engine"
start /B "QuantTrader Core Engine" cargo run > "%REPO_ROOT%\core_engine.log" 2>&1

REM Start Dashboard (React) in background
echo [STEP] Starting Dashboard...
cd "%REPO_ROOT%\quantum-engine\dashboard"
start /B "QuantTrader Dashboard" npm run dev -- --host > "%REPO_ROOT%\dashboard.log" 2>&1

REM Start AI Brain (Python) in background
echo [STEP] Starting AI Brain...
cd "%REPO_ROOT%\quantum-engine\ai_brain"

REM Determine Python Executable
set "PYTHON_EXE=python"
if exist "venv\Scripts\python.exe" (
    set "PYTHON_EXE=venv\Scripts\python.exe"
    echo [INFO] Using virtualenv python: !PYTHON_EXE!
) else (
    echo [INFO] Using system python.
)

start /B "QuantTrader AI Brain" !PYTHON_EXE! src\main.py > "%REPO_ROOT%\ai_brain.log" 2>&1

cd "%REPO_ROOT%"

echo [INFO] All services launched in background.
echo [INFO] Logs are being written to:
echo [INFO] - core_engine.log
echo [INFO] - dashboard.log
echo [INFO] - ai_brain.log
echo [INFO] Core Engine API: http://localhost:3001
echo [INFO] Dashboard: http://localhost:5173

REM ---------------------------------------------------------------------------
REM AUTO-UPDATE MONITOR LOOP
REM ---------------------------------------------------------------------------
:MONITOR_LOOP
echo [MONITOR] Watching for git updates (Ctrl+C to stop)...
timeout /t 20 /nobreak >nul

REM Fetch remote to see if there are updates
git fetch origin >nul 2>&1
git status -uno | find "Your branch is behind" >nul

if %ERRORLEVEL%==0 (
    echo [INFO] ---------------------------------------------------------------
    echo [INFO] New version detected! Restarting services...
    echo [INFO] ---------------------------------------------------------------
    
    REM Kill known processes to allow update
    echo [STEP] Stopping services...
    taskkill /F /IM "core_engine.exe" >nul 2>&1
    taskkill /F /IM "node.exe" >nul 2>&1
    taskkill /F /IM "python.exe" >nul 2>&1
    
    goto MAIN_LOOP
)

goto MONITOR_LOOP
