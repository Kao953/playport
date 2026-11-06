# 0186: A game's Steam language is the player's choice on its page

**Status:** accepted, 2026-11-06, by the person running this fork, after CHRONO TRIGGER (613830)
ran in English for a player who plays it in Chinese on a PC.

## Context

Playport's Steam client and the emulator both told every game `english`
(`ISteamApps::GetCurrentGameLanguage`, `ISteamUtils::GetSteamUILanguage`, gbe's `language=`).
A game that follows Steam's language, as CHRONO TRIGGER does, could not be played in another one.
On a PC Steam answers with the language picked for the game in its properties, else Steam's own.

## Decision

- A game's page has a **Game language** row in the Game section, under Steam API, in both builds:
  Default (English) or one of the Steam API languages (`PlayportKit/SteamLanguage.swift`). It is
  saved per game (`LaunchSettings.gameLanguage`).
- A launch tells the game that language in client and emulator mode alike.
- The depots installed are unchanged: English and language-neutral ones
  ([DepotSelection](../../app/SteamClient/Sources/SteamClientKit/Install/DepotSelection.swift)). A game
  whose language lives in a language depot does not get it from this setting.

## Consequences

- Games that read Steam's language show the chosen one if they have it.
- A game that keeps its own language setting ignores this row.
