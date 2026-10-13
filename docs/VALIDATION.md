# Release validation

Version 1.0.0, validated October 14, 2026 on the Windows 11 Dell/Intel system described in the README.

Completed checks:

- All application PowerShell files parsed with Windows PowerShell 5.1; setup compiled with the installed .NET Framework compiler.
- The EXE's `--extract-only` payload matched each source application file by SHA256. The payload is built from an explicit list, excluding personal XML, runtime backups, game logs and credentials.
- The Windows helper was run against isolated test registry keys. It changed the three intended values, preserved an unrelated sentinel value, preserved its initial backup on repeat application, restored an existing value's original contents, and removed a value that was originally absent. The original power scheme was restored after the test.
- Display restoration without any backup was verified to be a no-op.
- Quiet installation on the actual computer created five functional desktop shortcuts and applied the graphics and Windows profile.
- Repeat installation preserved the existing local Windows and Roblox XML backups.
- The installed all-settings restore returned graphics flags, saved XML, Windows registry values and the previous power plan; the performance settings were then reapplied successfully.
- Missing per-user URI registration was reproduced and fixed. Rivals was joined by passing its URI directly to the verified player. The executable resolver was also tested with all registry lookups unavailable and found the signed installed player.
- Rivals and Gakuran launches were checked during development. The final installed Rivals desktop shortcut reached its lobby with AboveNormal priority; closing the foreground game changed the installed display backup to inactive and restored 1920 × 1080 at 60 Hz.
- Source was reviewed for personal absolute paths, authentication tokens, Roblox account identifiers and game/server logs before publication. Only summarized performance data is included.

Run `tools\Build.ps1`, then `tools\Test-Package.ps1` on Windows to reproduce package, registry round-trip and empty-display-backup checks. The latter briefly selects an existing High Performance power plan and restores the initial scheme in its finally block. Other tests require the official player and interactive game access.

Limitations: one tested computer; short, changing game scenes; no full-match stability guarantee; no separate causal measurement for Game Mode, power plan or process priority; no broad GPU/monitor compatibility testing. Neither script parsing nor a successful launcher demonstrates stable 60 FPS.
