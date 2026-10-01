# Implementation Plan: Plug-in interface 107

**Branch**: `088-plugin-interface-107` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

## Summary

Two additions at the end of `CSalamanderGeneralAbstract`
(`IsUnattendedClose`, `SetWindowClosesUnattended`), one constant
(`SAL_MAX_PATH_UTF8`) and corrected buffer comments make interface 107. The
core's close decision lets declared windows pass (rule D8); the four viewer
plug-ins declare their windows and close them silently during an unattended
close; FTP stops asking. The viewer file-name services are guarded for older
plug-ins, and the in-tree plug-ins with 260-byte buffers are fixed.

## Technical Context

**Language/Version**: C++ (MSVC v143), pure WinAPI
**Primary Dependencies**: none new
**Storage**: none (a window property; no configuration)
**Testing**: `saltests` (pure decision rules), feature 080's PowerShell probes against the Debug build, a long-path GUI probe
**Target Platform**: Windows 10/11 x64
**Project Type**: desktop application + plug-ins
**Constraints**: binary compatibility for plug-ins built for 104–106 (constitution §II, §V); the close decision stays side-effect-free; no prompt on the unattended path
**Scale/Scope**: 2 interface methods, 1 constant, ~6 core files, 5 shipped plug-ins (4 viewers + FTP), 3 plug-ins not built by default

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | unchanged build; ✅ |
| II. Backward compatibility | interface append only; older plug-ins load; behaviour for them changes only where the old behaviour was a buffer overflow (B3) ✅ |
| III. Incremental modernization | one bump for two debts, as NEXT-WORK asks ✅ |
| IV. Windows platform | Restart Manager path only ✅ |
| V. Plug-in architecture | documented first: contract + header comments + version history before the code (tasks T003–T004) ✅ |
| VI. UI consistency | no new UI; one manual sentence corrected ✅ |
| Release documentation | CHANGELOG *Unreleased*; no product version bump; `PRIVACY.md` unaffected (no network, storage, crash-report or installer change) — recorded in the fix log ✅ |

## Project Structure

```text
specs/088-plugin-interface-107/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md, fix-log.md
├── contracts/plugin-api-v107.md
├── checklists/requirements.md
└── probe/                      # GUI probes (PowerShell), reusing 080's drivers

src/plugins/shared/spl_vers.h   # 107 + history
src/plugins/shared/spl_gen.h    # two methods, corrected comments
src/plugins/shared/spl_base.h   # SAL_MAX_PATH_UTF8
src/common/salpath.h            # #ifndef guard
src/common/salcloseapp.{h,cpp}  # D8: declared windows; viewer-name guard rule
src/plugins.h, src/zip.cpp      # CSalamanderGeneral overrides
src/mainwnd3.cpp                # enumeration reads the declaration
src/salamdr6.cpp / zip.cpp      # B3 guard
src/consts.h                    # corrected comments
src/saltests/saltests.cpp       # tests
src/plugins/{codeview,mdview,pictview,dbviewer}/  # declare + silent close; buffers
src/plugins/ftp/ftp.cpp         # no question
src/plugins/{mmviewer,demoview,demoplug}/         # buffers
help/, CHANGELOG.md, CLAUDE.md, specs/NEXT-WORK.md, specs/080-…/REMAINING-WORK.md
```

## Stages

1. **S1 — interface (documented first)**: contract, `spl_vers.h`,
   `spl_gen.h`, `spl_base.h`, core overrides, D8 rule + tests. Gate: full
   Debug build, saltests.
2. **S2 — viewers and FTP**: declarations at window creation, silent close,
   FTP. Gate: 080 probes — positive (four viewers), negatives (viewer dialog,
   other plug-in window, normal exit prompt unchanged), 080 regression set.
3. **S3 — buffers**: constant, comments, plug-in buffers, B3 guard + test.
   Gate: long-path probe in PictView and Database Viewer, Debug RTC silent.
4. **S4 — records**: manual sentence, CHANGELOG, NEXT-WORK, 080 handoff,
   CLAUDE.md, architecture/06. Full Debug + Release build, all gates.

Each stage: independent review before its commit (the 069 protocol).

## Complexity Tracking

None: no constitution deviation.
