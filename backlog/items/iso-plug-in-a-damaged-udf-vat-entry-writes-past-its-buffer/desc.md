---
title: ISO plug-in: a damaged UDF VAT file entry makes the reader write past its table buffer
type: bug
status: open
severity: 7
area: archives
source: measure:358
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a damaged UDF VAT file entry makes the reader write past its table buffer

## Problem

A damaged or crafted UDF disc image of a sequential medium (one with a virtual allocation table, VAT) whose
VAT file entry claims more allocation-descriptor bytes, or longer extents, than the file's information length
makes the ISO plug-in's UDF reader copy them into the VAT buffer without a bound - a heap write past the
buffer while the image is listed (Enter, Unpack). The buffer is allocated with the file's information length
cut to 32 bits; the descriptors' area is read from the 2048-byte sector at offsets taken from the entry.
Likely a crash; a memory write past a heap block cannot be ruled out.

## Evidence

- `src/plugins/uniso/udf.cpp` at e90bd554 (branch 358-uniso-udf-vat-missing), `CUDF::ReadVAT` (line 1324):
  `DWORD length = (int)fe.InformationLength` (1362) allocates the table; `offset = 176 + fe.L_EA`, `end =
  offset + fe.L_AD` (1371) - both from the entry, not checked against the sector's 2048 bytes - and every
  descriptor goes to `ReadAllocDesc`.
- `CUDF::ReadAllocDesc` (728): embedded data (`ICBTag.Flags & 7 == 3`) `memcpy(vat + *o, data, fe->L_AD)`
  (748); short / long / extended descriptors `Image->ReadBlock(..., ad.Length, vat + *o)` (753) - `*o +
  ad.Length` is never compared with the buffer's length.
- Found by reading during feature 358 (research R3); feature 358 bounds only the entry count it derives
  (`SalIsoUdfVat200Entries`), not this copy.

## Expected

The VAT reader never writes past the table buffer nor reads past the sector it parses: an entry whose
descriptors exceed the information length, or whose descriptor area does not fit the sector, is not taken as
a VAT (the volume then does not open - feature 358's "Missing virtual allocation table." path); a 64-bit
information length over the 32-bit buffer is refused, not cut. The rule pure in `src/common/salisoudfvat.h`
with `saltests` checks; a crafted image probe (mkudffs cdr image with its VAT entry's `L_AD` / extent length
enlarged) shows no crash.

- Reproduced by review 1 of feature 358 (`specs/358-uniso-udf-vat-missing/fix-log.md`, *Review*): mkudffs
  `--media-type=cdr` image (`specs/356-uniso-udf-rest/probe/mkudf356.sh`, `mk_cdr.img`) whose VAT extended file
  entry (the last file entry of file type 248) has its InformationLength (offset 56) lowered from 160 to 156,
  L_AD (offset 212) kept at 160; Alt+F9 on the Debug build of 358 -> the CRT box "HEAP CORRUPTION DETECTED:
  after Normal block ... CRT detected that the application wrote to memory after end of heap buffer", the block
  allocated at udf.cpp(1364) (`ReadVAT`). 358's `SalIsoUdfVat200Entries` in `CheckForVAT` refuses this table, but
  only after `ReadVAT` has written it.

## Notes

- A probe row can be added to `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1` (a `vatimg.py` kind that
  lowers the VAT entry's InformationLength by 4).

## Log

- 2026-10-31 — created (source measure:358)
- 2026-10-31 — extended: reproduction by review 1 of feature 358 (heap corruption on the Debug build)
- 2026-10-31 — related item iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes done in feature 358
- 2026-10-31 — moved to Next position 2
