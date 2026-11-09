# 0205: IAudioClient3 reports a shared-mode engine period of at least 40 ms

**Status:** accepted, 2026-11-09, by the person running this fork.

## Context

アライさんマンション探索ゲーム～Incarnation～ (4293310) is a Godot 4 game, and its music played
wrong. Its render stream is a polling one (no event callback), created through IAudioClient3 with a
10 ms period. Each ~10 s window the driver received about 79,000 frames, roughly 16 % of real time
at 48 kHz. Every GetBuffer was 480 frames, and the padding read 480 each time.

Godot's WASAPI driver (`drivers/wasapi/audio_driver_wasapi.cpp`, IAudioClient3 path) picks a
period from `GetSharedModeEnginePeriod`, as near its output latency (15 ms) as the reported range
allows, and sets its buffer to that period. It then writes only what the padding leaves of that
buffer. Wine reports default, minimum and maximum all as the driver's 10 ms, so Godot never queued
more than 480 frames. The iOS output unit takes about 21 ms of frames in each callback (decision
0172's evidence), so every callback found less than half of what it needed. The underrun refill
(0172) then held playback and the clock until 20 ms were queued, which this client never queues.
The padding stayed at 480, and Godot kept polling without writing.

## Decision

`GetSharedModeEnginePeriod` reports a default and minimum period of at least 40 ms
(`patches/wine-pe/0072`). Godot then sets a 1,920-frame buffer, which covers a whole callback
with time left to top up. `Initialize`, `GetDevicePeriod` and adjust_timing keep the driver's
own periods, so clients that do not use IAudioClient3 are unchanged.

## Consequences

An IAudioClient3 client gets at least 40 ms of latency where Windows might give it 10 ms. That
is inaudible for a game and is the price of the iOS callback size. Not yet measured on the phone.
