# 0192: Playport's Steam client serves ISteamRemoteStorage

**Status:** accepted, 2026-11-06, by the person running this fork. Amends
[0115](0115-a-steam-client-for-the-launched-app.md) and
[0161](0161-steam-client-for-i386-and-every-interface.md) (their served-method list).

## Context

In client mode, every game's default since decision 0153, `ISteamRemoteStorage` answered 0:
`FileExists` false, `FileWrite` false. A game that saves through the API (Mega Man 11, Guilty Gear
XX Accent Core Plus R's data files) could neither load nor create a save, and the player had to
switch it to Playport's emulator by hand.

## Decision

- The client serves every `ISteamRemoteStorage` version's file methods: `FileWrite`, `FileRead`,
  `FileWriteAsync`, `FileReadAsync` with `FileReadAsyncComplete`, the write streams, `FileExists`,
  `FilePersisted`, `GetFileSize`, `GetFileTimestamp`, `FileDelete`, `FileForget`, the sync
  platforms, `GetFileCount`, `GetFileNameAndSize`, `GetQuota` (two `int32` up to 013, two `uint64`
  from 014), the cloud-enabled checks (true) and the write batch. UGC and Workshop methods still
  answer 0.
- The files are `%APPDATA%\GSE Saves\<appid>\remote\<name>`, the emulator's folder, which the
  cloud sync already uploads and downloads as Steam's root-less files. A game keeps its saves when
  its Steam API mode changes.
- A write goes through a temporary file beside the target and replaces it, so a failed write keeps
  the old save. A name that is absolute, empty or has a `..` part is refused.
- Async calls complete at once, as call results (`RemoteStorageFileWriteAsyncComplete_t` 1331,
  `RemoteStorageFileReadAsyncComplete_t` 1332, 24 bytes): the call-result store now carries up to
  32 bytes.
- Each write logs `steamclient: remote storage: write <name>`.

## Consequences

- Games that save through Steam's API save in client mode.
- `tools/tests/test_steamclient_abi.py` (desktop Wine) was not run for this change.
