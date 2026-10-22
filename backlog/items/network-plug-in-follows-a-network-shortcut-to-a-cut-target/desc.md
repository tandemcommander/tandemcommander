---
title: Network plug-in follows a network shortcut to a cut target of 260 or more units
type: bug
status: new
severity: 4
area: other-plugins
source: review:305
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: [decide-ship-network-plugin-nethood]
depends-on: []
reason: -
---

# Network plug-in follows a network shortcut to a cut target of 260 or more units

## Problem

The Network (Nethood) plug-in lists the user's network shortcuts (folder shortcuts in the
profile's Network Shortcuts folder: `desktop.ini` naming the folder-shortcut class + `target.lnk`)
and reads each target with `IShellLinkW::GetPath(name, MAX_PATH, ...)`. On a volume without 8.3
names the shell answers a target of 260 or more units with NOERROR and the first 259 units (cut in
the middle of a name, or on a backslash = the parent folder) - feature 304 / 305 measured it - and
the plug-in takes that cut path as the place the shortcut points at. Opening the shortcut then
fails, or opens another folder (copying into it would put files elsewhere).

## Evidence

- `src/plugins/nethood/cache.cpp:2645` at dac3dbbc (the function above
  `CNethoodCacheEnumerationThread::EnumNetworkShortcuts`): `link->GetPath(name, MAX_PATH, &data,
  SLGP_UNCPRIORITY) == NOERROR` -> `StringCchCopyW(path, MAX_PATH, name)`, `ok = TRUE`.
- The cut itself: `specs/304-plugin-picker-shortcut-cut/fix-log.md` *Measurement before* and
  `specs/305-core-shortcut-target-cut/fix-log.md` *Measurement before* (GetPath answers NOERROR with
  exactly 259 units for 260 / 261 / 300 / 400-unit targets on D: and E:, any buffer size).
- Found by the independent review of feature 305 (NOTE 3); not reproduced through the plug-in.
- The plug-in is off in `plugins.cfg` (`nethood=off`), so not reachable in the default build.

## Expected

A network shortcut whose target is 259 units or more is followed only when the link's item list
proves the whole name (the rule of features 304 / 305: `GetIDList` +
`SHGetNameFromIDList(SIGDN_FILESYSPATH)`, plain forms, equal or extended), and only when the whole
target fits the plug-in's buffer; otherwise the shortcut is shown as one whose target cannot be
read - never a cut path.

## Approach

The plug-ins' twin `SplFileDlgDetail::LinkTargetWholeW` (`src/plugins/shared/splfiledlg.h`,
feature 304) already implements the rule for a loaded link; the Nethood plug-in can call it (it is
header-only) and refuse a result that does not fit `MAX_PATH` units, or keep the whole target on
the heap.

## Notes

Severity 4: a function that does not work in a narrow case (long network-shortcut targets on a
volume without 8.3 names), in a plug-in that is not shipped by default. Whether the plug-in ships
at all is the maintainer's decision (`decide-ship-network-plugin-nethood`).

## Log

- 2026-10-22 — created (source review:305)
