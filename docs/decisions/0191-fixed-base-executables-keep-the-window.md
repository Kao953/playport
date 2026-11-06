# 0191: A game whose executable must load in the executable window gets no pool over 768 MiB

**Status:** accepted, 2026-11-06, by the person running this fork, after Shining Resonance Refrain
(809890) ended at once with `0xC0000018` in every launch.

## Context

Its `game.exe` is x86-64, 200 MiB, with its relocations stripped (characteristics `0x23`) and
ImageBase `0x140000000`: it loads there or nowhere. The runtime keeps the executable window
(`0x140000000`-`0x15c000000`, ARCHITECTURE.md) only above a JIT pool of up to 768 MiB; every game's
default pool is 896 MiB (decision 0153), and at the slides seen in these launches the pool reached
`0x141714000` and `0x143b70000` (`executable window: not held`), so `map_image_view` refused the
preferred base (`ml985 … REFUSED status=0xc0000018`).

## Decision

- `PlayportKit/FixedBaseExecutable` reads the executable's header: an x86-64 image with its
  relocations stripped or without DYNAMIC_BASE, whose ImageBase is in the window, needs the window.
- For such a game the Play's pool is capped at `JitPool.windowKeepingMB` (768 MiB), logged
  `play …: the game's 896 MiB capped at 768 MiB: its executable must load at 0x140000000, in the
  executable window`. Every other game keeps its pool.

## Consequences

- Fixed-base x86-64 executables start at every slide.
- Such a game has 128 MiB less JIT pool; one that needs more would run out of pool instead.
