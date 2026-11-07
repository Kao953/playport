# 0195: Playport's Steam client logs each method's and export's first call

**Status:** accepted, 2026-11-07, by the person running this fork. Diagnostics.

## Context

The original Resident Evil (4249100) runs `japanese\Biohazard.exe`, an i386 executable packed
with Enigma Protector. In client mode it loaded Playport's `steamclient.dll`, asked for
`SteamClient017` and `SteamClient014` through `CreateInterface`, and then showed "Steam Error:
Application load error 3:0000065432" and exited with code 51. The release log had nothing in
between: only unserved slots logged their first call, and no export logged at all. The packer
hides the check, so the executable cannot be read for it.

## Decision

- Every i386 interface slot logs its first call, served or not, with what it answered
  (`steamclient: <version> slot <n> <method>` and `first call served|not served, answered <v>`).
- Every export logs its first call (`steamclient: export <name>: first call`).
- Each logs once per process, so a game's steady calls add nothing.

## Consequences

A client-mode game's log gains a line or two per method and export it uses. The x86-64 slots
log as before (unserved only): no x86-64 case needs it yet.
