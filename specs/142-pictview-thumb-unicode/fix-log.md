# Fix log: feature 142 - PictView, Update Thumbnail and Exif information for any file name

## 2026-10-14

- Source: the final independent review of Update Thumbnail (names outside the code page on a
  volume without short names; the OK-only box per file; `PRIVACY.md`).
- Spec, plan, tasks before the code.

## Before (the build without 142, `probe/before.txt`)

Rows UNI and UNIXMP of `specs/132-pictview-thumbnail-verify/probe/thumb132_probe.ps1` with
`-UniRoot E:\Projects\tandemcommander\build` (E: keeps no short names; C: does - checked by
asking for the short path of the test folder): a JPEG named in Japanese and Greek letters with
an emoji, in a folder named likewise: the file is unchanged; the box "Unable to create a file
with the new thumbnail. Disk full? ..." with OK only, then "No JPEG images with EXIF data were
found. No file was modified."

## Implementation and review

- Details in `impl-notes.md`. Worth knowing: appending two exports made the linker renumber
  three old ones - the six old ordinals are pinned in `exif.def` now (they match the 0.1.9
  library); the wide and the code-page export give byte-identical output on 91 real camera
  files, 5 calls each; the walker of 135 says "same" for all 82 files with Exif.
- Refute-first review with its own failure-injection drivers: no critical or medium finding.
  Lows fixed: one "Skip all" covered three kinds of error (three flags now); error 87 was
  folded into the "refused" text; the wording of `PRIVACY.md` (the new file is kept only when
  the picture vanished meanwhile); the temporary name was released for a moment before the
  create; the code-page wrapper converts with `MB_ERR_INVALID_CHARS` like the CRT did.

## After

- Debug build clean; `saltests` 21,794 / 0; `check_encoding.py` TOTAL 0.
- `probe/after.txt` (the 132 probe with `-UniRoot` on E:, the build with the review fixes):
  **PASS 20, FAIL 0** - UNI and UNIXMP: updated (74,544 -> 82,824 and 74,658 -> 82,938
  bytes), every byte from the picture data on and the planted marks kept; the eight older rows
  as before.
- `probe/after_old_library.txt` - the new plug-in with the EXIF.DLL of 0.1.9 beside it (no
  wide export: the fallback route): PASS 16, FAIL 0; what the old library spoils is still
  refused, and the refusal is said.
- The Save As probe of 105 (56 / 0, existing files lost 0) and the probe of 120 (20 / 0) on
  the same build.
- Library alone (scratch build): 91 real camera files x 5 calls (code-page export, wide with
  an ASCII name, wide with a Japanese + Greek + emoji name and folder, wide with a path of
  437 characters, the library of 135): 0 differing results, 0 differing bytes.
- Not driven: the new failure dialog's Skip all across several files (needs a failure that
  repeats: a read-only folder; by reading and review); the Exif information window in the
  program (it opens only for a flag the built-in engine does not set); a double-byte system
  code page.
