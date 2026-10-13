[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$windowsPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$env:PSModulePath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules'
$testId = [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('RobloxPerformanceTest-' + $testId)
$registryPrefix = 'HKCU:\Software\RobloxPerformanceValidation\'
$registryRoot = $registryPrefix + $testId
$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$powerBefore = (& $powercfg /getactivescheme) -join ' '
if ($LASTEXITCODE -ne 0 -or $powerBefore -notmatch '[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}') { throw 'Cannot capture the active power plan for the test.' }
$originalPower = $Matches[0]
try {
    $setup = Join-Path $root 'dist\RobloxPerformance-Setup.exe'
    $process = Start-Process -FilePath $setup -ArgumentList @('--extract-only',('"' + $testRoot + '"')) -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw 'Setup payload extraction failed.' }
    foreach ($file in Get-ChildItem (Join-Path $root 'app') -File) {
        $extracted = Join-Path $testRoot $file.Name
        if (-not (Test-Path -LiteralPath $extracted) -or (Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $extracted).Hash) { throw "Payload differs: $($file.Name)" }
    }
    Write-Host 'PASS: setup extracts the exact application payload.'
    # Run the real Windows settings helper with only registry destinations isolated.
    # The actual power plan is restored in finally, including if a test fails.
    if (Test-Path -LiteralPath $registryRoot) { throw 'The unique test registry destination already exists.' }
    $gameBar = $registryRoot + '\GameBar'
    $recording = $registryRoot + '\GameDVR'
    New-Item -Path $gameBar -Force | Out-Null
    New-Item -Path $recording -Force | Out-Null
    New-ItemProperty -LiteralPath $gameBar -Name AutoGameModeEnabled -Value 0 -PropertyType DWord | Out-Null
    New-ItemProperty -LiteralPath $gameBar -Name UnrelatedValue -Value 77 -PropertyType DWord | Out-Null
    New-ItemProperty -LiteralPath $recording -Name HistoricalCaptureEnabled -Value 1 -PropertyType DWord | Out-Null
    $helper = Join-Path $testRoot 'Set-WindowsPerformance.ps1'
    $contents = Get-Content -LiteralPath $helper -Raw
    $contents = $contents.Replace('HKCU:\Software\Microsoft\GameBar',$gameBar).Replace('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR',$recording)
    [IO.File]::WriteAllText($helper,$contents,(New-Object Text.UTF8Encoding($false)))
    & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File $helper
    if ($LASTEXITCODE -ne 0) { throw 'Applying Windows test settings failed.' }
    if ((Get-ItemPropertyValue $gameBar AutoGameModeEnabled) -ne 1 -or (Get-ItemPropertyValue $gameBar AllowAutoGameMode) -ne 1 -or (Get-ItemPropertyValue $recording HistoricalCaptureEnabled) -ne 0 -or (Get-ItemPropertyValue $gameBar UnrelatedValue) -ne 77) { throw 'Windows changes or unrelated value preservation failed.' }
    $backup = Join-Path $testRoot 'windows-before-profile.json'
    $firstBackupHash = (Get-FileHash -LiteralPath $backup).Hash
    & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File $helper
    if ($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $backup).Hash -ne $firstBackupHash) { throw 'Repeated setup replaced the original Windows backup.' }
    & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File $helper -Restore
    if ($LASTEXITCODE -ne 0) { throw 'Windows test restoration failed.' }
    if ((Get-ItemPropertyValue $gameBar AutoGameModeEnabled) -ne 0 -or (Get-ItemPropertyValue $recording HistoricalCaptureEnabled) -ne 1 -or (Get-ItemPropertyValue $gameBar UnrelatedValue) -ne 77 -or (Get-Item $gameBar).GetValueNames() -contains 'AllowAutoGameMode') { throw 'Original registry settings were not restored.' }
    Write-Host 'PASS: apply/restore preserves unrelated registry values and retains first backups on repeat setup.'
    & $windowsPs -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $testRoot 'Set-Roblox-Display.ps1') -Mode Restore
    if ($LASTEXITCODE -ne 0) { throw 'Restore without a display backup should be a no-op.' }
    Write-Host 'PASS: display restore without a backup succeeds without changing resolution.'
    Write-Host "All package checks passed. Extracted test files remain at $testRoot."
} finally {
    & $powercfg /setactive $originalPower | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning 'The test could not restore the original power plan.' }
    # Remove only the unique, verified test registry subtree created above.
    if ($registryRoot.StartsWith($registryPrefix,[StringComparison]::OrdinalIgnoreCase) -and
        $registryRoot.Substring($registryPrefix.Length) -match '^[a-f0-9]{32}$' -and
        (Test-Path -LiteralPath $registryRoot)) {
        Remove-Item -LiteralPath $registryRoot -Recurse -Force
    }
}
