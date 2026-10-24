# Implementation Plan: FTP upload listing cache recognises a server reached under another name

**Branch**: `341-ftp-upload-cache-alias` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/341-ftp-upload-cache-alias/spec.md`

## Summary

`CUploadListingCache` (`src/plugins/ftp/operats9.cpp`) routes every change report by
`FindServer(user, host, port)`, which matches the host as typed; a server reached as `localhost`
and as `127.0.0.1` is two entries, and a change through one name never reaches the other
(measured: data loss, probe rows ALIAS-REN, ALIAS-UP).

The six change reports of `CUploadListingCache` (`ReportCreateDirs`, `ReportRename`,
`ReportDelete`, `ReportStoreFile`, `ReportFileUploaded`, `ReportUnknownChange`) keep their
exact-host handling and additionally invalidate all listings of every other entry with the same
user and port (`InvalidateOtherNamesOfServer`) - another host name may reach the same server and
the client cannot tell (fails closed).

**Revised after review 1 (M1)**: the first design remembered the addresses of the plug-in's own
lookups (a table in `ftputils.cpp`, recorded in `CGetHostByNameThread::Body`, a pure rule in
`src/common/salftpserverident.h` with saltests) and kept the caches of names with known, disjoint
addresses. Disjoint addresses do not prove two servers (one server on 127.0.0.1 and 127.0.0.2, its
LAN and public address); the review reproduced the data loss (row MULTI-REN). The table, the hook,
the header and its tests were removed.

**Revised after review 2 (M1)**: an upload into an FTP panel seeds the cache from the panel's
listing (`fs5.cpp`, `AddOrUpdateListing`); the panel is refreshed only by changes made under its own
host name, so after a change under another name its listing is stale and the upload trusted it
(probe row SEED-ALIAS). The cache now stamps every reported change per server name
(`StampChange`, `IncListingCounter()`, kept after the uploads end; bound 1,000 names, then - or on
low memory - fails closed) and `AddOrUpdateListing` refuses a listing started before a change
stamped under another host with the same user and port (`ChangedUnderOtherName`).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; FTP plug-in (`src/plugins/ftp`)
**Storage**: N/A
**Testing**: hidden-desktop probe `specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1`
(ALIAS-REN, ALIAS-UP, SAME-REN, MULTI-REN, SEED-ALIAS, SEED-SAME) with 323's `ftpmini_hide.py` and `probe/ftpmini_at.py`
(the same server on 127.0.0.2); regression `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1`
(16 rows); saltests unchanged (0 failed)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `ftp.spl`)
**Performance Goals**: a report walks the few cached server entries; an invalidated listing costs
one `LIST` while uploads under two names with the same user and port exist
**Constraints**: no new network communication (PRIVACY.md unaffected), no plug-in interface,
UI string, registry or file change
**Scale/Scope**: 2 FTP source files (`operats.h`, `operats9.cpp`)

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency - PASS |
| II. Backward compatibility | no ABI, registry, configuration or file-format change - PASS |
| III. Incremental modernization | one helper, six calls - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plug-in architecture | internal FTP plug-in classes only - PASS |
| VI. UI consistency | no UI change - PASS |

CLAUDE.md standing rules: *Never lose the user's data* - the change only makes uploads trust their
cache less (invalidation) and fails closed when two names cannot be told apart (098). *Pure
decisions in a header with saltests*: the remaining decision is one condition inside the cache
(same user and port, another host); it is proven by the probe and its negative control, not by a
header of its own. Network: untouched. Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/341-ftp-upload-cache-alias/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ftp341_probe.ps1, ftpmini_at.py, result_main.txt, result_after.txt,
    result_negative.txt, regress_302.txt, design1/ (the first design's results)
```

(No `contracts/`: no interface other components or plug-ins rely on changes.)

### Source Code (repository root)

```text
src/plugins/ftp/operats.h             CUploadListingCache::InvalidateOtherNamesOfServer, StampChange,
                                      ChangedUnderOtherName, CUploadChangeStamp
src/plugins/ftp/operats9.cpp          their bodies; the six reports call the first; AddOrUpdateListing
                                      refuses a stale panel listing
```

**Structure Decision**: the existing FTP plug-in code of features 302 / 323.

## Complexity Tracking

None.
