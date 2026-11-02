# Implementation Plan: Viewer Find pre-fills the selection as the text the viewer shows

**Branch**: `398-viewer-find-seed` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/398-viewer-find-seed/spec.md`

## Summary

`CFindSetDialog::Transfer` (src/viewer.cpp) pre-fills the viewer's Find field with the selection's
raw bytes through an ANSI `WM_SETTEXT`. A UTF-8 selection becomes code-page mojibake, is not found,
and since 311 a long one is refused at OK. The fix: a pure header `src/common/salfindseed.h` with
`SalFindSeedDecodeW` that decodes the selected bytes by the viewer's content encoding and keeps the
longest whole-character beginning that fits 200 UTF-16 units and 200 UTF-8 bytes; the dialog sets
the field with `SetWindowTextW` on the combo box. `CViewerWindow::GetFindText` gets a buffer size so
the dialog can read enough bytes for 200 units of any encoding (UTF-16 needs 400 bytes). Hex mode
is unchanged.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143, `/J` (char unsigned)
**Primary Dependencies**: Win32 (`MultiByteToWideChar`, `IsDBCSLeadByteEx`) only
**Storage**: N/A
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/seed398_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: N/A (at most ~400 bytes decoded once per dialog open)
**Constraints**: field limit 200 UTF-16 units (`CB_LIMITTEXT FIND_TEXT_LEN - 1`); OK accepts at
most 200 UTF-8 bytes (`DlgItemTextFitsU8(..., FIND_TEXT_LEN)`, 311)
**Scale/Scope**: one dialog, one viewer method, one new header, tests

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; header-only; vendored nothing | PASS |
| II Backward compatibility | no settings, registry, plug-in ABI change; hex pre-fill and code-page pre-fill unchanged | PASS |
| III Incremental modernization | one site moved from ANSI to wide; pure rule with tests | PASS |
| IV Windows commitment | Win32 only | PASS |
| V Plug-in architecture | untouched (DB Viewer's copy is not part of this item) | PASS |
| VI UI consistency | no new strings or dialogs; no translations | PASS |

CLAUDE.md standing rules: UTF-8 / wide sinks (no `A` API, no `CP_ACP` for a name - the code-page
decoding here is of *file content* shown in the code page, the same the viewer draws; the encoding
checker must stay at 0); never cut a path - the seed is not the user's text (item *Notes*), it is
shortened at a whole character before it is shown.

## Project Structure

```text
specs/398-viewer-find-seed/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/find-seed.md
├── probe/seed398_probe.ps1, result_*.txt
└── fix-log.md
src/common/salfindseed.h        (new, pure rule)
src/viewer.cpp                  (CFindSetDialog::Transfer)
src/viewer2.cpp, src/viewer.h   (GetFindText with a buffer size)
src/saltests/saltests.cpp       (TestFindSeed398)
```

**Structure Decision**: existing core layout; the rule in `src/common/` per CLAUDE.md working method.

## Complexity Tracking

None.
