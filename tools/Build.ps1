[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root 'app'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$required = @('Install-Profile.ps1','Set-WindowsPerformance.ps1','Start-Roblox-Performance.ps1','Set-Roblox-Display.ps1','Restore-Roblox-Graphics.ps1','Restore-All-Settings.ps1','Play-Rivals-Performance.cmd','Play-Gakuran-Performance.cmd','Play-Roblox-Performance.cmd','Restore-Desktop-Resolution.cmd','Restore-Roblox-Graphics.cmd','Restore-All-Settings.cmd','README.md')
# Only this explicit list goes into the installer. No settings backups or logs.
foreach ($name in $required) {
    $file = Join-Path $app $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing payload file: $name" }
    if ($name.EndsWith('.ps1')) {
        $tokens=$null; $errors=$null
        [Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors) | Out-Null
        if ($errors.Count) { throw ($errors | Out-String) }
    }
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$payload = Join-Path $dist 'payload.zip'
$stream = [IO.File]::Open($payload,[IO.FileMode]::Create)
try {
    $zip = New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        foreach ($name in $required) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $app $name),$name,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler was not found.' }
$setup = Join-Path $dist 'RobloxPerformance-Setup.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/resource:$payload,Payload.zip" "/out:$setup" (Join-Path $PSScriptRoot 'Setup.cs')
if ($LASTEXITCODE -ne 0) { throw 'Setup compilation failed.' }
$digest=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
"$digest  RobloxPerformance-Setup.exe" | Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Encoding ASCII
Write-Host "Built $setup"
