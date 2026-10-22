# Tasks: FTP panel Create Directory and Quick Rename update the upload listing cache

**Input**: `specs/302-ftp-upload-cache-args/` - plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: the hidden-desktop probe is the test (spec SC-001..SC-003); no `saltests` rule (plan:
no pure decision).

## Phase 1: Setup

- [X] T001 Write the probe `specs/302-ftp-upload-cache-args/probe/ftp302_probe.ps1` in the style of `specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1` (registry backup / restore, fixture under `%TEMP%\tc302`, one `ftpmini.py` UTF-8 server on 127.0.0.1, rows `MKD-ABS` and `REN-UP`, dialogs of the operation threads left alone)

## Phase 2: Foundational (measure before the fix)

- [X] T002 Run the probe on the unchanged build (`build\tandemcommander\Debug_x64`) -> `specs/302-ftp-upload-cache-args/probe/result_before.txt`; expected `MKD-ABS` FAIL (`MKD new` sent), `REN-UP` PASS (masked by reading - measured: FAIL, see fix-log); record in `specs/302-ftp-upload-cache-args/fix-log.md`

## Phase 3: User Story 1 - a folder created from the panel is known to a running upload (P1)

**Goal**: Create Directory reports to the right server's cache. **Independent test**: row `MKD-ABS`.

- [X] T003 [US1] Pass `(userBuffer, hostBuf, portBuf, ...)` to both `UploadListingCache.ReportCreateDirs` calls of `CControlConnectionSocket::CreateDir` in `src/plugins/ftp/ctrlcon5.cpp`

## Phase 4: User Story 2 - a renamed file is not overwritten without the question (P2)

**Goal**: Quick Rename reports to the right server's cache. **Independent test**: row `REN-UP`.

- [X] T004 [US2] Pass `(userBuffer, hostBuf, portBuf, ...)` to both `UploadListingCache.ReportRename` calls of `CControlConnectionSocket::QuickRename` in `src/plugins/ftp/ctrlcon5.cpp`

## Phase 5: Polish & verification

- [X] T005 Build (`.\build.cmd`) -> `BUILD SUCCEEDED`; encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T006 Run the probe on the fixed build -> `specs/302-ftp-upload-cache-args/probe/result_after.txt`; expected every row PASS
- [X] T007 Regression: `specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1` -> `specs/302-ftp-upload-cache-args/probe/regress_288.txt` (20 / 0 as recorded by 288)
- [X] T008 Record before / after, commands and results in `specs/302-ftp-upload-cache-args/fix-log.md`

## Dependencies

T001 -> T002 -> T003, T004 (same file, sequential) -> T005 -> T006, T007 -> T008. US1 and US2 are
independent of each other in behaviour; they share one file.

## Implementation strategy

MVP = US1 (the visible case). US2 is the same one-line kind of fix; both land in one commit.
