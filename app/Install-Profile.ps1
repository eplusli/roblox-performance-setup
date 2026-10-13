[CmdletBinding()]
param([switch]$SkipApply)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$windowsPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$env:PSModulePath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules'
try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop -PathType Container)) { throw 'Your Desktop folder could not be located.' }
    $shortcutShell = New-Object -ComObject WScript.Shell
    $shortcuts = @(
        @{Name='Rivals - Performance';File='Play-Rivals-Performance.cmd'},
        @{Name='Gakuran - Performance';File='Play-Gakuran-Performance.cmd'},
        @{Name='Roblox - Performance';File='Play-Roblox-Performance.cmd'},
        @{Name='Restore Desktop Resolution';File='Restore-Desktop-Resolution.cmd'},
        @{Name='Restore Roblox Performance Settings';File='Restore-All-Settings.cmd'}
    )
    foreach ($spec in $shortcuts) {
        $shortcut = $shortcutShell.CreateShortcut((Join-Path $desktop ($spec.Name + '.lnk')))
        $shortcut.TargetPath = Join-Path $PSScriptRoot $spec.File
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = 'Roblox Performance 1.0.0'
        $shortcut.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',21'
        $shortcut.Save()
    }
    if (-not $SkipApply) {
        & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Set-WindowsPerformance.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'Windows settings could not be applied. See setup-last.log.' }
        $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object ProcessName -Match '^Roblox(Player|Studio|Installer)')
        if ($running.Count -eq 0) {
            & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'Start-Roblox-Performance.ps1') -Renderer D3D11 -Game Home -ApplyOnly
            if ($LASTEXITCODE -ne 0) {
                Write-Host 'Installed successfully. The graphics profile could not be applied now; the launchers will retry. Roblox must be installed from roblox.com.'
            }
        } else { Write-Host 'Roblox is running. Graphics will be applied on your next launch after you close it.' }
    }
    Write-Host "Installed in $PSScriptRoot. Use the Rivals, Gakuran or Roblox Performance desktop shortcuts."
    Write-Host 'Close Roblox before using another launcher. Press Alt+Enter in-game for exclusive fullscreen.'
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
