---
title: CheckVer: a non-ASCII module name in the filter list is shown garbled
type: bug
status: parked
severity: 1
area: other-plugins
source: measure:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [checkver-log-script-path-garbled]
depends-on: []
reason: plug-in checkver not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-11-01
---

# CheckVer: a non-ASCII module name in the filter list is shown garbled

## Problem

CheckVer (not shipped: `plugins.cfg` checkver=off) keeps a list of filtered modules. The names come from the update script (which the log window treats as UTF-8) and from the registry (the registry facade stores UTF-8), but they are shown through an ANSI list box (`LB_ADDSTRING` in `FiltersFillListBox`) and the *Remove* question composes them with a code-page `LoadStr` template. A module name with non-ASCII letters is therefore shown as mojibake in the list and in the question.

## Evidence

Found by feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Re-judged rows*; feature 255's review 2 SHOULD 1), by reading at 3e0da39c: `src/plugins/checkver/dialogs.cpp` `IDC_CFG_REMOVE` (`LB_GETTEXT` + `sprintf(buff, LoadStr(IDS_REMOVE_CNFRM), itemName)`), `src/plugins/checkver/data.cpp` `FiltersFillListBox` / `AddUniqueFilter` / the `CONFIG_FILTER_KEY` load, `src/plugins/checkver/logwnd.cpp` (the FILTER link, `IDS_FILTERVER_CONFIRM`). Reported by `python tools/check_encoding.py --plugins` (`mixed-composition`, `checkver/dialogs.cpp`). Not measured: the update server's scripts were ASCII as far as known, so the defect is latent.

## Expected

A filter whose module name has non-ASCII letters is shown correctly in the list and in the *Remove* and *Filter* questions; `check_encoding.py --plugins` no longer reports `checkver/dialogs.cpp`.

## Approach

Wide list-box messages (`SendMessageW` with `SplU8ToWAlloc`) and `LoadStrU8` templates; read the selection back with `LB_GETTEXT` W and convert with `SplWToU8`.

## Notes

The plug-in is not shipped, hence severity 1; fix before enabling it. Same plug-in: `checkver-log-script-path-garbled`.

## Log

- 2026-11-01 — created (source measure:379)
- 2026-11-01 — moved to Parked: plug-in checkver not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-11-01
