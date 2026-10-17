---
title: Real keyboard and IME pass: menu mnemonics, Czech layout, rows of 124-130
type: person-step
status: open
severity: 5
area: encoding
source: leftover:093
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [ftp-real-server-checks-090-116-121, zip-sftp-passwords-real-keyboard-086-094, clipboard-drag-mouse-routes-099-101-107-119-121]
depends-on: []
reason: -
---

# Real keyboard and IME pass: menu mnemonics, Czech layout, rows of 124-130

## Problem

Probes post window messages; they cannot press keys. Feature 093 (text outside the code page in dialogs) owes a real-keyboard pass - menu mnemonics in the main window and Find first, typing with a Czech layout, an input method editor, a mouse drag onto the command line - and features 124-130 recorded rows as NOT DRIVEN in their fix-logs for the same reason (real keyboard).

## Evidence

Migrated from specs/NEXT-WORK.md header 'Before 0.1.10 - steps owed to a person' point 4 and §B 'By hand' ('the real-keyboard / IME pass of 093 (menu mnemonics first, a mouse drag onto the command line)') (at 7993914c). Steps: specs/093-unicode-dialogs/quickstart.md 'Owed to a person (a real keyboard; Release build)' 1-6; the NOT DRIVEN rows in specs/124-regedt-key-text/fix-log.md, specs/125-unc-server-shares/fix-log.md, specs/126-package-api-late-bind/fix-log.md, specs/127-mixed-template-texts/fix-log.md, specs/128-shortcut-target-unicode/fix-log.md, specs/129-regedt-wide-inserts/fix-log.md, specs/130-plugin-mixed-templates/fix-log.md.

## Expected

Every step below done on a Release build and recorded in the feature's fix-log; any failure becomes a new item.

## Notes

Fourth of the four person steps owed before 0.1.10 (`backlog/RELEASE.md`, *Current release*). Overlapping rows written for the visible desktop are the person steps `clipboard-and-screen-rows-124-127` (mixed_probe.ps1 -Only COPYNAME,CLIPMSG,CLIPREG) and `unc-wait-window-esc-and-exit` (unc_probe.ps1 -Only W2, Esc in 125's wait window) - one session can do all three. 093's 'Not testable here': a system with a double-byte code page; a keyboard layout whose code page differs from the system's. Step 4's extra rows come from 093's second *Not driven / open* list (`specs/093-unicode-dialogs/fix-log.md` L565-580, items 1-5); its item 5 is a behaviour change to confirm, not a defect: the word-break routine no longer treats a character the code page maps to a delimiter by best fit (e.g. a full-width full stop) as a delimiter.

## Steps

- [ ] 093 step 1 (first): main window Alt+L, F, E, C, P, O, R, H open their menus, a letter picks an item, Esc closes; Find Files (Alt+F7) Alt+F, M, E, V, O the same; with a Czech layout Alt + an accented letter does nothing unexpected
- [ ] 093 step 2: Find Files in a folder named in Cyrillic or Chinese (Czech Windows) - Look in shows the real name; a mask with such characters finds the file; the histories show the text
- [ ] 093 step 3: Configuration - Hot Paths and User Menu keep such text after OK and reopen; in-place rename (F2) of a list item
- [ ] 093 step 4: command line - Ctrl+Enter on 日本.txt, typing and pasting such text, Ctrl+Backspace, Ctrl+Left/Right, Home/End, Shift selection, a mouse drag of a file onto the command line, copy nul "<such a name>", recall from history (Ctrl+E); also (093 fix-log L565-580) Ctrl+Shift+Enter (short name), Ctrl+[ / Ctrl+] / Ctrl+Space (path insertion), Alt+Enter, Tab, a double click on a word, the selection a plug-in file system returns, a real OLE drag with the insert mark painted, and a full-width full stop (or another character the code page maps to a delimiter by best fit) is no longer a word break for Ctrl+Left / Right
- [ ] 093 step 5: 7-Zip passwords - pack a 7z with heslo-ř and open it in 7-Zip; an 0.1.8 archive with an accented password; a wrong password gives one message; F3 inside an encrypted archive, then another file - no second prompt
- [ ] 093 step 6: an input method editor (Chinese / Japanese) in Find, Configuration and the command line
- [ ] 124-130: the rows recorded as NOT DRIVEN (real keyboard) in each fix-log

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — moved to Person steps position 4
- 2026-10-17 — migration review M1/N3/N12: fourth of the four steps owed before 0.1.10; step 4 extended with the rest of 093 fix-log L565-580; migration remarks replaced by slugs
