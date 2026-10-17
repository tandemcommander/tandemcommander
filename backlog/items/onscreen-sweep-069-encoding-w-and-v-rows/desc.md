---
title: On-screen sweep of 068/069: F1-F8, W1-W20 in cs and hu, V-01 to V-24, G7
type: person-step
status: open
severity: 4
area: encoding
source: leftover:069
who: person
created: 2026-09-02
updated: 2026-10-17
verified: -
effort: L
feature: -
related: []
depends-on: []
reason: -
---

# On-screen sweep of 068/069: F1-F8, W1-W20 in cs and hu, V-01 to V-24, G7

## Problem

Feature 069 (finish the encoding fixes) is green in everything automatable, but its on-screen sweep is owed, and so is 068's: first 068's fix verification F1-F8 (F1 is the crash fix of a long accented name on the command line), then the 068 sweep W1-W20 in the Czech UI and then the Hungarian UI (proving 069 did not disturb what earlier features repaired), followed by V-01...V-24 from 069's quickstart.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'On-screen sweeps' ('069 §4 (W1-W20, V-01...V-24)') and §3 '069 §4' (~line 1114) (at 7993914c). Detail: specs/069-finish-encoding-fixes/REMAINING-WORK.md §4 'Still owed: the on-screen sweep (maintainer)' (fixtures recreated by the script in quickstart.md 'Fixtures': D:\Zkouška\Můj disk\, ...\Árvíztűrő tükörfúrógép\, ...\surrogate\, %TEMP%\salamander-test\perf with 100,000 files); specs/069-finish-encoding-fixes/quickstart.md (V-rows). 068's fix-verification rows F1-F8 ("Start here: verifies the three highest-consequence fixes", F1-F3) and the English spot-check: specs/068-encoding-regression-review/review-report.md §10.1 (L531-549) and §9 gate G7 (L518, "partial - automated part PASS ... the on-screen English comparison ... is part of the user's manual pass"); specs/068-encoding-regression-review/REMAINING-WORK.md §4 (L384-397); RW069 §4 L163-164 (G7). Added by the migration review (`specs/242-backlog-system/ledger/review.md`, M4).

## Expected

W1-W20 pass in Czech and Hungarian, V-01...V-24 pass; results recorded in 069's records; any failure goes back through fix, independent review and gates.

## Notes

The side-by-side reference tree Release_x64_prefix069\ no longer exists (checked 2026-09-24: build\tandemcommander\ holds only Release_x64 and translator). Only side-by-side rows need a reference; rebuild it from git in a separate worktree at 64dcbb5 (the commit before 069's first), Release x64 - and only for a row that actually needs the comparison. 068's reference `Release_x64_prefix\` is gone as well (NEXT-WORK, revision of 2026-09-24); 068's baseline commit is `c577ff3` (review-report §9, G7). 068's F8 caveat (verify the File Comparator title on a text comparison, deferred item D04) no longer applies: D04 was fixed by 069. RW068 §4 and RW069 §4 are the same entry.

## Steps

- [ ] Recreate the fixtures with the script in specs/069-finish-encoding-fixes/quickstart.md ('Fixtures')
- [ ] 068 §10.1 F1 (start here): in `D:\Zkouška\Můj disk\` focus `žluťoučký kůň.docx`, Ctrl+Enter, then Ctrl+Space, Ctrl+[, Ctrl+]; repeat in a folder with a very long path - the name / path appears on the command line and the program does NOT disappear
- [ ] 068 §10.1 F2: with `%TEMP%` under an accented profile, F3-view a file inside a ZIP, exit, look in `%TEMP%` for `SAL*.tmp`; restart - none left behind; if any exist from before, the start-up prompt appears and deleting them works
- [ ] 068 §10.1 F3: hot path `Můj disk` -> `D:\Zkouška\Můj disk`; right-click the taskbar icon - the entry reads `Můj disk` and clicking it opens that folder
- [ ] 068 §10.1 F4: on `D:` enter `D:\Zkouška\Můj disk`, switch to another drive, exit, restart, return to `D:` - the panel returns to `...\Můj disk`, not to `D:\`
- [ ] 068 §10.1 F5: Czech (also sk / hu / de / es) Plugins > Plugins Manager, select UnDelete or Portables - the "Show in Change Drive menu" label and the plug-in name are readable
- [ ] 068 §10.1 F6: Detailed view, Full row select off, drag a selection rectangle past `žluťoučký kůň.docx` - only files the rectangle touches are selected
- [ ] 068 §10.1 F7: extract onto an existing accented file inside a ZIP - the name is readable in the overwrite prompt
- [ ] 068 §10.1 F8: Czech / French / Hungarian / Slovak, compare two files with accented names in the File Comparator - the window title is present and readable
- [ ] 068 sweep W1-W20 in the Czech UI
- [ ] 068 sweep W1-W20 in the Hungarian UI
- [ ] V-01...V-24 from 069's quickstart.md, starting with V-01 (command line), V-09 (help and config.reg under an accented install path), V-11 (cloud entries)
- [ ] G7 English spot-check (068 gate G7 "partial", review-report L518; 069 §4): W1-W6 and W13 in the English UI against a pre-fix reference - rebuild it if needed (Release x64 from 64dcbb5 for 069, from 068's baseline c577ff3 for 068's fixes) - the surfaces look the same
- [ ] Only where a row needs a side-by-side comparison: build the reference from 64dcbb5 (Release x64) in a separate worktree

## Log

- 2026-09-24 — the reference tree Release_x64_prefix069 is gone from the build folder (checked)
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — migration review M4: 068 §10.1 F1-F8 and gate G7 (English spot-check of W1-W6, W13) added as steps
- 2026-10-17 — title shortened to 80 characters
