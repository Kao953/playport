# 0204: A title's path may use any UTF-8 name

**Status:** accepted, 2026-11-09, by the person running this fork.

## Context

アライさんマンション探索ゲーム～Incarnation～ (4293310) installs into a Japanese folder name.
Play refused it before anything started: `resolve ... -> -1 ... only ASCII names are supported`.
That refusal in `title_path_resolve` dates from Madeira's launcher, which passed the working
directory through `MADEIRA_INITIAL_CWD`. The runtime widened that variable one byte per
character, which garbled a UTF-8 name. Playport starts every title through the session root
instead. The root receives the DOS path and working directory as UTF-8 and converts them with
`MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS)` before `CreateProcessW`. Playport never
sets `MADEIRA_INITIAL_CWD`, and `wine_host_session_start` unsets it.

## Decision

`title_path_resolve` accepts any well-formed UTF-8 path. It refuses only malformed UTF-8 (which
the root's conversion would refuse anyway), including encoded surrogates and overlong forms. The
MAX_PATH check counts UTF-16 units, as Windows does, not bytes.

## Consequences

A game in a folder named in Japanese, Chinese or another non-ASCII script starts like any other.
The host C test (`app/tests/title_path_test.c`) resolves a Japanese folder, and refuses Latin-1
bytes and an encoded surrogate.
