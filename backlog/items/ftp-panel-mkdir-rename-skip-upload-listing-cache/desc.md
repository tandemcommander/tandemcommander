---
title: FTP: Create Directory and Quick Rename in a panel never update the upload listing cache
type: bug
status: in-progress
severity: 7
area: ftp
source: measure:288
who: agent
created: 2026-10-21
updated: 2026-10-23
verified: 2026-10-23 4c33e2fc
effort: S
feature: 323
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
- 2026-10-22 — measured in feature 302: on main an uploaded b.txt replaced a file just renamed to b.txt without the overwrite question (probe row REN-UP) - data loss in a narrow scenario, as the Notes foresaw
- 2026-10-22 — blocked: the independent review rejected the fix twice - review 2 MUST: Create Directory with a path (.cfg/new, docs/new) caches an existing folder the listing does not show as new and empty, an upload into it then overwrites without the question; continue on the branch, see its fix-log section Stopped (feature 302, branch 302-ftp-upload-cache-args)
- 2026-10-23 — unblocked: rules of 2026-10-23: a run carries over origin/302-ftp-upload-cache-args (SKILL.md 4.6) and fixes review 2 MUST in ReportCreateDirs as its fix-log Stopped says, up to three reviews
- 2026-10-23 — verified at 4c33e2fc: still present at 4c33e2fc: the four ReportCreateDirs/ReportRename calls in ctrlcon5.cpp still swap host and user (unchanged since 02eba55f, where probe REN-UP replaced b.txt without the question)
- 2026-10-23 — run started, feature 323
