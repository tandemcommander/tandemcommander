---
title: Check Copy UNC Path on a subst drive with a long non-ASCII target
type: person-step
status: open
severity: 3
area: long-paths
source: leftover:301
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check Copy UNC Path on a subst drive with a long non-ASCII target

## Problem

Feature 301 made *Copy UNC Path + Name as Text* (Ctrl+Shift+Insert) build the path of a file on a subst drive from the exact
subst target (or say the path is too long) instead of a code-page `?` target. The command writes
to the clipboard, which the hidden desktop of the probes does not have, so the change is checked
only by reading (`CopyUNCPathToClipboardAux` in `src/fileswn9.cpp`).

## Evidence

Feature 301 (`specs/301-subst-target-whole/quickstart.md` step 5; fix-log *Callers (T009)*, row
"`fileswn9.cpp` Copy as UNC"). Before 301 the subst target came from `MyQueryDosDevice`, which
fell back to the code-page `QueryDosDevice` for a target over 259 bytes of UTF-8 - `?` for every
CJK letter.

## Expected

The clipboard holds the exact `\\machine\share\...` path of the file, or the program shows its
"path too long" message - never a path with `?` and never a cut one.

## Steps

- [ ] Share a folder (or use an existing share), e.g. `C:\Share` shared as `Share`. In it make a
      folder named by 90 CJK letters (copy them from any CJK text) and a file `f.txt` inside.
      In a command prompt: `subst Z: "C:\Share\<the CJK folder>"`.
- [ ] Tandem Commander: open `Z:\`, focus `f.txt`, Edit > *Copy UNC Path + Name as Text*
      (Ctrl+Shift+Insert); paste into Notepad -> `\\<machine>\Share\<the CJK folder>\f.txt`
      exactly, every letter as in the folder name (no `?`).
- [ ] The same on a folder of `Z:\` whose whole UNC path passes 520 bytes (nest two more CJK
      folders of 90 letters) -> the program says the path is too long; the clipboard is not a
      cut path.
- [ ] `subst Z: /d`; stop sharing the test folder.

## Log

- 2026-10-22 — created (source leftover:301)
- 2026-10-22 — title: the real menu command name
- 2026-10-22 — moved to Person steps position 29
