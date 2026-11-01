# Research - 386-mydocs-path-whole

## R1 Where the cut happens

- Decision: the cut is `lstrcpyn(path, buff, pathLen)` + `SalU8TrimIncompleteTail` in
  `GetMyDocumentsOrDesktopPath`; `buff[2 * MAX_PATH]` additionally makes a Documents path of more
  than 519 bytes fall to the Desktop even for callers with `SAL_MAX_PATH_UTF8`.
- Rationale: `SHGetPathFromIDListW` gives at most 259 units; `SalWToU8` returns 0 (and empties the
  buffer) when the UTF-8 form does not fit, so converting straight into the caller's buffer is
  "whole or nothing" by itself; the size must be told apart from "no path" to refuse instead of
  using the Desktop.
- Alternatives: keep `buff` and add a length check before `lstrcpyn` (still limits long callers to
  519 bytes - rejected); `SHGetKnownFolderPath` (no 259-unit limit; changes the Documents lookup
  for every caller - outside the item, rejected).

## R2 Callers (enumerated with Grep at 10eb1994)

| Caller | Buffer before | After |
|---|---|---|
| `fileswn0.cpp` Ctrl+; | `MAX_PATH` | `SAL_MAX_PATH_UTF8` (whole) |
| `fileswn3.cpp` `ChangePathToDrvType` (drive bar button via `CDriveBar::Execute`, Alt+F1/F2 menu via `ChangeDrive`) | `MAX_PATH` | `SAL_MAX_PATH_UTF8` (whole) |
| `salamdr6.cpp` `SafeGetSaveFileNameW`, `SafeGetOpenFileNameW` | `MAX_PATH` | `SAL_MAX_PATH_UTF8`; the wide initial folder `MAX_PATH` units holds any 259-unit path |
| `salamdr6.cpp` `SafeGetOpenFileName`, `SafeGetSaveFileName` (code page) | `SAL_MAX_PATH_UTF8` | unchanged (then `SalU8ToACP` into `MAX_PATH`, refused as before) |
| `salamdr6.cpp` `GetIfPathIsInaccessibleGoTo` (rescue path; callers fileswn2 x3, dialogs5 x2, mainwnd2, zip.cpp -> plug-ins) | `MAX_PATH` | unchanged; refusal -> its existing fallback (Windows drive root) |

`ChangePathToDisk` accepts paths up to `SAL_MAX_PATH_UTF8 - 2`; the stack is 3 MB
(`sal_base.props`) and `ChangePathToDisk` already holds `SAL_MAX_PATH_UTF8` arrays on the stack,
so the two new local arrays follow the existing pattern.

## R3 Measuring without touching the user's Documents

- Decision: a Debug-only environment seam `TC_PROBE_MYDOCS_FILE` (wide) replaces the Documents path
  the shell reports; committed before the fix.
- Rationale: redirecting the real Documents changes the maintainer's live profile (Explorer, other
  programs) - not acceptable on a working machine. Drive bar buttons are driven by
  `WM_COMMAND CM_DRIVEBAR_MIN + index` (feature 246), the index read from the
  `TC_PROBE_DRIVES_DUMP` seam (`ITEM ... type=7` = `drvtMyDocuments`). Ctrl+; needs a real Ctrl
  key state (NOT DRIVEN; same helper and buffer change as the drive button).
- Alternatives: a person redirects Documents (slow, risky); a unit test only (does not show the
  panel opening another folder) - the rule gets saltests checks in addition.
