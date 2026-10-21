---
title: FTP: server folder names compared by the code-page case rule on UTF-8 bytes
type: bug
status: new
severity: 4
area: ftp
source: review:277
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# FTP: server folder names compared by the code-page case rule on UTF-8 bytes

## Problem

On a case-insensitive FTP server (Windows, OS/2, Netware, VMS, MVS, z/VM, Tandem path types) the plug-in decides "the same server folder" with `StrNICmp` / `StrICmp` - the code-page case table applied to UTF-8 bytes - not the file system's name rule of feature 092. Two spellings of one folder that differ by the case of a non-ASCII letter (`Č` / `č`) are two folders, and two different non-ASCII folder names that the code-page table folds together can be one. Feature 277 moved the opened-file lock's *name* comparison to `SalNameOrderEqualCI`, but the lock's *path* comparison and the upload listing cache's `FindPath` still use the old fold: the lock can be off for a file in such a folder (two operations on one server file), and the upload listing cache can answer for another folder or miss its own.

## Evidence

By reading at 15eb57d2 (review of feature 277, NOTE 4; not measured):
- `src/plugins/ftp/ftputils.cpp` `FTPIsPrefixOfServerPath` (and `FTPIsTheSameServerPath`, which calls it): `SalamanderGeneral->StrNICmp(prefix, path, l1)` for VMS, MVS, Windows / Netware / OS/2, z/VM / Tandem.
- `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile` (path part) and `CUploadListingsOnServer::FindPath` use it.
- The name rule for plug-ins: `src/common/salnameorder.h` (`SalNameOrderEqualCI`, feature 115).

## Expected

Server paths on case-insensitive server types compared component by component with the 092 rule (header-only `salnameorder.h`), the prefix test included; ASCII-only paths compare as before. A saltests check of the path rule; the existing FTP probes (215, 224, 233, 277) as regressions.

## Notes

Severity 4: a wrong "same folder" answer needs non-ASCII folder names on a case-insensitive server and two concurrent operations (the lock) or an upload into a cached folder; no data loss seen, not verified. Many callers use `FTPIsPrefixOfServerPath` (panel path history, cycle checks of the explore, the listing caches) - enumerate them before changing; a changed answer for the explore's cycle check must stay conservative.

## Log

- 2026-10-21 — created (source review:277)
