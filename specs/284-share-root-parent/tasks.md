# Tasks: The parent of a share's root offers the server's shares

**Input**: `specs/284-share-root-parent/` - plan.md, spec.md, research.md, data-model.md,
contracts/share-root-rule.md, quickstart.md
**Tests**: the pure rule gets `saltests` checks (project rule: pure decisions in `src/common/` with
checks); the behaviour is checked by the probe `probe/shareroot_probe.ps1`.

## Phase 1: Setup

- [X] T001 Keep the measurement probe and its before result in specs/284-share-root-parent/probe/ (shareroot_probe.ps1, result_before.txt) and record the measurement in specs/284-share-root-parent/fix-log.md; add rows P1 (the *Parent directory* command 822) and N1 (Backspace, seam list with no folder share -> one "share name is missing" box naming `\\localhost\`, location unchanged)

## Phase 2: Foundational (blocks every story)

- [X] T002 Add `SalUncShareRootServerPath(path, serverPath, serverPathSize)` to src/common/saluncserver.h exactly as contracts/share-root-rule.md says (header comment list updated; never cut, refuse)
- [X] T003 Add `TestUncShareRoot284()` to src/saltests/saltests.cpp covering every row of contracts/share-root-rule.md (incl. the exact-fit / one-byte-short buffer, NULL buffer, UTF-8 names) and call it next to `TestUncServer125()`
- [X] T004 List the `..` entry in a share's root also without a Network plug-in: in `CFilesWindow::ReadDirectory` (src/fileswn3.cpp) the `!upDir && GetFirstNethoodPluginFSName()` test also passes when `SalUncShareRootServerPath(GetPath(), ...)` is TRUE (`UNCRootUpDir = TRUE`, no FindFirstFile); include saluncserver.h

## Phase 3: User Story 1 - Backspace / `..` in a share's root offers the shares (P1)

**Independent test**: probe rows B1, D1, X1, E1.

- [X] T005 [US1] In `CFilesWindow::Execute`, the `..` branch at a root (src/fileswn2.cpp): when the plug-in test is FALSE and `SalUncShareRootServerPath(GetPath(), ...)` is TRUE, call `ChangeDir(serverPath)` before `EndStopRefresh(); return;`; include saluncserver.h

## Phase 4: User Story 2 - Go to root in a share's root offers the shares (P2)

**Independent test**: probe rows G1, S2.

- [X] T006 [US2] In `CFilesWindow::GotoRoot` (src/fileswn1.cpp): plug-in route first as now; else, when `SalUncShareRootServerPath(GetPath(), ...)` is TRUE, `ChangeDir(serverPath)`; else the old `GetRootPath` + `ChangePathToDisk`; include saluncserver.h

## Phase 5: User Story 3 - `..` of a share's root in the other panel (P3)

**Independent test**: probe row O1.

- [X] T007 [US3] In `CFilesWindow::OpenFocusedInOtherPanel` (src/fileswn8.cpp): for `..` on a UNC root without the plug-in, when `SalUncShareRootServerPath(buff, ...)` is TRUE, the location handed to the other panel is `serverPath` (not `\\server\share\..`); include saluncserver.h

## Phase 5b: A consumer of the new `..` (found while enumerating them)

- [X] T013 [US1] Dropping onto the `..` of a share's root without the plug-in: `GetCurrentDir` (src/shellsup.cpp) returns no target (stop cursor) instead of `\\server\`; include saluncserver.h. Drag and drop cannot be driven on the hidden desktop: NOT DRIVEN, a person step

## Phase 6: Polish & verification

- [X] T008 Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T009 Build `build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed` (record the check counts before / after)
- [X] T010 Probe `shareroot_probe.ps1 -Expect fixed` on the hidden desktop -> every row PASS (B1 P1 G1 D1 O1 X1 E1 N1 S1 S2 L1); result into specs/284-share-root-parent/probe/result_after.txt; negative control: `-Expect fixed` run on the unchanged build (before T002) into probe/result_negative.txt must FAIL B1 P1 G1 D1 O1 X1 E1 N1
- [X] T011 Check that no UI string was added (`git diff main...` of `*.rc*` / `lang` empty), no seam string was added (the seam is 125's), and that at every changed site the Network plug-in test still comes first and its branch is byte-for-byte unchanged (FR-005, code reading of the diff)
- [X] T012 Record before / after, commands and results in specs/284-share-root-parent/fix-log.md

## Dependencies

T001 -> T002 -> T003; T002 -> T004 -> T005 (D1 needs the `..` entry); T002 -> T006; T004 -> T007;
T005-T007 -> T008-T012. US1, US2, US3 are independent of each other after Phase 2 (different
files: fileswn2.cpp, fileswn1.cpp, fileswn8.cpp).

## Parallel opportunities

T005, T006, T007 touch different files and can be written in parallel after T004.

## Implementation strategy

MVP = Phase 2 + US1 (the `..` entry and Backspace). US2 and US3 follow; the probe covers all.
