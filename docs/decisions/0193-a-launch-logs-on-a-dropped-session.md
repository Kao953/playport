# 0193: A launch logs on again a CM session iOS dropped

**Status:** accepted, 2026-11-07, by the person running this fork. Amends
[0017](0017-encrypted-app-ticket.md) and [0062](0062-steam-live-session.md) (no restore at Play).

## Context

iOS closes the app's CM socket while Playport sits in the background (exporting a report,
switching apps). The session learns of it only when a request fails, and the first request after
Play is the encrypted app ticket. Every launch on 2026-11-07 logged `[cm] connection closed:
transport: websocket receive: 57` just after Play, then `tickets off (the session is not
connected)`, and Playport's Steam client told the game it was not logged on. Mega Man Legacy
Collection 2 (495050) checks `SteamUser()->BLoggedOn()` and exits at once ("Steam user must be
logged in to play this game").

## Decision

- After Play, when no encrypted app ticket came back and the session is no longer connected,
  `SteamService.reconnectForLaunch` closes it and logs on again from the stored session, within
  5 s, once. The ticket is then asked for again, and the play's tickets are armed on the new
  session.
- A logon that fails or runs out of time closes the session, so nothing outlives the limit into
  the launch; the game starts as before, not logged on.
- A refusal from Steam on a live session (EResult Fail) logs on nothing.
- Logged as `[ticket] CM logged on again before the launch in N s`, or `... failed: <error>`.

## Consequences

A launch after the app was in the background can take up to 5 s longer. Signed-out, suspended
and live sessions behave as before.
