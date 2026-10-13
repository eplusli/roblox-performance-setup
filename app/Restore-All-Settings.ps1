$ErrorActionPreference = 'Stop'
$windowsPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    if (@(Get-Process -ErrorAction SilentlyContinue | Where-Object ProcessName -Match '^Roblox(Player|Studio|Installer)').Count) { throw 'Close Roblox and Studio before restoring settings.' }
    $displayBackup = Join-Path $PSScriptRoot 'display-before-game.json'
    if ((Test-Path -LiteralPath $displayBackup) -and (Get-Content -LiteralPath $displayBackup -Raw | ConvertFrom-Json).Active) {
        & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Set-Roblox-Display.ps1') -Mode Restore
        if ($LASTEXITCODE -ne 0) { throw 'Desktop restoration failed; backups were kept.' }
    }
    & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Restore-Roblox-Graphics.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Graphics restoration failed; backups were kept.' }
    & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Set-WindowsPerformance.ps1') -Restore
    if ($LASTEXITCODE -ne 0) { throw 'Windows restoration failed; backups were kept.' }
    Write-Host 'Saved settings restored. Launchers and backups remain installed.'
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
