# Closing report - 364-uniso-udf-folder-extents

Backlog item: iso-plug-in-a-udf-folder-stored-in-more-than-one-extent-is - ISO plug-in: a UDF folder stored in more
than one extent is listed cut and the image deleted
Outcome: closed

## What changed

- `src/common/salisoudfentry.h`: `SAL_ISO_UDF_FOLDER_MAX_EXTENTS` (32), `SalIsoUdfFolderExtents` (which leading
  recorded extents are walked, their bytes, whether they cover the folder's Information Length),
  `SalIsoUdfFolderSector` (which extent holds a folder block).
- `src/plugins/uniso/udf.h`, `udf.cpp`: `CUDFFolder`; `CUDF::MapICB(CAD, CICBTag*, CUDFFolder*)` reads up to 32
  descriptors and applies the rule (362's walkable check on the first walked extent); `CUDF::ReadFolderWindow` fills
  the walk's two-block window through the extents; `CUDF::ScanDir(const CUDFFolder&, ...)` walks every walked extent
  (64-bit end); the root and every sub-folder read short mark `ListingLeftOut` incomplete (feature 330) and list
  what was read.
- `src/saltests/saltests.cpp`: `TestIsoUdfFolderExtents_364`.
- Probe `probe/iso364_probe.ps1` + `probe/img364.py` + `probe/mkimg364.sh`.
- No UI string, dialog or menu; no plug-in interface change.

## Measurements (before / after, commands)

- Before (main b1d9e31b, Debug x64): `iso364_probe` **20 PASS / 8 FAIL** (`probe/result_before.txt`) - split /
  fragmented root and sub: 28 or 68 of 80 UDF files, image deleted; type 3 / type 1 second descriptor and the 38 /
  40-byte extent of an 88-byte folder: read short, image deleted, nothing marked.
- After (branch, Debug x64): **28 PASS / 0 FAIL** (`probe/result_after.txt`) - fragmented folders 80 of 80 files,
  deleted; folders read short: the readable part extracted, image KEPT; controls unchanged.
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\364-uniso-udf-folder-extents\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\364-uniso-udf-folder-extents\probe\iso364_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (one pre-existing C4267 warning in `udf.cpp`, not the feature's lines).
- `saltests.exe` -> `saltests: 29791 checks, 0 failed` (29,748 before).
- Probes: 364 28 / 0; regressions 330 30 / 0, 356 56 / 0, 358 52 / 0, 361 24 / 0, 362 34 / 0, 363 24 / 0
  (`probe/regress_*.txt`); registry restored and identical after every run.
- clang-format (VS 2022) on the feature's hunks: no change.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST, no SHOULD. Negative control (three mutations of `udf.cpp` built in a copy):
  22 / 6, each mutation caught by its own rows. NOTE 2 (the "walked as today" wording) - taken; NOTE 4 (VAT block
  mapping, predates the feature) - Inbox; NOTEs 1, 3, 5, 6 accepted (fix-log *Review*).

## Owed to a person (with the new person-step items)

- The changelog: `CHANGELOG.md` has no `## [Unreleased]` section (the tree is at the released 0.2.0); the run does
  not create one. Entry to add under the next version's heading:

  ```text
  - **A UDF disc image with a folder stored in several pieces was listed cut, and Unpack with "Delete archive after unpacking" deleted the image** (feature 364).
    - **Before:** the ISO plug-in read a UDF folder only up to its first piece (extent). On fragmented rewritable or packet-written media the folder's later files were not listed, and a whole Unpack (Alt+F9) with "Delete archive after unpacking" extracted only part of the tree and deleted the image. A folder whose piece was shorter than the folder's declared size was read short the same way.
    - **Now:** every piece of a folder is read in order, so all its files are listed and extracted. A folder that still cannot be read whole (a piece not recorded on the disc, a list of pieces continued elsewhere, more than 32 pieces, pieces shorter than the folder's size) lists what can be read and marks the listing incomplete, so a whole Unpack keeps the image. Folders in one piece are read exactly as before.
  ```

- No person-step item: nothing in the change needs a keyboard, clipboard or another machine.

## New Inbox items (slug - title)

- iso-plug-in-a-udf-folder-of-several-blocks-in-a-vat - ISO plug-in: a UDF folder of several blocks in a VAT
  partition is read past its mapping (review:364)
