# Implementation Plan: FTP - a listing column built from several parts is decoded part by part

**Branch**: `384-ftp-joined-column` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/384-ftp-joined-column/spec.md`

## Summary

The FTP listing rule step `add_string_to_column` (`parser2.cpp`, `fpfAdd_string_to_column`) joins
the column's decoded UTF-8 value with the appended part and decodes the joined bytes again; with a
raw code-page part the joined text is not UTF-8 and the head is read in the code page a second time
(`nameč.extč` -> `nameÄŤ.extč`). The fix: decode the appended part alone by its kind (raw listing
bytes by the server's listing-field rule, a literal alone, another column as it is), append it to
the head, and assign the joined UTF-8 without a further decode; register the joined value as a
code-page name of the server when a part came from the code page (pure rule in
`src/common/salftpsrvenc.h`, saltests).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: FTP plug-in (`src/plugins/ftp`), Salamander plug-in API (unchanged)
**Storage**: none (the per-server name set of 288 is in memory)
**Testing**: `saltests` (pure rule), GUI probe `probe/ftp384_probe.ps1` with `probe/ftpmini.py` (z/VM listing form) on the hidden desktop; regression probes of 288 / 269 / 224
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: none beyond the current parse (one extra small allocation per joined value)
**Constraints**: plug-in ABI untouched; UTF-8 / WTF-8 names (066); never cut a name (215's `FTP_MAX_NAME_U8` check stays); no UI strings
**Scale/Scope**: one parser step, one helper in `ftputils.cpp`, one pure rule

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency, no project change | PASS |
| II. Backward compatibility | listing results change only for names that were garbled; ASCII / UTF-8 / head-ASCII names unchanged (probe controls) | PASS |
| III. Incremental modernization | local fix in the parser step; pure rule in a header with tests | PASS |
| IV. Windows commitment | WinAPI code page decode as before | PASS |
| V. Plugin architecture | no change to `spl_*.h`, `LAST_VERSION_OF_SALAMANDER` | PASS |
| VI. UI consistency | no UI change, no strings | PASS |

Post-design re-check: PASS (design adds no interface, no string, no stored data).

## Project Structure

### Documentation (this feature)

```text
specs/384-ftp-joined-column/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ ftp384_probe.ps1, ftpmini.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salftpsrvenc.h        # + SalFtpJoinPartHandling, SalFtpJoinedFieldIsCodePageName (pure)
src/saltests/saltests.cpp        # + checks of the two rules
src/plugins/ftp/ftputils.h/.cpp  # + FTPListingJoinFieldU8 (decode the part by kind, join, register)
src/plugins/ftp/parser2.cpp      # AssignU8StringToColumn split out of AssignStringToColumn;
                                 # fpfAdd_string_to_column uses FTPListingJoinFieldU8
```

**Structure Decision**: existing plug-in and common header layout; no new files in `src/`.

No `contracts/`: the change is internal to the FTP plug-in (no plug-in API, no file format, no
command-line or registry interface changes).

## Complexity Tracking

None.
