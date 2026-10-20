---
title: CheckVer: the log shows a script path with non-ASCII letters garbled
type: bug
status: parked
severity: 1
area: other-plugins
source: review:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20
---

# CheckVer: the log shows a script path with non-ASCII letters garbled

## Problem

CheckVer (not shipped: `plugins.cfg` checkver=off) writes "file opened / cannot open / cannot
read" lines into its log window with the code-page `LoadStr` template and the UTF-8 path of the
script file chosen in its open dialog. The log draws each line as UTF-8 only when the whole line
is strict UTF-8, else through the code page. So in a translation whose template has non-ASCII
letters every non-ASCII path is garbled, and in any language a path with an unpaired surrogate
(WTF-8) is garbled whole.

## Evidence

Found by the review of feature 255 (`specs/255-plugin-encoding-findings/fix-log.md`, *Review*, branch `255-plugin-encoding-findings`),
by reading, at e849e68c: `src/plugins/checkver/dialogs.cpp` (the open dialog:
`GetOpenFileNameW` + `SplWToU8`), `src/plugins/checkver/data.cpp` (the
`sprintf(buff, LoadStr(IDS_FILE_OPENED / IDS_FILE_OPENERROR / IDS_FILE_READERROR), fileName)` +
`AddLogLine` sites), `src/plugins/checkver/logwnd.cpp` `FlexTextOut` (strict probe, then
`CP_ACP`). Reported by `python tools/check_encoding.py --plugins` (`strict-probe-rejects-wtf8`,
`logwnd.cpp`); the `mixed-composition` rule does not see the `AddLogLine` sink.

## Expected

Czech UI: opening the script `C:/Skripty/žluťoučký.txt` logs the path spelled correctly; a path
with an unpaired surrogate shows as the core shows it; `check_encoding.py --plugins` no longer
reports `logwnd.cpp`.

## Approach

`LoadStrU8` for the three templates, and `SplU8ToW` (WTF-8) as the probe in `FlexTextOut`, keeping
the code-page fallback for resource texts that are not UTF-8.

## Notes

The plug-in is not shipped, hence severity 1.

## Log

- 2026-10-20 — created (source review:255)
- 2026-10-20 — moved to Inbox
- 2026-10-20 — moved to Parked: plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20
