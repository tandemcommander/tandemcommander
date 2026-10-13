# Implementation Plan: SFTP checked against a server; a listing that ends early is an error

**Branch**: `133-sftp-server-verify` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

1. A GUI probe that drives the SFTP plug-in in the program against the container `tandem-sftp`
   (`localhost:2222`): connect by a typed address, answer the password and host-key dialogs,
   then delete / create / download / move, and read both the message boxes and the state of
   the server (through `docker exec`). Rows of 131: R1-R4 (reasons), P1-P5 (long paths), plus
   the rows of this feature (LIST-COPY, LIST-MOVE, LIST-PANEL with the seam).
2. `CSFTPSession::ListDir` returns failure unless the server answered "end of directory"
   (`readdir` returned 0); the classification is a pure function with unit checks.
3. A debug-only seam (`TC_SFTP_PROBE_LIST_FAIL`) that makes the read of the Nth entry of a
   directory whose path ends with a given text fail a given number of times - so the row can be
   run before and after the fix on the same build tree (the seam goes in first, with the old
   logic; the measurement of "before" is taken then).

## Technical Context

- `src/plugins/sftp/session.cpp` (`ListDir`), callers: `fs.cpp` `ListCurrentPath`,
  `operats.cpp` `DownloadDir`, `DeleteRecursive`, `ChmodRecursive`, `ChownRecursive`.
- Pure helper in `src/plugins/sftp/sftputils.h/.cpp` (the plug-in's unit harness
  `src/plugins/sftp/test/harness.cpp` compiles `sftputils.cpp`; 85 checks today).
- Probe: Windows PowerShell 5.1 on the hidden desktop, the library of feature 098
  (`specs/098-long-path-overruns/probe/fix_probe_lib.ps1`); the server is prepared and inspected
  with `docker exec -u tctest tandem-sftp`.
- Control build: `build\tandemcommander\Debug_x64_v019` (0.1.9, before 131's SFTP changes).
- No new strings (an existing "cannot list" text carries the reason); no interface change;
  `PRIVACY.md` untouched (the seam is debug-only and contacts nothing).

## Constitution Check

- Never lose the user's data: a failed listing fails the operation built on it; verified on the
  server's own state, not on messages only.
- Backward compatibility / plug-in ABI: untouched.
- Build reproducibility: the seam is inside `#ifdef _DEBUG`.
- UI consistency: existing message boxes.

## Structure

1. Server fixture + probe skeleton (connect, dialogs); first run on 0.1.9 and on the current
   build: rows R and P of 131.
2. Seam with the old logic; rows LIST-* measured ("before").
3. Fix (`ListDir`, pure classification, callers); unit checks; rows LIST-* again.
4. Fix what the R / P rows show in 131's code; the rest to `specs/NEXT-WORK.md`.
5. Independent review, final builds, regressions, records.
