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
- [ ] Find (Ctrl+F) with a real mouse and keyboard, Default and Dark theme: search a folder with sub-folders, click the Date header twice and press Ctrl+F5 twice in the result list - the order reverses each time (folders stay first) and the Date header shows the arrow up, then down; Find again - no arrow. The Registry Editor's Find window: a second click on a column header reverses the order, the arrow shows (feature 407)
- [ ] Markdown Viewer, real mouse and clipboard, Default and a dark scheme (F9): open a .md file with several code blocks (one with Czech and an emoji, one in a list, a Makefile block with tab-indented lines); hover a block - *Copy* appears in its top-right corner; click - a native notice at the viewer's bottom right shows *Copied* and the first lines, gone after about 2.5 s; paste into Notepad - exactly the block's code, the Makefile's tabs kept, Windows line breaks, no extra last line; Tab to a control + Enter copies too and the focus stays there; the page never scrolls (feature 408)
- [ ] Markdown Viewer select-all: Ctrl+A, Ctrl+C on a page with code blocks, paste - the *Copy* labels are not in the pasted text (feature 408)
- [ ] Markdown Viewer copy control on a touch screen or pen, if available: one tap on a block's top-right corner copies and shows the notice (feature 408)
- [ ] Backlog app state folder repaired on the maintainer's tree: start the app once (`bin/start-backlog-app.sh`), then `Get-Acl` over `.git/tandem-backlog-app` shows no entry with an empty protected DACL (`D:PAI` alone; 375 before), `main-worktree/.git` and `events.jsonl` readable, and a change made in the app during a run lands on `main` (feature 412)
- [ ] Panel tab drag to the first place with a real mouse: in the left and in the right panel drag a tab that is not the first one to the left end of the strip and release - it becomes the first tab; with more tabs than fit, it becomes the first of the tabs shown (feature 413)
- [ ] Panel tab strip, Default and Dark theme side by side (also at a scaling other than 100 %): the strip looks equally high in both; in the Dark theme the inactive panel's active tab is a visible rounded tab (a lighter grey than its directory line, its title readable), likewise with a user colour scheme whose caption colour is close to the strip; tell whether the Dark theme still looks lower anywhere (feature 413)
- [ ] Toolbar icons on a real screen, Default and Dark theme, at your usual display scaling: with no choice made the program shows the Fluent 2 set - top and panel toolbars, drive bar and Change Drive menu, the `..` symbol of the file list, the toolbars of the configuration lists - legible and consistent; Configuration > Appearance > Toolbar icons shows both previews, Classic + OK switches at once (no restart) to exactly the 0.2.0 look, Fluent 2 + OK switches back (feature 416)
- [ ] Menus with icons (Files, Commands, the panel context menus) in the Fluent 2 set, both themes, with a real mouse or keyboard: every icon stays recognisable on the highlighted row and greyed items stay readable (feature 416)
- [ ] Toolbar buttons hot and pressed with a real mouse, both icon sets and both themes: no icon disappears; disabled buttons stay discernible (feature 416)
- [ ] Fluent 2 icons at 125 %, 150 % and 200 % display scaling: sharp, centred in their buttons, not clipped (toolbar, drive bar, `..`, the Appearance previews) (feature 416)
- [ ] Configuration > Appearance in Czech and German: the Toolbar icons group, its two choices and previews fit and read well (feature 416)
- [ ] Plug-in icons with a real mouse or keyboard in the Fluent 2 set, Default and Dark theme: the Plugins menu and each plug-in submenu, View With (F3 menu) and Help > About Plugin - every plug-in shipped with the program shows its Fluent 2 icon (DBViewer, PEViewer, TAR, UnCAB too), legible on the highlighted row, disabled items readable; with Classic exactly the old icons (feature 417)
- [ ] Plugins bar (Options > Toolbars > Plugins Bar) hot and pressed with a real mouse, Fluent 2, both themes: no plug-in icon disappears; its drop-down menus open as before (feature 417)
- [ ] Plug-in icons at 125 %, 150 % and 200 % display scaling, Fluent 2: sharp in the Plugins bar, the Plugins Manager, Alt+F1, the drive bar and the tab / Directory line of an FTP or Windows Registry file system (feature 417)
- [ ] Configuration > Appearance in Czech and Spanish: the group now reads "Styl ikon" / "Estilo de iconos" (English "Icon style"), fits and reads well; Alt+I (Czech) reaches it (feature 417)

## Log

- 2026-11-06 — created (source manual)
- 2026-11-06 — body written: the release checklist runs append to (maintainer rule 2026-11-06)
- 2026-11-06 — moved to Person steps position 1
- 2026-11-06 — feature 404: 5 checks of the variant F tab strip
- 2026-11-06 — feature 405: 1 check of a tab switch that shows a question
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — edited Steps
- 2026-11-07 — feature 408: 3 checks added
- 2026-11-07 — feature 412: one check added
- 2026-11-07 — edited Steps
- 2026-11-07 — feature 416: 5 checks added
- 2026-11-07 — feature 417: 4 checks added
