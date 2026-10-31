---
title: Check feature 349 with a Mac-made HFS+ image holding a moved folder
type: person-step
status: open
severity: 5
area: archives
source: leftover:349
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [check-feature-332-with-a-mac-made-hfs-disc-image]
depends-on: []
reason: -
---

# Check feature 349 with a Mac-made HFS+ image holding a moved folder

## Problem

Feature 349 makes the ISO plug-in list every HFS+ entry in its own folder whatever the catalog order: a
folder made first and moved (on a Mac) into a newer folder has a lower catalog ID than its new parent, so the
records inside it come before its own record - they were listed and unpacked at the root of `HFS (...)`. It
was verified only with images crafted from an xorriso HFS+ hybrid whose catalog was changed as macOS would
after a move (no Mac on this machine). Whether a real macOS image orders such a folder as expected needs a
person with a Mac.

## Evidence

- `specs/349-uniso-hfs-folder-order/fix-log.md` (*Measurement before*, *Checks*), `spec.md` *Assumptions*
  ("no Mac-made image is used - a person step to check one is owed"), probe `probe/iso349_probe.ps1`
  (crafted rows H-MOVE, H-LONG, H-CYCLE, H-STRAY by `probe/img349.py`).
- The rule: `src/common/salisonamefit.h` `CSalHfsFolderOrder`; the reader: `src/plugins/uniso/hfs.cpp`
  `CHFS::ListDirectory` / `TakePending` / `ListRecord`.

## Expected

On a Mac-made HFS+ image with a folder moved into a newer folder, the moved folder's files are listed and
unpacked inside it (not at the root of `HFS (...)`), and "Delete archive after unpacking" deletes the image
only when everything was extracted.

## Steps

- [ ] On a Mac: make a folder `old` with `old/a.txt` (text A) and `old/sub/s.txt` (text S); then make a
      folder `new` with `new/n.txt`; move `old` into `new` in Finder (`old` keeps its lower catalog ID).
      Make an HFS+ image of the parent folder: `hdiutil create -fs HFS+ -srcfolder <parent> -format UDTO
      test.cdr`, rename it `test.iso`.
- [ ] In Tandem Commander, open `test.iso`: under `HFS (...)` the folder `new` holds `old`, `old` holds
      `a.txt` and `sub` with `s.txt`; nothing of `old` at the root of `HFS (...)`.
- [ ] Alt+F9 (keep a copy of the image) with "Delete archive after unpacking" checked into an empty
      folder -> `new/old/a.txt` = A, `new/old/sub/s.txt` = S, `new/n.txt` under `HFS (...)`; nothing extra
      at the root of `HFS (...)`; the image deleted.
- [ ] Record the result in the item's *Log*; files of `old` at the root of `HFS (...)` mean macOS ordered
      the catalog differently than feature 349 expects.

## Log

- 2026-10-31 — created (source leftover:349)
- 2026-10-31 — moved to Person steps position 13
