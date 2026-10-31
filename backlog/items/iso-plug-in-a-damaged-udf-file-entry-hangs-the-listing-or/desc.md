---
title: ISO plug-in: a damaged UDF file entry hangs the listing or reads past its sector
type: bug
status: open
severity: 7
area: archives
source: review:360
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

# ISO plug-in: a damaged UDF file entry hangs the listing or reads past its sector

## Problem

A damaged or crafted UDF disc image whose folder or file entry declares a reserved allocation-descriptor type (ICB flags 4 - 7) makes the ISO plug-in's general file-entry reader loop for ever: Tandem Commander stops answering while the image is listed (Enter, Unpack) and has to be killed - the user's other work in it is lost. The same reader takes the descriptor area at 176 (216 in an extended entry) + L_EA, L_AD bytes long, in 32 bits without comparing it with the 2048-byte sector, so an entry with a large L_EA or L_AD makes it read past the sector buffer. Feature 360 bounded only the VAT's own reader (`CUDF::ReadVAT` / `ReadAllocDesc`); this one was not part of its item.

## Evidence

- `src/plugins/uniso/udf.cpp` at the merge of feature 360, `CUDF::ReadFileEntry(Uint8* data, bool bEFE, Uint16 part, CICBTag* icbTag, CUDF::CAD* ad, int maxAds)`: `p = 176 (+40) + l_ea` and `while (p < l_ea + l_ad)` in 32 bits, `ShortAD(&data[p], ...)` with no bound against the sector; the `switch (icbTag->Flags & 0x0007)` has no case for 4 - 7, so `p` never advances while `maxAds` stays > 0.
- Reproduced by review 1 of feature 360 (`specs/360-uniso-udf-vat-bound/fix-log.md`, *Review*): `specs/360-uniso-udf-vat-bound/probe/vatext360.py` kind `rootadt5` (mk_cdr.img from `specs/356-uniso-udf-rest/probe/mkudf356.sh` with the root folder's file entry set to descriptor type 5), Enter on the Debug build at HEAD of 360 - the main window stopped answering (WM_NULL False), the probe ended the process (`specs/360-uniso-udf-vat-bound/probe/result_rootadt5_review1.txt`, row L-ROOTADT5 END FAIL).
- The rules of feature 360 in `src/common/salisoudfvat.h` (`SalIsoUdfVatDescArea`, `SalIsoUdfVatDescSize`, `SalIsoUdfVatDescFits`) decide the same questions for the VAT's entry.

## Expected

The general file-entry reader never loops on a reserved descriptor type and never reads past the sector: such an entry is refused (the folder or file is left out / reported as the reader reports unreadable entries today, never a hang), with the area and descriptor rules shared with feature 360 (reused or generalised in `src/common/`) and `saltests` checks; a probe row (vatext360.py `rootadt5`, and an entry with L_EA past the sector) shows the program answering and the image kept by a whole unpack with "Delete archive after unpacking".

## Log

- 2026-10-31 — created (source review:360)
- 2026-10-31 — auto-triage: severity 6 -> 7: the program stops answering and must be killed (and reads past its sector buffer) on a damaged image - a crash in an unusual scenario, as the sibling VAT item of feature 360
- 2026-10-31 — moved to Next position 1
