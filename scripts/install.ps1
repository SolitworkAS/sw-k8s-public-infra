# PowerShell script to download K3S setup script
# This script downloads the main K3S setup script for use on Linux systems

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        K3S Setup - Download Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will download the K3S setup script." -ForegroundColor Yellow
Write-Host "The downloaded script should be transferred to a Linux system for execution." -ForegroundColor Yellow
Write-Host ""

try {
    # Download the script
    Write-Host "Downloading K3S setup script..." -ForegroundColor Green
    $scriptUrl = "https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/main/scripts/k3s-setup.sh"
    $outputFile = "k3s-setup.sh"
    
    Invoke-WebRequest -Uri $scriptUrl -OutFile $outputFile
    
    Write-Host ""
    Write-Host "Script downloaded successfully as '$outputFile'" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Transfer this file to your Linux system" -ForegroundColor White
    Write-Host "2. Make it executable: chmod +x k3s-setup.sh" -ForegroundColor White
    Write-Host "3. Run it: ./k3s-setup.sh" -ForegroundColor White
    Write-Host ""
    Write-Host "For more information, see: https://github.com/SolitworkAS/sw-k8s-public-infra/tree/main/scripts" -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: Failed to download the script." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Read-Host "Press Enter to continue" 