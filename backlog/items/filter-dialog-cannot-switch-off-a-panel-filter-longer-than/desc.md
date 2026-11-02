---
title: Filter dialog cannot switch off a panel filter longer than 259 bytes
type: bug
status: new
severity: 4
area: long-paths
source: review:392
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Filter dialog cannot switch off a panel filter longer than 259 bytes

## Problem

A panel tab's filter can be longer than 259 bytes (a tab's `Filter` registry value is read with
`SAL_TAB_FILTER_MAX`, 1001 bytes, and becomes the panel's filter when the tab is activated).
Change Filter shows that filter whole, but OK is refused with "The path specified is too long."
whatever the user chose - also with "Don't use filter" - because the field is measured against
260 bytes before anything else (feature 270). To switch the filter off (or keep it while changing
nothing) the user must first shorten the text, and so loses the long filter.

## Evidence

Review 1 of feature 392 (NOTE, `specs/392-filter-dialog-backup/fix-log.md` *Review*), by reading
at e81d6cfd: `src/dialogs3.cpp` `CFilterDialog::Validate` starts with
`if (!DlgItemTextFitsU8(HWindow, IDE_FILTER, &ti, MAX_PATH)) return;` before the radio buttons are
read; `CFilterDialog::Transfer` reads the field with `SalGetWindowTextU8(hWnd,
Filter->GetWritableMasksString(), MAX_PATH)` and stores it in the history. Feature 392's probe
`specs/392-filter-dialog-backup/probe/flt392_probe.ps1` builds the state (two left tabs from the
registry, tab 1 with a 300-byte filter, CM_LEFT_NEXTTAB, CM_CHANGEFILTER): the first dialog shows
300 of 300 bytes. The refusal with the text unchanged is not measured.

## Expected

Change Filter accepts a panel filter as long as the panel can hold (1000 bytes): with "Don't use
filter" it switches the filter off and keeps the text whole; with "Use filter" an unchanged or
edited text up to that length is checked and stored whole - or, where a limit stays, it is the
group's limit and the refusal does not hit the panel's own current filter.

## Notes

Not verified: whether the history (`Configuration.FilterHistory`, `AddValueToStdHistoryValues`)
and the panel's own `Filter` registry value (read with `MAX_PATH` in `mainwnd2.cpp`) take a
longer text whole - both need checking before the 260-byte check is widened. Measure first: run
392's probe state, leave the field unchanged, choose "Don't use filter", OK.

## Log

- 2026-11-02 — created (source review:392)
