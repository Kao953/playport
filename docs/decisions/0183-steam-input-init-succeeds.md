# 0183: Playport's Steam client answers Steam Input's Init with success

**Status:** accepted, 2026-11-06, by the person running this fork, after CHRONO TRIGGER (613830)
quit at start. Amends [0115](0115-a-steam-client-for-the-launched-app.md) and
[0161](0161-steam-client-for-i386-and-every-interface.md) (their served-method list).

## Context

In client mode every unserved slot answers 0. CHRONO TRIGGER (i386) asks `SteamController008`
right after `SteamAPI_Init`, gets `false` from `Init`, shows a message box
"SteamController()->Init failed" and exits with code 1 about two seconds after its first frame.
Steam's own client answers `Init` with true whether or not a Steam controller is connected.

## Decision

- Every version of `ISteamController` and `ISteamInput` serves `Init` and `Shutdown` (true) and
  `RunFrame` (nothing). Every other method still answers 0: no controller connected, no action
  sets, no handles, so a game falls back to its own pad input (XInput, which Playport feeds).
- Steam Input itself (action sets, glyphs, a Steam controller) is not provided.

## Consequences

- A game that refuses to start without a working Steam Input `Init` starts in client mode; one
  that needs Steam Input to read a pad has no pad input through it.
