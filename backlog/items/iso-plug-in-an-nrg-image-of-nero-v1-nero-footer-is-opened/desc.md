---
title: ISO plug-in: an NRG image of Nero v1 (NERO footer) is opened without its track table
type: bug
status: open
severity: 4
area: archives
source: measure:365
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: [iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size]
depends-on: []
reason: -
---

# ISO plug-in: an NRG image of Nero v1 (NERO footer) is opened without its track table

## Problem

Nero writes two forms of `.nrg`: v2 ends with "NER5" and a 64-bit offset of its chunks (DAOX, ETN2, ...),
v1 (older Nero versions) with "NERO" and a 32-bit offset (DAOI, ETNF, ...). The ISO plug-in reads the track
table only from a v2 footer: a v1 image falls to the plain detection (`CheckForISO` at sector 16, then
`CheckForNRG` at 0x4B000), which lists only the volume found there - for a multi-session or mixed-mode v1
image the other sessions / tracks are not listed, and their layout (2336 / 2352-byte sectors) may not be
found at all. Whether a whole Unpack with "Delete archive after unpacking" then deletes such an image
(features 353 / 354 / 355 mark some plain-detected images whose rest lies past the volume) is not
measured.

## Evidence

- At 41f18c08 (`main` before feature 365), `src/plugins/uniso/nrg.cpp` `CISOImage::ReadSessionNRG`: seeks
  to file size - 12 and `ReadNRGRoot` returns FALSE unless the 4 bytes there are "NER5" (by reading).
- libmirage `libmirage/images/image-nrg/parser.c` (read in feature 365's research, fix-log section
  *Research*): a "NERO" footer at file size - 8 with a 32-bit chunk offset, `old_format = TRUE`, then
  "DAOI" / "ETNF" chunks with 32-bit fields (DAOI entries 30 bytes).
- Feature 365 fixed `readETNF`'s sector sizes, but an ETNF chunk is reached only inside an NER5 image (as
  the probes of 334 / 335 / 365 build them).
- Not measured: no v1 image was made.

## Expected

A v1 image's chunks are read like a v2 image's (32-bit chunk offset from the "NERO" footer; DAOI entries
with 32-bit offsets; ETNF as today), so every session and track is listed; measured with a crafted v1
image (feature 365's `probe/img365.py` style) before and after, and a whole Unpack deletes the image only
when everything was listed.

## Notes

- The DAOX reader would need a 32-bit variant (DAOI: 18 common bytes + three 32-bit offsets).
- Related: the ETNF size bound item (the same reader).

## Log

- 2026-11-01 — created (source measure:365)
- 2026-11-01 — moved to Next position 34
