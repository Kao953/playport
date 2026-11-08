# 0199: Spatial audio starts each update from a silent buffer

**Status:** accepted, 2026-11-08, by the person running this fork.

## Context

DRAGON QUEST VII Reimagined Demo (2499870) renders through `ISpatialAudioClient` with a 7.1.4
static bed: Wine's spatial audio stream opens a 12-channel float stream (mask `0x2d63f`) and adds
each static object's samples into the render buffer that `GetBuffer` returns. Windows leaves that
buffer's contents undefined, and the iOS driver hands back the same area each period with the
previous period still in it. Each period was added onto the last: the phone played loud noise in
both Steam modes, the front pair rising from silence to a mean of 1.86 and peaks of 5.4 within
twenty seconds (`slot=0 channel peaks: 5.402 4.787 0.000 …`), the other ten channels silent.
Turning AVX off for the title changed nothing.

## Decision

`patches/wine-pe/0071`: `BeginUpdatingAudioObjects` clears the render buffer after `GetBuffer`,
before the objects are mixed into it.

`patches/madeira-unix/0292` takes back the gain scaling 0291 added on the summing guess (decision
0198); the clamp, NaN guard and channel peaks stay.

## Consequences

A game rendering through spatial audio static objects is heard as it renders, whatever its driver
leaves in the buffer. Dynamic objects are still not mixed (Wine's own limit).
