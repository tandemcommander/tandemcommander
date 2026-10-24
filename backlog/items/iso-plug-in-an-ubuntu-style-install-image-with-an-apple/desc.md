---
title: ISO plug-in: an Ubuntu-style install image with an Apple partition map shows Cannot read sector #00000200
type: bug
status: open
severity: 3
area: other-plugins
source: measure:333
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot]
depends-on: []
reason: -
---

# ISO plug-in: an Ubuntu-style install image with an Apple partition map shows Cannot read sector #00000200

## Problem

Unpacking (Alt+F9) an ISO image laid out like Ubuntu's / Debian's install images (xorriso
`-isohybrid-mbr -isohybrid-apm-hfsplus` with an EFI boot image: an Apple partition map whose
`Apple_HFS` partition "EFI" holds the EFI image) shows the message box "Cannot read sector #00000200."
(UnISO). The files are listed and extracted; the user sees an error for an image that is fine.

## Evidence

- Measured during feature 333 at e9f777da and after its change, the same:
  `specs/333-uniso-hfs-part-missing/probe/result_before.txt` / `result_after.txt`, row APM-EFI
  (`iso333_probe.ps1`; image `apm.iso` from `probe/mkimg333.sh` - zero-filled boot images, an MBR
  template of 432 bytes starting `33 ED` + 30 NOPs). The probe counts the box as known and does not fail
  on it.
- `IDS_ERROR_READING_SECTOR` ("Cannot read sector #%08X.") is shown not quietly by
  `src/plugins/uniso/iso9660.cpp` (about line 1190, `Error(IDS_ERROR_READING_SECTOR, FALSE, sector -
  ExtentOffset)`), and quietly-or-not by `xdvdfs.cpp` `CXDVDFS::Open` (sector 0x20), `udf.cpp`.

## Expected

Such an image opens and unpacks without an error message.

## Notes

Not verified: whether the box comes at the open or during the extraction, which reader shows it, and
whether real Ubuntu images (with a real isolinux and a FAT EFI image) show it too - the probe's boot
images are zeros. It may share its cause with the related item (a valid xorriso HFS+ hybrid shows
"Cannot read sector #00000020." - the Xbox reader's sector 0x20 read); 0x200 is 0x20 x 16.

## Log

- 2026-10-24 — created (source measure:333)
- 2026-10-24 — moved to Next position 72
