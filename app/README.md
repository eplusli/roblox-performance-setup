# Roblox Performance Setup

Full documentation and measurement files: [GitHub project](https://github.com/eplusli/roblox-performance-setup). Relative source and documentation links below refer to the GitHub repository; those developer files are not installed on your computer.

A Windows setup that installs reversible low graphics Roblox launchers for **Rivals**, **Gakuran**, and Roblox home. It targets a 60 FPS cap with a 720p display profile. It uses the official Roblox player and currently allowed graphics flags.

**Measured best Rivals average: 58.81 FPS. Gakuran classroom average: 44.68 FPS. Stable 60 FPS was not achieved.** These are short captures on one PC, not a performance promise for every device or game.

## Install and play

1. Install the official desktop Roblox player from [roblox.com](https://www.roblox.com/download).
2. Download **RobloxPerformance-Setup.exe** from this repository's Releases and run it. It installs under `%LOCALAPPDATA%\RobloxPerformance` for your Windows account and creates desktop shortcuts. No administrator service is installed.
3. Close Roblox, then double-click **Rivals - Performance**, **Gakuran - Performance**, or **Roblox - Performance**.
4. In-game, press **Alt+Enter** to request exclusive fullscreen. Keep the launcher process running; it restores your previous display mode when Roblox exits.

Setup enables Windows Game Mode, disables historical background game recording, and selects an existing High Performance power plan where available. High Performance can increase power use. It backs up each affected registry value and the active power plan before changing them. It does not change the saved PowerShell execution policy; each helper uses process-only RemoteSigned and Windows PowerShell's built-in modules.

The game launcher verifies the Roblox Corporation digital signature, discovers either a user or machine-wide registration, and falls back to installed version folders. It passes game links directly to the verified player. It fetches Roblox's current flag allowlist before applying settings. An unavailable network or removed flag produces a visible error rather than silently applying an unverified profile.

Windows 10/11 desktop Roblox, Windows PowerShell 5.1, .NET Framework 4.5 or newer, and a primary display supporting **1280 × 720 at 60 Hz** are required. Only the primary display is changed. Setup can install while Roblox is running; graphics are then applied on the next launcher run after you close Roblox. This v1.0.0 release was tested on Windows 11; other hardware and multi-monitor configurations were not validated. The setup is unsigned; no certificate or trusted-publisher claim is supplied.

## What the profile does

| Change | Purpose |
|---|---|
| 1280 × 720 instead of 1920 × 1080 | Renders about 56% fewer pixels; reduces pixel-related GPU work. FPS does not increase in direct proportion. |
| Manual graphics level 1, texture override 0, rendering quality override 1 | Reduces visual detail and graphics workload. |
| One MSAA sample, grass distance 0, CSG detail switching distances 250 | Reduces anti-aliasing, grass and mesh detail. |
| Direct3D 11 | Retained after Vulkan showed worse frame-time spikes in the tested scenes. |
| Native 60 FPS cap | Sets the target; does not create missing performance. |
| Alt+Enter fullscreen request | Rivals was measured using Hardware Composed: Independent Flip rather than composed copy presentation. This path depends on Windows and the display configuration. |
| AboveNormal process priority | Gives Roblox more scheduling preference; reapplied if startup resets it. This is not an FPS guarantee. |
| Game Mode and historical recording setting | Enables the Windows game mode preference and disables historical game recording. The individual FPS effect was not isolated. |
| Existing High Performance power plan | Prefers performance over power saving. The individual FPS effect was not isolated. |

Graphics and display quality are reduced. The profile changes local flags and native saved settings, not Roblox binaries. It does not inject code, replace the Roblox client, bypass anti-cheat, overclock hardware, or pretend system RAM becomes a faster GPU.

In the original Rivals test, **optimized lighting, optimized textures and optimized wraps** were also enabled inside Rivals. Those game-owned preferences are not included in the installer; enable them in Rivals' own settings. The setup does not distribute Roblox, GPU drivers or Intel PresentMon. PresentMon was a measurement tool used during development.

## Measurements and limits

Test PC: Dell OptiPlex 3090 Micro, Intel Core i3-10105T, Intel UHD 630, one 8 GB DDR4 module at 2666 MT/s, Windows 11, Intel graphics driver 31.0.101.2145.

| Scene/configuration | Duration | Average rendered FPS | 1% low FPS | 95th percentile frame time |
|---|---:|---:|---:|---:|
| Rivals, low graphics, D3D11 window | 30 s | 43.11 | 14.15 | 31.82 ms |
| Rivals, low graphics, Vulkan window | 30 s | 40.07 | 9.59 | 42.58 ms |
| Rivals, D3D11, 720p fullscreen | 30 s | 58.58 | 19.66 | 21.21 ms |
| Rivals, D3D11, 720p, independent flip | 20 s | 58.81 | 21.77 | 21.52 ms |
| Gakuran, D3D11, 720p classroom | 30 s | 44.68 | 14.97 | 29.13 ms |

Intel PresentMon 2.6.0 recorded the foreground player. Average rendered FPS is 1000 divided by the mean frame interval. The 1% low is 1000 divided by the mean of the slowest 1% of intervals. Population, game activity and scenes changed between captures, so this is **not a controlled before/after experiment** and cannot attribute all improvement to a specific change. Gakuran had its stats/phone UI visible during capture. These are not full match benchmarks. The raw logs and personal settings backups are not published; summarized values are in [docs/measured-performance.json](docs/measured-performance.json).

The original computer had limited memory headroom and a single RAM module. Integrated graphics shares system memory, but allocating more reported VRAM does not add GPU compute power or memory bandwidth. The locked i3/Dell platform was not overclocked. CPU counters indicated turbo activity; a thermal throttling audit was not performed. A compatible second RAM module could help bandwidth and capacity, but this project does not claim that it guarantees 60 FPS.

## Restore settings

Close Roblox and use **Restore Roblox Performance Settings** on your desktop. It restores the backed-up graphics flags, Roblox settings XML, Windows values and power plan. A graphics XML restore also rolls back later sensitivity, volume and other preferences in that saved XML. Backups and launchers are retained. Reusing a performance launcher reapplies the graphics profile; reinstalling reapplies Windows settings.

If the helper was forcibly closed and your display remains at 720p, use **Restore Desktop Resolution**. A later launcher run also recovers an unfinished display change. If no display backup exists, restoration is a no-op. Avoid running multiple launchers at once. Installation updates replace application files and retain existing backups. Windows changes affect the current account's game settings and the system power plan; the display change is temporary.

To remove the application, restore first, then delete `%LOCALAPPDATA%\RobloxPerformance` and its five desktop shortcuts. The folder includes your local backups; keep a copy if you need them later.

## Build from source

On Windows, run `tools\Build.ps1` with Windows PowerShell 5.1. It uses the .NET Framework C# compiler already installed with Windows. No package manager, remote build script or external compiler download is needed. The compiler embeds an explicit list of application files in a ZIP resource inside the setup EXE.

Outputs: `dist\RobloxPerformance-Setup.exe`, `dist\SHA256SUMS.txt`, and the intermediate `dist\payload.zip`. The setup accepts `--quiet` for installation without dialogs and `--extract-only PATH` for inspecting its payload without applying settings or creating shortcuts. Rebuilding can produce a different EXE hash because compiler/ZIP timestamps vary; compare a downloaded release against that release's published SHA256SUMS instead.

See [docs/VALIDATION.md](docs/VALIDATION.md) for completed checks and [docs/SOURCES.md](docs/SOURCES.md) for the official documentation and preset references. This project is independent of Roblox and Intel. MIT license.
