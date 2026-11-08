# 0198: The audio driver mixes a multichannel stream down to stereo

**Status:** accepted, 2026-11-08, by the person running this fork.

## Context

The iOS audio driver's endpoint is stereo and its mix format says so, but it accepts any format,
and a client that asks AUTOCONVERTPCM expects the engine to convert. The mixer played only the
first two channels of a wider stream. DRAGON QUEST VII Reimagined Demo (2499870) renders 12
channels (7.1.4); its stream carried audio (`peak=2.266`), and the phone stayed silent.

## Decision

`patches/madeira-unix/0290`: a stream of more than two channels gets per-channel stereo gains at
attach, from its WAVEFORMATEXTENSIBLE channel mask or the usual layout for its channel count
(5.1, 7.1, 7.1.4): a front, side or back speaker to its side (0.707 off the front), a centre one
to both at 0.707, LFE left out. The log says `N-channel stream (mask …) mixed down to stereo`.
Mono and stereo streams mix as before.

- With those gains the game played loud constant noise in both Steam modes: its samples already
  reach past full scale (`peak=2.266`), and a side summing six speakers clipped. `0291` scales the
  gains so uncorrelated channels keep one full-scale channel's level (1/√ of the summed squared
  gains, 0.55 for 7.1.4), clamps each input sample to full scale, and turns a NaN or infinity, in
  a mixed-down sample or in the final mix, into silence. Each wider stream logs
  `slot=N channel peaks: …` with its level line.

## Consequences

A game rendering surround on the phone is heard; its LFE channel is not.
