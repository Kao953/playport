# 0208: Audio diagnostics show the output route and the render callbacks' shape

**Status:** accepted, 2026-11-26, by the person running this fork.

## Context

Yu-Gi-Oh! EARLY DAYS COLLECTION (3013550) sounds clean on the phone's speaker and stutters on
headphones, both wired and Bluetooth. With decision 0207's diagnostics, every stream window shows
100 % delivery, no short callbacks and no underrun frames. The driver hands iOS every frame, so
the difference lies in how the route's callbacks take them, or in how the game reacts. The logs
named neither the route nor the callbacks' sizes and timing.

## Decision

- The app logs the audio session's route at activation and at every route change. That covers
  each output port's type and name, the hardware rate, the I/O buffer duration and the output
  latency.
- With audio diagnostics on, each ten-second window adds a device line
  (`patches/madeira-unix/0298`). It gives the fewest and most frames a render callback asked for,
  the longest gap between two callbacks, the passes whose sample time did not follow on, and the
  unit's output rate.

## Consequences

Diagnostics only: no change to what is played. The port name can be a device's name, such as a
headset's. It stays in the player's own log.
