# 0209: The audio session asks for 48 kHz

**Status:** accepted, 2026-11-26, by the person running this fork.

## Context

Yu-Gi-Oh! EARLY DAYS COLLECTION (3013550) sounded clean on the phone's speaker and stuttered on
headphones. Decision 0208's diagnostics showed the same play on three routes:

| Route | Hardware rate | Frames per callback |
| --- | --- | --- |
| Wired headphones | 44.1 kHz | 1114–1115 |
| Speaker | 48 kHz | 1024 |
| Bluetooth A2DP | 44.1 kHz | 1114–1115 |

On every route the driver delivered 100 % with no short callbacks. The audio driver gives every
game a 48 kHz mix format and opens its RemoteIO unit at the stream's rate. On headphones iOS
converted 48 → 44.1 kHz, and only the converted routes stuttered.

## Decision

Before the session is activated, it asks for a preferred sample rate of 48 kHz
(`setPreferredSampleRate(48000)`), so a route that can run at 48 kHz plays the mix without a
conversion. A refusal is logged and the session goes on.

## Consequences

A route that cannot do 48 kHz, likely Bluetooth A2DP (AAC at 44.1 kHz), still converts. If such a
route still stutters, the next step is the driver's own conversion to the hardware rate. Not yet
measured on the phone.
