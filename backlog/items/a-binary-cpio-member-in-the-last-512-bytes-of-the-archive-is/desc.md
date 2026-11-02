---
title: A binary cpio member in the last 512 bytes of the archive is not recognised
type: bug
status: new
severity: 4
area: archives
source: measure:395
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# A binary cpio member in the last 512 bytes of the archive is not recognised

## Problem

The TAR plug-in reads the old binary cpio format (magic 070707 as a little-endian short) only while
at least 512 bytes of the archive remain after the header: a member - or the `TRAILER!!!` member -
that starts within the last 512 bytes is "Archive format not recognised or not supported", and the
members from there on are neither listed nor extracted. A binary cpio padded to a 512-byte block
(the usual output) therefore seems to fail at its end; the operation fails (the archive is kept),
so no data is lost, but the files at the end cannot be extracted.

## Evidence

Measured by feature 395 (branch `395-cpio-solo-empty-name`, build at e3a27bda), probe
`specs/395-cpio-solo-empty-name/probe/cpiosolo_probe.ps1`, run `probe/result_review1_before.txt`:
the fixture writer then padded binary archives to 512 bytes only - row `UNP-BIN-LINK-DOT-DEL`
(`a.txt`, `.`, `ok.txt`, trailer; 512 bytes in all): `a.txt` was extracted, then the box
"Archive format not recognised or not supported.", `ok.txt` missing; rows `UNP-BIN-SOLO-DOT-DEL` /
`UNP-BIN-ORPHAN-DOT-DEL`: `ok.txt` missing. With the archive padded to 10240 bytes every row
passes (`probe/result_after.txt`).

Code at 4e17495e, `src/plugins/tar/untar.cpp`: `ReadArchiveHeader` first asks the stream for a
512-byte block (`Stream->GetBlock(preRead)` with `preRead = BLOCKSIZE`); when less is left it falls
back to `preRead = 6`; `GetArchiveType` recognises `e_Binary` only with
`(*(unsigned short*)buffer == 070707) && (preRead >= 26)` - false after the fallback, so the format
becomes `e_Unknown`.

## Expected

Measured first with a fixture whose last member and trailer lie within the last 512 bytes (also
an archive written by GNU cpio `-H bin`, if available). Then a binary cpio member is recognised
whenever its 26-byte header is present, wherever it lies in the archive; listing and extraction
reach every member up to the trailer. newc / odc / crc and tar keep their behaviour.

## Notes

Not verified: whether GNU cpio `-H bin` output really ends within 512 bytes of a member header in
practice (it pads to a 512-byte block, so its trailer usually does).

The byte-swapped binary format (`e_SwapBinary`) is never detected at all - found by review 2 of
feature 395 (`specs/395-cpio-solo-empty-name/fix-log.md`, *Review 2*, NOTE 2): `GetArchiveType`
compares `*(unsigned short*)buffer == 0707070`, and 0707070 octal = 233016 does not fit 16 bits
(the swapped magic read as a little-endian short is 0xC771); such an archive is "not recognised"
and kept. Its reader (`ReadBinaryHeader`, the `else` branch) would then parse the binary fields as
hex text (`TxtToShort` / `TxtToQuad`). Fix it in the same feature only if measured cheap; else a
separate item.

## Log

- 2026-11-02 — created (source measure:395)
