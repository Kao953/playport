# 0190: My Documents' shell item resolves to its folder

**Status:** accepted, 2026-11-06, by the person running this fork, after Guilty Gear XX Accent
Core Plus R (348550) could not save in any Steam API mode.

## Context

The game asks the shell for My Documents as an item ID list (`SHGetFolderLocation(CSIDL_PERSONAL)`
gives Wine's virtual My Documents item) and turns it into a path. Wine's desktop folder returns
that item's file system path only when `HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\ShellFolder`
has `WantsFORPARSING` (`dlls/shell32/shfldr_desktop.c`); otherwise its parsing name is
`::{450d8fba-ad25-11d0-98a8-0800361b1103}`. The prefix lacked the key, as neither wine.inf nor
shell32's registration writes it, so the game made `::\{450d8fba-…}\ARC SYSTEM WORKS\GGXXAC\save`
(`STATUS_OBJECT_PATH_NOT_FOUND`) and saved nothing.

## Decision

The registry seed (`app/tools/prefix-registry.py` `SHELL_FOLDERS`) gives that key Windows' values,
`Attributes` = `0xF0400174` (with `SFGAO_FILESYSTEM`) and `WantsFORPARSING` = "", marked for
top-up so an existing prefix gets them at its next launch.

## Consequences

- `SHGetPathFromIDList` and `GetDisplayNameOf(SHGDN_FORPARSING)` on My Documents' item give
  `C:\users\playport\Documents`, as Wine's My Documents folder (`shfldr_fs.c`) reads
  `CSIDL_PERSONAL`.
