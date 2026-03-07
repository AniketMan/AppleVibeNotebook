@echo off
title Fig Viewer
color 0A

echo.
echo  ============================================
echo    Fig Viewer - Figma Asset Extractor
echo  ============================================
echo.

:: Check for Node.js
where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    color 0C
    echo  [ERROR] Node.js is not installed or not in PATH.
    echo.
    echo  Please install Node.js from: https://nodejs.org
    echo  Then re-run this script.
    echo.
    pause
    exit /b 1
)

:: Show Node version
for /f "tokens=*" %%i in ('node -v') do set NODE_VER=%%i
echo  Node.js %NODE_VER% detected.

:: Check for unzip (optional, PowerShell fallback exists)
echo  Checking dependencies...

:: Install npm dependencies if needed
if not exist "node_modules" (
    echo  Installing dependencies (first run only)...
    echo.
    call npm install --production
    if %ERRORLEVEL% neq 0 (
        color 0C
        echo.
        echo  [ERROR] Failed to install dependencies.
        echo  Check your internet connection and try again.
        echo.
        pause
        exit /b 1
    )
    echo.
    echo  Dependencies installed successfully.
)

echo.
echo  Starting Fig Viewer...
echo  Open your browser to: http://localhost:4000
echo.
echo  Press Ctrl+C to stop the server.
echo  ============================================
echo.

:: Open browser automatically
start "" http://localhost:4000

:: Start the server
node server.js

pause
