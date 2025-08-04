@echo off
REM Windows batch file to download K3S setup script
REM This script downloads the main K3S setup script for use on Linux systems

echo ==========================================
echo        K3S Setup - Download Script
echo ==========================================
echo.

echo This script will download the K3S setup script.
echo The downloaded script should be transferred to a Linux system for execution.
echo.

REM Check if PowerShell is available
powershell -Command "& {Write-Host 'PowerShell is available'}" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is required but not available.
    pause
    exit /b 1
)

REM Download the script using PowerShell
echo Downloading K3S setup script...
powershell -Command "& {Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/main/scripts/k3s-setup.sh' -OutFile 'k3s-setup.sh'}"

if %errorlevel% equ 0 (
    echo.
    echo Script downloaded successfully as 'k3s-setup.sh'
    echo.
    echo Next steps:
    echo 1. Transfer this file to your Linux system
    echo 2. Make it executable: chmod +x k3s-setup.sh
    echo 3. Run it: ./k3s-setup.sh
    echo.
    echo For more information, see: https://github.com/SolitworkAS/sw-k8s-public-infra/tree/main/scripts
) else (
    echo ERROR: Failed to download the script.
)

echo.
pause 