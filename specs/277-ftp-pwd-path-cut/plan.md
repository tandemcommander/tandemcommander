# Implementation Plan: FTP - a PWD reply or a created folder path that does not fit is never cut and used

**Branch**: `277-ftp-pwd-path-cut` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/277-ftp-pwd-path-cut/spec.md`

## Summary

The FTP plug-in refuses, instead of cutting, every server path or name of the item that does not
fit its buffer. The PWD / 257 reply's path extraction moves into a pure header-only rule
(`src/common/salftppwd.h`, `SalFtpPathFromPwdReply`, checked by `saltests`) that reads only within
the reply's size, accepts a path that fills the buffer exactly and fails (instead of cutting) in
all three forms; the plug-in's conversion of a legacy server's path to UTF-8 fails when the result
does not fit. The created-folder report walks a name that does not fit in heap buffers and only
invalidates listings; `FTPCompleteAbsolutePath` and `FTPAS400CutFileNamePart` fail instead of
cutting; the opened-file lock compares names by `SalNameOrderEqualCI`; the upload's link size is
skipped when the source path does not fit. Measured by `probe/ftp277_probe.ps1` (AIX row
"ANCESTOR" before).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (plug-in `ftp.spl`; header-only rules from `src/common/`)
**Storage**: N/A (no registry or file format change)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/ftp277_probe.ps1` with 215's
`ftpmini.py` (PWDMAP option), regression probes 215 / 233
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in
**Performance Goals**: N/A (one reply parse per PWD)
**Constraints**: path buffer stays `FTP_MAX_PATH` (301); no new UI strings; plug-in ABI untouched
**Scale/Scope**: 7 source files of the FTP plug-in, 1 new header, saltests

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header in `src/common/` like `salftplisting.h` - PASS |
| II. Backward compatibility | replies that fit parse as before (saltests: the three forms, `""` escapes); only cut results become refusals, which every caller already handles; exactly-300 now accepted - PASS |
| III. Incremental modernization | local changes at the item's sites - PASS |
| IV. Windows commitment | N/A |
| V. Plug-in architecture | no `spl_*.h` change, no interface version change - PASS |
| VI. UI consistency | existing messages only (`IDS_TOOLONGPATH`, the existing working-path errors) - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/277-ftp-pwd-path-cut/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ftp277_probe.ps1, result_*.txt
specs/215-ftp-long-name-command/probe/ftpmini.py   (PWDMAP option added, backward compatible)
```

### Source Code

```text
src/common/salftppwd.h                  NEW  SalFtpPathFromPwdReply (pure)
src/saltests/saltests.cpp               checks TestFtpPwdReply277
src/plugins/ftp/ftputils.cpp            FTPGetDirectoryFromReply on the header; decode fails if it does not fit;
                                         FTPCompleteAbsolutePath fails instead of cutting;
                                         FTPAS400CutFileNamePart(mbrName, mbrNameSize, name) -> BOOL
src/plugins/ftp/ftputils.h              the two signatures
src/plugins/ftp/operats9.cpp            ReportCreateDirs heap buffers + invalidate; IsSameFile by SalNameOrderEqualCI
src/plugins/ftp/fs4.cpp                 AS/400 member name buffer 3 * MAX_PATH; failure -> IDS_TOOLONGPATH
src/plugins/ftp/operats6.cpp            AS/400 member name buffer 3 * MAX_PATH; failure -> no item (explore error)
src/plugins/ftp/fs5.cpp                 link size only when the whole source path fits linkName
```

**Structure Decision**: plug-in sources in place; the one pure decision (reply parse) as a
header-only rule (CLAUDE.md: shared rules for plug-ins are header-only).

## Design

1. `SalFtpPathFromPwdReply(reply, replySize, dirBuf, dirBufSize)` -> `SALFTPPWD_OK` (1),
   `SALFTPPWD_SYNTAX` (0), `SALFTPPWD_TOOLONG` (-1); `dirBuf` = "" unless OK. Forms as today
   (first `"` or `'` after the code; AIX = `'` first and the last `'` with no `"` after it; else
   the quoted RFC / VxWorks form with `""` = `"`). Only bytes in `[reply, reply + replySize)` are
   read. A path of `dirBufSize - 1` bytes is OK; one more byte is TOOLONG.
2. `FTPGetDirectoryFromReply`: the header, then `FTPDecodeServerReplyPathInPlace` returning BOOL
   (ASCII / UTF-8 unchanged -> TRUE; converted result that does not fit, or NULL -> FALSE). On
   failure `dirBuf` = "" and FALSE (traces kept). Callers unchanged.
3. `ReportCreateDirs`: `newLen >= FTP_MAX_PATH` -> `unknownResult = TRUE`. Buffers for the
   relative name / the absolute path and the cut component: heap, `max(FTP_MAX_PATH, newLen +
   strlen(workPath) + 3)`; the relative walk's `path` stays `FTP_MAX_PATH` (an append that does
   not fit ends the walk, as now - nothing deeper can be cached). Allocation failure: the
   workPath listing is invalidated (conservative).
4. `FTPCompleteAbsolutePath`: when the completed path does not fit `pathBufSize`, return FALSE
   with `path` unchanged (the caller's heap buffer always fits; its FALSE handling for a relative
   workPath stays).
5. `FTPAS400CutFileNamePart(char* mbrName, int mbrNameSize, const char* name)` -> BOOL; FALSE
   (mbrName = "") when the result does not fit. Callers pass `3 * MAX_PATH` (more than any listed
   name, `FTP_MAX_NAME_U8 + 1`); fs4 shows `IDS_TOOLONGPATH` and stops on FALSE, operats6 creates
   no item (the explore's existing error path).
6. `CFTPOpenedFile::IsSameFile`: case-insensitive branch `SalNameOrderEqualCI(Name, -1, name,
   -1)` (`#include "../../common/salnameorder.h"`); host compare unchanged.
7. fs5 upload: `linkPathWhole = strlen(sourcePath) + 1 < _countof(linkName)`; the link size is read
   only when it holds (else size unknown, as for a link name that does not fit).

## Complexity Tracking

None.
