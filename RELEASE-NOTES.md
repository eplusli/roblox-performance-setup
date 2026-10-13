# Roblox Performance Setup v1.0.0

One Windows setup EXE installs reversible minimum graphics launchers and five desktop shortcuts. The official Roblox player must already be installed.

- Low graphics Direct3D 11 profile using Roblox's live allowed flags, native 60 FPS cap and 720p fullscreen.
- Session AboveNormal priority and automatic desktop resolution restoration after the player exits.
- Windows Game Mode enabled, historical game recording disabled, existing High Performance power selected where available.
- Robust signed-player discovery with user/system registration and installed-version fallback; direct game launching does not depend on a working Windows URI association.
- Initial settings backups retained across updates, plus graphics/Windows restoration tools.
- Source and build script included; SHA256SUMS accompanies the setup.

Best measured short Rivals capture: **58.81 average FPS**, with dips. Gakuran classroom: **44.68 average FPS**. Stable 60 FPS was not achieved. Results are from one Intel UHD 630 PC with changing scenes and should not be treated as a guarantee.

Requires Windows desktop Roblox, Windows PowerShell 5.1, .NET Framework 4.5 or newer, and primary-display 1280 × 720 at 60 Hz support. Tested on Windows 11. Installer is unsigned. No Roblox client, driver, overclocking tool or anti-cheat bypass is included.

Download RobloxPerformance-Setup.exe, run it, close Roblox, and use a Performance desktop shortcut. Press Alt+Enter in-game for exclusive fullscreen. Use Restore Desktop Resolution if the helper was forcibly stopped, or Restore Roblox Performance Settings to roll back the saved profile.
