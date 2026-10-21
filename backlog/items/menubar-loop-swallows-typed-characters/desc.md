---
title: After a menu popup closes by itself, typed characters are swallowed until Esc
type: bug
status: blocked
severity: 3
area: panels-ui
source: leftover:168
who: agent
created: 2026-10-14
updated: 2026-10-21
verified: 2026-10-21 fed08ad1
effort: S
feature: -
related: []
depends-on: []
reason: not reproduced at fed08ad1: a popup closed by activation, cancel-mode or by itself ends the menu bar loop too (thread hook closes every menu window); typed characters reach the field - evidence/menubar_probe_result_fed08ad1.txt
---

# After a menu popup closes by itself, typed characters are swallowed until Esc

## Problem

`CMenuBar`'s loop ends on Esc, Alt, F10, a mouse button or `WM_USER_CLOSEMENU`. A popup closed by anything else (activation, `WM_CANCELMODE`) leaves the loop running; while it runs the window's keys go to the menu bar and plain characters are dropped (`WM_CHAR` only looks for a mnemonic) - typing into e.g. the Find window does nothing until Esc / Alt / a click. Found by reading; not seen by a person yet.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 18 (L381) (at 7993914c). specs/168-probe-artefacts/fix-log.md, *Recorded, not changed (product, from reading)*; the diagnostic there (a popup closed by the Find window's start-up, `probe/dialogs093_drive_failing_diag.txt`). At 7993914c: `src/menubar.cpp` ~314 `CMenuBar::EnterMenuInternal`.

## Expected

When the popup goes away for any reason the menu bar's loop ends, and typed characters reach the focused field.

## Approach

Reproduce first: 168's diagnostic showed the popup closed by the Find window's start-up - the same timing can drive the row "plain F in the menu bar loop" of 093's dialogs probe, NOT DRIVEN since 168.

## Notes

Severity 3 until a person sees it (reading only).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-21 — verified at fed08ad1: not reproduced: probe evidence/menubar_probe.ps1 on the hidden desktop - main window: Esc control keeps the loop (plain e opens a popup), WM_CANCELMODE, WA_INACTIVE and another window opening end it; Find window: every self-closed popup left qm reaching the Named field. The thread hook sends WM_USER_CLOSEMENU to the menu bar too
- 2026-10-21 — blocked: not reproduced at fed08ad1: a popup closed by activation, cancel-mode or by itself ends the menu bar loop too (thread hook closes every menu window); typed characters reach the field - evidence/menubar_probe_result_fed08ad1.txt
- 2026-10-21 — side observation: on the hidden desktop the Find window menu bar loop did not stay even after F10 or Esc (its control rows FAIL), unlike 168 runs; the 093 probe comment that a left-running loop swallowed later Alt+letters is not supported - an ended loop let the probe Esc reach the Find window (close question)
