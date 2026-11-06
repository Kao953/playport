# 0180: A game's folders open in the Files app

**Status:** accepted, 2026-11-06, by the person running this fork, after Bunny Garden's Steam
saves were in `Save/jk/…` (the PC's Windows user) while the phone's game read `Save/playport/…`,
and nothing on the phone could show it. Amends [0009](0009-dev-and-release-builds.md) ("Not
shown": the Files app did not show the container's Documents).

## Decision

- **Documents in the Files app.** `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`
  put the container's Documents under On My iPhone › Playport: the prefix, the games, Cloud
  Backups and the logs, in both builds.
- **Two rows on a game's page**, in the Game section above Check game files: *Game folder*
  (`C:\Games\<install>`) and *Windows user folder* (`C:\users\playport`: AppData, Documents,
  Saved Games). Each opens the folder in the Files app (`shareddocuments://`), where the player
  can look at, copy, rename or move files.
- Playport writes no file browser of its own: the Files app already copies, moves, renames,
  compresses and deletes.

## Why

A save one place and Steam Cloud's copy another (a folder named after a Windows user, a
different subfolder) is something a player can fix in a minute once they see it; without a way to
see the prefix it took a log, a report and a build. The Files app is the phone's own tool for it.

## Consequences

- A player can delete or break anything in the prefix or a game from the Files app; Check game
  files and Repair put a Steam game's own files back, a deleted save is gone.
- The logs (`playport.log`) are readable on the phone itself; Report a problem still zips them.
- Files hides names starting with a dot; the prefix's `dosdevices` links are shown as they are.
