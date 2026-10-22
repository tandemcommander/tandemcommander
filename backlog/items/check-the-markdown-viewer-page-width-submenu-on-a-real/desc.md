---
title: Check the Markdown Viewer Page Width submenu on a real screen and in eight languages
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:314
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [mdview-page-width-levels]
depends-on: []
reason: -
---

# Check the Markdown Viewer Page Width submenu on a real screen and in eight languages

## Problem

Feature 314 (View > Page Width in the Markdown Viewer) was verified on the hidden desktop by
posted messages and PrintWindow captures only. The real mouse and keyboard, the dark-menu
rendering of the radio bullet, two windows on a visible screen and the translated menu texts
were not seen by a person.

## Evidence

- `specs/314-mdview-page-width/fix-log.md`, *Owed*; `quickstart.md` step 5.
- `probe/result_after.txt` of 314: 16 PASS rows (menu, each level's text width, stored value,
  restart, two windows, unknown and wrong-type values) - all driven by posted messages.

## Expected

All steps below as described; anything else is recorded as a new Inbox item.

## Steps

Do these after the two-stage `.slt` refresh of the mdview module (feature 314's stop record).

- [ ] Open a Markdown file with a wide table (e.g. 20+ columns) with F3 and maximise the window:
  View > Page Width shows Normal, Wide, Wider, Full Window with Normal checked; the page looks as
  before 314.
- [ ] Choose each level with the mouse: the text column widens Normal < Wide < Wider < Full
  Window at once; in Full Window the table needs no horizontal scroll bar when the window is wide
  enough; the margins stay.
- [ ] With the keyboard: Alt+V, W, then N / W / D / F choose the levels (mnemonics work, also in
  the dark theme - Options > Theme Dark - where the checked level shows a radio bullet).
- [ ] View Source (Ctrl+U) uses the chosen width too; zoom (Ctrl++ / Ctrl+-) still works at every
  level.
- [ ] Close the viewer, open another .md: the last level is checked and used; restart the
  program: still used.
- [ ] Two viewer windows: choosing a level in one does not change the other's page; the level
  chosen last is used by the next window.
- [ ] Switch the program language (Czech, German, French, Dutch, Hungarian, Romanian, Slovak,
  Spanish): the submenu and its four items are translated and their mnemonics are unique.
- [ ] Run `specs/081-mdview-shared-webhost/probe/mdview_probe.ps1 -Scenario all` on a visible
  desktop (with the registry key backed up): all checks pass.

## Log

- 2026-10-23 — created (source leftover:314)
- 2026-10-23 — moved to Inbox
- 2026-10-23 — moved to Person steps position 35
