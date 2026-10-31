# Closing report - 358-uniso-udf-vat-missing
Backlog item: iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes - ISO plug-in: a UDF image with a VAT and data past it crashes Tandem Commander
Outcome: closed

## What changed

- `src/plugins/uniso/udf.cpp`: `ReadSupportingTables` returns FALSE when a virtual partition's VAT is not found
  (the existing box "Missing virtual allocation table.") or its search ends with a terminating error - the UDF
  volume does not open, as with an unreadable VAT sector; `LogSector` (virtual partition) translates only through
  `SalIsoUdfVatTranslates` (a table and `block < entries`); `CheckForVAT` takes a VAT 2.00 entry count only through
  `SalIsoUdfVat200Entries` (a header longer than the file, or a file longer than the table held, is not a VAT);
  the constructor initializes `Entries` / `Length`; `VatMissing` records a volume whose VAT is missing or
  unreadable.
- `src/plugins/uniso/udf.h`, `udfiso.cpp`: a UDF + ISO 9660 hybrid whose UDF part has a missing VAT marks the
  listing incomplete (`PartMissing`) also without an anchor at sector 256 (review 1's NOTE; measured by review 2).
- `src/common/salisoudfvat.h` (new, header-only) and `src/saltests/saltests.cpp` (`TestIsoUdfVat_358`).
- No UI string, menu or dialog - no translation refresh.

## Measurements (before / after, commands)

- Probe `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1` through `tools\run_on_hidden_desktop.ps1`:
  main 249e35f0 **14 / 8** (`result_before.txt`: R-VCDR100, R-VCLAIM16, R-VCLAIM100Z, L-VCDR100 - access
  violation reading address 0) -> **22 / 0** (`result_after.txt`) -> with review rows **40 / 0**
  (`result_after2.txt`) -> **52 / 0** (`result_after3.txt`).
- Negative controls: main's `uniso.spl` on review 1's rows 7 / 7 (`result_neg_main_uniso.txt`: UDF 1.50 and
  plain-entry images + data crash, damaged headers read garbage sectors); the build before the hybrid change:
  R-HND100 deletes the image (`result_neg_hybrid.txt`); `SalIsoUdfVatTranslates` mutated to `<=`: saltests 4 failed.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED.
- saltests: 29,553 -> **29,578 checks, 0 failed**.
- Probes: 358 52 / 0; regression 356 56 / 0 (`regress_356.txt`). Registry restored and identical after every run.

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 1 (the VAT buffer overflow reproduced) - recorded on the Inbox item; SHOULD 2 (probe
  rows for UDF 1.50, plain entries, damaged headers) - added; NOTE hybrid without anchor at 256 - fixed (fail
  closed); other NOTEs recorded; NOTE padded dumps -> Inbox.
- Review 2: no MUST. SHOULD (commit the hybrid builder and rows; the fix-log's "cannot be built" was wrong) -
  done; NOTE possible endless loop in the VAT search (older) -> Inbox; other NOTEs recorded.
- Deviation: the run removed review 2's scratch worktree (`%TEMP%\rev358b\neg`) with `git worktree remove --force`
  - nothing of the repository was in it; recorded in the fix-log.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below to the next release's section (`CHANGELOG.md` has no `## [Unreleased]` section;
  versions are the maintainer's).
- No new person-step item: real packet-written / Blu-ray UDF images are already owed by
  `check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd`.

CHANGELOG entry (for the next release's section):

- **Opening or unpacking certain CD-R / DVD-R / BD-R disc images closed Tandem Commander** (feature 358).
  - **Before:** a UDF disc image of a sequentially written disc (CD-R, DVD-R or BD-R written in UDF, for example
    with mkudffs or by packet writing) whose file held more than the disc's volume - data or empty sectors after
    it - showed "Missing virtual allocation table." and then Tandem Commander closed ("A problem has occurred,
    forcing Tandem Commander to close"), on Enter and on Unpack (Alt+F9).
  - **Now:** the message is shown and the image does not open; Tandem Commander keeps running, and a whole
    Unpack with "Delete archive after unpacking" keeps the image. A disc image that also has an ISO 9660 part
    lists that part and is kept by such an unpack. Images that end with their table open as before.
  - **Limitation:** an image whose table is in the file but followed by other data still does not open.

## New Inbox items (slug - title)

- `iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer` - ISO plug-in: a damaged UDF VAT file entry makes
  the reader write past its table buffer (measure:358; reproduced by review 1)
- `iso-plug-in-a-udf-image-with-data-past-its-vat-does-not-open` - ISO plug-in: a UDF image with data past its VAT
  does not open although the VAT is in the file (review:358)
- `iso-plug-in-a-cut-udf-vat-image-may-hang-the-listing` - ISO plug-in: a UDF VAT image cut a few sectors after its
  partition start may hang the listing (review:358)
