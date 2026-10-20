# Tasks: SFTP upload into drop folders, the limits of a replacement, left temporary files

**Input**: `specs/258-sftp-drop-folder-upload/` - plan.md, spec.md, research.md, data-model.md,
contracts/upload-routes.md, quickstart.md
**Tests**: the plug-in harness (pure rules) and the GUI probe are required by the project's
working method (measure first, probe rows before / after).

## Phase 1: Setup

- [ ] T001 Keep the probe and the test server in `specs/258-sftp-drop-folder-upload/probe/` (`sftp258_probe.ps1`, `dropsftp.py`, `result_before.txt`) and check that `python -c "import paramiko"` works

## Phase 2: Foundational (pure rules, used by all stories)

- [ ] T002 Add `SftpTargetStatRefused`, `SftpUploadConfirmation` (enum `CSftpUploadConfirm`: `ucNo`, `ucBySize`, `ucByAcks`) and `SftpIsUploadTempPath` to `src/plugins/sftp/sftputils.h` and `src/plugins/sftp/sftputils.cpp`
- [ ] T003 Add harness checks for the three helpers (with negative cases: status 0, not connected, sizes that differ, names with upper-case or 7 / 9 hex digits, a path whose directory part looks like a temp) in `src/plugins/sftp/test/harness.cpp`; run `src/plugins/sftp/test/build_and_run.cmd`

## Phase 3: User Story 1 - Upload into a drop folder (P1)

**Goal**: Copy / Move / folder Copy into a folder whose files the server will not show.
**Independent test**: probe rows DROPNEW, DROPEXIST, DROPMOVE, DROPDIR.

- [ ] T004 [US1] In `UploadSendAndConfirm` (`src/plugins/sftp/operats.cpp`) confirm by `StatEx` + `SftpUploadConfirmation`; `ucByAcks` logs one line ("the server does not show the size ... acknowledged N bytes")
- [ ] T005 [US1] In `UploadOneFileImpl` (`src/plugins/sftp/operats.cpp`) take the drop route when `StatEx(target)` = sxError and `SftpTargetStatRefused`: log, `CheckCancel`, `OpenWriteNew(target)` (no fallback), refused -> box with the reason + "the server does not show whether a file of that name exists; nothing was replaced"; send + confirm; failure / stop -> `Unlink` once, the box names a partial file that stays (contract D1-D4)
- [ ] T006 [US1] Rebuild (`build.cmd`) and run the probe rows DROP* on the hidden desktop

## Phase 4: User Story 2 - The limits of a replacement are stated (P2)

**Independent test**: probe row REPL.

- [ ] T007 [US2] Extend the question text of `ConfirmOverwriteRemote` in `src/plugins/sftp/operats.cpp` (hard links keep the old content; ACL and extended attributes not carried over)

## Phase 5: User Story 3 - Left temporary files are offered for removal (P3)

**Independent test**: probe row CUT.

- [ ] T008 [US3] Add the record to `CSFTPSession` (`LeftTemps[16]`, `LeftTempCount`, `NoteLeftTemp`, `TakeLeftTemps`; freed in the destructor, kept by `Disconnect`) in `src/plugins/sftp/session.h` and `src/plugins/sftp/session.cpp`
- [ ] T009 [US3] Record in `UploadDropTemp` (`src/plugins/sftp/operats.cpp`) when the unlink failed and the session is no longer connected (never for kept temps - they do not pass through it)
- [ ] T010 [US3] At the start of `SFTPUploadToFS` (`src/plugins/sftp/operats.cpp`), on a connected session, take the record and ask (Yes / No, English literal, list of base names with their folder); Yes: per file `StatEx` lstat -> regular file and `SftpIsUploadTempPath` -> `Unlink`; failures logged and named in one box
- [ ] T011 [US3] Look at the CUT row's second Copy that showed no dialog before; adjust the probe if it is the probe's fault (`specs/258-sftp-drop-folder-upload/probe/sftp258_probe.ps1`)

## Phase 6: Polish

- [ ] T012 `python tools/check_encoding.py --strict` -> TOTAL 0; `build.cmd` -> BUILD SUCCEEDED; harness green
- [ ] T013 Probe after (`probe/result_after.txt`): all rows PASS; regression: 133's SFTP probe on the container (`probe/regress_133.txt`)
- [ ] T014 Negative control: revert one fix in a scratch build or reason from `result_before.txt`, record in `fix-log.md`
- [ ] T015 Update `specs/258-sftp-drop-folder-upload/fix-log.md` (after measurements, decisions, limits)
- [ ] T016 CHANGELOG entry under the `— unreleased` heading in `CHANGELOG.md`

## Dependencies

T002-T003 before every story. US1 (T004-T006) first (MVP). US2 (T007) independent. US3 (T008-T011)
after T002. Polish last. T007 and T008 can run in parallel with US1 work in other functions, but
all touch `operats.cpp`: done in sequence.

## Implementation strategy

MVP = US1 (the failing function). Then US2 (one text), US3 (record + offer). One build and one
probe run cover all three.
