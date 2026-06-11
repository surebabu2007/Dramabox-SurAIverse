@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch.ps1"
if errorlevel 1 (
    echo.
    echo DramaBox exited with an error. See messages above.
    pause
)
