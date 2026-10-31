---
title: Check Shift+F6 rename in place with a real keyboard and an FTP/SFTP panel
type: person-step
status: open
severity: 3
area: panels-ui
source: leftover:346
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check Shift+F6 rename in place with a real keyboard and an FTP/SFTP panel

## Problem

Feature 346 was probed on the hidden desktop only: keys were sent as messages, and no plug-in file system panel was driven.

## Evidence

specs/346-shift-f6-inplace-rename/fix-log.md, sections Measured after and Review (N5).

## Expected

Each step below behaves as written.

## Steps

- [ ] Real keyboard, disk panel (Detailed view): focus `report.txt`, press Shift+F6 → an edit box opens over the name with `report` selected; type `report2`, Enter → the file is `report2.txt` and stays focused. Again Shift+F6, type something, Esc → nothing renamed.
- [ ] Real keyboard: Shift+F6 on a folder selects the whole name; on `..` nothing happens; inside a ZIP archive nothing happens; F2 still opens the *Quick Rename* dialog; Ctrl+Shift+F6 still restores the selection (Ctrl+Shift+F5 first).
- [ ] Detailed view scrolled horizontally (a narrow panel, name column partly out of view): Shift+F6 opens the edit inside the panel, over the name.
- [ ] Files menu shows *Rename in Place  Shift+F6* right after *Quick Rename...  F2*; it is greyed on `..` and in an archive; clicking it opens the edit. In German the shortcut reads `Umschalt+F6`.
- [ ] FTP or SFTP panel (a test server, e.g. the SFTP container on localhost:2222): Shift+F6 on a remote file opens the edit (or the plug-in's own rename dialog first, as a slow click does); Enter renames the file on the server; Esc cancels.
- [ ] After the help is compiled (HTML Help Workshop): Help > Keyboard Shortcuts lists Shift+F6; What's This (Shift+F1), then Files > Rename in Place opens *Changing the Name of File or Directory* (alias `CM_QUICKRENAMEINPLACE` in `help/src/salamand.hhp`).

## Log

- 2026-10-31 — created (source leftover:346)
- 2026-10-31 — moved to Person steps position 44
