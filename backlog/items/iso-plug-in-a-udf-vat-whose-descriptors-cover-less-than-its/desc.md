---
title: ISO plug-in: a UDF VAT whose descriptors cover less than its length is read with heap content
type: bug
status: new
severity: 3
area: archives
source: measure:360
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

# ISO plug-in: a UDF VAT whose descriptors cover less than its length is read with heap content

## Problem

A UDF disc image of a sequential medium (one with a virtual allocation table, VAT) whose VAT file entry's allocation descriptors cover fewer bytes than the file's information length is still taken as a VAT: the ISO plug-in allocates the table with the information length and copies only what the descriptors give, so the table's tail holds whatever the heap held. Entries in that tail translate virtual blocks to arbitrary sector numbers - the listing or an unpack reads unrelated sectors of the image or fails with a read error naming a garbage sector. No read or write outside the buffer (feature 360 bounds the copy); a damaged or non-conforming image only.

## Evidence

- `src/plugins/uniso/udf.cpp` at the merge of feature 360, `CUDF::ReadVAT`: `*vat = new BYTE[length]` (not zeroed), the descriptor walk copies `o` bytes, `o` < `length` is accepted; `CUDF::CheckForVAT` derives the entry count from the information length (`SalIsoUdfVat200Entries`, `(vatLen - 36) / 4` for UDF 1.50).
- Noted by review 2 of feature 358 (`specs/358-uniso-udf-vat-missing/fix-log.md`, *Review*, NOTE 5) and left open by feature 360 (`specs/360-uniso-udf-vat-bound/research.md` R3: the item it implemented named only descriptors that exceed the length).
- Not measured with an image: the probe of 360 (`specs/360-uniso-udf-vat-bound/probe/vat360.py`) has no kind that lowers L_AD below the information length.

## Expected

A VAT whose descriptors do not cover its information length is either refused (not taken as a VAT - feature 358's "Missing virtual allocation table." path) or its uncovered entries never translate (zeroed / counted only up to the bytes written) - decided in `src/common/salisoudfvat.h` with `saltests` checks; a probe row (vat360.py kind: L_AD lowered by 8 in mk_cdr.img) shows the chosen behaviour. Well-formed images (mkudffs: L_AD equal to the length) unchanged.

## Log

- 2026-10-31 — created (source measure:360)
