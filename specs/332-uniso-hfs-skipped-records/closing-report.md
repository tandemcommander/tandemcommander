# Closing report - 332-uniso-hfs-skipped-records
Backlog item: iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let - ISO plug-in: UDF and HFS+ entries skipped as damaged let Unpack delete the image
Outcome: closed

## What changed

- `src/common/salhfscatalog.h`: `SalHfsCatalogRecordClass` - what an HFS+ catalog leaf record is for the
  listing: FOLDER / FILE (listed), NOT_ENTRY (thread records, the root folder used as the volume label,
  the root folder "<4 x U+0000>HFS+ Private Data"), DAMAGED (key / name / type past the record, a name
  over 255 units, a folder / file record shorter than its structure, an empty name that is not a thread
  or the root folder, any other U+0000-first name), UNKNOWN (a named record of a type not handled).
- `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory`: DAMAGED and a name that does not convert - skipped,
  `ListingLeftOut.SetIncomplete()`; UNKNOWN - marked, the listing ends as before (inside a folder left out
  by 329 skipped with it, as before). A whole Unpack of such a listing fails, so "Delete archive after
  unpacking" keeps the image. No UI string, no message, no plug-in interface change.
- `src/saltests/saltests.cpp`: `TestHfsRecordClass332`.
- The item's UDF part was already fixed by feature 330 (measured; probe row U-FILE) - no UDF change.

## Measurements (before / after, commands)

Probe `probe/iso332_probe.ps1` via `tools/run_on_hidden_desktop.ps1` (seeds `probe/mkimg332.sh` in WSL,
damaged copies `probe/img332.py`):
- before (main 6070ac51, `probe/result_before.txt`): PASS 10 / FAIL 4 - H-TYPE, H-KEY, H-LONG, H-SHORT
  deleted the image (`side.txt`, only in the HFS+ part, lost); H-OK, U-OK, U-FILE pass.
- review-1 build, row H-NUL (`probe/result_review1_nul.txt`): FAIL - image deleted.
- after (`probe/result_after.txt`): PASS 16 / FAIL 0 (rows H-OK, H-TYPE, H-KEY, H-LONG, H-SHORT, H-NUL,
  U-OK, U-FILE, each with its END row).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (no UI string or resource changed - no `full` build, no `.slt` refresh).
- saltests: 28,304 -> 28,345 checks, 0 failed; mutants: thread records DAMAGED - 3 failed; no root check
  for the metadata folder - 1 failed.
- Regression probes (`probe/regress_*.txt`): 322 18 / 0, 328 20 / 0, 329 14 / 0, 330 30 / 0.
- Registry restored and identical after every probe (SHA-256 F92E573A...).

## Reviews (findings and what was done)

- Review 1 (e135085e): MUST - every U+0000-first folder / file name was exempt (a damaged file lost, row
  H-NUL) - fixed (only the exact root folder); SHOULD - a refused catalog drops the HFS+ part silently -
  the existing Inbox item `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is`; NOTE 4 - an
  UNKNOWN record inside a left-out folder ended the listing - fixed; NOTE 5 - U+0000 inside a name lists
  it cut - new Inbox item; NOTE 3 / 6 recorded.
- Review 2 (d8e666a7): the first agent stopped mid-probe (registry restored from its backup, fixture
  removed); a fresh agent with its partial work: no MUST, no SHOULD - main build 15 / 7 on 22 rows, branch
  22 / 0, a differential test of 20,000,000 random records against main's loop 0 mismatches; NOTE 1
  (hard links) - new Inbox item.

## Owed to a person (with the new person-step items)

- `check-feature-332-with-a-mac-made-hfs-disc-image` - unpack an intact Mac-made HFS+ hybrid with
  "Delete archive after unpacking" (no Mac-made image was available to the run).

## New Inbox items (slug - title)

- `iso-plug-in-an-hfs-name-with-u-0000-inside-is-listed-cut-at` - ISO plug-in: an HFS+ name with U+0000
  inside is listed cut at it
- `iso-plug-in-hfs-hard-links-extract-as-empty-files-their-data` - ISO plug-in: HFS+ hard links extract as
  empty files, their data under iNode names
- (person step) `check-feature-332-with-a-mac-made-hfs-disc-image` - Check feature 332 with a Mac-made
  HFS+ disc image
