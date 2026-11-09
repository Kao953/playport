# 0201: The Visual C++ runtime key is there for arm64 too

**Status:** accepted, 2026-11-09, by the person running this fork.

## Context

FINAL FANTASY RESONANCE DEMO (4474710) ended 2 s after Play with exit code 9001 (0x2329). Its
`FFRS.exe` is an Unreal Engine packaged-game bootstrapper. The log showed its dialog: "The
following component(s) are required to run this program: Microsoft Visual C++ 2015-2022
Redistributable (arm64)". The bootstrapper checks the runtime's version key for the native
machine, and Wine here reports that as ARM64. The prefix seed wrote only
`VisualStudio\14.0\VC\Runtimes\x64` (House of Golf 2's case), so the arm64 key was missing.

## Decision

The prefix registry seed (`app/tools/prefix-registry.py` VC_RUNTIME) writes the same values under
`Runtimes\arm64` as under `Runtimes\x64`. Like the x64 key, it is a top-up section, so an
existing prefix gets it at the next start, and a value already there is kept.

## Consequences

Any Unreal bootstrapper (or other check) that reads the arm64 key finds the runtime installed, as
the x64 one already did. Wine's builtin msvcp140 and vcruntime140 serve the x86-64 game either way.
