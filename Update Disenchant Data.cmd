@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-DisenchantData.ps1"
if errorlevel 1 (
    echo Update failed. Existing data preserved.
) else (
    echo Updated successfully.
)
pause
