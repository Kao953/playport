# 0182: A game's exit code, in words, in both builds

**Status:** accepted, 2026-11-06, by the person running this fork, so that a game that does not
run says what kind of failure it was. Amends [0009](0009-dev-and-release-builds.md) (the release
app's failure screen said only "The game ended with an error").

## Decision

- **The failure screen** of a game that ended with a code shows the code and what it means in both
  builds: `It exited with code 0xC0000135 (DLL not found: …)` (PlayportKit `ExitCodeNote`). A code
  not listed is named as an NTSTATUS, an HRESULT or the game's own.
- **The log**, after a launch that failed or ended with a code, gets `title: exit: <code (meaning)>`
  and `title: files the game could not open:` with up to twelve paths from the runtime's
  `[file-fail]` lines since the game started, last first, with their status (`FileFailNote`); the
  runtime's own lookups (FEX configuration, the session folder, the unix side) are left out.
- `0x0000042B` after Quit game is named as expected: Playport ends a game that did not close
  itself within 10 s.

## Why

Most incompatible games fail inside the game, where Playport cannot know why; the exit code and
the files the game looked for are the first two things to read, and a code alone needs looking up.
