---
title: Remove the dormant start-up import of older Open Salamander configurations
type: tech-debt
status: new
severity: 2
area: data-safety
source: measure:245
who: agent
created: 2026-10-18
updated: 2026-10-18
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Remove the dormant start-up import of older Open Salamander configurations

## Problem

Feature 032 (FR-010) asked to remove the upstream import of older configurations; only its list of roots was cut to one entry. GetUpgradeInfo, FindLatestConfiguration, CImportConfigDialog and DeleteOldConfigurations remain: they replace the whole configuration at start-up and can delete the old product keys. Adding a root back would revive them; the settings import of feature 245 deliberately does not use them.

## Evidence

src/mainwnd2.cpp:656 GetUpgradeInfo, :941 FindLatestConfiguration, :1115 CMainWindow::DeleteOldConfigurations at 18e0bd3c; src/dialogs2.cpp CImportConfigDialog; SALCFG_ROOTS_COUNT 1 in src/consts.h. specs/245-settings-import-salamander/analysis.md A9.

## Expected

The dead start-up import path is removed (or reduced to what the single root needs), so it cannot be revived by accident.

## Log

- 2026-10-18 — created (source measure:245)
