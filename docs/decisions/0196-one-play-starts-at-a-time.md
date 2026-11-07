# 0196: One Play starts at a time

**Status:** accepted, 2026-11-07, by the person running this fork. Amends
[0193](0193-a-launch-logs-on-a-dropped-session.md) and [0062](0062-steam-live-session.md).

## Context

A second press of Play while the first was still preparing (the encrypted app ticket, the
ticket session) ran the whole Play again side by side. Its `prepareTicketSession` ended the
first Play's ticket broker (`play ended: 0 ticket(s) made`) to arm its own; the first Play then
started the game, and `suspendForLaunch`, finding no armed broker, closed the CM session
(`suspended for a title launch; CM session closed`). Mega Man Legacy Collection 2 (495050) got
`not logged on` from Playport's Steam client and exited after 0 s (report of 2026-11-07 20:47).
0193 coalesced only the logon two Plays share; the rest of the Play was not.

## Decision

`LibraryModel.play` refuses a Play while another is starting (`play <id>: refused, another Play
is still starting`), from its first check until it returns; after that `TitleLaunch.running`
refuses it as before.

## Consequences

A double tap starts the game once, with the first Play's tickets and a logged-on session.
