# Implementation Plan: 7zip plug-in follow-ups

**Branch**: `089-7zip-followups` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

## Summary

Three small defects recorded by feature 087's reviews: one rule in the
core's association update, WTF-8 in the shared plug-in converters, and
cleaned names in the 7z update matching.

## Technical Context

**Language/Version**: C++ (MSVC v143), WinAPI
**Storage**: registry (association records; 7zip plug-in configuration version 4 → 5)
**Testing**: saltests; feature 087's engine probe; a registry probe on the Debug build
**Constraints**: plug-in interface stays 107 (a header-only helper changes, no vtable change); the legacy extension-update path of other plug-ins is untouched

## Constitution Check

| Principle | Status |
|---|---|
| II. Backward compatibility | associations migrated once; converters byte-identical for valid text ✅ |
| V. Plug-in architecture | `splunicode.h` behaviour extended (accepts and produces surrogate sequences) — documented in the header and the contract first ✅ |
| Release documentation | CHANGELOG *Unreleased*; `PRIVACY.md` unaffected ✅ |

## Stages

1. **S1 — associations**: `CArchiverConfig::NeverBrowses`, helpers in
   `src/common/salarcassoc.h` + tests, the rule in `AddPanelArchiver`,
   plug-in configuration version 5. Gate: registry probe (three
   configurations).
2. **S2 — converters**: `splunicode.h` fallback + parity tests; 7zip
   `structs.h`. Gate: saltests, engine probe, full build (every plug-in
   uses `splunicode.h`).
3. **S3 — update matching**: cleaned names in `GetArchiveItemList`.
4. **S4 — records**. Independent review before the commit.

## Complexity Tracking

None.
