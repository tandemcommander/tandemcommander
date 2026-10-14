# Fix log: 181 - a shortcut in a long folder opens its target

Backlog: NEXT-WORK section D, "Found by the second verification of 124-128", item 3 (128).

## Measured (before)

Probe `probe/lnk_probe.ps1` (hidden desktop; `go.lnk` -> a folder `...\target`, made by
WScript.Shell in a short folder and moved in), the build at 168: 7 / 3 (`probe/result_before.txt`).

- Enter on `go.lnk` in a folder of 130 Czech letters (321 bytes of UTF-8, fewer than MAX_PATH
  characters): "Cannot finish operation because of too long name." - `Execute` built the shortcut's
  path with a MAX_PATH-byte limit.
- In a folder of more than MAX_PATH characters (301): refused the same way.
- Focus Shortcut Target (838) in the 301-character folder: "The file 'go.lnk' is not valid shortcut
  nor link." - the strict conversion into `OLECHAR[MAX_PATH]` failed and the code-page widening cut
  the path. In the 321-byte folder (fewer characters) it worked.

## Work

- `src/fileswn2.cpp` `Execute`: the path with `SAL_MAX_PATH_UTF8` (the buffer is that size).
- `src/common/salshelllink.h` `SalShellLinkLoadNameAlloc` (review: one helper, not two copies):
  the name for `IPersistFile::Load` on the heap, in the `\\?\` form when it has MAX_PATH
  characters or more; the code-page widening only for a name that is not UTF-8. Used by
  `src/fileswn2.cpp` `Execute` and `src/fileswn0.cpp` `FocusShortcutTarget`. saltests
  `TestShellLinkLoadName181` (22,344 checks, 0 failed).

No string, interface or registry change. Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

The same probe: 10 / 0 (`probe/result_after.txt`), registry identical.

## Review

Independent refute-first review: the change sound (no `goto`, the buffer released after the COM
objects, `fullName` large enough, everything after `Load` already `SAL_MAX_PATH_UTF8`). Taken: the
shared helper with saltests checks; the code-page widening only when the strict conversion failed.
Not verified: `Load` of a `\\?\` name on Windows 10 (driven on Windows 11 only; a refusal there is
the old failure), a target of MAX_PATH characters or more, `Resolve` with `SLR_UPDATE` through the
`\\?\` name. Recorded in NEXT-WORK: `FocusShortcutTarget`'s `errBuf[MAX_PATH + 300]` takes a name
of up to 780 bytes with `sprintf` - a stack overrun (feature 182); a junction / symlink in a folder
of 260 bytes or more is not recognised (`strlen < MAX_PATH` guard); `GetSHObjectName(..., MAX_PATH)`
cuts and converts with the code page (server links, Network plug-in only).
