# 0179: The Steam API choice is in the release app too

**Status:** accepted, 2026-11-05, by the owner ("can I switch it myself before I play?"), after Mega
Man 11 looped on its save at start and Bunny Garden did not load its Steam save in the release app.
Amends [0034](0034-a-gamepad-first-ui.md) (the Steam API choice was dev-only) and
[0153](0153-rdr2s-settings-are-every-games-defaults.md) (release launched every game's or the
compatibility default's mode, never a person's).

## Decision

- **A row on the game's page in both builds.** Steam API sits in the Game section under Cloud saves,
  with the dev build's choices: Default, Playport's emulator, Playport's Steam client, the game's
  own. Its note says to try the emulator when a game cannot save or load.
- **Release launches the player's choice**, else the game's compatibility default, else every
  game's (Playport's Steam client). The other dev-only settings (memory ordering, block size, x87
  precision, disk cache, runtime keys) stay out of release.
- The default is unchanged: Playport's Steam client for every Steam game (0153).

## Why

Playport's Steam client serves ISteamClient, ISteamUser, ISteamUtils, ISteamApps and the app ticket;
every other interface answers 0 (`app/SteamClientShim/steamclient.c`). A game that saves through
ISteamRemoteStorage then finds no save and cannot write one, and Steam Cloud's downloads of such
files go to the emulator's remote folder, which only the emulator reads. The emulator serves
remote storage. Until the client does, a player needs a way to put such a game on the emulator
without waiting for a compatibility entry and a release.

## Consequences

- A player can pick a mode that breaks a game (the game's own, with no Steam); Default undoes it.
- A compatibility entry is still the fix for every player; this row is the way to find it.
