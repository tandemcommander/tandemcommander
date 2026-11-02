# Implementation Plan: Hex mode in Find keeps quoted letters outside the code page

**Branch**: `397-hex-find-quoted` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/397-hex-find-quoted/spec.md`

## Summary

`DoHexValidation` (`src/viewer.cpp`) tidies a hex-mode combo box on every `CBN_EDITUPDATE`: it reads
the text with a code-page `WM_GETTEXT` into `char[textLen]`, runs a loop that only looks at `' '`
and `'"'` and counts characters, and writes the text back with a code-page `WM_SETTEXT`. Move the
loop, unchanged except for the character type, into a pure header `src/common/salhexfield.h`
(`SalHexFieldTidyW`, UTF-16, the caret in UTF-16 units - the units `CB_GETEDITSEL` /
`CB_SETEDITSEL` use) with one added guard: the hex-digit grouping never inserts a space between
the two halves of a surrogate pair. `DoHexValidation` reads the whole field with
`GetWindowTextLengthW` / `GetWindowTextW` into a heap buffer sized for the text plus the room the
tidying may add (never a cut), calls the rule with the same limit as today (`textLen - 1` units,
the field's `CB_LIMITTEXT`), and writes back with `SetWindowTextW`. The two callers
(`CFindDialog` `IDC_FIND_CONTAINING`, `CFindSetDialog` `IDC_FINDTEXT`) and everything downstream
(UTF-8 read in `HistoryComboBox`, `ConvertHexToString`, 311's refusal at OK) stay as they are.

## Technical Context

**Language/Version**: C++20 (MSVC v143), `/J` (char unsigned)
**Primary Dependencies**: none new (Win32 W functions)
**Storage**: N/A
**Testing**: `saltests` (new `TestHexFieldTidy397`: fixed cases from the old behaviour, caret
arithmetic, limit, surrogate guard, and a brute-force comparison against a byte copy of the old
loop for ASCII texts); hidden-desktop probe `probe/hex397_probe.ps1`; regression probe
`specs/311-find-containing-cut/probe/grep311_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: unchanged (linear in a 200-unit text per key press)
**Constraints**: never cut the text; same tidying result as before for code-page characters; no
UI string, no resource change; plug-in ABI untouched
**Scale/Scope**: ~100 lines header, ~30 lines in `viewer.cpp`, ~120 lines saltests

## Constitution Check

- I Build reproducibility: a new header only, no dependency. PASS
- II Backward compatibility: ASCII / code-page texts tidy exactly as before (brute-force check
  against the old loop); stored history and settings unchanged. PASS
- III Incremental modernization: one function moved from the code page to UTF-16. PASS
- IV Windows commitment: W APIs. PASS
- V Plug-in architecture: untouched (core-only function). PASS
- VI UI consistency: no visible change except the letters staying. PASS

Re-check after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/397-hex-find-quoted/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/hex-field-tidy.md
├── checklists/requirements.md
├── fix-log.md
├── probe/ (hex397_probe.ps1, results)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salhexfield.h        new - SalHexFieldTidyW (pure, header-only)
src/viewer.cpp                  DoHexValidation reads / writes UTF-16 and calls the rule
src/saltests/saltests.cpp       TestHexFieldTidy397
```

**Structure Decision**: the rule is a header under `src/common/` (standing rule: pure decisions in
a header with saltests checks); the window glue stays in `viewer.cpp`.

## Complexity Tracking

None.
