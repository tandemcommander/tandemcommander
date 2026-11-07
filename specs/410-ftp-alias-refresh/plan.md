# Implementation Plan: FTP panel refreshed after a change made under another name of its server

**Branch**: `410-ftp-alias-refresh` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/410-ftp-alias-refresh/spec.md`

## Summary

A change-on-path notification reaches the FTP plug-in twice: `CPluginInterface::AcceptChangeOnPathNotification`
(`ftp.cpp`: drops cached listings - `CListingCache` - and viewer files of the notified name) and
`CPluginFSInterface::AcceptChangeOnPathNotification` (`fs3.cpp`, once per FS in a panel or detached:
refreshes the panel when the root matches by `FTPHasTheSameRootPath`). Both compare the host as
typed. The fix: one pure rule `SalFtpRootMatch` (new header `src/common/salftproot.h`, saltests) -
same root / same user and port under another host / other - used by

1. `FTPRootPathMatch` (`ftputils.cpp`, new; `FTPHasTheSameRootPath` becomes "== same root") and
   `fs3.cpp`: an "other host" match with the path rule refreshes the panel with the same timing,
   while its connection is open (a closed one is not reconnected for a change perhaps made on
   another server - review 1); `NextRefreshWontClearCache` stays TRUE (the notification drops the
   path's caches for every host itself - first design cleared it, revised after review 1); and, for every "other host"
   FS whatever its path, drops viewer files of the notified path under that FS's own name (FR-007);
2. `CListingCache::AcceptChangeOnPathNotification` (`ctrlcon4.cpp`): the host is no longer
   compared - same user (anonymous = no user) and port drop the matching listings (FR-004).

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: none new (FTP plug-in, `SalamanderGeneral` services)
**Storage**: none (in-memory caches only)
**Testing**: `saltests` (header rule), hidden-desktop probe `probe/ftp410_probe.ps1` (+ 341's `ftp341_probe.ps1` as regression)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: at most one extra listing per panel showing the changed folder
**Constraints**: plug-in ABI unchanged; no UI strings; no registry change
**Scale/Scope**: 4 source files + 1 header + saltests

## Constitution Check

- I Build reproducibility: no new dependency - PASS.
- II Backward compatibility: no stored data, no ABI change; behaviour changes only for another
  host with the same user and port - PASS.
- III Incremental modernization: a small header rule with tests - PASS.
- IV Windows commitment / V plug-in architecture: unchanged - PASS.
- VI UI consistency: no UI change - PASS.

## Project Structure

```text
src/common/salftproot.h            new: SalFtpSameUser / SalFtpSamePortText / SalFtpRootMatchOf
src/saltests/saltests.cpp          checks of the rule
src/plugins/ftp/ftputils.cpp/.h    FTPRootPathMatch; FTPHasTheSameRootPath through it
src/plugins/ftp/fs3.cpp            CPluginFSInterface::AcceptChangeOnPathNotification
src/plugins/ftp/ctrlcon4.cpp       CListingCache::AcceptChangeOnPathNotification
specs/410-ftp-alias-refresh/probe/ ftp410_probe.ps1, ftpmini_sess.py
```

**Structure Decision**: existing plug-in files; the rule header-only (the FTP plug-in cannot link
a `.cpp` of `src/common` into saltests - CLAUDE.md *Shared engines*).

## Complexity Tracking

None.
