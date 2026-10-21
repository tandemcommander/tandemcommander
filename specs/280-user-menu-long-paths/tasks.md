# Tasks: User Menu on items in folders of 260 or more bytes - work, or refuse aloud

**Input**: Design documents from `specs/280-user-menu-long-paths/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/um-enumeration.md

**Tests**: saltests checks for the pure rules (CLAUDE.md working method) and the GUI probe
`probe/um280_probe.ps1` (measured before: 15 / 5).

## Phase 1: Setup

- [ ] T001 Record the measurement before (probe 15 / 5) and the sites at HEAD in specs/280-user-menu-long-paths/fix-log.md; keep probe/um280_probe.ps1 and probe/result_before.txt

## Phase 2: Foundational (blocking)

- [ ] T002 Create src/common/salumvalue.h with `SalUMCopyWhole(src, buf, size)`, `SalUMPathWithBackslash(path, buf, size)`, `SalUMJoinWhole(path, name, buf, size)` - whole or FALSE with `buf` empty, never cut (SalPathAppend / SalPathAddBackslash semantics for the separators)
- [ ] T003 Add `TestUserMenuValue280` to src/saltests/saltests.cpp (include the header, call it from main): fits / exactly 259 / 260 bytes, a 259-byte path ending with a backslash plus a name (refused, the negative of the lstrcpyn cut), roots `C:` / `C:\`, UTF-8 multi-byte at the edge, NULL / size 0
- [ ] T004 Change the enumeration contract in src/mainwnd.h: `UM_ITEM_TEXT_SIZE`, `UMNEXT_END/ITEM/TOOLONG`, `typedef int (*UM_GetNextFileName)(...)`, the comment; `GetNextFileFromPanel` returns int
- [ ] T005 Add `FullPathLeftTooLong`, `FullPathRightTooLong`, `FullPathInactiveTooLong`, `CompareName1TooLong`, `CompareName2TooLong` to `CUserMenuAdvancedData` in src/execute.h

## Phase 3: User Story 2 - A refusal comes before anything runs (P1)

**Goal**: whole values through the enumeration; a refused item stops everything before any
command runs (direct route too). **Independent test**: probe rows MIXDIRECT, MIXBAT, LNAME,
LDIRFOCUS, LDIRSEL, CONTROL.

- [ ] T006 [US2] `GetNextFileFromPanel` in src/mainwnd4.cpp: copy folder and name with `SalUMCopyWhole(..., UM_ITEM_TEXT_SIZE)`, `UMNEXT_TOOLONG` when a value does not fit; 225's refusal kept (returns `UMNEXT_END`)
- [ ] T007 [P] [US2] `GetNextItemFromFind` in src/finddlg1.cpp: the same (remove the "truncated here" comment)
- [ ] T008 [US2] `CMainWindow::UserMenu` in src/mainwnd4.cpp: item buffers on the heap (`CSalMaxPathBuffer`, low memory -> return before the batch file is made); after each `getNextFile` refuse with `IDS_TOOLONGNAME` (error, no other box) on `UMNEXT_TOOLONG` or a folder / name of `MAX_PATH` bytes or more, before the `firstItemDir` / `lastCdDir` copies
- [ ] T009 [US2] `CMainWindow::UserMenu` in src/mainwnd4.cpp: the route without a shell keeps each prepared command (command without outer quotes, arguments, initial folder, item folder) and starts them after the loop only when no error occurred; a launch failure shows the error and stops (as before)

## Phase 4: User Story 1 - No command acts on a cut path (P1)

**Goal**: `$(FullPathLeft/Right/Inactive)` whole or "too long name". **Independent test**: probe
rows FPRCUT, FPRLONG.

- [ ] T010 [US1] The User Menu command in src/mainwnd3.cpp: fill `FullPathLeft/Right` with `SalUMPathWithBackslash(panel->GetPath(), ..., MAX_PATH)` for disk panels; set the too-long flags (inactive flag from the inactive panel)
- [ ] T011 [P] [US1] `OnUserMenu` in src/finddlg1.cpp: the full-path flags FALSE
- [ ] T012 [US1] `CMainWindow::UserMenu` in src/mainwnd4.cpp: a used full-path variable that is empty shows `IDS_TOOLONGNAME` when its flag is set, else the "not defined" text as before

## Phase 5: User Story 3 - Compare names and the full-name list (P2)

**Goal**: "too long name" instead of the empty compare dialog; the panel's list of full names
whole. **Independent test**: probe rows CMPLONG, LISTFULL.

- [ ] T013 [US3] src/mainwnd3.cpp: `CompareName1/2` with `SalUMJoinWhole(..., MAX_PATH)`, the too-long flags set when a name does not fit (`CompareNamesReversed` as before)
- [ ] T014 [P] [US3] src/finddlg1.cpp `OnUserMenu`: the same for the Find results' compare names
- [ ] T015 [US3] `CMainWindow::UserMenu` in src/mainwnd4.cpp: swap the flags with the names; clear them with the names; refuse with `IDS_TOOLONGNAME` before the "files or folders" question and the dialog when a flag of a name not cleared is set
- [ ] T016 [US3] src/mainwnd3.cpp: `ListOfSelFullNames` built with `CSalPathBuf` Set + AppendComponent (both the selection and the focus branch), as the Find route

## Phase 6: Polish & checks

- [ ] T017 `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- [ ] T018 `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T019 Probe after on the hidden desktop -> 20 / 0; results in specs/280-user-menu-long-paths/probe/result_after.txt
- [ ] T020 Regression probes 226, 229, 234 on the hidden desktop; results in specs/280-user-menu-long-paths/probe/
- [ ] T021 Record measurements after, the commands and results in specs/280-user-menu-long-paths/fix-log.md; the Find route as a person's step

## Dependencies

- T002 -> T003, T006-T016; T004 -> T006-T009; T005 -> T010-T015.
- US2 (T006-T009) and US1 (T010-T012) and US3 (T013-T016) touch `UserMenu` in mainwnd4.cpp:
  done in sequence; finddlg1.cpp tasks [P] beside them.
- Phase 6 after all.

## Parallel examples

- T007, T011, T014 (finddlg1.cpp) beside the mainwnd4.cpp / mainwnd3.cpp tasks.

## Implementation strategy

MVP: Phase 2 + US1 (the cut path that runs a command on the parent folder), then US2, US3;
one build and one probe run at the end of each story when convenient.
