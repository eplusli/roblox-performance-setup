[CmdletBinding()]
param(
    [ValidateSet('D3D11', 'Vulkan')]
    [string]$Renderer = 'D3D11',
    [ValidateSet('Home', 'Rivals', 'Gakuran')]
    [string]$Game = 'Rivals',
    [switch]$ApplyOnly,
    [switch]$Fullscreen720
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$restoreDisplay = $false

function Assert-RobloxClosed {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Roblox(Player|Studio|Installer)' })
    if ($running.Count -gt 0) {
        throw 'Close Roblox and Roblox Studio before applying this profile. No process was stopped.'
    }
}

function Assert-VersionPath([string]$Path, [string]$VersionsRoot) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($VersionsRoot).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing a path outside Roblox Versions: $resolved"
    }
    return $resolved
}

function Write-AtomicText([string]$Path, [string]$Text) {
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($Path)) ('.roblox-profile-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, $Text, (New-Object Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temporary, $Path, [System.Management.Automation.Language.NullString]::Value)
        } else {
            [IO.File]::Move($temporary, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

function Set-ExistingXmlProperty([xml]$Document, [string]$Name, [string]$Value) {
    $node = $Document.SelectSingleNode("/roblox/Item[@class='UserGameSettings']/Properties/*[@name='$Name']")
    if ($null -ne $node) { $node.InnerText = $Value }
}

function Resolve-OfficialPlayer([string]$VersionsRoot) {
    $candidates = New-Object 'Collections.Generic.List[string]'
    # HKCR includes both per-user and machine-wide protocol registrations.
    foreach ($keyPath in @(
        'Registry::HKEY_CLASSES_ROOT\roblox\shell\open\command',
        'Registry::HKEY_CURRENT_USER\Software\Classes\roblox\shell\open\command',
        'Registry::HKEY_LOCAL_MACHINE\Software\Classes\roblox\shell\open\command'
    )) {
        $key = Get-Item -LiteralPath $keyPath -ErrorAction SilentlyContinue
        if ($null -eq $key) { continue }
        $command = [string]$key.GetValue('')
        if ($command -match '^\s*"([^"]+)"') { $candidates.Add($Matches[1]) }
        elseif ($command -match '^\s*([^\s]+)') { $candidates.Add($Matches[1]) }
    }
    # An official installation can remain usable even without a URI registration.
    $versions = @(Get-ChildItem -LiteralPath $VersionsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -Match '^version-[a-fA-F0-9]+$' | Sort-Object LastWriteTime -Descending)
    foreach ($version in $versions) {
        $candidates.Add((Join-Path $version.FullName 'RobloxPlayerBeta.exe'))
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            $path = Assert-VersionPath $candidate $VersionsRoot
            $directory = [IO.Path]::GetDirectoryName($path)
            if ([IO.Path]::GetFileName($path) -cne 'RobloxPlayerBeta.exe' -or
                [IO.Path]::GetFileName($directory) -notmatch '^version-[a-fA-F0-9]+$' -or
                [IO.Path]::GetDirectoryName($directory).TrimEnd('\') -ine [IO.Path]::GetFullPath($VersionsRoot).TrimEnd('\') -or
                -not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            $signature = Get-AuthenticodeSignature -LiteralPath $path
            if ($signature.Status -eq 'Valid' -and $null -ne $signature.SignerCertificate -and
                $signature.SignerCertificate.Subject -match '(?:^|,\s*)CN=Roblox Corporation(?:,|$)') {
                return $path
            }
        } catch { continue }
    }
    throw 'No signed official Roblox player was found. Repair Roblox using its official installer.'
}

try {
    Assert-RobloxClosed
    $versionsRoot = Join-Path $env:LOCALAPPDATA 'Roblox\Versions'
    $playerPath = Resolve-OfficialPlayer $versionsRoot
    $playerPath = Assert-VersionPath $playerPath $versionsRoot
    if ([IO.Path]::GetFileName($playerPath) -cne 'RobloxPlayerBeta.exe' -or -not (Test-Path -LiteralPath $playerPath -PathType Leaf)) {
        throw 'The registered command is not an installed official RobloxPlayerBeta.exe.'
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $playerPath
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Subject -notmatch '(?:^|,\s*)CN=Roblox Corporation(?:,|$)') {
        throw 'Roblox player signature verification failed. The player was not launched or modified.'
    }
    $versionDirectory = [IO.Path]::GetDirectoryName($playerPath)
    $versionName = [IO.Path]::GetFileName($versionDirectory)
    if ($versionName -notmatch '^version-[a-fA-F0-9]+$' -or [IO.Path]::GetDirectoryName($versionDirectory).TrimEnd('\') -ine [IO.Path]::GetFullPath($versionsRoot).TrimEnd('\')) {
        throw 'The registered player is not directly inside an official Roblox version directory.'
    }

    $profile = [ordered]@{
        DFFlagDisableDPIScale = 'False'
        DFFlagTextureQualityOverrideEnabled = 'True'
        DFIntTextureQualityOverride = '0'
        FIntDebugForceMSAASamples = '1'
        DFIntDebugFRMQualityLevelOverride = '1'
        FIntFRMMinGrassDistance = '0'
        FIntFRMMaxGrassDistance = '0'
        DFIntCSGLevelOfDetailSwitchingDistance = '250'
        DFIntCSGLevelOfDetailSwitchingDistanceL12 = '250'
        DFIntCSGLevelOfDetailSwitchingDistanceL23 = '250'
        DFIntCSGLevelOfDetailSwitchingDistanceL34 = '250'
        FFlagDebugGraphicsPreferD3D11 = $(if ($Renderer -eq 'D3D11') { 'True' } else { 'False' })
        FFlagDebugGraphicsPreferVulkan = $(if ($Renderer -eq 'Vulkan') { 'True' } else { 'False' })
        FFlagDebugGraphicsPreferOpenGL = 'False'
        FFlagHandleAltEnterFullscreenManually = 'False'
    }

    # Roblox publishes its current allowlist as a Base64-encoded JSON payload.
    # HTTPS authenticates the source; this script does not implement Roblox's private signature verifier.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $liveConfiguration = Invoke-RestMethod -Uri 'https://clientsettingscdn.roblox.com/v2/settings/application/PCDesktopClient' -TimeoutSec 30
    $encodedAllowlist = [string]$liveConfiguration.applicationSettings.DFStringAllowedPublicFlags
    if ([string]::IsNullOrWhiteSpace($encodedAllowlist)) { throw 'Roblox did not publish its current public allowlist. Nothing was changed.' }
    $decodedAllowlist = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encodedAllowlist)) | ConvertFrom-Json
    $allowedFlags = @($decodedAllowlist.Allowed)
    if ($allowedFlags.Count -eq 0) { throw 'The current public allowlist is empty. Nothing was changed.' }
    foreach ($flag in $profile.Keys) {
        if ($allowedFlags -cnotcontains $flag) {
            throw "Roblox no longer allows $flag. Nothing was changed; update this profile before using it."
        }
    }

    $clientSettingsDirectory = Assert-VersionPath (Join-Path $versionDirectory 'ClientSettings') $versionsRoot
    $flagsPath = Assert-VersionPath (Join-Path $clientSettingsDirectory 'ClientAppSettings.json') $versionsRoot
    $mergedSettings = [ordered]@{}
    $flagsExisted = Test-Path -LiteralPath $flagsPath -PathType Leaf
    if ($flagsExisted) {
        $existingSettings = Get-Content -LiteralPath $flagsPath -Raw | ConvertFrom-Json
        if ($null -eq $existingSettings -or $existingSettings -is [Array] -or $existingSettings -isnot [pscustomobject]) {
            throw 'Existing ClientAppSettings.json is not a JSON object. Nothing was changed.'
        }
        foreach ($property in $existingSettings.PSObject.Properties) {
            $mergedSettings[$property.Name] = $property.Value
        }
    }
    foreach ($flag in $profile.Keys) { $mergedSettings[$flag] = $profile[$flag] }
    $newFlagsJson = $mergedSettings | ConvertTo-Json -Depth 100

    $globalSettingsPath = Join-Path $env:LOCALAPPDATA 'Roblox\GlobalBasicSettings_13.xml'
    $globalSettingsExisted = Test-Path -LiteralPath $globalSettingsPath -PathType Leaf
    $settingsXmlText = $null
    if ($globalSettingsExisted) {
        $settingsDocument = New-Object Xml.XmlDocument
        $settingsDocument.PreserveWhitespace = $true
        $settingsDocument.Load($globalSettingsPath)
        Set-ExistingXmlProperty $settingsDocument 'FramerateCap' '60'
        Set-ExistingXmlProperty $settingsDocument 'SavedQualityLevel' '1'
        Set-ExistingXmlProperty $settingsDocument 'GraphicsQualityLevel' '1'
        Set-ExistingXmlProperty $settingsDocument 'Fullscreen' $(if ($Fullscreen720) { 'true' } else { 'false' })
        Set-ExistingXmlProperty $settingsDocument 'StartMaximized' 'false'
        Set-ExistingXmlProperty $settingsDocument 'PerformanceStatsVisible' 'false'
        $widthNode = $settingsDocument.SelectSingleNode("/roblox/Item[@class='UserGameSettings']/Properties/Vector2[@name='StartScreenSize']/X")
        $heightNode = $settingsDocument.SelectSingleNode("/roblox/Item[@class='UserGameSettings']/Properties/Vector2[@name='StartScreenSize']/Y")
        if ($null -ne $widthNode) { $widthNode.InnerText = '1280' }
        if ($null -ne $heightNode) { $heightNode.InnerText = '720' }
        $settingsXmlText = $settingsDocument.OuterXml
    }

    # Guard again after the network request and parsing; never write a live player's files.
    Assert-RobloxClosed
    $backupDirectory = Join-Path (Join-Path $PSScriptRoot 'graphics-backups') $versionName
    $metadataPath = Join-Path $backupDirectory 'metadata.json'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        if ($flagsExisted) {
            Copy-Item -LiteralPath $flagsPath -Destination (Join-Path $backupDirectory 'ClientAppSettings.original.json') -Force
        }
        $metadata = [ordered]@{
            SchemaVersion = 1
            VersionName = $versionName
            VersionDirectory = $versionDirectory
            OriginalFlagsExisted = [bool]$flagsExisted
            BackedUpAt = [DateTimeOffset]::Now.ToString('o')
        }
        Write-AtomicText $metadataPath ($metadata | ConvertTo-Json)
    } else {
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        if ($metadata.VersionName -cne $versionName -or [IO.Path]::GetFullPath([string]$metadata.VersionDirectory) -ine $versionDirectory) {
            throw 'The existing graphics backup does not match this player version. Nothing was applied.'
        }
        if ($metadata.OriginalFlagsExisted -and -not (Test-Path -LiteralPath (Join-Path $backupDirectory 'ClientAppSettings.original.json') -PathType Leaf)) {
            throw 'The original graphics backup is missing. Nothing was applied.'
        }
    }
    $xmlBackupPath = Join-Path $PSScriptRoot 'settings-before-advanced.xml'
    if ($globalSettingsExisted -and -not (Test-Path -LiteralPath $xmlBackupPath -PathType Leaf)) {
        Copy-Item -LiteralPath $globalSettingsPath -Destination $xmlBackupPath
    }
    New-Item -ItemType Directory -Path $clientSettingsDirectory -Force | Out-Null
    Write-AtomicText $flagsPath $newFlagsJson
    if ($null -ne $settingsXmlText) { Write-AtomicText $globalSettingsPath $settingsXmlText }
    $displayDescription = if ($Fullscreen720) { '720p fullscreen' } else { '1280 x 720 window' }
    Write-Host "Applied experimental $Renderer profile to $versionName. Target: 60 FPS, minimum graphics, $displayDescription."
    Write-Host 'This profile does not guarantee stable 60 FPS. Restore-Roblox-Graphics.ps1 restores the saved graphics settings.'
    if ($ApplyOnly) { exit 0 }

    if ($Fullscreen720) {
        $restoreDisplay = $true
        & (Join-Path $PSScriptRoot 'Set-Roblox-Display.ps1') -Mode 720p
        Write-Host 'Desktop is temporarily 1280 x 720. It will restore when Roblox closes. Press Alt+Enter in-game for exclusive fullscreen.'
    }

    if ($Game -eq 'Rivals') {
        Start-Process -FilePath $playerPath -ArgumentList 'roblox://placeId=17625359962'
    } elseif ($Game -eq 'Gakuran') {
        Start-Process -FilePath $playerPath -ArgumentList 'roblox://placeId=128736949265057'
    } else {
        Start-Process -FilePath $playerPath
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $players = @(Get-Process -Name 'RobloxPlayerBeta' -ErrorAction SilentlyContinue)
        foreach ($player in $players) {
            try {
                $matchesInstalledPlayer = [IO.Path]::GetFullPath($player.Path) -ieq $playerPath
            } catch {
                # A new player may not expose its executable path yet.
                continue
            }
            if ($matchesInstalledPlayer) {
                try {
                    $player.PriorityClass = [Diagnostics.ProcessPriorityClass]::AboveNormal
                    Write-Host 'Roblox priority set to AboveNormal for this session.'
                } catch {
                    Write-Warning "Roblox opened, but its priority could not be changed: $($_.Exception.Message)"
                }
                if ($Fullscreen720) {
                    Write-Host 'Keep this helper running while playing; it will restore the desktop on exit.'
                    while (-not $player.WaitForExit(5000)) {
                        # Roblox can reset its priority during startup.
                        try {
                            $player.Refresh()
                            if ($player.PriorityClass -ne [Diagnostics.ProcessPriorityClass]::AboveNormal) {
                                $player.PriorityClass = [Diagnostics.ProcessPriorityClass]::AboveNormal
                            }
                        } catch {
                            if (-not $player.HasExited) {
                                Write-Warning "Could not refresh Roblox priority: $($_.Exception.Message)"
                            }
                        }
                    }
                }
                exit 0
            }
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Roblox did not start within 30 seconds. Check the official Roblox player and try again.'
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    if ($restoreDisplay) { & (Join-Path $PSScriptRoot 'Set-Roblox-Display.ps1') -Mode Restore }
}
