# 0202: An Unreal bootstrap's fixed-base shipping executable keeps a 480 MiB window

**Status:** accepted, 2026-11-09, by the person running this fork. Amends 0191.

## Context

With decision 0201 in, FINAL FANTASY RESONANCE DEMO (4474710) got past its prerequisite check
and ended 0.4 s after Play with `0xC0000018`. Its `FFRS.exe` (an Unreal bootstrap, relocatable)
started `FFRS\Binaries\Win64\FFRS-Win64-Shipping.exe`, which has its relocations stripped
(characteristics `0x23`), ImageBase `0x140000000`, and an image of `0x1da1b000` bytes (474 MiB).
The log showed three things in the way:

- `executable window: not held`: decision 0191 caps the pool only when the executable Play
  starts is fixed-base, and Play starts the bootstrap, so the game's 896 MiB pool stayed;
- `[exe-base] 0x140000000+0x1da1b000 is held by a Wine view 0x1455c0000+0x113000`: with no window
  held, the scan had put the bootstrap itself there;
- the window, `[0x140000000, 0x15c000000)` (448 MiB), is smaller than the image anyway.

## Decision

- `FixedBaseExecutable.imageBase(launching:)` also reads an Unreal bootstrap's
  `<Project>\Binaries\Win64\<Project>-Win64-Shipping.exe`, so such a game's pool is capped at 768
  MiB as 0191 does for a fixed-base executable Play starts itself. The bootstrap still runs, and
  the scan places it outside the held window.
- The executable window grows to `[0x140000000, 0x15e000000)` (480 MiB) and the exec-time
  reservation to 1472 MiB, so the reservation still passes the window's top from the lowest
  executable end seen (`0x103ea8000` + 1472 MiB = `0x15fea8000`) and ends at `0x1663f8000` from the
  highest, under the lowest main-thread stack seen (`0x16d0c4000`).

## Consequences

- A fixed-base x86-64 executable of up to 480 MiB loads, also when an Unreal bootstrap starts it.
- The app's zero-fill reservation is 32 MiB larger in address space; untouched, it costs no
  memory.
- Not checked on the phone when written.
