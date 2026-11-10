@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-DisenchantTooltip.ps1"
if errorlevel 1 (
    echo Installation failed.
) else (
    echo Installed successfully.
)
pause
