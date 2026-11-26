# 0210: The audio endpoint runs at the hardware's rate, and the mixer converts

**Status:** accepted, 2026-11-26, by the person running this fork.

## Context

After decision 0209, wired headphones run at 48 kHz and Yu-Gi-Oh! EARLY DAYS COLLECTION (3013550)
plays clean on them. Bluetooth A2DP stays at 44.1 kHz and still stuttered slightly. The RemoteIO
unit was opened at the first client's rate (48 kHz), so on such a route iOS's unit converted. The
driver's own conversion, used only when a stream's rate differed from the endpoint's, took the
nearest frame and always used up the rounded-up count.

## Decision

- **The endpoint takes the unit's output (hardware) rate** (`patches/madeira-unix/0299`).
- **The mixer converts a stream at another rate.** Each stream keeps a 32.32 position past its
  play position across passes, which Reset clears. Each output frame is interpolated linearly
  between two input frames. Over time it uses up exactly the ratio of the two rates.
- **A route change moves the endpoint.** The app calls `ios_audio_route_changed()` on every route
  change, and a running endpoint moves to the new hardware rate (stop, new input format, start).
- The session still asks for 48 kHz (0209), so a route that can do it converts nothing at all.

## Consequences

Every game on a 44.1 kHz route now plays through the driver's linear interpolation instead of
iOS's converter. A host simulation of 48 → 44.1 kHz over about 1,000 s of callbacks used up the
expected frame count to within one frame. A 1 kHz tone came within 0.24 % of the ideal. Linear
interpolation slightly softens the highest frequencies. Not yet measured on the phone.
