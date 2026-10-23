---
title: ISO plug-in: a valid xorriso ISO + HFS+ hybrid opens with Cannot read sector 00000020
type: bug
status: new
severity: 3
area: other-plugins
source: measure:322
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a valid xorriso ISO + HFS+ hybrid opens with Cannot read sector 00000020

## Problem

Opening a valid ISO 9660 + Rock Ridge + Joliet + HFS+ hybrid image made by xorriso 1.5.6
(`-hfsplus on -joliet on`; it starts with an Apple partition map, `ER` with 2048-byte blocks) shows
the message box "Cannot read sector #00000020." (UnISO) before the listing. The text matches the
Xbox file-system reader's open, which reads sector 0x20 and reports a failure without honouring a
quiet probe. The user sees an error for an image that is fine.

## Evidence

- Measured during feature 322 at a222bd88 (before its change) and after it, the same:
  `specs/322-uniso-hfs-btree-joliet/probe/result_before.txt` / `result_after.txt`, row HYB
  (`iso322_probe.ps1`; image from `probe/mkimg322.sh`).
- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::Open` (line 74 at a222bd88):
  `Error(IDS_ERROR_READING_SECTOR, quiet, 0x20)`; `CISOImage::CheckForXbox` (`isoimage.cpp` ~572)
  and the file-system choice (`isoimage.cpp` ~1186-1206, `case fsXbox`).

## Expected

A valid xorriso hybrid opens without an error message; its ISO 9660 (and HFS+) parts are listed.

## Notes

Not verified: why the Xbox reader is chosen or run for this image, and why sector 0x20 cannot be read
(the image has 224 sectors of 2048 bytes) - perhaps the sector size taken from the Apple partition
map's block 0. Found while making valid seed images for feature 322; not part of that item.

## Log

- 2026-10-23 — created (source measure:322)
