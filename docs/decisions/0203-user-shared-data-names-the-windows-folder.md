# 0203: The user shared data names the Windows folder

**Status:** accepted, 2026-11-09, by the person running this fork.

## Context

With its executable window fixed (decision 0202), FINAL FANTASY RESONANCE DEMO (4474710) started
`FFRS-Win64-Shipping.exe`, which showed its own "加載 SteamAPI 失敗" (failed to load SteamAPI)
dialog about 3 s later and exited with -1. It did this in every Steam API mode, before Unreal had
created any Saved folder, and it never opened the engine's `steam_api64.dll`. A run that traced
Wine's module loader (`WINEDEBUG=err+all,warn+module,+loaddll`, a diagnostic compatibility entry)
showed one failed load just before the dialog: `\System32\wintrust.dll`, status c0000135, which
has no drive or Windows folder.

The path is built from `KUSER_SHARED_DATA.NtSystemRoot`. Desktop Wine's wineboot writes
`C:\windows` there at every start (programs/wineboot `update_user_shared_data`). The app never
runs wineboot, and nothing else wrote the field, so it was empty.

## Decision

On iOS the wineserver writes `C:\windows` into NtSystemRoot when it creates the user shared data
mapping (`patches/madeira-unix/0296`, in the iOS wineserver's `mapping_ios.c`). Every process maps that page.

## Consequences

Code that reads the Windows folder from the shared page, such as a game's signature check,
gets the same answer that `%SystemRoot%` and GetWindowsDirectory give. Wineboot's other fields
(NtBuildNumber, NtMajorVersion, NtMinorVersion, NtProductType, SuiteMask) are still zero. If a
title is found reading those, they go in the same place.
