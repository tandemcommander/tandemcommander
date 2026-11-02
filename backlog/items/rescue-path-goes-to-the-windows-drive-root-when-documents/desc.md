---
title: Rescue path goes to the Windows drive root when Documents needs more than 259 bytes
type: improvement
status: open
severity: 2
area: long-paths
source: leftover:386
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Rescue path goes to the Windows drive root when Documents needs more than 259 bytes

## Problem

The rescue path ("If the path is inaccessible, go to Documents", Configuration > Drives) holds
`MAX_PATH` bytes. Since feature 386 a Documents folder whose UTF-8 path needs more than 259 bytes
(fewer than 260 UTF-16 units, e.g. 90 CJK letters) is refused there instead of cut, and the panel
falls back to the root of the Windows drive - no longer another folder, but not Documents either.
The settings page shows the drive root in its field for such a user, and plug-ins asking for
`SALCFG_IFPATHISINACCESSIBLEGOTO` get it as well.

## Evidence

Feature 386 (`specs/386-mydocs-path-whole/spec.md`, *Clarifications* and *Assumptions*;
`fix-log.md`, *T005-T011*), branch `386-mydocs-path-whole`: `src/salamdr6.cpp`
`GetIfPathIsInaccessibleGoTo(char* path, BOOL forceIsMyDocs)` calls
`GetMyDocumentsOrDesktopPath(path, MAX_PATH)`; its callers hold `MAX_PATH` buffers:
`src/fileswn2.cpp` `ChangeToRescuePathOrFixedDrive` (`ifPathIsInaccessibleGoTo[MAX_PATH]`),
`CFilesWindow::ChangePathToDisk` (`ifPathIsInaccessibleGoTo[MAX_PATH]`; the third call writes into
the `SAL_MAX_PATH_UTF8` heap `changedPath`), `src/dialogs5.cpp` (the settings page,
`EditLine(IDE_DRVSPEC_ONERRGOTO, path, MAX_PATH)`), `src/mainwnd2.cpp` (configuration load),
`src/zip.cpp` (`SALCFG_IFPATHISINACCESSIBLEGOTO`, limited to `MAX_PATH` for plug-ins). The
configuration value `Configuration.IfPathIsInaccessibleGoTo` is `MAX_PATH` too. Not driven in the
GUI: the rescue route needs a root that exists but cannot be listed (386 fix-log).

## Expected

With the rescue path set to Documents, a panel whose path became inaccessible opens the whole
Documents folder, however long its UTF-8 form; the settings page shows it whole. What plug-ins get
for `SALCFG_IFPATHISINACCESSIBLEGOTO` stays within the plug-in interface (append-only).

## Notes

Review 1 of 386 (NOTE 2): the settings page (`src/dialogs5.cpp`, `IDE_DRVSPEC_ONERRGOTO`) and the
configuration load (`src/mainwnd2.cpp`, a configuration without the "Go To My Docs" value) compare
the typed or stored path with `GetIfPathIsInaccessibleGoTo(path, TRUE)` - for such a user that is
the drive root, so the page shows `C:\` for "Documents" and a typed `C:\` switches to the
Documents mode. The same feature's probe drives the rescue route (rows RESCUE-SHORT /
RESCUE-LONG: a subst drive whose folder denies listing).

The plug-in value and the stored configuration are maintainer-owned areas (plug-in interface,
stored data); a feature may need a decision first. Severity 2: only users with such a Documents
folder, and the fallback is a safe folder, not another one.

## Log

- 2026-11-02 — created (source leftover:386)
- 2026-11-02 — moved to Next position 137
