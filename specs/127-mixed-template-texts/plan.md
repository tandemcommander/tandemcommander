# Implementation Plan: Translated sentences with names and error texts are readable

**Branch**: `127-mixed-template-texts` (from `126-package-api-late-bind`) | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)
**Input**: GitHub issue #7 (`issues/issue_7.md`)

## Summary

`LoadStr()` gives code-page text; names, paths and `GetErrorText()` are UTF-8. Where the two
are composed and the result goes to a UTF-8 sink, the template is loaded with `LoadStrU8()`
instead, the composition is bounded, and a text that had to be shortened is cut at a whole
character. The places: the report's 21 + 4 + the Find status line, and the ones found by the
inventory and the triage (research R3). The Registry Editor's five messages get the same
treatment with the plug-in's own `LoadStrU8`. The encoding guard learns the class.
`LoadStrU8` itself loses its one failure mode (no retry at the end of its buffer).

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: existing `LoadStrU8`, `SalU8TrimIncompleteTail`, `SalFindTrimTornTail`
**Storage**: none (one file name generated on disk is affected: the "copy in the same folder" name)
**Testing**: GUI probe `probe/mixed_probe.ps1` on the hidden desktop in Czech (LOG exact by `LVM_GETITEMTEXTW`; STATUS and BOX by window text and text recognition), rows for the Find title, the Slovak copy name (read from disk), a Registry Editor question; before (0.1.9) and after; `tools/check_encoding.py` before/after and a re-broken line; `probe/scan_mixed.py` inventory; saltests for the `LoadStrU8` retry is not possible (it needs resources) - covered by a probe row that loads many texts
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core + one plug-in + a build tool)
**Constraints**: English unchanged; no new string; consistent code-page compositions untouched; never write past a buffer; cut only at a whole character
**Scale/Scope**: about 45 call sites in 14 core files, 5 in `regedt`, the guard, `LoadStrU8`

## Constitution Check

| Principle | Verdict |
|-----------|---------|
| I. Build reproducibility | PASS - the guard (part of every build) gains a rule extension; it passes on the fixed tree |
| II. Backward compatibility | PASS - display texts; the generated copy name changes only where it was wrongly spelled |
| III. Incremental modernization | PASS - the established `LoadStrU8` pattern, site by site |
| IV. Windows commitment | PASS |
| V. Plugin architecture preservation | PASS - no interface change; texts handed to plug-ins are left alone (research R4) |
| VI. UI consistency | PASS |

## Stages

| Stage | Content |
|---|---|
| S0 measure | done: `probe/mixed_result_before_v019.txt`; guard with the rule extension: 22 findings; inventory `probe/scan_mixed.py`: 46 candidates; triage by a separate agent (research R3) |
| S1 loader | `salamdr2.cpp` `LoadStrU8`: when the converted text does not fit the rest of the rotating buffer, start at the beginning and convert again |
| S2 Find | `finddlg1.cpp` (status base, three titles), `find.cpp` (duplicates text, five log compositions, three plain log texts, `CSearchingString::Set` cut at a whole character) |
| S3 message boxes and texts | `dialogs3.cpp`, `fileswn3.cpp`, `fileswn5.cpp` (4 + 2 menu items), `fileswn6.cpp` (6 + junction text), `fileswn8.cpp`, `fileswn9.cpp`, `icncache.cpp`, `mainwnd4.cpp`, `salamdr1.cpp`, `codetbl.cpp`; `callstk.cpp` marked as the allowed exception |
| S4 the copy name | `fileswn6.cpp`: `IDS_NEWNAME_COPY` / `IDS_NEWNAME_OF` through `LoadStrU8` |
| S5 Registry Editor | `fs2.cpp` (2), `fs3.cpp` (2), `utils.cpp` (1) through the plug-in's `LoadStrU8` |
| S6 guard | `tools/check_encoding.py`: `GetErrorText(` as a UTF-8 argument; `params.Text =` and `log.Text =` as sinks; documentation text |
| S7 tests, gates, records | probe rows; builds; guard; review; records; NEXT-WORK for what is left |

## Project Structure

```text
src/salamdr2.cpp, src/find.cpp, src/finddlg1.cpp, src/dialogs3.cpp, src/fileswn3.cpp,
src/fileswn5.cpp, src/fileswn6.cpp, src/fileswn8.cpp, src/fileswn9.cpp, src/icncache.cpp,
src/mainwnd4.cpp, src/salamdr1.cpp, src/codetbl.cpp, src/callstk.cpp
src/plugins/regedt/fs2.cpp, fs3.cpp, utils.cpp
tools/check_encoding.py
specs/127-mixed-template-texts/probe/   # mixed_probe.ps1, lvtext_lib.ps1, scan_mixed.py, results, shots/
```

**Structure Decision**: no new source file; the rule lives in the guard.

## Complexity Tracking

No violations.
