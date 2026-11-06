# 0187: The phone's CJK fonts stand in for the Windows ones

**Status:** accepted, 2026-11-06, by the person running this fork, after CHRONO TRIGGER (613830)
in Traditional Chinese drew every character as a box.

## Context

The runtime ships Wine's Tahoma and Marlett only. win32u reads the phone's fonts through CoreText
(`load_mac_fonts`), but a game names Windows faces ("Microsoft JhengHei", "MS Gothic") and the
default system links name Windows files (`MINGLIU.TTC`, `SIMSUN.TTC`) that are not there, so
nothing in the fallback chain had CJK glyphs.

## Decision

`patches/wine-unix/0205`, `0206` and `0207`, iOS only:

- the four faces' files are loaded by PostScript name through CoreText (PingFangTC-Regular,
  PingFangSC-Regular, HiraginoSans-W3, AppleSDGothicNeo-Regular), as Madeira's `freetype_ios.c`
  cuts off the sweep of every system font; a face with no family or style name is skipped rather
  than crashing, and a `[fonts] iOS: …` line names each file or why a name has none;

After the system links load:

- for each script the stand-in is the phone's face when it loaded, else the first loaded family
  whose code pages cover the script (`FS_CHINESETRAD`, `FS_CHINESESIMP`, `FS_JISJAPAN`, `FS_WANSUNG`),
  such as a font the player put in `C:\windows\Fonts` under any file or family name. On the owner's
  phone the four system files loaded no face (`0 face(s)`), so for now a player-supplied font is
  the way to CJK text;
- each Windows CJK face name the prefix lacks is a replacement family for its script's stand-in: Traditional Chinese names (Microsoft JhengHei, PMingLiU, MingLiU, DFKai-SB) for PingFang TC,
  Simplified (Microsoft YaHei, SimSun, SimHei, KaiTi, FangSong) for PingFang SC, Japanese (MS Gothic,
  MS Mincho, Meiryo, Yu Gothic and their variants) for Hiragino Sans, Korean (Malgun Gothic, Gulim,
  Dotum, Batang) for Apple SD Gothic Neo;
- those four phone faces are linked, in that order, after the other entries of Tahoma, Microsoft
  Sans Serif, MS Shell Dlg (2), System, Arial and Segoe UI, through which every GDI font falls back;
- `[fonts] iOS CJK faces: …` in the log names the faces found.

## Consequences

- GDI text in Chinese, Japanese or Korean draws with the phone's fonts. Han characters shared by
  the four take PingFang TC's shapes when the requested face has none of its own.
- DirectWrite still sees only the faces the `Fonts` key names (Tahoma, Marlett).
