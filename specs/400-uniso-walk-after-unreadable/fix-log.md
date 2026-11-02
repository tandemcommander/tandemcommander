# Fix log - 400-uniso-walk-after-unreadable

Backlog item `iso-plug-in-after-a-folder-that-cannot-be-read-no-later` (leftover of 330).

## Measurement before (main at aaf95b94)

- `.\build.cmd` (Debug x64, up to date) at aaf95b94.
- Hidden desktop: `tools\run_on_hidden_desktop.ps1 ... iso330_probe.ps1 -Exe build\...\tandemcommander.exe
  -Label before-walk -Only RD-EXT,RD-REC,UD-EXT,UD-TAG,XD-EXT` -> PASS 10 / FAIL 0 under 330's
  expectations, i.e. the defect present:
  - RD-EXT, RD-REC, XD-EXT: `files 1: top.txt` (zlast/z.txt never listed), one box, image kept;
  - UD-EXT, UD-TAG: the ISO 9660 part's three files + `UDF (TC330)/top.txt` only, one box, image kept.
  - Registry restored, identical (SHA-256 0014109...20B4).
- Code at HEAD: `iso9660.cpp` `CISO9660::ListDirectoryRe`, `udf.cpp` `CUDF::ScanDir`,
  `xdvdfs.cpp` `CXDVDFS::ScanDir` descend a listed folder only `if (ret == ERR_OK)`; a nested failure
  sets `ret = ERR_CONTINUE` for the rest of the directory, and it is returned to every ancestor.
- `BL verify` recorded.

## Decisions

See spec *Clarifications*: one box per file system walk; a damaged folder's own tail is not walked;
out of memory still stops later descents (a core refusal keeps 328 / 329's handling); UDF and Xbox walks get a visited set (328's
rule).

## speckit-analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM I1 (FR-003 vs the unchanged core-refusal boxes) fixed in spec.md;
  LOW C1 (FR-007 covered by the build), C2 (no row for a hybrid with both parts damaged - follows from
  one walk per file system) accepted.
- Run 2 (after the fix): 0 CRITICAL, 0 HIGH, 0 MEDIUM.

## Probe and images (T001-T003)

- `probe/img400.py` (330's commands loaded from img330.py, plus isotwo, xboxtwo, xboxloop, xboxloop2,
  udfloop), `probe/mkimg400.sh` (330's seeds + rd2.iso), `probe/iso400_probe.ps1` (330's rows with the
  new expectation, `-Once` = the box exactly once; new rows RD-TWO, XD-TWO, XD-LOOP, XD-LOOP2, UD-LOOP).
- Traps met: (1) my first isotwo / xboxtwo pointed both damaged folders at the same far sector - the
  second would be "a folder met again" (328's Visited returns OK before reading), not a second failure;
  now FAR and FAR + 1. (2) A new switch `$Kept` was the script's `$kept` (image exists) - PowerShell
  names ignore case (the trap of 328 / 330 again); renamed `$KeepImage`.
- Before (main's code, build at aaf95b94 + only probe files changed): `result_before.txt` 28 / 12 and
  `result_before_rows2.txt` (RD-TWO, XD-TWO with the fixed images, XD-LOOP2, UD-LOOP with the fixed
  switch) 3 / 5:
  - RD-EXT, RD-REC, RD-ZERO, XD-EXT, RD-TWO, XD-TWO, XD-LOOP: `files 1: top.txt; missing: zlast/z.txt`,
    one box (none for RD-ZERO), image kept;
  - UD-EXT, UD-TAG: `UDF (TC330)/zlast/z.txt` missing;
  - XD-LOOP2 (no damaged folder, a folder listing itself twice): the program does not answer
    (`WM_NULL False`, ended by the probe) - a pre-existing exponential walk, fixed by the visited set;
  - UD-LOOP: the "(206)" report of `UDF (TC330)\a\side.txt\side.txt\...` down to the path limit, the
    image kept;
  - 330's control and other rows: PASS (as 330's result_after).

## Implementation (T004-T013)

- `src/common/salisowalk.h`: `SalIsoWalk { Stopped, BoxShown }`, `SalIsoWalkDescends`,
  `SalIsoWalkAfterChild`, `SalIsoWalkBoxQuiet`; results asserted equal to `ERR_*` in each reader.
- ISO 9660: `Walk` member; fresh for the boot record, the fit walk and the listing walk; `CountUnder`
  saves / restores it; out-of-memory sites -> `WalkOutOfMemory()` (Stopped + the walk's one box);
  `IDS_ERROR_LISTING_IMAGE` boxes of `ListDirectoryRe` and `ChainNotListed` gated; descent by the rule.
- UDF / Xbox: `Walk` + `Visited` (UDF: ICB partition << 32 | block; Xbox: start sector; root marked
  first); boxes of `ScanDir` gated; `AddFileDir` / `ScanDir` out-of-memory -> `WalkOutOfMemory()`; a
  folder met again is not descended (listed empty, not marked). UDF's `ADD_FAILED` for a file whose
  entry cannot be read keeps ending its directory silently (not a stop of the walk).
- `saltests`: `TestIsoWalk400` (38 checks, model trees): 282,271 -> 282,309 checks, 0 failed.
  Mutants (each built and run, then reverted): Descends = `!Stopped && !BoxShown` -> 6 failed;
  AfterChild assigns the child's result -> 5 failed; BoxQuiet never quiet after the first -> 3 failed.
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); `.\build.cmd` -> BUILD SUCCEEDED
  (three C4267 warnings on unchanged `fd.NameLen = strlen(...)` lines).

## Verification (T014-T016)

- After: `iso400_probe.ps1 -Label after` -> `probe/result_after.txt` PASS 40 / FAIL 0 (20 RUN rows):
  RD-EXT, RD-REC, XD-EXT, RD-TWO, XD-TWO, XD-LOOP `files 2: top.txt, zlast/z.txt`, the box once (seen 1),
  image kept; RD-ZERO the same without a box; UD-EXT / UD-TAG `UDF (TC330)/zlast/z.txt` listed, one
  box; XD-LOOP2 and UD-LOOP answer, no window, image deleted (nothing damaged); 330's rows unchanged.
  Registry restored, identical.
- Regressions on the same build: 328 20 / 0 (LOOP-RR, LOOP-J answer, CPU 0.7 / 0.6 s), 329 14 / 0,
  327 77 / 0 (`probe/regress_*.txt`).
- Negative control (build with the UDF / Xbox visited sets off and `SalIsoWalkBoxQuiet` showing every
  box; `probe/result_negctl.txt`, rows RD-EXT, RD-TWO, XD-TWO, XD-LOOP, XD-LOOP2, UD-LOOP): 5 / 7 -
  RD-TWO / XD-TWO two boxes; XD-LOOP 67 boxes seen (138 stray at the end), files 0, not closing in
  30 s; XD-LOOP2 no answer; UD-LOOP the "(206)" report, image kept. RD-EXT (one damaged folder) passes
  - expected, it needs neither part. Reverted (`git checkout HEAD -- ...`), rebuilt: saltests 282,309 /
  0; the same rows `probe/result_after_restore.txt` 12 / 0.
- The item's measurement repeated: zlast/z.txt of the damaged file system is now extracted in all 6
  rows that lost it at aaf95b94 (RD-EXT, RD-REC, RD-ZERO, UD-EXT, UD-TAG, XD-EXT).
