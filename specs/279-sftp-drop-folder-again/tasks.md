# Tasks: SFTP - a folder uploaded again into an upload-only folder

**Input**: Design documents from `specs/279-sftp-drop-folder-again/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/unconfirmed-folder.md, quickstart.md

**Tests**: the spec asks for harness checks (SC-005) and probe rows (SC-001..SC-004).

## Phase 1: Setup

- [X] T001 Start `specs/279-sftp-drop-folder-again/fix-log.md` with the measurement before (3541e7ad, 258's probe rows DROPDIR / DROPDIR2 / DROPHOLE)
- [X] T002 [P] Copy `specs/258-sftp-drop-folder-upload/probe/dropsftp.py` to `specs/279-sftp-drop-folder-again/probe/dropsftp.py` and make `NotADirectoryError` answer SSH_FX_NO_SUCH_FILE (OpenSSH's ENOTDIR mapping; research R5)

## Phase 2: Foundational (the pure rules)

- [X] T003 Add `SftpUnconfirmedDir`, `SftpEndsUnconfirmedDir`, `CSftpUnconfirmedDirVerdict` + `SftpUnconfirmedDirVerdict` to `src/plugins/sftp/sftputils.h` / `src/plugins/sftp/sftputils.cpp` (contract table "Pure rules")
- [X] T004 Add checks with the negatives of the contract to `src/plugins/sftp/test/harness.cpp`; run `src/plugins/sftp/test/build_and_run.cmd` -> 0 failed

## Phase 3: User Story 1 - a folder uploaded again arrives (P1)

**Goal**: an unconfirmed folder's files are uploaded. **Independent test**: probe rows DROPDIR2, DROPAGAIN.

- [X] T005 [US1] `CUploadItemNote` and its passing: `UploadOneFile` / `UploadOneFileImpl` set `Arrived` before `UploadFinishMove` (both routes); `UploadDirRecursive` / `UploadDirLevel` take the note, in `src/plugins/sftp/operats.cpp`
- [X] T006 [US1] `UploadDirLevel`: after a refused `mkdir`, `StatEx` (followed); B2 folder -> as today; B4 (`SftpUnconfirmedDir`) -> unconfirmed level, log line; B5 -> today's box, in `src/plugins/sftp/operats.cpp`
- [X] T007 [US1] The loop of an unconfirmed level passes a note to every item (`QuietNoFolder` = nothing confirmed yet), counts `Arrived`, in `src/plugins/sftp/operats.cpp`

## Phase 4: User Story 2 - nothing confirmed: the local folder is kept (P1)

**Goal**: FR-004..FR-007. **Independent test**: probe rows DROPHOLE, DROPEMPTY, DROPHOLE2, OSSHLINK, OSSHLINK2.

- [X] T008 [US2] `UploadDropRoute` and the temporary-file create of `UploadOneFileImpl`: a creation refused with 2 / 10 under `QuietNoFolder` -> no box, `NoFolder`, log line; a subfolder's `mkdir` refused so under `QuietNoFolder` -> the same, in `src/plugins/sftp/operats.cpp`
- [X] T009 [US2] End of an unconfirmed level: stop on `NoFolder`; after Cancelled / list error / `StopIfSessionLost` the verdict: `udNotThere` / `udNothingConfirmed` -> one `IDS_ERR_MKDIR` box with the contract's tail, xrFailed (local kept); `udConfirmed` -> today's Move rule; the level's own `Arrived`, in `src/plugins/sftp/operats.cpp`
- [X] T010 [US2] Build (`.\build.cmd`), no warning in the SFTP sources; encoding guard `python tools/check_encoding.py --strict` -> TOTAL 0

## Phase 5: Probes and regressions

- [X] T011 Write `specs/279-sftp-drop-folder-again/probe/sftp279_probe.ps1` (style of 258's probe; rows DROPDIR, DROPDIR2, DROPAGAIN, DROPHOLE, DROPEMPTY, DROPHOLE2 on the drop server; OSSHCTL, OSSHLINK, OSSHLINK2 on `tandem-sftp`) and `specs/279-sftp-drop-folder-again/probe/fixture279.sh` (prepared as root: a root 0700 folder and a link to it; state; clean)
- [X] T012 Run the probe on the build of 3541e7ad (before: `probe/result_before.txt`) and on the feature build (`probe/result_after.txt`): every row PASS, registry identical
- [X] T013 Negative control: the verdict's zero-confirmed branch disabled (marked NEGATIVE CONTROL), rebuilt, rows DROPEMPTY / DROPHOLE must FAIL (`probe/result_negative.txt`); code restored, rebuilt
- [X] T014 Regressions: 258's probe without DROPDIR2 (`probe/regress_258.txt`), 133's probe on the container (`probe/regress_133.txt`) - the counts of before

## Phase 6: Polish

- [X] T015 `fix-log.md`: after, the checks with numbers, the limits (box per file on a refused right - research R3)
- [X] T016 Note in `specs/258-sftp-drop-folder-upload/probe/sftp258_probe.ps1`'s header that DROPDIR2 records the limit 279 removed (the row is superseded by 279's)

## Dependencies

T001, T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011 -> T012 -> T013 -> T014 -> T015, T016.
US2 builds on US1 (the same function); both are P1 and shipped together.

## Parallel opportunities

T002 with T001; T011 (probe writing) can start once T009's behaviour is fixed, while the build runs.

## Implementation strategy

One increment: the rules first (harness), then the level, then the probes; the negative control proves the rows detect the review-2 defect.
