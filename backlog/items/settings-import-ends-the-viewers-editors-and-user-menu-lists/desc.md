---
title: Settings import ends the viewers, editors and User Menu lists at a damaged entry
type: bug
status: open
severity: 3
area: panels-ui
source: measure:268
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [settings-import-ends-the-highlighting-list-at-a-damaged]
depends-on: []
reason: -
---

# Settings import ends the viewers, editors and User Menu lists at a damaged entry

## Problem

The settings import (Options > Import Settings from Salamander, feature 245) reads the source's viewers, alternative viewers, editors and User Menu lists and stops at the first entry without a required value (viewers: Masks or Type missing, or '|' in the masks; editors: Masks missing; User Menu: Item Name, Command, Execute Through Shell or Close Shell Window missing). The good entries after it are not imported; the preview shows one "stopped" line. Since feature 268 the program's own loaders skip such an entry and keep the rest, so the import and the loaders now treat the same list differently, and the parsers' comments ("the program stops reading there too") are no longer true.

## Evidence

At f4f40b00: src/common/salcfgimport.h, `SalCfgImpParseViewers` - `if (masks == NULL || (!editors && !SalCfgGetDword(k, "Type", &type))) { ... *stopReason = SALCFGIMP_VSTOP_INVALID; break; }` and the `SALCFGIMP_VSTOP_PIPE` `break` after `strchr(masks, '|')`; `SalCfgImpParseUserMenu` - `if (name == NULL || command == NULL || !SalCfgGetDword(...) ...) { *stopReason = 1; break; }`. Their callers in src/cfgimport.cpp add `IDS_CFGIMP_LN_STOPPED` to the preview (`CfgImpPlanViewers`, the User Menu plan). saltests checks of these parsers exist (src/saltests, `SalCfgImpParseUserMenu` / `SalCfgImpParseViewers` calls) and would have to change with the rule. The loaders: src/salamdr2.cpp `LoadViewers` / `LoadEditors` and the User Menu loop of `CMainWindow::LoadConfig` (src/mainwnd2.cpp), changed by feature 268 (specs/268-damaged-list-entries/fix-log.md). Found by reading during feature 268; not reproduced with a damaged Altap / Open Salamander configuration.

## Expected

The import skips a damaged source entry (one "incomplete" line in the preview) and imports the entries after it, like the loaders; the comments state the new rule.

## Notes

Narrow: needs a damaged source configuration, and the preview shows the stop before the user confirms - hence severity 3. The same mismatch for the highlighting list is `settings-import-ends-the-highlighting-list-at-a-damaged` (feature 250); both could be one feature. Whether the import should mirror the source program (which also stops) or this program's loader is a judgement the triage may want to make.

## Log

- 2026-10-20 — created (source measure:268)
- 2026-10-21 — moved to Next position 37
