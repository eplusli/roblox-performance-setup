[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Assert-VersionPath([string]$Path, [string]$VersionsRoot) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($VersionsRoot).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing a path outside Roblox Versions: $resolved"
    }
    return $resolved
}

function Restore-AtomicFile([string]$Original, [string]$Destination) {
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($Destination)) ('.roblox-restore-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Copy-Item -LiteralPath $Original -Destination $temporary
        if (Test-Path -LiteralPath $Destination -PathType Leaf) {
            [IO.File]::Replace($temporary, $Destination, [System.Management.Automation.Language.NullString]::Value)
        } else {
            [IO.File]::Move($temporary, $Destination)
        }
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

try {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Roblox(Player|Studio|Installer)' })
    if ($running.Count -gt 0) { throw 'Close Roblox and Roblox Studio before restoring graphics. No process was stopped.' }
    $versionsRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Roblox\Versions'))
    $backupRoot = Join-Path $PSScriptRoot 'graphics-backups'
    $restorePlans = @()
    if (Test-Path -LiteralPath $backupRoot -PathType Container) {
        foreach ($backupDirectory in @(Get-ChildItem -LiteralPath $backupRoot -Directory)) {
            $metadataPath = Join-Path $backupDirectory.FullName 'metadata.json'
            if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) { continue }
            $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
            $versionName = [string]$metadata.VersionName
            if ($metadata.SchemaVersion -ne 1 -or $versionName -notmatch '^version-[a-fA-F0-9]+$' -or $backupDirectory.Name -cne $versionName) {
                throw "Unrecognized backup metadata in $($backupDirectory.Name). Nothing was restored."
            }
            $versionDirectory = Assert-VersionPath (Join-Path $versionsRoot $versionName) $versionsRoot
            if ([IO.Path]::GetFullPath([string]$metadata.VersionDirectory) -ine $versionDirectory) {
                throw "The backup path does not match the official version directory: $versionName"
            }
            $flagsPath = Assert-VersionPath (Join-Path $versionDirectory 'ClientSettings\ClientAppSettings.json') $versionsRoot
            $originalPath = Join-Path $backupDirectory.FullName 'ClientAppSettings.original.json'
            if ($metadata.OriginalFlagsExisted -and -not (Test-Path -LiteralPath $originalPath -PathType Leaf)) {
                throw "The original graphics backup is missing for $versionName. Nothing was restored."
            }
            $restorePlans += [pscustomobject]@{
                VersionName = $versionName
                VersionDirectory = $versionDirectory
                FlagsPath = $flagsPath
                OriginalPath = $originalPath
                OriginalFlagsExisted = [bool]$metadata.OriginalFlagsExisted
            }
        }
    }
    # Validate every backup before making the first restoration.
    $restoredCount = 0
    foreach ($plan in $restorePlans) {
        if (-not (Test-Path -LiteralPath $plan.VersionDirectory -PathType Container)) {
            Write-Host "Skipped removed Roblox version $($plan.VersionName)."
            continue
        }
        $safeFlagsPath = Assert-VersionPath $plan.FlagsPath $versionsRoot
        if ($plan.OriginalFlagsExisted) {
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($safeFlagsPath)) -Force | Out-Null
            Restore-AtomicFile $plan.OriginalPath $safeFlagsPath
        } elseif (Test-Path -LiteralPath $safeFlagsPath -PathType Leaf) {
            # The verified target is one JSON file, never a directory or recursive deletion.
            Remove-Item -LiteralPath $safeFlagsPath -Force
        }
        $restoredCount++
        Write-Host "Restored original graphics flags for $($plan.VersionName)."
    }
    $xmlBackupPath = Join-Path $PSScriptRoot 'settings-before-advanced.xml'
    if (Test-Path -LiteralPath $xmlBackupPath -PathType Leaf) {
        $xmlDestination = Join-Path $env:LOCALAPPDATA 'Roblox\GlobalBasicSettings_13.xml'
        if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($xmlDestination)) -PathType Container)) {
            throw 'The local Roblox settings directory no longer exists; saved XML was preserved.'
        }
        Restore-AtomicFile $xmlBackupPath $xmlDestination
        Write-Host 'Restored the settings XML saved before this advanced profile.'
    } else {
        Write-Host 'No advanced settings XML backup was found.'
    }
    Write-Host "Graphics restoration completed for $restoredCount installed version(s). Earlier Windows and power changes remain unchanged."
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
