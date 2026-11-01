# Implementation Plan: FTP server folder names compared by the file system's name rule

**Branch**: `385-ftp-path-name-rule` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/385-ftp-path-name-rule/spec.md`

## Summary

`FTPIsPrefixOfServerPath` (`src/plugins/ftp/ftputils.cpp`, also behind `FTPIsTheSameServerPath`
and `FTPIsTheSamePath`) compares server paths of the case-insensitive path types with the
code-page byte fold (`StrNICmp`, `LowerCase[]` = `CharLowerA` per byte) over UTF-8 bytes and a
byte count taken from the prefix. The function body moves into a new header-only rule
`src/common/salftpsrvpath.h` (`SalFtpServerPathIsPrefix`) that walks the two paths separator by
separator and name by name and compares each name with `SalNameOrderEqualCI` (092 rule,
`salnameorder.h`, 115). The trailing-separator, root and boundary logic of each path type is kept
as it is; only the "these bytes are equal case ignored" step changes, and every length test that
compared the prefix's byte count with the path's now uses the position the walk reached in the
path. `ftputils.cpp` maps `CFTPServerPathType` to the header's path kind and calls it. saltests
checks the rule, including an exhaustive ASCII equivalence against a copy of the old function.

## Technical Context

**Language/Version**: C++20 (MSVC v143), WinAPI
**Primary Dependencies**: `src/common/salnameorder.h` (header-only, already used by the FTP plug-in, `operats5.cpp`, `operats9.cpp`)
**Storage**: N/A
**Testing**: `saltests` (pure rule), GUI probe on the hidden desktop with feature 323's `ftpmini_hide.py` (copied, plus a SYST option), regressions: probes 215, 224, 233, 277
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (FTP `.spl`)
**Performance Goals**: no measurable change; the walk converts to UTF-16 only names that contain non-ASCII bytes (salnameorder's fast paths)
**Constraints**: no fixed buffer, no cut (FR-007): `SalNameOrderEqualCI` takes lengths and uses a heap buffer over 519 bytes
**Scale/Scope**: one function body (about 120 lines) + mapping, 22 call sites unchanged

## Constitution Check

- I. Build reproducibility: a header-only file, no new project or dependency - PASS.
- II. Backward compatibility: ASCII answers proven unchanged (exhaustive saltests check); no
  stored data, registry or plug-in ABI change - PASS.
- III. Incremental modernization: replaces a code-page rule by the project's Unicode rule at one
  site - PASS.
- IV. Windows commitment: `CompareStringOrdinal` via salnameorder - PASS.
- V. Plug-in architecture: internal to the FTP plug-in; no `spl_*.h` change - PASS.
- VI. UI consistency: no UI change, no strings - PASS (no `.slt` refresh needed).

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/385-ftp-path-name-rule/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/server-path-rule.md
├── fix-log.md
├── probe/ftp385_probe.ps1, probe/ftpmini385.py, probe/result_*.txt
└── tasks.md
```

### Source Code

```text
src/common/salftpsrvpath.h          # new: SalFtpServerPathIsPrefix + SalFtpVmsEscaped (header-only)
src/plugins/ftp/ftputils.cpp        # FTPIsPrefixOfServerPath -> the header (kind mapping)
src/saltests/saltests.cpp           # TestFtpServerPath385 (+ old-rule reference copy)
```

**Structure Decision**: one header under `src/common/` (stop-rules §2.5), callers untouched.

## Design

1. **Path kinds** (`ESalFtpSrvPathKind`): `CaseSensitive` (Unix, Empty, Unknown: unchanged
   `strncmp` branch), `Vms`, `Mvs`, `Slashes` (Windows, NetWare, OS/2), `Dotted` (IBM z/VM,
   Tandem), `As400`.
2. **Separators per kind**: Vms `.` `[` `]` when not escaped (`^` count, `SalFtpVmsEscaped` =
   `FTPIsVMSEscapeSequence`); Mvs `.` `'`; Slashes `/` `\` (one separator); Dotted `.`; As400 `/`.
3. **The walk** `Walk(kind, a, la, b, lb, &i, &j)`: while `i < la`: a separator in `a` must meet
   the same separator in `b` (Slashes: any of the two) - both advance one byte; otherwise both
   names (up to the next separator or the end) are compared with `SalNameOrderEqualCI` and both
   advance by their own lengths; the first difference stops the walk.
4. **Branches**: Vms / Mvs / Dotted: the old trailing-strip of `l1` / `l2`, then the walk over
   `[0, l1)` / `[0, l2)`; a match needs `i == l1`, the old length test on `j` vs `l2` and the old
   boundary test on `path[j]` (Vms also `prefix[l1 - 1] == '['`, now guarded by `l1 > 0`).
   Slashes / As400: the walk, then the old post-logic on the stop positions (skip one separator
   of each, both at the end, or the prefix at its end and the path just after a separator).
5. **Why ASCII answers do not change**: for ASCII the old fold and `SalNameOrderEqualCI` are both
   the ASCII case fold; equal names have equal lengths, so the walk stops at the same positions
   as the old byte loop whenever the result can be TRUE, and at a name start (the result is
   FALSE in both) otherwise. Proven by saltests over all pairs of a generated ASCII set.
6. **Callers** (22 sites, enumerated in research.md) keep their logic.

## Complexity Tracking

None.
