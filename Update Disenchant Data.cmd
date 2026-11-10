@echo off
title Disenchant Tooltip - ForeverDB Update
echo Updating disenchant data from ForeverDB...
echo This can take a few minutes. Progress appears below.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-DisenchantData.ps1"
if errorlevel 1 (
    echo Update failed. Existing data preserved.
) else (
    echo Updated successfully.
)
pause
