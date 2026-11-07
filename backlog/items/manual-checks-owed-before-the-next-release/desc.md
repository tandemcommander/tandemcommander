---
title: Manual checks owed before the next release
type: person-step
status: open
severity: 5
area: build-release
source: manual
who: person
created: 2026-11-06
updated: 2026-11-07
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Manual checks owed before the next release

## Problem

Autonomous runs leave checks only a person can do: a real keyboard, mouse, clipboard or IME, another machine, admin rights, the look on a real screen. Until 2026-11-06 each such check became a `person-step` item of its own, and they piled up (97 of 99 *Person steps* items came from features' leftovers). From now on, every run appends its checks to this **one** checklist instead, and the maintainer works through it before a release.

## Evidence

The maintainer's rule of 2026-11-06 is recorded in:
- `/tandem-backlog-implement` `stop-rules.md` rule 9 (runs append lines here) and rule 11 (findings of severity 5 or less are fixed inside the feature);
- the exception in `/tandem-backlog` `SKILL.md` §0.3 (a run may only append lines, never change or remove them);
- `CLAUDE.md` *Working method*.

The *Person steps* items recorded before that day stay where they are.

## Expected

Before the release, every line below is ticked (`BL step <slug> <n> --done`). Or its failure has become an *Inbox* item named in the line's note. Then the maintainer closes this item. The first run after the release opens a new checklist.

## Steps

- [ ] Before the release: work through every unticked line below; each names the feature it comes from and the expected result
- [ ] Panel tab strip on a real screen at 100 %, Default and Dark theme: the rounded active tab with feet, location icons (folder, drive, archive, an SFTP tab), the hover pill and the hover circles of the X and + follow the real mouse and disappear when it leaves the strip (feature 404)
- [ ] Live tab drag with a real mouse: the tab follows the cursor, neighbours slide aside smoothly (about 150 ms), the tab glides into place on release; Esc during a drag puts every tab back; with Windows *Animation effects* off the tabs jump instead of gliding (feature 404)
- [ ] Close on release with a real mouse: pressing a tab's X shows it pressed and does not switch the tab; releasing over the X closes it, releasing elsewhere closes nothing (feature 404)
- [ ] Panel tab strip at 125 % and 150 % display scaling and under Windows High Contrast: metrics scale, icons sharp, texts readable (feature 404)
- [ ] Tab context menu: *Move to Other Panel* moves a folder tab and an SFTP tab (a second connection opens in the other panel, the first closes); *New Tab as Other Panel* opens the other panel's location; both greyed where the contract says (single tab, empty strip) (feature 404)
- [ ] Tab switch that asks a question, with a real mouse (GitHub issue #22): with an FTP connection in one tab of a panel, click another tab of the same panel, answer the FTP question with the mouse (*keep the connection*), then move the mouse over the strip and click a file in the panel -> no insert mark follows the mouse, the click goes to the panel, no tab moves; a tab dragged with the button held still moves (feature 405)
- [ ] Registry Editor, **elevated** (Run as administrator), Move of an HKEY_CLASSES_ROOT key held by both halves: as admin create a scratch key `HKLM\Software\Classes\.tc406` with a value `m` = `1` and a subkey `S`, and as the user `HKCU\Software\Classes\.tc406` with a value `u` = `2` and a subkey `S`; F6 `\HKEY_CLASSES_ROOT\.tc406` into `\HKEY_CURRENT_USER\Software\` -> no box, the copy holds `m`, `u` and `S`, both halves of `.tc406` are gone and HKCR no longer shows it. Repeat with the user's value named `m` = `9` -> the box "Unable to remove the original registry key. (50) The request is not supported." names `HKEY_LOCAL_MACHINE\Software\Classes\.tc406`, the machine's half is kept; delete the scratch keys afterwards (feature 406)

## Log

- 2026-11-06 — created (source manual)
- 2026-11-06 — body written: the release checklist runs append to (maintainer rule 2026-11-06)
- 2026-11-06 — moved to Person steps position 1
- 2026-11-06 — feature 404: 5 checks of the variant F tab strip
- 2026-11-06 — feature 405: 1 check of a tab switch that shows a question
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
