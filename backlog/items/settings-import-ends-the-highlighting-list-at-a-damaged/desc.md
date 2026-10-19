---
title: Settings import ends the highlighting list at a damaged entry
type: bug
status: new
severity: 3
area: panels-ui
source: measure:250
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Settings import ends the highlighting list at a damaged entry

## Problem

The settings import (Options > Import Settings from Salamander, feature 245) reads the source's panel item highlighting list and stops at the first entry without a usable Masks value (missing, or MAX_PATH bytes or longer): the following good entries of the source are not imported, and since the imported list replaces the current one, the preview offers to remove the current entries and add only the ones before the damaged entry. Since feature 250 the program's own loader skips such an entry and keeps the rest, so the import and the loader now treat the same list differently, and the import's comment ("the program's own loader would not go further either") is no longer true.

## Evidence

src/cfgimport.cpp at 6ed54ba2, the highlighting-list block after `SalCfgKeyFindChild(ck, "Panel Items Hilighting")`: `if (masks == NULL || (int)strlen(masks) >= MAX_PATH) { CfgImpAddLineF(g, CFGIMP_LINE_SKIPPED, IDS_CFGIMP_LN_INCOMPLETE, name); break; }`. The loader: src/mainwnd2.cpp, CMainWindow::LoadConfig, highlighting loop changed by feature 250 to skip a damaged entry (specs/250-damaged-highlight-entry/fix-log.md). Found by reading during feature 250; not reproduced with a damaged Altap / Open Salamander configuration.

## Expected

The import skips a damaged source entry (one "incomplete" line in the preview) and imports the entries after it, like the loader; the comment states the new rule.

## Notes

Narrow: needs a damaged source configuration, and the preview shows the change before the user confirms - hence severity 3.

## Log

- 2026-10-20 — created (source measure:250)
