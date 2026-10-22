---
title: Quick search ignoring accents: check with a real keyboard
type: person-step
status: new
severity: 2
area: panels-ui
source: leftover:313
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [quick-search-keys-skip-canonical-reordering-of-combining]
depends-on: []
reason: -
---

# Quick search ignoring accents: check with a real keyboard

## Problem

Feature 313 made quick search (the new mode of feature 244, *Configuration > Panels > Quick search
finds text anywhere in names*) ignore accents. Its hidden-desktop probe types with synchronous
`WM_CHAR` messages to the panel's list box; a real keyboard - a Czech or German layout, dead keys,
Left / Right / Backspace pressed by hand - was not used (no real keyboard on the hidden desktop).

## Evidence

Feature 313: `specs/313-quick-search-diacritics/fix-log.md` (sections *measured*, *Review*),
probe `specs/313-quick-search-diacritics/probe/qs313_probe.ps1` rows D01-D16 (all PASS in
`probe/result_after.txt`), `quickstart.md`.

## Expected

Each step below gives the stated result on a build that contains feature 313, with the option on
(the default).

## Steps

- [ ] A folder holding `žluťoučký` (a folder) and `zlutý.txt`: type `zlut` with an English layout -> both are shown, nothing else.
- [ ] The same folder, Czech layout: type `žlut` (the `ž` key, or a dead caron + `z`) -> both are shown.
- [ ] `Straße.txt` and `Strand.txt`: type `strasse` -> only `Straße.txt` remains; the directory line shows the whole typed text `strasse`.
- [ ] `Straße.doc` and `Straße.txt`: type `stras`, then press Right four times -> the text grows to `Straße.do` and only `Straße.doc` stays.
- [ ] A file whose name is stored decomposed (for example copied from a Mac, `r` + combining caron + `eka.txt`): type `r`, press Left once -> the search ends and all names show again.
- [ ] Option *Quick search finds text anywhere in names* switched off: type `zlut` -> the cursor goes to `zlutý.txt`, `žluťoučký` is not found (the earlier rule keeps accents).

## Log

- 2026-10-23 — created (source leftover:313)
