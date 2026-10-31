# Closing report - 362-uniso-udf-folder-no-descs
Backlog item: iso-plug-in-a-udf-folder-entry-without-descriptors-is-listed - ISO plug-in: a UDF folder entry without descriptors is listed empty and the image deleted
Outcome: closed

## What changed

- `src/common/salisoudfentry.h`: `SalIsoUdfFolderEntryWalkable(int stored, unsigned long long firstLen)` and
  `SAL_ISO_UDF_MIN_FID` (38) - a folder entry is walked only when the reader stored a descriptor or embedded data and
  the first extent / embedded data holds at least one file identifier (38 bytes).
- `src/plugins/uniso/udf.cpp` `CUDF::MapICB(CAD, CICBTag*, CAD*)`: returns 0 for a refused entry (361) or a folder
  entry the rule does not walk - the existing unreadable-folder path (feature 330): the root "Bad root ICB", a
  sub-folder listed empty with the listing marked incomplete, so a whole unpack fails and "Delete archive after
  unpacking" keeps the image.
- `src/saltests/saltests.cpp`: `TestIsoUdfFolderEntry_362`.
- Probe `probe/iso362_probe.ps1`, `probe/img362.py`, `probe/mkimg362.sh`.
- No UI string, dialog, resource, plug-in interface or configuration change; no `.slt` refresh needed.

## Measurements (before / after, commands)

Probe (hidden desktop): `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\362-uniso-udf-folder-no-descs\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\362-uniso-udf-folder-no-descs\probe\iso362_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

| Run | Build | Result |
|---|---|---|
| `result_before.txt` | main 5d74e338 | PASS 15, FAIL 7 - five damaged images deleted after a partial unpack, no "Bad root ICB" |
| `result_after.txt` | d9df08bd (L_AD 0 rule) | PASS 22, FAIL 0 |
| `result_before_review1.txt` | d9df08bd, rows of a first extent of length 0 | 3 FAIL |
| `result_after_review1.txt` | 1c528005 | PASS 28, FAIL 0 |
| `result_before_review2.txt` | 1c528005, rows of a 20-byte first extent | 3 FAIL |
| `result_after_review2.txt` | 8ed54e06 | **PASS 34, FAIL 0**; registry restored + identical |

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` - TOTAL: 0 finding(s).
- `.\build.cmd` - BUILD SUCCEEDED (Debug x64).
- `saltests` - 29,720 checks, 0 failed (was 29,700); negative controls: the old rule 3 failed, the length clause off
  3 failed, the threshold back to `> 0` 5 failed.
- Regression probes on the final build: 330 30 / 0, 361 24 / 0, 356 56 / 0 (their recorded results).

## Reviews (findings and what was done)

- Review 1 (no MUST): SHOULD 1 a first extent of length 0 - fixed; SHOULD 2 a folder in more than one extent read
  short - Inbox; NOTEs recorded.
- Review 2 (no MUST): SHOULD 1 a first extent shorter than an identifier (20 bytes) - fixed (threshold 38); measured
  IMAPI2FS UDF 1.02 - 2.01 and all mkudffs media (probe 356) - no valid folder refused.
- Review 3 (no MUST / SHOULD): boundary 37 / 38 wired in the program; pycdlib UDF 2.60 folders walked; NOTE an extent
  shorter than the Information Length - added to the Inbox item; stale comment updated.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (no `## [Unreleased]` section in `CHANGELOG.md`; versions are the maintainer's):

  - **A damaged UDF disc image could be deleted by Unpack although a folder of it was not extracted** (feature 362).
    - **Before:** a UDF folder whose entry describes no folder data (no allocation descriptors, or a first extent too
      short to hold even the folder's link to its parent) was listed as an empty folder without any warning; the
      root such a folder showed an empty UDF part. Unpack of the whole image with "Delete archive after unpacking"
      extracted the rest and deleted the image - the folder's files were lost.
    - **Now:** such a folder is treated as unreadable: a sub-folder is still listed empty, but the listing is
      incomplete, so the unpack reports failure and the image is kept; a damaged root shows "Bad root ICB. Cannot
      read directory structure." Intact images, real empty folders and empty volumes list and unpack as before.
    - **Limitation:** a folder stored in more than one piece on the disc, or whose only piece is shorter than its
      recorded size, is still read only partly (recorded for a later fix).

## New Inbox items (slug - title)

- `iso-plug-in-a-udf-folder-stored-in-more-than-one-extent-is` - ISO plug-in: a UDF folder stored in more than one
  extent is listed cut and the image deleted (review:362).
