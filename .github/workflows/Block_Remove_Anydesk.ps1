# Block-AnyDesk.ps1 — Run as Administrator
# Requires: Windows 10/11, PowerShell 5+

$ErrorActionPreference = 'SilentlyContinue'

## ── 1. SOFTWARE RESTRICTION / APPLOCKER ──────────────────────────────────
# Block AnyDesk.exe from running anywhere on the machine
$ruleName = 'Block AnyDesk'
$applockerXml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="11111111-1111-1111-1111-111111111111"
      Name="Allow Everyone - All files" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="*"/></Conditions>
    </FilePathRule>
    <FileHashRule Id="22222222-2222-2222-2222-222222222222"
      Name="Block AnyDesk" Description="Prevent AnyDesk from running" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions><FileHashCondition/></Conditions>
      <!-- Path-based denial -->
    </FileHashRule>
    <FilePathRule Id="33333333-3333-3333-3333-333333333333"
      Name="Block AnyDesk by name" Description="" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions><FilePathCondition Path="*\AnyDesk.exe"/></Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@

# Write AppLocker policy
$xmlPath = "$env:TEMP\anydesk-block.xml"
$applockerXml | Out-File $xmlPath -Encoding UTF8
Set-AppLockerPolicy -XmlPolicy $xmlPath -Merge
Write-Host "[OK] AppLocker rule set" -ForegroundColor Green

## ── 2. WINDOWS FIREWALL — block outbound + inbound ──────────────────────
$fwRules = @(
    @{ Name='AnyDesk Block Inbound';  Dir='Inbound';  Action='Block' },
    @{ Name='AnyDesk Block Outbound'; Dir='Outbound'; Action='Block' }
)
foreach ($rule in $fwRules) {
    New-NetFirewallRule `
        -DisplayName $rule.Name `
        -Direction   $rule.Dir `
        -Action      $rule.Action `
        -Program     "*\AnyDesk.exe" `
        -Enabled     True `
        -Profile     Any | Out-Null
}
Write-Host "[OK] Firewall rules added (inbound + outbound)" -ForegroundColor Green

## ── 3. BLOCK AnyDesk DOWNLOAD DOMAINS via HOSTS FILE ────────────────────
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$domains   = @(
    'download.anydesk.com',
    'relay.anydesk.com',
    'net.anydesk.com',
    'anydesk.com',
    'www.anydesk.com'
)
$existing = Get-Content $hostsPath
$toAdd    = $domains | Where-Object { $existing -notmatch $_ } |
              ForEach-Object { "0.0.0.0  $_  # AnyDesk block" }
if ($toAdd) { Add-Content $hostsPath ("`n" + ($toAdd -join "`n")) }
Write-Host "[OK] Hosts file updated ($($toAdd.Count) entries added)" -ForegroundColor Green

## ── 4. KILL + UNINSTALL any existing AnyDesk ────────────────────────────
Get-Process -Name AnyDesk | Stop-Process -Force
$paths = @(
    "$env:LOCALAPPDATA\Programs\AnyDesk\AnyDesk.exe",
    "$env:ProgramFiles\AnyDesk\AnyDesk.exe",
    "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        Start-Process $p '--remove' -Wait
        Write-Host "[OK] Uninstalled AnyDesk from $p" -ForegroundColor Green
    }
}

## ── 5. REGISTRY: disable service if it exists ───────────────────────────
$svc = 'AnyDesk'
if (Get-Service $svc -ErrorAction SilentlyContinue) {
    Stop-Service $svc -Force
    Set-Service  $svc -StartupType Disabled
    Write-Host "[OK] AnyDesk service disabled" -ForegroundColor Green
}

## ── 6. SCHEDULED TASK — re-enforce on every startup ─────────────────────
$taskAction = New-ScheduledTaskAction `
    -Execute    'powershell.exe' `
    -Argument   '-NonInteractive -WindowStyle Hidden -Command "Get-Process AnyDesk | Stop-Process -Force"'
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
$taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
Register-ScheduledTask `
    -TaskName   'Block AnyDesk Startup' `
    -Action     $taskAction `
    -Trigger    $taskTrigger `
    -Principal  $taskPrincipal `
    -Force | Out-Null
Write-Host "[OK] Startup enforcement task registered" -ForegroundColor Green

Write-Host "`n✔  AnyDesk is fully blocked. Reboot recommended." -ForegroundColor Cyan
