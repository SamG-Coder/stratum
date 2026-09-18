@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js 20 or newer is required. Install it from https://nodejs.org/ and try again.
  pause
  exit /b 1
)
node server.mjs --open
if errorlevel 1 pause
