---
title: Configuration offers the update level in an unpacked copy that can only notify
type: bug
status: new
severity: 3
area: panels-ui
source: review:428
who: agent
created: 2026-11-14
updated: 2026-11-14
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Configuration offers the update level in an unpacked copy that can only notify

## Problem

Configuration > General shows *When a new version is found* (Notify me only / Download it and offer installation / Install it automatically) also in a copy of the normal edition that was not installed by the installer (for example the build tree or an unpacked folder). Such a copy can only notify (`UpdInstall_IsEligible` is FALSE), so the two other choices do nothing there. The notification window already disables the list for such a copy (feature 421), and the portable edition hides it on both (feature 428).

## Evidence

Reported by the independent review of feature 428 (`specs/428-portable-build/fix-log.md`); not reproduced in 428 - verify how the General page decides before fixing. The page's portable handling: `src/dialogs4.cpp` (`#ifdef TC_PORTABLE`, `IDC_UPDATELEVEL` / `IDC_UPDATELEVEL_LABEL` hidden). The notification's handling: `src/upddlg.cpp` `CUpdateNoticeDialog::RefreshLevel` (enabled only when `Eligible`).

## Expected

In a copy that cannot install updates, the General page disables the level list (as the notification does) or says why, so the choice cannot suggest a behaviour the copy does not have.

## Log

- 2026-11-14 — created (source review:428)
