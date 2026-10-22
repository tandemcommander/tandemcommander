# Research - 301-subst-target-whole

## R1 Which target lengths are reachable

- Decision: support any length on read; size the display buffers for `subst.exe` targets
  (< MAX_PATH units); refuse beyond a caller's buffer.
- Rationale: measured at 0f7bd140 - `subst.exe` takes 138 units (80 CJK letters, 298 bytes of
  UTF-8) and refuses 359 ("Invalid parameter"); `DefineDosDeviceW` takes 359;
  `QueryDosDeviceW(260)` fails with `ERROR_INSUFFICIENT_BUFFER` for it, `(1024)` returns it.
- Alternatives: a fixed `SAL_MAX_PATH_W` buffer (64 KiB on the stack per query - rejected; the
  heap buffer grows only when needed).

## R2 What to do when a target does not fit

- Decision: refuse - `FALSE` (+ `tooLong`), the buffer emptied; never the code page, never a cut.
- Rationale: the item's *Expected*; CLAUDE.md "a path is never cut"; 069 already took the wide
  call, the code-page fallback was the remaining leak.
- Alternatives: keep the code-page fallback for code-page-representable targets - rejected: the
  answer is code page, not UTF-8 (the 069 F-P1-13 defect itself).

## R3 `ResolveSubsts` when the target is refused

- Decision: `ret = FALSE`, path unchanged.
- Rationale: identical to its existing "too long path!" branch; the plug-in contract
  (`spl_gen.h`) keeps a MAX_PATH buffer, so a resolved path over 259 bytes cannot be returned.
  An unresolved `Z:\...` path is valid - Windows resolves the subst itself (probe LONG DEL PASS
  before the fix shows exactly that).
- Consequence (limit): same-volume checks then answer "different" for such a path (as for any
  path whose resolution passes 260 bytes); `GetVolumePathNameW` / `GetVolumeNameForVolumeMountPointW`
  give no volume for a subst path (measured), so there is no whole-path alternative here. The
  Undelete plug-in's same-partition warning fails open on it -> Inbox item.

## R4 Where the parse rule lives

- Decision: header-only `src/common/salsubst.h` with `saltests` checks (stop-rules §2.5).
- Rationale: the forms (`\??\X:`, `\??\UNC\`, other devices) and the exact-fit refusal are pure.

## R5 The "related cut" in the Change Drive menu

- Decision: no change.
- Rationale: `netRemotePath` is `char['z' - 'a' + 1][MAX_PATH]` (`drivelst.cpp`), so
  `strlen <= MAX_PATH - 1` and `min(l, MAX_PATH - 1)` never cuts.
