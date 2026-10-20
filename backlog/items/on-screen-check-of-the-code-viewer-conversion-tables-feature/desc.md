---
title: On-screen check of the Code Viewer conversion tables (feature 262)
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:262
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [onscreen-pass-codeview-070-074]
depends-on: []
reason: -
---

# On-screen check of the Code Viewer conversion tables (feature 262)

## Problem

Feature 262 lets the Code Viewer read a single-byte file through the product's conversion tables. Its hidden-desktop probe drives the menu, the status bar and the stored setting (16 rows PASS), but not the letters themselves: they are drawn in the WebView2 page, which no probe reads. Nor does it press F8 / Shift+F8 on a real keyboard inside the page; the probe posts the commands those keys map to.

## Evidence

specs/262-codeview-code-tables/fix-log.md *NOT DRIVEN (owed to a person)*; quickstart.md *By a person*; probe specs/262-codeview-code-tables/probe/cvtab262_probe.ps1 (result_after.txt). The table pass itself is checked by saltests TestCodeTable262 on the same bytes.

## Expected

On a real desktop the letters read right after choosing the table, the keys cycle the list, and the remembered table works as the probe showed.

## Steps

- [ ] CP1250 machine, F3 on src/plugins/codeview/test/corpus/encodings/cp852.bat: wrong letters, status bar `ANSI`; View > Encoding shows the five entries, a separator and the tables in the order of the built-in viewer's Convert menu.
- [ ] Choose *CP852 - CP1250*: the first line reads "Příliš žluťoučký kůň úpěl ďábelské ódy", the status bar names the table, the item is checked.
- [ ] F3 on iso8859-2.ini, choose *ISO-8859-2 - CP1250*: the same sentence.
- [ ] With the page focused, press F8 and Shift+F8: the next / previous table is applied (status bar); the remembered table does not change (close, F3 on cp852.bat again: still the table chosen from the menu).
- [ ] Restart the program, F3 on cp852.bat: read through the remembered table at once; F3 on utf8-nobom.cpp: unchanged; View > Encoding > System code page: today's letters again, also on the next file.

## Log

- 2026-10-20 — created (source leftover:262)
- 2026-10-20 — moved to Person steps position 12
