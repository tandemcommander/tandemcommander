---
title: ISO plug-in: Rock Ridge names of xorriso images are not read, the ISO 9660 names are listed
type: bug
status: open
severity: 5
area: other-plugins
source: measure:322
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: 2026-10-23 2c033750
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: Rock Ridge names of xorriso images are not read, the ISO 9660 names are listed

## Problem

The ISO plug-in reads Rock Ridge names only when the first System Use entry of a directory record is
the `RR` entry. Rock Ridge 1.12 (RRIP) dropped that entry, and xorriso / libisofs - the tool most
Linux distributions build their images with - do not write it (genisoimage still does). Such images
list the plain ISO 9660 names: `top.txt` shows and is extracted as `TOP.TXT`, a file of a 200-letter
name as 31 upper-case letters. Names lose their case and length; two files can collide.

## Evidence

- Measured during feature 322 at a222bd88 (before its change) and after it, the same:
  `specs/322-uniso-hfs-btree-joliet/probe/result_before.txt` / `result_after.txt`, rows RR
  (`TOP.TXT`) and RR-LONG (31 letters; "the Rock Ridge name used False"); images from
  `specs/322-uniso-hfs-btree-joliet/probe/mkimg322.sh` (xorriso 1.5.6, `-joliet off`).
- `src/plugins/uniso/iso9660.cpp` `CISO9660::ExtractExtFileName`:
  `if (strncmp((char*)rrHeader.Signature, "RR", 2) == 0) ext = extRockRidge;` - checked on the first
  entry only. Feature 223's probe used a genisoimage image, which carries `RR`.

## Expected

Rock Ridge names are read from images without an `RR` entry (RRIP 1.12: recognise Rock Ridge by its
other entries - `NM`, `PX`, or the `SP` / `ER` of the root directory's first record), whole and
with their case; images with `RR` keep working.

## Notes

Not verified: how the SUSP `SP` / `ER` entries of xorriso's root record look; which detection keeps
the existing behaviour for every other image. Found while making valid seed images for feature 322.

## Log

- 2026-10-23 — created (source measure:322)
- 2026-10-23 — moved to Next position 5
- 2026-10-23 — verified at 2c033750: still present at 2c033750: iso322_probe RR lists TOP.TXT, RR-LONG 31 letters; root dot record has SP + CE->ER RRIP_1991A, no RR entry
