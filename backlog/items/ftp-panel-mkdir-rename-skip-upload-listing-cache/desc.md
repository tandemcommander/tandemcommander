---
title: FTP: Create Directory and Quick Rename in a panel never update the upload listing cache
type: bug
status: open
severity: 5
area: ftp
source: measure:288
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: Create Directory and Quick Rename in a panel never update the upload listing cache

## Problem

After a user creates a folder (F7) or Quick-Renames a file in an FTP panel, the plug-in tells its upload listing cache about the change with the host and the user name swapped, so the cache never finds the server and keeps its old listing of that folder. The upload's "does the target exist?" check reads that cache: until the cached listing is refreshed, an upload in the same session may not know of the new folder or the renamed file (suspected: a file renamed to `b.txt` then uploaded as `b.txt` could be stored without the overwrite question), or may think the old name still exists.

## Evidence

By reading at 92b9926e (found while measuring feature 288, `specs/288-ftp-per-server-encoding/research.md` R5): `src/plugins/ftp/ctrlcon5.cpp:578` and `:624` (`CControlConnectionSocket::CreateDir`) call `UploadListingCache.ReportCreateDirs(hostBuf, userBuffer, portBuf, ...)`, and `:767` / `:789` (Quick Rename) `UploadListingCache.ReportRename(hostBuf, userBuffer, portBuf, ...)`; the functions are declared `(const char* user, const char* host, unsigned short port, ...)` (`src/plugins/ftp/operats.h:3290`, `:3299`), and `CUploadListingCache::FindServer` (`operats9.cpp`) compares `Host` with the first argument's position. Not reproduced: the panel's own refresh after the command may update the cache through `AddOrUpdateListing` (`fs2.cpp`, "update the cached listing"), which would shorten or close the window.

## Expected

The panel's Create Directory and Quick Rename update the upload listing cache of the right server (arguments in the declared order); a probe row: rename `a.txt` to `b.txt` in the panel, then upload a local `b.txt` into that folder in the same session - the overwrite question appears (or the cached listing knows `b.txt`).

## Notes

Severity 5 because the effect is not measured; if the probe shows an upload replacing a file without the question, raise it to the data-loss band (7-8, narrow scenario). An upstream defect (Open Salamander), not caused by 288.

## Log

- 2026-10-21 — created (source measure:288)
- 2026-10-21 — moved to Next position 8
