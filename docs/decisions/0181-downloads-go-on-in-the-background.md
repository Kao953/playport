# 0181: Downloads go on in the background

**Status:** accepted, 2026-11-06, by the person running this fork ("can downloads run in the
background while Steam downloads a game?"). Amends the foreground-only downloads that
`UI/Downloads.swift` described (the screen stayed on, and iOS suspending the app paused a job).

## Decision

- While a download job runs and Playport is in the background, a silent sound plays on a loop
  (`UI/DownloadKeepAlive.swift`): an `AVAudioPlayer` with volume 0 in the `.playback` category,
  mixed with other apps' audio. iOS keeps an app that plays audio running, so the job goes on.
- It uses the `audio` background mode Info.plist already declares for the pairing code's
  picture-in-picture window; nothing new is declared or entitled.
- It stops when Playport is in front again, when no job runs, or when iOS interrupts the audio
  (a call, another app taking the audio session without mixing). An interrupted job pauses as
  before and goes on once Playport is in front.
- Download mode (the dimmed screen in front) stays as it was.

## Why

A Steam install is many gigabytes; holding the phone on Playport's screen for it is the one
thing a player cannot do while using the phone for anything else. Background URL sessions do not
fit Steam's depot downloads (thousands of chunks, each decrypted, decompressed and written as it
arrives), and a background task gives about thirty seconds.

## Consequences

- More battery than a suspended app: the network, the CPU for decompression and the audio
  session stay on while a download runs. Nothing plays once the queue is empty.
- iOS may still end the app (memory pressure, an audio interruption); the queue is saved after
  every change, so the job resumes from its stage at the next start.
- An App Store app would be refused for this use of the audio mode; Playport is sideloaded.
