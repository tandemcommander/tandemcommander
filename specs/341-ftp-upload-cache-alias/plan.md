# Implementation Plan: FTP upload listing cache recognises a server reached under another name

**Branch**: `341-ftp-upload-cache-alias` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/341-ftp-upload-cache-alias/spec.md`

## Summary

`CUploadListingCache` (`src/plugins/ftp/operats9.cpp`) routes every change report by
`FindServer(user, host, port)`, which matches the host as typed; a server reached as `localhost`
and as `127.0.0.1` is two entries, and a change through one name never reaches the other
(measured: data loss, probe rows ALIAS-REN, ALIAS-UP). The fix:

1. The plug-in's existing name lookup (`CGetHostByNameThread::Body`, `src/plugins/ftp/sockets.cpp`)
   records the addresses it received for the looked-up name in a small in-memory table
   (`ftputils.cpp`, SRW lock, leaf); a typed IPv4 address is read with `inet_addr` as the plug-in
   already does. No new lookup.
2. A pure rule (`src/common/salftpserverident.h`, header-only, `saltests`) decides from the host
   text and the two known-address lists whether two names are the same, maybe the same, or
   different servers, and holds the bounded host -> addresses table (no locking, no Win32).
3. The six change reports of `CUploadListingCache` (`ReportCreateDirs`, `ReportRename`,
   `ReportDelete`, `ReportStoreFile`, `ReportFileUploaded`, `ReportUnknownChange`) keep their
   exact-host handling and additionally invalidate all listings of every other entry with the same
   user and port that is maybe the same server.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; FTP plug-in (`src/plugins/ftp`), Winsock (already used)
**Storage**: N/A - an in-memory table for the life of the plug-in (no registry, no file)
**Testing**: `saltests` (`TestFtpServerIdent341`); hidden-desktop probe
`specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1` (ALIAS-REN, ALIAS-UP, SAME-REN) with
323's `ftpmini_hide.py`; regression `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` (16 rows)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `ftp.spl`)
**Performance Goals**: a report walks the few cached server entries; an invalidated listing costs
one `LIST` while an upload to a maybe-same name exists
**Constraints**: no new network communication (PRIVACY.md unaffected), no plug-in interface,
UI string, registry or file change; a host name longer than the table slot is not recorded
(unknown = maybe the same - never cut)
**Scale/Scope**: 4 FTP source files (`sockets.cpp`, `ftputils.cpp/.h`, `operats9.cpp`, `operats.h`),
1 new header, saltests

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only rule - PASS |
| II. Backward compatibility | no ABI, registry, configuration or file-format change - PASS |
| III. Incremental modernization | minimal: one recording site, one fan-out helper - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plug-in architecture | internal FTP plug-in classes only; the plug-in interface untouched - PASS |
| VI. UI consistency | no UI change - PASS |

CLAUDE.md standing rules: *Never lose the user's data* - the change only makes uploads trust their
cache less (invalidation), never applies a report to a server not proven the same. Pure decision
in a header under `src/common/` with `saltests` (the FTP plug-in compiles no `.cpp` from
`src/common`). *A name is never cut* - a host name that does not fit the table slot is refused
(not recorded), which reads as "address unknown" = maybe the same. Network: the maintainer-owned
area is untouched - the recording reads a result the existing lookup already received.
Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/341-ftp-upload-cache-alias/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ftp341_probe.ps1, result_main.txt, result_after.txt
```

(No `contracts/`: no interface other components or plug-ins rely on changes.)

### Source Code (repository root)

```text
src/common/salftpserverident.h        new - SalFtpCompareServerNames, CSalFtpHostAddrTable
src/saltests/saltests.cpp             TestFtpServerIdent341
src/plugins/ftp/sockets.cpp           CGetHostByNameThread::Body records the received addresses
src/plugins/ftp/ftputils.h/.cpp       FTPRecordHostAddrs / FTPGetHostAddrs (table + SRW lock)
src/plugins/ftp/operats.h             CUploadListingCache::InvalidateOtherNamesOfServer
src/plugins/ftp/operats9.cpp          the six reports call it
```

**Structure Decision**: the existing FTP plug-in and `src/common` header pattern of features 288,
303 and 323.

## Complexity Tracking

None.
