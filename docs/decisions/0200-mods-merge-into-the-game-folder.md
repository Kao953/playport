# 0200: Mods merge into the game's folder and can be taken out

**Status:** accepted, 2026-11-08, by the person running this fork.

## Context

A player put mods into Resident Evil HD REMASTER (304240) by copying their folders in from a
Mac. Finder and the Files app replace a folder of the same name rather than merge into it, so
the game's own `nativePC/arcPC/id/` went missing, and the game stopped at start with
`Failed open file. …\nativePC\arcPC\id\e_rom\common.arc 3`. A copy that stopped half way also
left a 0-byte `.sngw`. On the phone, merging many mod folders file by file is not practical.

## Decision

The game page has **Install a mod** (Files picker: folders or .zips, several at once, merged in
the order picked) and, once a mod is in, **Remove mods** (`PlayportKit/ModInstall.swift`,
`UI/ModInstalls.swift`).

- The mod's tree is read as an import reads a game (`.DS_Store` and `__MACOSX` left out, a
  zip's single top folder taken off). Where it goes in the game is found, not asked: the tree as
  it is, with each leading folder all its files share taken off, or under the picked folder's
  name, whichever matches more of the game's existing folders and files. A mod none of whose
  folders the game has is refused, except one that is only top-level files (a loader DLL).
- The merge never deletes. A mod file replaces the game file of the same path, matched without
  regard to case under the game's spelling. An empty mod file does not replace a non-empty one.
- A game file is moved (not copied: no space) to `Games/.playport-mods/<folder>/backup/` the
  first time a mod replaces it; `manifest.json` there lists the mods, the replaced files, and the
  files and folders the mods added. Remove mods puts the backups back and deletes the added
  files and empty added folders.
- Play is not offered while mods are being changed; the mod rows do nothing while the game runs
  or a download job holds it.

## Consequences

Check game files reports modded files as damaged, and Repair from Steam puts the originals back
over them; the backups then match what Steam has, so Remove mods afterwards is harmless.
