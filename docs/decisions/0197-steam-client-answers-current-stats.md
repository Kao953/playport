# 0197: Playport's Steam client answers RequestCurrentStats

**Status:** accepted, 2026-11-08, by the person running this fork. Amends
[0115](0115-a-steam-client-for-the-launched-app.md) (what Playport's Steam client serves).

## Context

DRAGON QUEST VII Reimagined Demo (2499870, Unreal Engine) stayed on a black loading screen in the
Default mode (Playport's Steam client) and loaded in the Emulator mode. The client logged
`ISteamUserStats012 slot 0 RequestCurrentStats: not served, answers 0`: the game never got
`UserStatsReceived_t`, which the emulator posts.

## Decision

`RequestCurrentStats` answers true on a logged-on session and posts `UserStatsReceived_t`
(callback 1101, `k_EResultOK`, the app and the account) on the next `Steam_BGetCallback`. No stat
or achievement is served: their reads still answer false, as an account with none set.

## Consequences

A game that waits for its stats before going on gets them. Achievements earned in the Default mode
are still not sent to Steam.
