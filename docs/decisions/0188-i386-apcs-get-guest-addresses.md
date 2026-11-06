# 0188: An i386 APC gets guest addresses

**Status:** accepted, 2026-11-06, by the person running this fork, after Resident Evil HD
REMASTER (304240) crashed a second after its first frame in every Steam API mode.

## Context

The crash was in kernelbase's `read_write_apc`, the completion routine of `ReadFileEx`: it read
`[esi+4]` with `esi = 0xf4e8ff34`, no guest memory. In Playport's WoW64 window a guest address is
not its host address. `iosb_32to64` gives the native `NtReadFile` the guest's `IO_STATUS_BLOCK` as
its host address in the window (`0x72f4e8ff34`), the completion APC receives that pointer, and
`Wow64ApcRoutine` wrote it into the 32-bit `KiUserApcDispatcher` frame cut to 32 bits
(`0xf4e8ff34`) instead of the guest's `0x34e9ff34`. Stock Wine maps the guest's 4 GiB at the same
host addresses, so the cut there is harmless.

## Decision

`patches/wine-pe/0065`: `Wow64ApcRoutine` turns an i386 APC argument at or above 4 GiB back into
the guest address (a host pointer outside the window is logged and becomes 0); a value below
4 GiB, as `NtQueueApcThread`'s arguments are, goes through unchanged.

## Consequences

- An i386 game's overlapped I/O with a completion routine (`ReadFileEx`, `WriteFileEx`,
  `ReadDirectoryChangesW`, `NtNotifyChangeKey` with an APC) gets its `OVERLAPPED` back.
- Completion ports were already right: `NtRemoveIoCompletion` returns the 32-bit context the guest
  gave.
