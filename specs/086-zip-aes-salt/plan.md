# Implementation Plan: Unpredictable salts for encrypted ZIP archives

**Branch**: `086-zip-aes-salt` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/086-zip-aes-salt/spec.md`

## Summary

The ZIP plugin's `FillBufferWithRandomData` (AES salt of every encrypted file,
random part of every ZIP 2.0 encryption header) uses `rand()` seeded with
time ^ pid. Replace its source with a new header-only shared generator,
`src/common/salrandom.h` `SalGenRandom` (`BCryptGenRandom`), which the core's
password manager (feature 085 F6) adopts too, so the product has one
definition of where random bytes come from. Traced fallback kept in both
callers. No format, configuration, UI or plugin-interface change.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; `bcrypt.dll` (system; new import of `zip.spl`)
**Storage**: N/A (bytes written into archives; format unchanged)
**Testing**: `saltests` (`TestRandom086`); probe `probe/zip_salts.py` (reads
salts/headers out of archives, self-test against archives made by 7-Zip);
GUI round trip owed (`quickstart.md`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + plugin
**Performance Goals**: N/A (8–16 bytes per encrypted file)
**Constraints**: plugin interface 106 unchanged; old archives readable
**Scale/Scope**: 1 new header, 2 functions changed, tests, records

## Constitution Check

| Principle | Assessment |
|---|---|
| I. Build reproducibility | header-only, `#pragma comment(lib)`; no project or build-script change ✅ |
| II. Backward compatibility | archive format unchanged; reading never generates random data; old archives readable by construction (R1) ✅ |
| III. Incremental modernization | two small functions changed; `pwdmngr.cpp` only swaps its call for the shared one ✅ |
| IV. Windows platform | system CNG API ✅ |
| V. Plugin architecture | plugin interface untouched; the plugin includes a header from `src/common`, as mdview/codeview/ftp do ✅ |
| VI. UI consistency | no UI ✅ |

Post-design re-check: unchanged — all gates pass.

## Project Structure

### Documentation (this feature)

```text
specs/086-zip-aes-salt/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/salrandom.md
├── checklists/requirements.md
├── tasks.md        # /speckit-tasks
├── fix-log.md      # implementation record
└── probe/zip_salts.py
```

### Source Code (repository root)

```text
src/common/salrandom.h              # NEW: SalGenRandom (header-only)
src/pwdmngr.cpp                     # FillBufferWithRandomData -> SalGenRandom
src/plugins/zip/crypt.cpp           # FillBufferWithRandomData -> SalGenRandom
src/saltests/saltests.cpp           # TestRandom086
CHANGELOG.md, specs/NEXT-WORK.md, CLAUDE.md
```

**Structure Decision**: existing layout; the new helper follows the
`src/common/sal*.h` convention, header-only for the reason in research R2.

## Complexity Tracking

No constitution violations.
