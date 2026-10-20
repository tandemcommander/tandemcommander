# Implementation Plan: SFTP upload into drop folders, the limits of a replacement, left temporary files

**Branch**: `258-sftp-drop-folder-upload` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/258-sftp-drop-folder-upload/spec.md`

## Summary

Three changes in the SFTP plug-in's upload (`src/plugins/sftp/operats.cpp`, feature 139's
`UploadOneFileImpl` and helpers), each from the backlog item:

1. **Drop route**: when the `lstat` of the target is refused with a permission status on a live
   session, the file is created only by an exclusive create under its own name (never opened
   over an existing file), sent, closed; the size is confirmed by `stat` where the server
   allows it, else by the server's acknowledgments of every byte and of the close (this second
   confirmation applies to every route). A failed drop upload removes its partial file once and
   says if it stays.
2. **Statement of the limits**: the overwrite question names hard links, ACL and extended
   attributes.
3. **Left temporary files**: a `.tcpart-*` whose removal failed because the connection was lost
   is remembered on the session (memory only); the next upload on that session offers to delete
   the remembered files (checked to be regular files and named like ours first).

Pure decisions go to `sftputils.cpp/.h` with checks in the plug-in's harness
(`src/plugins/sftp/test/harness.cpp`, run by `build_and_run.cmd`). Proof: the GUI probe
`probe/sftp258_probe.ps1` with the local test server `probe/dropsftp.py` (drop, cut, plain
folders), plus 133's whole SFTP probe on the OpenSSH container as regression.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: vendored libssh2 1.11.1 (WinCNG); the plug-in's `CSFTPSession`  
**Storage**: none (the left-file record is memory only, per session)  
**Testing**: plug-in harness (`test/build_and_run.cmd`), GUI probe on the hidden desktop, 133's
probe against container `tandem-sftp`; `saltests` unaffected (no core change)  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`sftp.spl`)  
**Performance Goals**: no extra request on the ordinary route (the drop route adds none either:
it replaces the temp + rename with one exclusive create)  
**Constraints**: plug-in ABI untouched; no new UI strings (English literals as 139); 139's
rule "old content never gone before the new one is whole" kept on every route  
**Scale/Scope**: one source file mainly (`operats.cpp`), `session.h/.cpp` (record),
`sftputils.cpp/.h` (pure helpers), harness

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency in the product; the probe's server needs Python + paramiko on the test machine only |
| II Backward compatibility | ordinary uploads unchanged (133/139 rows); the drop route only where the item failed before |
| III Incremental modernization | changes confined to the upload of one plug-in |
| IV Windows commitment | n/a |
| V Plugin architecture | no interface change, `LAST_VERSION_OF_SALAMANDER` untouched |
| VI UI consistency | one longer question, one new Yes/No question, in the plug-in's existing box style (`SalMessageBox`, English literals as 139) |

Gate: pass. Re-checked after design: pass.

## Project Structure

### Documentation (this feature)

```text
specs/258-sftp-drop-folder-upload/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/upload-routes.md   # the upload's routes and what each leaves (139's table, extended)
├── fix-log.md, closing-report.md
└── probe/  sftp258_probe.ps1, dropsftp.py, result_*.txt
```

### Source Code

```text
src/plugins/sftp/
├── operats.cpp     # UploadOneFileImpl drop route, UploadSendAndConfirm, UploadDropTemp record,
│                   # ConfirmOverwriteRemote text, SFTPUploadToFS offer
├── session.h/.cpp  # left temporary files of the session (record, take, free)
├── sftputils.h/.cpp# SftpTargetStatRefused, SftpUploadConfirmation, SftpIsUploadTempPath
└── test/harness.cpp# checks of the three helpers
```

**Structure Decision**: plug-in only; nothing in the core or `src/common/`.

## Complexity Tracking

None.
