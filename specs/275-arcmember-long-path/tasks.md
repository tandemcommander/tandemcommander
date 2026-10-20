# Tasks: F3 / F4 take archive members whose path inside the archive has 520 bytes or more

**Input**: Design documents from `specs/275-arcmember-long-path/` (plan.md, spec.md, research.md,
data-model.md, contracts/arc-member-path.md, quickstart.md)

**Tests**: the spec's success criteria are a hidden-desktop probe (SC-001) and two regression
probes (SC-002); no new saltests rule (none is added - plan, *Structure Decision*).

## Phase 1: Setup

- [ ] T001 Write the probe `specs/275-arcmember-long-path/probe/arcmember275_probe.ps1` in the style of `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` (library `specs/098-long-path-overruns/probe/fix_probe_lib.ps1`, registry backed up / restored / verified, fixture under `%TEMP%\tc275`): rows VIEWCAP (ZIP, top-level member of 200 CJK letters + `.txt`, F3 -> viewer), VIEWDEEP (ZIP entry `<84 CJK>/<100 CJK>.txt`, panel at `a.zip\<folder>`, F3 -> viewer), EDITCAP (ZIP, the 604-byte member, F4, write new content, leave, update -> one member under the whole name with the new content), 7Z (`7z.exe a`, F3 -> viewer; NOT DRIVEN when 7z.exe is missing), TAR (a GNU tar built by the probe with a `././@LongLink` header, F3 -> viewer), OVERLIMIT (250 `a` + `.txt`, F3 -> "too long" message), CTL (`short.txt`, F3 -> viewer)

## Phase 2: Foundational (measure before)

- [ ] T002 Run the probe on the build of HEAD before any source change (hidden desktop, label `before`) into `specs/275-arcmember-long-path/probe/result_before.txt`; expected: VIEWCAP, VIEWDEEP, EDITCAP, 7Z, TAR FAIL with the 520-byte message, OVERLIMIT and CTL PASS; record in `specs/275-arcmember-long-path/fix-log.md`

## Phase 3: User Story 1 - View a member with a long path inside the archive (P1)

**Goal**: F3 opens the viewer for a member whose path inside the archive has 520+ bytes.
**Independent Test**: probe rows VIEWCAP, VIEWDEEP, 7Z, TAR, OVERLIMIT, CTL.

- [ ] T003 [US1] Remove feature 095's `>= 2 * MAX_PATH` test of the path inside the archive in `CFilesWindow::ViewFile` (F3) in `src/fileswn5.cpp`; keep the heap copy `nameInArchiveBuf` (the key may get a `:0x<pointer>` suffix); comment with feature 275
- [ ] T004 [US1] Change row ARCCAP of `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` to expect the viewer (and its description comment), and add a pointer to 275 in `specs/260-archive-cache-long-names/contracts/cache-tmp-path.md`

## Phase 4: User Story 2 - Edit such a member (P2)

**Goal**: F4 / Enter edit a member with a 520+ byte path and pack the edit back under the whole name.
**Independent Test**: probe row EDITCAP.

- [ ] T005 [US2] Remove the same test in `CFilesWindow::ExecuteFromArchive` (F4 / Enter) in `src/fileswn6.cpp`; comment with feature 275

## Phase 5: User Story 3 - An archiver that cannot take the path refuses it (P3)

**Goal**: the CAB plug-in never cuts the path inside the cabinet.
**Independent Test**: by reading (no real cabinet can hold such a path).

- [ ] T006 [P] [US3] In `CPluginInterfaceForArchiver::UnpackOneFile` in `src/plugins/uncab/uncab.cpp`, refuse `nameInArchive` of `U8_MAX_CAB_NAME` bytes or more with `Error(IDS_TOOLONGNAME)` before it is copied into `rootDir` (no `lstrcpyn` cut)

## Phase 6: Polish & verification

- [ ] T007 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T008 `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED` (core and uncab.spl rebuilt)
- [ ] T009 `saltests.exe` -> `saltests: <n> checks, 0 failed`
- [ ] T010 Run the probe on the new build (label `after`) into `specs/275-arcmember-long-path/probe/result_after.txt`: every row PASS (or NOT DRIVEN recorded)
- [ ] T011 Regressions: feature 260's probe (ARCCAP now viewer) into `specs/275-arcmember-long-path/probe/regress_260.txt` and feature 222's probe into `specs/275-arcmember-long-path/probe/regress_222.txt` -> all PASS
- [ ] T012 Record before / after, the commands and their results in `specs/275-arcmember-long-path/fix-log.md`; file the Inbox items found on the way (unchm overflow, tar PAX headers) with source `measure:275`

## Dependencies

T001 -> T002 -> (T003, T005, T006) -> T007 -> T008 -> T009 -> T010 -> T011 -> T012. T004 with T003.
T006 is independent of T003 / T005 (another project).

## Parallel example

T003, T005 (two core files) and T006 (the plug-in) can be edited in parallel after T002.

## Implementation strategy

MVP = User Story 1 (F3). US2 is the same one-line removal in F4; US3 is a hardening of one shipped
plug-in. All are verified together by one build and one probe run.
