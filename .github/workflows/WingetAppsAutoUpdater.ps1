# Get the Windows version
$osInfo = Get-WmiObject -Class Win32_OperatingSystem

# Parse the version number and product type
$version = [Version] $osInfo.Version
$productType = $osInfo.ProductType

# Windows 10 1809+ (10.0.17763), Windows 11 (10.0.22000+), or Server 2022 (10.0.20348+)
if (
    ($productType -eq 1 -and $version -ge [Version] "10.0.17763") -or
    ($productType -eq 1 -and $version -ge [Version] "10.0.22000") -or
    ($productType -eq 3 -and $version -ge [Version] "10.0.20348")
) {
    # Change directory to WindowsApps
    Set-Location "C:\Program Files\WindowsApps\"

    # Find the latest DesktopAppInstaller directory
    $installer = Get-ChildItem -Directory "Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" | Sort-Object Name -Descending | Select-Object -First 1

    if ($null -eq $installer) {
        Write-Output "DesktopAppInstaller not found."
        exit 1
    }

    # Change to the selected directory
    Set-Location $installer.FullName

    # Run the winget upgrade
    .\winget.exe upgrade --all -h --accept-package-agreements --accept-source-agreements --include-unknown --force

} else {
    Write-Output "The system does not meet the minimum requirements. This script requires Windows 10 1809 or later, any version of Windows 11, or Windows Server 2022."

}
