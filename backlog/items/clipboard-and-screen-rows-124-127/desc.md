---
title: Clipboard and real-screen rows of 124 and 127 (Registry Editor, messages)
type: person-step
status: open
severity: 3
area: encoding
source: leftover:127
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Clipboard and real-screen rows of 124 and 127 (Registry Editor, messages)

## Problem

Rows of features 124 and 127 that need the clipboard or a real screen (the hidden desktop has no clipboard; the probe may not overwrite a clipboard holding non-text data).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L849, L852-854, L857-865. Commands in the *Second verification* sections of `specs/124-regedt-key-text/fix-log.md` and `specs/127-mixed-template-texts/fix-log.md`; `specs/127-mixed-template-texts/probe/mixed_probe.ps1 -Only COPYNAME,CLIPMSG,CLIPREG`.

## Expected

Pasted texts are exact and readable; the new name and the queued title read as given.

## Steps

- [ ] A look at the Registry Editor panel on a real screen in Czech and in German (124)
- [ ] Czech: Registry Editor *Copy Name* on `(Výchozí)` and on a key `příliš` -> paste gives the exact text (124)
- [ ] Czech: Ctrl+C in an error box that names a file (e.g. Copy of a folder with an unreadable subfolder) -> the pasted text is readable, caption and body (127)
- [ ] Slovak: Ctrl+C / Ctrl+V of a file in its own folder -> the new name reads `a - Kópia.txt` (127)
- [ ] Czech: the title of a queued Copy reads `(čekající) Kopírovat ...` (127)
- [ ] Or run `mixed_probe.ps1 -Only COPYNAME,CLIPMSG,CLIPREG` on an unlocked visible desktop

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
