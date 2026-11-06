# 0184: winmm's joystick API reads the host's pads

**Status:** accepted, 2026-11-06, by the person running this fork, after CHRONO TRIGGER (613830)
took no controller input. Amends the "Pads are XInput only" line of
[ARCHITECTURE.md](../ARCHITECTURE.md).

## Context

CHRONO TRIGGER's executable imports `joyGetNumDevs` and `joyGetPosEx` from winmm and feeds
cocos2d's controller events from them; it loads no XInput, and of Steam Input it calls only
`Init` (decision 0183). Wine's winmm finds joysticks through DirectInput, which sees no HID device
in this process, so the game ran on the keyboard alone in either Steam API mode.

## Decision

- `joyGetDevCapsW` (and `A`) and `joyGetPosEx` (and `joyGetPos`, the capture timer) ask the host
  slot first, through the `NtUserCallTwoParam_GetGamepadState` call xinput uses
  (`patches/wine-pe/0064`). A pad in host slot 0-3 is joystick 0-3.
- The layout is what Windows' own driver gives an Xbox 360 controller through winmm: X/Y the left
  stick, Z both triggers (LT up from the middle, RT down), R/U the right stick's Y/X, buttons A, B,
  X, Y, LB, RB, Back, Start, LS, RS as 1-10, the D-pad a four-way POV; caps name VID 045e PID 028e.
- With no host pad in a slot the DirectInput path answers as before.

## Consequences

- Games that read pads through winmm (older titles, some engine ports) see the controller.
- DirectInput still finds no pad.
