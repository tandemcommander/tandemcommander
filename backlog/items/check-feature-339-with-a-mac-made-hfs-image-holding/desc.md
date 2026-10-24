---
title: Check feature 339 with a Mac-made HFS+ image holding compressed files
type: person-step
status: new
severity: 6
area: archives
source: leftover:339
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [check-feature-332-with-a-mac-made-hfs-disc-image]
depends-on: []
reason: -
---

# Check feature 339 with a Mac-made HFS+ image holding compressed files

## Problem

Feature 339 makes the ISO plug-in refuse an HFS+ file whose content is HFS+ compressed or only in its resource
fork (a box with Skip / Skip all / Cancel; the file is not written; a whole unpack keeps the image). It was
verified only with images crafted from an xorriso HFS+ hybrid (no Mac on this machine). Whether a real macOS
image carries the compressed flag the way the rule expects, and that ordinary files of such an image still
extract, needs a person with a Mac.

## Evidence

- `specs/339-uniso-hfs-fork-content/fix-log.md` (*Measurement after*), `spec.md` *Assumptions* ("A check with a
  Mac-made image with compressed files is owed to a person"), probe `probe/iso339_probe.ps1` (crafted rows
  H-RSRC, H-COMP, H-COMPIN, H-FLAG).
- The rule: `src/common/salhfscatalog.h` `SalHfsFileContentKind` (UF_COMPRESSED 0x20 in the BSD owner flags
  when the file mode's type bits are not 0; else an empty data fork beside a non-empty resource fork).

## Expected

On a Mac-made HFS+ image the compressed and resource-fork-only files are refused with the box and the image is
kept; ordinary files extract with their content.

## Steps

- [ ] On a Mac: make a folder with an ordinary text file `plain.txt`, a compressed copy of a text file
      (`ditto --hfsCompression src.txt comp.txt`; `ls -lO comp.txt` shows `compressed`), and a folder with a
      custom icon (Finder > Get Info > paste an icon; it creates the file `Icon\r`, data fork empty). Make an
      HFS+ image of it: `hdiutil create -fs HFS+ -srcfolder <folder> -format UDTO test.cdr`, rename it
      `test.iso`.
- [ ] In Tandem Commander, open `test.iso` and press Alt+F9 with "Delete archive after unpacking" checked:
      one "Error" box says `comp.txt` is compressed by the HFS Plus file system; one says the icon file's
      content is stored only in its resource fork. Answer Skip to each -> `plain.txt` is extracted with its
      content, `comp.txt` and `Icon` are not written, and `test.iso` is KEPT.
- [ ] Repeat answering Skip all at the first box -> no second box, the image kept.
- [ ] Copy (F5) `plain.txt` out of the opened image -> copied with its content, no box.
- [ ] Record the result (and `ls -lO` of the files) in the item's *Log*; a compressed file that extracts empty
      without a box means macOS wrote it differently than the rule expects.

## Log

- 2026-10-24 — created (source leftover:339)
- 2026-10-24 — set related=check-feature-332-with-a-mac-made-hfs-disc-image
