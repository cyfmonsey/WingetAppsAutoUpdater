# ====================================================================
# Script: Block-AnyDesk.ps1
# Description: Kills, uninstalls, cleans up, and permanently blocks 
#              AnyDesk from being executed or installed on Windows.
# ====================================================================

# Ensure the script is running as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Elevated privileges required. Please run this script as an Administrator."
    Exit
}

Write-Host "Starting AnyDesk removal and blocking process..." -ForegroundColor Cyan

# 1. Kill running AnyDesk processes
Write-Host "Terminating active AnyDesk processes..."
Stop-Process -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 2. Silent Uninstallation
Write-Host "Attempting silent uninstallation..."
$anydeskPaths = @(
    "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe",
    "${env:ProgramFiles}\AnyDesk\AnyDesk.exe",
    "$env:APPDATA\AnyDesk\AnyDesk.exe",
    "$env:LOCALAPPDATA\AnyDesk\AnyDesk.exe",
    "$env:ProgramData\AnyDesk\AnyDesk.exe"
)

foreach ($path in $anydeskPaths) {
    if (Test-Path $path) {
        Write-Host "Found AnyDesk at $path. Uninstalling..."
        # AnyDesk supports the --remove command for silent uninstallation
        Start-Process -FilePath $path -ArgumentList "--remove" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
}

# 3. Clean up leftover files and folders
Write-Host "Cleaning up leftover directories..."
$folders = @(
    "${env:ProgramFiles(x86)}\AnyDesk",
    "${env:ProgramFiles}\AnyDesk",
    "$env:APPDATA\AnyDesk",
    "$env:LOCALAPPDATA\AnyDesk",
    "$env:ProgramData\AnyDesk"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed directory: $folder"
    }
}

# 4. Block Execution via Image File Execution Options (IFEO)
# This redirects any attempt to run anydesk.exe into a dummy process that immediately exits.
Write-Host "Applying Registry block to prevent anydesk.exe from running..."
$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\anydesk.exe"

if (!(Test-Path $ifeoPath)) {
    New-Item -Path $ifeoPath -Force | Out-Null
}
# 'systray.exe' is a legacy Windows stub that does nothing and immediately closes, silently neutralizing AnyDesk.
Set-ItemProperty -Path $ifeoPath -Name "Debugger" -Value "systray.exe" -Type String -Force

# 5. Block AnyDesk network traffic via Hosts file
Write-Host "Blocking AnyDesk domains in the Hosts file..."
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$blockEntries = @(
    "127.0.0.1 anydesk.com",
    "127.0.0.1 www.anydesk.com",
    "127.0.0.1 boot.net.anydesk.com",
    "127.0.0.1 relay.net.anydesk.com"
)

$hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
foreach ($entry in $blockEntries) {
    if ($hostsContent -notcontains $entry) {
        Add-Content -Path $hostsPath -Value "`n$entry"
    }
}

Write-Host "=======================================================" -ForegroundColor Green
Write-Host "Success: AnyDesk has been removed and successfully blocked!" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
