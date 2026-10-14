# Fix log: 165 - a ZIP archive of 65,535 entries or more gets the right count

Found by the review of 164 (recorded in NEXT-WORK item 15): the ZIP plug-in keeps the entry
counts in the 16-bit fields of the end of central directory record.

## Measured

`probe/zip_count_probe.ps1`; `zipcount.py eocd` walks the central directory by its size and
offset, reads the 16-bit counts and the zip64 end record, and gives the EFFECTIVE count (what a
reader that trusts the end record gets); PASS = it equals the records, a count of 65,535+ is in a
zip64 record, and Python's zipfile reads every member (testzip clean).

| Row | Before (build at 164) | After |
|-----|-----------------------|-------|
| DEL-2K (control): 2,000, *.del deleted | 1,000 - PASS | PASS |
| DEL-70K: 70,000 (zip64), *.del deleted | **30,535** | 35,000 |
| DEL-140K: 140,000, *.del deleted | **61,071** | 0xFFFF + zip64 70,000 |
| WRONG-70K: end record 4,464 for 70,000 (an earlier version's Pack), *.del deleted | (not run) | 35,000 |
| PACK-70K: 70,000 files packed into a new archive | **4,464** | 0xFFFF + zip64 70,000 |
| PACK-70K-RE: that archive, f00*.txt (10,000) deleted | (not run) | 60,000 |
| ADD-66K: 1,000 files added to an archive of 65,000 | **464** | 0xFFFF + zip64 66,000 |

Before: 4 of 5 COUNT rows FAIL, the control PASS. The archives' data was intact (Python's
zipfile walks the directory by its size) - the end record lied.

## Cause (by reading)

`CEOCentrDirRecordEx` (`typecons.h`) holds the counts in 16 bits. `FindZip64EOCentrDirLocator`
(`common.cpp`) kept 0xFFFF when the zip64 count was 65,535 or more; deletions (`del.cpp`) counted
down from it, writing a central record (`add.cpp` `WriteCentralHeader`, `RestoreReplaced`)
counted up and wrapped; `WriteEOCentrDirRecord` wrote the zip64 end record only when the
directory's size or offset needed 64 bits.

## Work

- `src/common/salzipcount.h`: `SalZipEndRecordCounts` (the 16-bit fields: the count, 0xFFFF from
  65,535 on; whether zip64 is needed), `SalZipReadEntryCount` (the zip64 value when the field says
  0xFFFF), `SalZipCountCentralRecords`; saltests `TestZipCount165`.
- `typecons.h`: `TotalEntries64`, `DiskTotalEntries64` in the in-memory struct (only
  `sizeof(CEOCentrDirRecord)` is written).
- `common.cpp`: set after the end record is read, from a zip64 end record when there is one.
- `add.cpp`: the resets (new / empty archive, a new volume) and every increment mirrored;
  `LoadCentralDirectory` sets the counts from the walked records of the loaded directory;
  `WriteEOCentrDirRecord` derives the 16-bit fields and writes the zip64 records for the counts.
- `del.cpp`: both deletion paths (164's batch and the per-member one) mirrored.

## Review

Independent refute-first review (read-only) of the first version:
- **CRITICAL, taken**: a self-extracting archive of exactly 65,535 entries (refused only above
  0xFFFF) got the zip64 records - the stub reads the end record where they would be (FinishPack
  writes `EOCentrDirOffs` into its header) and fails. A self-extracting archive keeps the 16-bit
  counts now, as before (by reading; the SFX stub is not driven on the hidden desktop).
- **SHOULD-FIX, taken, measured**: an archive whose end record an earlier version wrote wrong
  (4,464 for 70,000) - deleting 35,000 underflowed the 64-bit count: WRONG-70K on the first
  version wrote 0xFFFF + zip64 18,446,744,073,709,521,080 (FAIL). Now the count of a changed
  archive is the walked records (this also repairs such archives on their next change).
- **SHOULD-FIX, taken**: the zip64 locator said one disk; a multi-volume archive of 65,535+
  entries now gets one - `TotalDisks = DiskNum + 1`.
- **NIT, taken**: the zip64 count is taken only when the 16-bit field holds 0xFFFF (APPNOTE).
- Confirmed: no use before initialisation (every route passes `CheckZip`, the ZeroZip or Pack
  resets), every `EONewCentrDir = EOCentrDir` follows the setting, `SaveComment` writes the
  counts as read (unchanged), `WriteSFXECRec` runs after the derivation, the multi-volume order,
  a counts-only zip64 record with real 32-bit size/offset is allowed and read by the plug-in.
- Not changed (recorded): `zip2sfx/checkzip.cpp` reads the 16-bit count (as before).

## Regression

Final build: BUILD SUCCEEDED, saltests 22,303 / 0, `check_encoding.py` TOTAL 0; the probe 14 / 0
(`probe/result_after.txt`; WRONG-70K on the first version: `result_wrong_first_version.txt`).
113 zipskip 37 / 0, 110 zipname 42 / 0, 164 delete cost 6 / 0, 119 packleft 104 / 0 / 8 NOT DRIVEN
(as recorded). 106's packself 69 / 1: A-zip-noask-refused expects the "already exists" question
before the refusal - 119 moved the refusal before the question and carries that row with the new
expectation in packleft (PASS); the 106 probe is superseded, not a regression.
