---
title: Relative path under a deep plug-in file-system path is refused: the core buffer for GetFullFSPath is MAX_PATH
type: improvement
status: new
severity: 3
area: long-paths
source: leftover:380
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Relative path under a deep plug-in file-system path is refused: the core buffer for GetFullFSPath is MAX_PATH

## Problem

When the user types a path relative to the current location of a plug-in file system (Change
Directory, Shift+F7, or the command line `cd`), the core asks the plug-in for the full path into
`char absFSPath[MAX_PATH]`. A full path over 259 bytes of UTF-8 (`fs-name:` included) cannot be
returned, so feature 380 makes the Registry Editor refuse it ("too long path name") instead of
handing back a cut path. Under a deep key (for example 150 Latin or 60 CJK letters of key names)
every relative path is therefore refused, although the plug-in can show and open such keys when the
whole path is typed. Other FS plug-ins (FTP, SFTP, Folders, Undelete, Portables, Nethood, demoplug)
get the same 260-byte buffer.

## Evidence

- Core caller: `src/fileswn3.cpp` (at 89c410a1 around line 2011 `char absFSPath[MAX_PATH]; // plugin
  FS paths keep the legacy convention`, and around line 2280 the call
  `GetFullFSPath(HWindow, ..., absFSPath, MAX_PATH, success)` in the `IDS_INCOMLETEFILENAME` branch).
- Interface: `src/plugins/shared/spl_fs.h` `CPluginFSInterfaceAbstract::GetFullFSPath` - "'path' is a
  buffer of 'pathSize' characters ... the buffer size is a BYTE count".
- Feature 380 probe `specs/380-regedt-full-path-cut/probe/regpath380_probe.ps1`, rows LONG and CJK:
  the refusal at 294 / over 259 bytes.

## Expected

The core passes a buffer large enough for any plug-in FS path (for example `SAL_MAX_PATH_UTF8`
bytes) with that size as `pathSize`, and the code after the call (`CHANGE_AGAIN_NO_DLG`, the
`ChangePathToPluginFS` route) accepts a path of that length; each FS plug-in's `GetFullFSPath` is
checked for assuming `MAX_PATH` instead of `pathSize`. A relative path under a deep registry key then
works; a full path over the new limit is still refused, never cut.

## Notes

Not verified: whether the code after the call (path history, the panel's stored FS path) accepts
paths over `MAX_PATH` - measure first. Plug-ins that ignore `pathSize` would then overrun nothing (a
larger buffer), but those that write `MAX_PATH` into it explicitly need a look. Severity 3: a refusal,
not a wrong result, reached only under deep keys.

## Log

- 2026-11-01 — created (source leftover:380)
