# 0211: The audio position moves with time between render passes

**Status:** accepted, 2026-11-26, by the person running this fork.

## Context

After decision 0210, Yu-Gi-Oh! EARLY DAYS COLLECTION (3013550) on Bluetooth A2DP (44.1 kHz) got
everything the driver could give it. The endpoint ran at the hardware rate, the mixer converted,
delivery was 100 % and no callback came up short (report 20261126-123309). It still trembled
slightly. アライさんマンション探索ゲーム played clean on the same headphones, so the route was
not the cause. The game's emulator steers its speed by the stream's padding. The padding moved
in steps of one render pass: 1114.6 stream frames every 23.2 ms at 44.1 kHz. Wired headphones at
44.1 kHz had stuttered the same way before 0209.

## Decision

- **GetPosition and GetCurrentPadding read a position that moves with time**
  (`patches/madeira-unix/0300`). The render callback records each pass under a seqlock: the
  position before it, the frames it took, when it ran, and the output time it covers. The
  position read is the position before the pass plus the share of its frames that time has
  covered.
- **The position never passes `play_pos`.** It equals `play_pos` once the pass's time is over,
  during a refill hold (0172), and whenever the record is not the latest pass. So the padding a
  game reads is never smaller than what the ring holds.
- **GetBuffer's room check keeps the real `play_pos`**, so a request sized from the padding is
  never refused.
- **`MADEIRA_AUDIO_SMOOTH=0` turns it off.**

## Consequences

Every game sees the position move evenly instead of jumping once per hardware buffer, as on
Windows. Right after a pass, the padding reads up to one pass larger than the ring holds. By the
next pass the two agree again, so a game that refills before each pass sees the true amount.
Whether it removes the tremble is up to a play on the phone.
