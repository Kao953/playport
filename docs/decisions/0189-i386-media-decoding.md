# 0189: i386 games get Media Foundation and DirectShow decoding

**Status:** accepted, 2026-11-06, by the person running this fork, after Resident Evil HD
REMASTER (304240) showed its Capcom logo and then a black screen.

## Context

An i386 game's winegstreamer unix calls went to the stub table
(`[unixlib] module … (winegstreamer.dll) WoW64 -> … (stub table)`): the WoW64 dispatch in
`virtual_ios.c` routes only the libraries it lists, and winegstreamer was not among them, so no
32-bit game could decode a movie or compressed audio. Wine's WoW64 thunks for it (`wg_parser.c`)
read guest pointers with `ULongToPtr`, which in Playport's WoW64 window are offsets, not host
addresses.

## Decision

- `patches/wine-unix/0208`: on iOS the thunks' `ULongToPtr` goes through `ios_wow64_to_host` for
  the calling process's window, and a `wg_sample`'s `data` (a guest buffer the PE side never reads
  back) becomes its host address when the sample is handed to a transform or muxer, as GStreamer's
  streaming threads read it later and own no window.
- `patches/madeira-unix/0289`: an i386 caller of winegstreamer gets
  `winegstreamer_unix_call_wow64_funcs`.
- `build/stages/gstreamer.sh` exports that table from the prelinked object and fails without it.
- The game's movies are WMV in ASF, which the plugin set could not open: `gstreamer.sh` registers
  gst-plugins-ugly's `asf` (libav already decodes WMV, VC-1 and WMA), and
  `build/gstreamer-notices.sources.json` adds gst-plugins-ugly 1.28.7 (LGPL-2.1, `COPYING`).

## Consequences

- 32-bit games' movies and Media Foundation audio decode as 64-bit games' do.
- A pointer inside a `wg_format` or another structure the thunks do not list would still be a guest
  offset; none is known.
