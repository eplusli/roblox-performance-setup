[CmdletBinding()]
param([switch]$Restore)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$backupPath = Join-Path $PSScriptRoot 'windows-before-profile.json'
$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$entries = @(
    @{ Path='HKCU:\Software\Microsoft\GameBar'; Name='AutoGameModeEnabled'; Value=1 },
    @{ Path='HKCU:\Software\Microsoft\GameBar'; Name='AllowAutoGameMode'; Value=1 },
    @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name='HistoricalCaptureEnabled'; Value=0 }
)
if ($Restore) {
    if (-not (Test-Path -LiteralPath $backupPath)) { Write-Host 'No Windows backup exists; nothing to restore.'; exit 0 }
    $saved = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
    if ($saved.SchemaVersion -ne 1 -or $saved.Entries.Count -ne $entries.Count) { throw 'Unrecognized Windows backup.' }
    # Validate all paths and values before restoring any registry entry.
    for ($i=0; $i -lt $entries.Count; $i++) {
        if ($saved.Entries[$i].Path -cne $entries[$i].Path -or $saved.Entries[$i].Name -cne $entries[$i].Name) { throw 'Windows backup does not match the supported settings.' }
        if ($saved.Entries[$i].Existed -and $saved.Entries[$i].Kind -ne 'DWord') { throw 'Unsupported registry value type in Windows backup.' }
    }
    if ([string]$saved.PowerScheme -notmatch '^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$') { throw 'Invalid power scheme backup.' }
    foreach ($entry in $saved.Entries) {
        if ($entry.Existed) {
            if (-not (Test-Path -LiteralPath $entry.Path)) { New-Item -Path $entry.Path | Out-Null }
            New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value ([int]$entry.Value) -PropertyType DWord -Force | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
        }
    }
    & $powercfg /setactive $saved.PowerScheme | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Windows settings were restored, but the saved power scheme is no longer available.' }
    Write-Host 'Saved Windows Game Mode, historical recording and power plan restored.'
    exit 0
}
if (-not (Test-Path -LiteralPath $backupPath)) {
    $capturedEntries = @()
    foreach ($entry in $entries) {
        $key = Get-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue
        $existed = $null -ne $key -and $key.GetValueNames() -contains $entry.Name
        $value = $null; $kind = $null
        if ($existed) {
            $value = $key.GetValue($entry.Name)
            $kind = [string]$key.GetValueKind($entry.Name)
            if ($kind -ne 'DWord') { throw "Unsupported existing type for $($entry.Name); nothing changed." }
        }
        $capturedEntries += [pscustomobject]@{Path=$entry.Path;Name=$entry.Name;Existed=[bool]$existed;Value=$value;Kind=$kind}
    }
    $powerOutput = & $powercfg /getactivescheme
    if ($LASTEXITCODE -ne 0 -or ($powerOutput -join ' ') -notmatch '[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}') { throw 'Cannot back up the active power scheme.' }
    $powerScheme = $Matches[0]
    [pscustomobject]@{SchemaVersion=1;Entries=$capturedEntries;PowerScheme=$powerScheme} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupPath -Encoding UTF8
}
foreach ($entry in $entries) {
    # Never recreate an existing registry key with -Force: preserve unrelated values.
    if (-not (Test-Path -LiteralPath $entry.Path)) { New-Item -Path $entry.Path | Out-Null }
    New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType DWord -Force | Out-Null
}
$schemes = (& $powercfg /list) -join ' '
$highPerformance = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
if ($schemes -match $highPerformance) {
    & $powercfg /setactive $highPerformance | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning 'High Performance power could not be selected.' }
    else { Write-Host 'High Performance power selected. This can increase power use.' }
} else { Write-Host 'High Performance is unavailable; the current power scheme was retained.' }
Write-Host 'Game Mode enabled; historical background game recording disabled.'
