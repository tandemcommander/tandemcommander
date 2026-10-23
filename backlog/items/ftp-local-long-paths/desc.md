---
title: FTP: download and upload refuse local paths and names over 259 bytes
type: improvement
status: open
severity: 3
area: ftp
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-23
verified: -
effort: L
feature: -
related: []
depends-on: []
reason: -
---

# FTP: download and upload refuse local paths and names over 259 bytes

## Problem

Part of `ftp-long-name-and-path-leftovers` (split at 4c6fd132). The FTP plug-in's local disk work (download targets, upload sources, View's cache file, files to close) keeps local paths and names in MAX_PATH (260-byte) buffers. Since feature 215 a longer path is refused ("file name is too long", `TooLong`) and a longer name of a created file is cut at a whole letter and marked (`NameCut`) - nothing wrong is written, but a user cannot download into or upload from a folder whose local path is 260+ bytes, or a file whose name is that long, although the core works with such paths since the long-path features.

## Evidence

By reading at 4c6fd132: `src/plugins/ftp/operats.h:791-806` `CFTPDiskWork` (`Path[MAX_PATH]`, `Name[MAX_PATH]`, `TooLong`, `NameCut`), `:859` `CFTPFileToClose` (`FileName[MAX_PATH]`), `src/plugins/ftp/datacon.h:212` `TgtDiskFileNameTooLong`; the disk thread `operats3.cpp` / `operats5.cpp`, `datacon1.cpp`. Measured by feature 215 (`specs/215-ftp-long-name-command/fix-log.md`, *Measured (before)* rows DL-LONG / UP-LONG, *Work*: "the local side's paths of 259 bytes (long-path support would need `CFTPDiskWork`, `CFTPFileToClose`, `nameBackup` widened together)"); probe `specs/215-ftp-long-name-command/probe/ftp215_probe.ps1`.

## Expected

Download into and upload from a local folder of 260+ bytes, and of a file name up to the file system's limit, works (`\\?\` forms where the Win32 calls need them); a path that the file system cannot hold is still refused, never cut. Probe rows DL-LONG / UP-LONG of 215 pass with a deep local folder.

## Approach

Widen `CFTPDiskWork`, `CFTPFileToClose` and the name backups together (heap or `CSalMaxPathBuffer`-sized), use the core's long-path wide calls for create / open / delete / attributes; keep the autorename's deliberate shortening. Measure first with 215's probe and a target folder of ~300 bytes.

## Notes

Not a cut today - a refusal (215). Severity 3: deep local folders are rare and the refusal says why. The core's `SalIsValidFileNameComponent` limit (222) may meet it first for names of 86+ CJK letters - check.

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 40
- 2026-10-23 — related item ftp-long-name-and-path-leftovers closed: split into: ftp-pwd-and-created-path-cut (done in 277), ftp-escaped-path-does-not-fit-decision, ftp-local-long-paths, ftp-mask-letters-by-server-encoding - the parts replace it; maintainer 2026-10-23
