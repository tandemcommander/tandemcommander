# Implementation Plan: SFTP - a folder uploaded again into an upload-only folder

**Branch**: `279-sftp-drop-folder-again` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/279-sftp-drop-folder-again/spec.md`

## Summary

A folder of an upload whose creation the server refuses with FAILURE / FILE_ALREADY_EXISTS and
whose existence it refuses to show (a permission status on a live session) becomes an
*unconfirmed folder*: its items are uploaded (files through 258's drop route, the exclusive
create), and the folder counts the items the server confirmed. Zero confirmed = the folder fails
with one box naming it and a Move keeps it; while nothing is confirmed, an item whose creation is
refused with "no such file / path" ends the folder without a box of its own (one box naming the
folder). The rules are pure functions in `sftputils` with checks in the plug-in's harness; the
counting lives in `UploadDirLevel`, fed by a small note each item returns.

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI; the SFTP plug-in (`src/plugins/sftp`, libssh2)  
**Primary Dependencies**: libssh2 (vendored), the plug-in's `CSFTPSession`  
**Storage**: N/A  
**Testing**: the plug-in's rule harness (`src/plugins/sftp/test/build_and_run.cmd`, 239 checks at 258); GUI probe on the hidden desktop against `dropsftp.py` (paramiko, 127.0.0.1) and the OpenSSH container `tandem-sftp` (localhost:2222); 258's probe and 133's probe as regressions  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`.spl`)  
**Performance Goals**: no extra request for an ordinary upload (the new branch runs only after a refused `mkdir`)  
**Constraints**: no new UI strings (English reasons appended to the existing "Cannot create directory" text, as 258); no plug-in interface change; a Move never removes what the server did not confirm  
**Scale/Scope**: one function of `operats.cpp` (`UploadDirLevel`) plus the item note through `UploadOneFile` / `UploadOneFileImpl` / `UploadDropRoute` / `UploadDirRecursive`; 3 pure rules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency, no project change | PASS |
| II. Backward compatibility | every refusal other than the new pair keeps today's behaviour (FR-002); no stored data, no registry, no plug-in ABI change | PASS |
| III. Incremental modernization | a local change inside the plug-in, pure rules tested | PASS |
| IV. Windows commitment | unchanged | PASS |
| V. Plugin architecture | no `spl_*.h` change, `LAST_VERSION_OF_SALAMANDER` untouched | PASS |
| VI. UI consistency | the existing message box and string, a reason appended | PASS |
| CLAUDE.md data rules | a Move removes only what the server confirmed (fails closed: zero confirmed = kept) | PASS |

Post-design re-check: PASS (no change of the above).

## Project Structure

### Documentation (this feature)

```text
specs/279-sftp-drop-folder-again/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/unconfirmed-folder.md
├── fix-log.md
├── probe/ (sftp279_probe.ps1, dropsftp.py copy, fixture279.sh, results)
└── tasks.md
```

### Source Code

```text
src/plugins/sftp/
├── sftputils.h / sftputils.cpp   # SftpUnconfirmedDir, SftpEndsUnconfirmedDir, SftpUnconfirmedDirVerdict
├── operats.cpp                   # CUploadItemNote; UploadDirLevel; the note through the upload chain
└── test/harness.cpp              # checks of the three rules (with negatives)
```

**Structure Decision**: the plug-in's existing files only; the probe in the feature folder.

## Complexity Tracking

None.
