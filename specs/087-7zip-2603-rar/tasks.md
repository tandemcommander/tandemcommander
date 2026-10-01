# Tasks: 7-Zip engine 26.03 and RAR out of the box (087)

**Input**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/{engine-build,plugin-engine,item-names}.md`, `quickstart.md`
**Tests**: requested (FR-013 unit tests; SC-001–SC-003 measured by the engine probe).
**Protocol**: 069 fix protocol — independent review before each stage's commit.
Stages map to plan "Delivery stages" S1–S5.

## Phase 1: Setup

- [X] T001 Record the baseline in specs/087-7zip-2603-rar/fix-log.md: HEAD, the verified source archive and SHA-256, the inventory of 16.04 local patches (research R6), today's 7z behaviour notes
- [X] T002 Write the engine driver specs/087-7zip-2603-rar/probe/7zdrive.cpp (commands: `formats`, `list`, `extract <dir>`, `test`, `-p<password>`, volume callback, `create` via IOutArchive, `make-hostile`), its build script build_7zdrive.cmd (cl, against a given 7za tree and DLL) and run_engine_probe.cmd (fixtures vs `7z.exe` reference); run it against the **current 16.04** DLL to record the baseline (7z corpus passes, RAR not reachable)

## Phase 2: Foundational — the engine (S1, blocks every story)

- [X] T003 Replace src/plugins/7zip/7za/ with the 26.03 subset per contracts/engine-build.md E1; delete src/plugins/7zip/patch/; keep and update spl/ (splthread.c, 7za.def, VersionInfo.rc), drop spl/main.cpp and spl/splthread.cpp
- [X] T004 Apply the call-stack patch in src/plugins/7zip/7za/C/Threads.c (E4) and write src/plugins/7zip/7za/TC-PATCHES.md (source, hash, every patch with reason, retired 16.04 patches with reason — R6)
- [X] T005 Rewrite src/plugins/7zip/vcxproj/7ZA/7za.dll.vcxproj (+ 7za_base/_debug/_release.props, .filters if present): file list E2, defines, no asm, def file, resources
- [X] T006 Port the plugin to compile against 26.03: Z7_NO_UNICODE in src/plugins/7zip/vcxproj/7zip.props; the 7za sources compiled by src/plugins/7zip/vcxproj/7zip.vcxproj; callback classes to Z7 macros in src/plugins/7zip/{open,extract,update,FStreams}.h/.cpp; wide engine path in src/plugins/7zip/7zclient.cpp; times through CPropVariant (P2)
- [X] T007 Build Debug + Release (7za, 7zip); run the engine probe on the 7z corpus with the new DLL (same results as T002 baseline); `formats` = 7z, Rar, Rar5; wrong-password 7z extraction fails (FR-007 — decides whether the "JRY FIX" is needed)
- [X] T008 Independent review of S1; fix; commit `[087] S1 …`

## Phase 3: User Story 3 — extraction never writes outside the folder (P1) (S2)

- [X] T009 [US3] Create src/common/salarcname.h: `SalArcCleanItemPath`, `SalArcDetectFormat`, `SalArcIsRarExtension`, `SalArcRarVolumeIndex` per contracts/item-names.md
- [X] T010 [US3] Add `TestArcNames087` (N5 corpus) in src/saltests/saltests.cpp; build; 0 failed
- [X] T011 [US3] Apply cleaning at listing (`AddFileDir`, skip `kpidIsAltStream`) in src/plugins/7zip/7zclient.cpp and at `GetStream` in src/plugins/7zip/extract.cpp
- [X] T012 [US3] `7zdrive make-hostile` builds probe/hostile/*.7z (`..\..\x`, `C:\x`, `\\srv\x`, `a:b`, `con`, `x.`); extracting them through the driver's copy of the plugin rules shows no escape; record; independent review; commit `[087] S2 …`

## Phase 4: User Story 1 — RAR out of the box (P1) (S3)

- [X] T013 [US1] Open by detected format (P1) in src/plugins/7zip/7zclient.cpp: read the first 8 bytes, `SalArcDetectFormat`, CLSID table; unsupported signature → existing error
- [X] T014 [US1] Volume callback (P3) in src/plugins/7zip/open.h/.cpp: expose `IArchiveOpenVolumeCallback`, `GetProperty(kpidName)`, `GetStream(name)` wide, `S_FALSE` when missing
- [X] T015 [US1] Unicode password (P4): wide prompt in src/plugins/7zip/dialogs.cpp/.h, UTF-16 `CryptoGetTextPassword` in src/plugins/7zip/open.cpp and extract.cpp, session password wiped on close
- [X] T016 [US1] Memory bound (P5): `IArchiveRequestMemoryUseCallback` in the open and extract callbacks (src/plugins/7zip/open.*, extract.*)
- [X] T017 [US1] Read-only RAR (P7) in src/plugins/7zip/7zclient.cpp / 7zip.cpp update and delete entry points
- [X] T018 [US1] Registration and migration (P8) in src/plugins/7zip/7zip.cpp: CURRENT_CONFIG_VERSION 4, `rar` panel archiver and unpacker mask, gated on `< 4`
- [X] T019 [US1] New strings (if any) in src/plugins/7zip/7zip.rc2 / .rh2 with never-used IDs; translations in translations/<lang>/7zip.slt via the merge tool (gap check)
- [X] T020 [US1] Build; engine probe over all 22 RAR fixtures (list + extract vs 7z.exe; encrypted with the fixture passwords; volumes; damaged; missing volume; memory refusal); independent review; commit `[087] S3 …`

## Phase 5: User Story 2 — 7z keeps working (P1)

- [X] T021 [US2] 7z regression through the driver: archives of a 16.04-built DLL (T002 outputs) read by 26.03 and vice versa; encrypted IV length 16 (R3); results in fix-log (covered by T007/T020 runs, recorded here as the US2 evidence)

## Phase 6: User Story 4 — leaner engine, no dead helper (P2) (S4)

- [X] T022 [US4] Remove 7zwrapper: src/plugins/7zip/vcxproj/7zwrapper/, its project entry in src/vcxproj/salamand.sln, the reference in src/plugins/7zip/vcxproj/7zip.vcxproj, src/plugins/shared/baseaddr_x86.txt / baseaddr_x64.txt lines
- [X] T023 [US4] Stale-file removal: setup/tandemcommander.iss `[Code]` at ssPostInstall (next to salmon.exe), build.cmd output-tree cleanup (next to the salmon.exe line)
- [X] T024 [US4] Licence: doc/third_party.txt (7-Zip 26.03, LGPL-2.1+, unRAR restriction, years), src/plugins/7zip/7za/DOC kept; build; independent review; commit `[087] S4 …`

## Phase 7: User Story 5 — engine threads in crash reports (P3)

- [X] T025 [US5] Debug check that every engine thread passes the trampoline (TRACE in splthread.c under _DEBUG or a breakpoint count during a multi-threaded pack/extract via the driver); record in fix-log

## Phase 8: Polish & records (S5)

- [X] T026 Full gates: `build.cmd` Debug, `build.cmd full release`, saltests, check_encoding, runtime closure, `git diff src/plugins/shared/*.h` empty, performance check SC-005 (driver listing 10,000-item 7z, old vs new DLL)
- [X] T027 [P] CHANGELOG.md *Unreleased*; PRIVACY.md check (expected: no change — record why); specs/NEXT-WORK.md item 8 done; specs/084-archiver-cleanup/tasks.md S7 tasks marked with the 087 evidence; CLAUDE.md (Missing deps, project count, Recent Changes); architecture/04-dependencies.md, 09-plugin-catalog.md
- [X] T028 Final independent review of the records against the code; complete fix-log; commit `[087] Records …`

## Dependencies

S1 (T003–T008) blocks everything. S2 (T009–T012) and S3 (T013–T020) both
touch 7zclient.cpp — S2 first. S4 independent of S2/S3 after S1. T025
after S1. Records last.

## Parallel opportunities

T002 (driver) alongside T003–T005; T009/T010 (header + tests) alongside
T006; T022–T024 alongside S3 (different files); T027 split across files.

## Implementation strategy

MVP = S1 (the security upgrade on its own, 7z unchanged) + S2 (the path
defect). S3 delivers RAR. S4/S5 complete the feature. Every stage leaves a
building, working product.
