@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
echo ============================================
echo Install finished. Press any key to close...
echo ============================================
pause >nul
