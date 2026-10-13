# Fix log: feature 141 - a name built from a mask is never cut

## 2026-10-14

- Source: the final cross-feature review (the in-place rename cut at 519 bytes; the FTP upload
  autorename). Reading the code before the spec found the same buffer in the Copy / Move
  script builder (719 bytes).
- Spec, plan, tasks, then the probe (`probe/maskname_probe.ps1`) and "before".

## Before (0.1.9 control build, `probe/before.txt`)

The premise "a copy lands under a cut name" was only partly right - measured:

- CP250, MV250, CPD250 - a file or directory named 'a' + 249 CJK letters (752 / 748 bytes; a
  legal name): Copy and Move **fail** with Windows error 123 ("the file name, directory name
  or volume label syntax is incorrect"). The name is cut at byte 719, inside a letter, and the
  cut name is not a name. Nothing is created - but such a file cannot be copied or moved at
  all.
- CP200 (602 bytes): copied under its whole name.
- QR250, QR200 - Quick Rename to a name of 752 / 602 bytes: error 123, the file keeps its
  name (cut at byte 519 inside a letter).
- QR256 - Quick Rename to 256 CJK letters (768 bytes; no file system takes it): the file is
  renamed **silently to the first 173 letters** (519 bytes happen to end at a whole letter).
  This is the silent cut the review described.

## Implementation and review

- The rule moved to `src/common/salmaskname.h`; details and the before / after table per site
  in `impl-notes.md`. Premises of the brief that did not hold: no `ErrTooBigFileFAT32SkipAll`
  slip at the directory site; PictView's buffers were `3 * MAX_PATH` already; "nothing of the
  name left" cannot happen in the FTP generator for UTF-8 names.
- Decision kept: `?` and literal mask characters consume whole UTF-8 characters (the old code
  produced invalid names: `?.*` on `été.txt`); ASCII name with ASCII mask is byte-identical
  (12,221,081 differential checks against the code of HEAD, the reviewer's own 11.7 million
  exhaustive + 1.4 million random under AddressSanitizer agree).
- Refute-first review: no critical or medium finding. Lows fixed: the FTP shortening could
  return an empty name for code-page text (step back at most 3 bytes, only onto a lead byte);
  a trailing dot after a cut; the "name too long" boxes lost their path line for long names
  (heap text). Found on the way and fixed (old, identical in HEAD): the OpenVMS autorename
  crashed for `a_123;1` (stale `semicol`, `memmove` size -1).
- The probe's first run reported 7 FAIL with the right state on the disk: a one-name list
  reached the judge as a string. Fixed in the probe; the facts were right from the start.

## After

- `saltests` 21,794 checks, 0 failed (with `TestMaskName141`); `check_encoding.py` TOTAL 0;
  Debug build clean.
- `probe/after.txt`, on the build with the review fixes: **PASS 14, FAIL 0** - CP250, MV250,
  CPD250, CP200: the target holds exactly the expected name; QR250, QR200: renamed to exactly
  the typed name; QR256: "Cannot finish operation because of too long name.", the file keeps
  its name, the dialog comes back with the text.
- FTP probe (English, with the AUTOREN row of 137) on the same build: PASS 33, FAIL 0.
- Not driven: the in-place rename line (no keyboard on the hidden desktop; it reaches the same
  `RenameFileInternal`); a typed mask longer than 779 bytes in Copy; the FTP upload autorename
  against a server (covered by the differential harness only: no test server reports "file
  exists" for an upload); Edit New File.
