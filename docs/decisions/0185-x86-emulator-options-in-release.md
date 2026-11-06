# 0185: A game's x86 emulator options are on its page in the release app too

**Status:** accepted, 2026-11-06, by the person running this fork, after GUILTY GEAR Xrd REV 2
(520440) crashed the same way under every graphics backend and Steam API mode. Amends
[0034](0034-a-gamepad-first-ui.md) (these rows were a dev build's).

## Context

GUILTY GEAR Xrd REV 2 ends about a second after its window with `0xC00000BB`, with DX9 or DX11,
Vulkan or DXMT, Playport's Steam client or the emulator. Each run logs a FEX call-return stack
underflow at the same guest address (0xd3c7e0) just before several threads raise and UE3's crash
handler runs: the emulator is the one part these runs share. The FEX switches that change how
x86 code runs (memory ordering, block size, x87 precision, the disk cache) were dev-only, and the
release launch cleared any stored choice.

## Decision

- A game's page shows an **x86 emulator** section in both builds, after Game: the four memory
  ordering switches, block size, x87 precision and disk cache, each over the game's profile, as the
  dev build's Developer section showed them (same row ids).
- The release launch takes the player's choices for them. Runtime keys, the Vulkan loader, Windows
  services and graphics options stay a dev build's.

## Consequences

- A player can try a crashing game with 80-bit x87, full ordering or a smaller block size, and
  report which one runs it.
- A wrong choice can make a game slower or crash it; each row resets to Default.
