# 0207: A Play waits for a Steam logon under way, and a title can turn on audio diagnostics

**Status:** accepted, 2026-11-26, by the person running this fork.

## Context

Yu-Gi-Oh! EARLY DAYS COLLECTION (3013550) crashed at start (0xC0000005, in its steam_api64.dll) in
one play. iOS had dropped the CM connection one second before Play, and the automatic restore had
started. The launch found the account `restoring`, not `signedIn`. Its tickets went off, the
launch-time reconnect (decision 0193) did nothing, and the game's Steam client reported "not
logged on". The restore finished 1.5 s later. Every play of the game that started signed in ran.

The same game's sound wavers in pitch, like a worn tape. Its stream delivers 100 % of real time
and its ring stays about 80 % full. But the release runtime's `MADEIRA_NO_DIAGNOSTICS` hides the
fields that would show short callbacks and underruns. The guest is told the panel's 120 Hz while
its frames are limited to 60 FPS. An emulator that paces its sound by frames would then waver.

## Decision

- **Wait for a logon under way.** Before the encrypted app ticket, a launch whose session is
  `restoring` waits up to 5 s for it (`SteamService.settleRestore`). In any other state it does
  not wait. A logon that is not done by then leaves the launch as before.
- **Audio diagnostics for one title.** `PLAYPORT_AUDIO_DIAGNOSTICS` turns the audio driver's
  stream diagnostics on in a quiet runtime (`patches/madeira-unix/0297`). A title gets it from an
  `env.` runtime key.
- **3013550's compat default:** `env.MADEIRA_SCREEN_HZ=60 env.PLAYPORT_AUDIO_DIAGNOSTICS=1`. This
  is an experiment for its pitch.

## Consequences

A Play pressed just after the app returns to the front can take up to 5 s longer to start. That
is the price of keeping its tickets. 3013550's compat default is to be revised once its report
shows whether 60 Hz helped. Not yet measured on the phone.
