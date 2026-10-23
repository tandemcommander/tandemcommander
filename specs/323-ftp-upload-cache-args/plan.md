# Implementation Plan: FTP panel Create Directory and Quick Rename update the upload listing cache

**Branch**: `323-ftp-upload-cache-args` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/323-ftp-upload-cache-args/spec.md`; continues the
stopped feature 302 (`origin/302-ftp-upload-cache-args`, record in `fix-log-302.md`).

## Summary

`CControlConnectionSocket::CreateDir` and `::QuickRename` (`src/plugins/ftp/ctrlcon5.cpp`) report
their change to `UploadListingCache` with host and user swapped, so the report is dropped (measured
by 302: an uploaded `b.txt` replaced a file just renamed to `b.txt` without the question). Carried
over from 302: the four calls in the declared order, and (302 review 1) `ReportRename` /
`ReportUnknownChange` invalidate every cached listing of the server. New here (302 review 2 MUST):
`CUploadListingsOnServer::ReportCreateDirs` records only the last named component of a successful
Create Directory as a new, empty folder; an earlier component is never given an empty listing, and
when its cached parent listing does not show it (or cannot tell), that parent listing is
invalidated. The per-component decision is a pure rule in a header under `src/common/` with
`saltests` checks; the probe gets the review-2 rows MKD-HID and MKD-CASE.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; FTP plug-in (`src/plugins/ftp`)
**Storage**: N/A (in-memory cache only, lives while an upload operation exists)
**Testing**: `saltests` (the per-component decision, `src/common/salftpmkdirreport.h`);
hidden-desktop GUI probe `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` (rows MKD-ABS,
REN-UP, MKD-REN, REN-PATH, + MKD-HID, MKD-CASE) with 215's `ftpmini.py` and 302 review 2's
`ftpmini_hide.py` (hides dot names on a plain `LIST`, resolves path components without case);
`ftp288_probe.ps1` as regression (20 / 0).
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `ftp.spl`)
**Performance Goals**: N/A (an invalidated listing costs one `LIST` while an upload exists)
**Constraints**: no change to the plug-in interface, UI strings, stored data or network traffic
other than an upload listing a folder whose cached listing became uncertain
**Scale/Scope**: 3 FTP source files (2 carried over), 1 new header, saltests

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; a header-only rule - PASS |
| II. Backward compatibility | no ABI, registry, configuration or file-format change - PASS |
| III. Incremental modernization | a minimal fix at the defective sites - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plug-in architecture | the plug-in interface is untouched (internal FTP plug-in classes) - PASS |
| VI. UI consistency | no UI change - PASS |

CLAUDE.md standing rules touched: *Never lose the user's data* - every change makes the upload's
existence check trust the cache less, never more than the server's answer; pure decisions in a
header under `src/common/` with `saltests` (the FTP plug-in cannot compile a `.cpp` from
`src/common` - header-only). Names and paths are passed through unchanged (no cut, no code-page
conversion). Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/323-ftp-upload-cache-args/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md            (this run), fix-log-302.md (the stopped run's record)
├── checklists/requirements.md
└── probe/ftp302_probe.ps1, probe/ftpmini_hide.py, probe/result_*.txt,
    probe/run302/ (302's results), probe/review2/ (302 review 2's reproduction)
```

No `contracts/`: nothing external changes (internal classes of the FTP plug-in).

### Source Code (repository root)

```text
src/plugins/ftp/ctrlcon5.cpp   # carried over: CreateDir / QuickRename report (user, host, port)
src/plugins/ftp/operats9.cpp   # carried over: ReportRename / ReportUnknownChange -> InvalidateAllListings();
                               # new: ReportCreateDirs per-component decision (last named component only)
src/plugins/ftp/operats.h      # carried over: InvalidateAllListings(); comments of ReportCreateDirs
src/common/salftpmkdirreport.h # new: pure rule - what a reported Create Directory does per component
src/saltests/saltests.cpp      # new checks of salftpmkdirreport.h
```

**Structure Decision**: the decision table in a header-only rule (like 303's `salftpupname.h`); the
walk over path components stays in `operats9.cpp` (it needs the plug-in's path functions).

## Complexity Tracking

None.
