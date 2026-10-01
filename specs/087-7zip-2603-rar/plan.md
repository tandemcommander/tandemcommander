# Implementation Plan: 7-Zip engine 26.03 and RAR out of the box

**Branch**: `087-7zip-2603-rar` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/087-7zip-2603-rar/spec.md`

## Summary

Replace the plugin's private 7-Zip 16.04 engine with a pristine subset of
7-Zip 26.03 built as the upstream 7z-only `Format7z` bundle plus the RAR/RAR5
handlers (research R4); carry the one local patch that still matters
(call-stack tracking for engine threads, now in one place, `Threads.c`) and
retire the rest (R6); port the plugin's callback classes to the 23.01+
interface macros (R7, R8); add RAR reading to the plugin — format detection,
volumes, Unicode password, memory bound, read-only, registration with
configuration version 4 (R10); clean every archive item name before it
becomes a panel name or a file path, closing a path-traversal / alternate
stream defect that exists today for 7z (R9); remove the unused
`7zwrapper.dll` (R11). Evidence through unit tests, a command-line engine
driver over the 084 RAR fixtures and a 7z corpus compared with an independent
7-Zip, and builds; GUI steps owed (quickstart).

## Technical Context

**Language/Version**: C++ (engine: as upstream, compiles as C++14+ and C; plugin: C++20 `/std:c++latest`), MSVC v143
**Primary Dependencies**: 7-Zip 26.03 source (vendored, LGPL-2.1+ with unRAR restriction); WinAPI
**Storage**: plugin configuration in the registry (`ConfigVersion` 3 → 4)
**Testing**: `saltests` (names, format detection); `probe/7zdrive` engine driver + `run_engine_probe.cmd` against `7z.exe` 22.01; builds; GUI owed
**Target Platform**: Windows 11 x64 (x86 still compiles if it does today)
**Project Type**: desktop application plugin + its engine DLL
**Performance Goals**: listing 10,000 items ≤ 1.5 × 0.1.8 (SC-005)
**Constraints**: plugin interface 106; old 7z archives readable; archive defaults unchanged; no assembler
**Scale/Scope**: ~600 vendored files replaced; ~10 plugin source files changed; 2 projects edited, 1 removed; installer + build script

## Constitution Check

| Principle | Assessment |
|---|---|
| I. Build reproducibility | engine source pinned by SHA-256 in `TC-PATCHES.md`; projects build from one `build.cmd`; no assembler or extra tools ✅ |
| II. Backward compatibility | 7z archives from 0.1.8 stay readable (format and handler unchanged in kind); plugin configuration migrated once (`ConfigVersion` 4) and only adds RAR; the name-cleaning change alters behaviour only for names that were unsafe — a documented defect fix ✅ (justified) |
| III. Incremental modernization | the engine is replaced wholesale because it is third-party code pinned to a release (not refactoring of ours); our own code changes are limited to the callback port, RAR additions and the cleaning call sites; delivered in reviewable commits (engine+build, plugin port, RAR, safety, removal, records) ✅ |
| IV. Windows platform | WinAPI; LGPL engine is GPL-compatible; the unRAR restriction was accepted by the maintainer (084 R4) and is documented ✅ |
| V. Plugin architecture | plugin interface untouched; plugin improved (RAR) ✅ |
| VI. UI consistency | the password prompt stays the existing dialog, made Unicode-capable without restyling ✅ |

Post-design re-check: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/087-7zip-2603-rar/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/engine-build.md, plugin-engine.md, item-names.md
├── checklists/requirements.md
├── tasks.md, fix-log.md
└── probe/   7zdrive.cpp, build_7zdrive.cmd, run_engine_probe.cmd, make_hostile (in 7zdrive)
```

### Source Code (repository root)

```text
src/plugins/7zip/7za/                 # REPLACED: 7-Zip 26.03 subset + spl/ + TC-PATCHES.md
src/plugins/7zip/7za/C/Threads.c      # TC_7ZIP_PATCH: call-stack trampoline
src/plugins/7zip/7za/spl/             # splthread.c (kept), 7za.def, VersionInfo.rc; main.cpp removed
src/plugins/7zip/vcxproj/7ZA/         # 7za.dll.vcxproj (+ props): new file list and defines
src/plugins/7zip/vcxproj/7zip.vcxproj, 7zip.props   # Z7_NO_UNICODE, 7za sources the plugin compiles
src/plugins/7zip/{7zclient,open,extract,update,FStreams,7zthreads,7zip,dialogs}.{h,cpp}
src/common/salarcname.h               # NEW: name cleaning + format detection (header-only)
src/saltests/saltests.cpp             # TestArcNames087
src/vcxproj/salamand.sln              # 7zwrapper removed
src/plugins/shared/baseaddr_*.txt     # 7zwrapper lines removed (not plugin ABI)
setup/tandemcommander.iss, build.cmd  # stale 7zwrapper.dll removal
doc/third_party.txt, CHANGELOG.md, PRIVACY.md (check), specs/NEXT-WORK.md,
specs/084-archiver-cleanup/{tasks,fix-log}.md, CLAUDE.md, architecture/04,09
```

**Structure Decision**: the existing layout. `src/plugins/shared/` holds
only the base-address table that changes (removing a project's line is not
an interface change; the plugin headers are untouched).

## Delivery stages (one commit each, independent review before the next)

1. **S1 Engine**: vendored tree replaced, `7za.dll` project rebuilt, Threads.c
   patch, `TC-PATCHES.md`; the plugin is ported just enough to compile
   (macros, wide `Load`) — 7z behaviour identical. Gate: Debug+Release build,
   engine probe on the 7z corpus.
2. **S2 Names**: `salarcname.h` + tests + the two call sites + alt-stream skip.
   Gate: saltests, hostile corpus through the driver.
3. **S3 RAR**: detection, volume callback, Unicode password, memory callback,
   read-only refusal, registration (config 4). Gate: engine probe over the 22
   RAR fixtures.
4. **S4 Removal**: 7zwrapper project/source/sln/baseaddr, installer and
   build-script cleanup.
5. **S5 Records**: licences, changelog, PRIVACY check, NEXT-WORK item 8,
   084 S7 records, CLAUDE.md, architecture docs; full gates.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|---|---|---|
| Replacing ~600 third-party files in one change | the engine is pinned to an upstream release; partial upgrades are not possible | keeping 16.04 leaves RCE CVEs in 7z/PPMd and blocks RAR |
