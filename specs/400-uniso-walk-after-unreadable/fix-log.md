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

## Review

### Review 1 (refute-first agent, on e48568c6)

- Re-measured with its own builds of main (aaf95b94) and HEAD (worktrees and build folders under
  `%TEMP%\rv400`): HEAD 40 / 0 as `result_after.txt`; main's plug-in fails all 11 new rows; its own
  `xd_many.iso` (300 damaged Xbox folders, then top.txt, zlast/z.txt): HEAD both files, one box, image
  kept - main top.txt only.
- **MUST 1 (fixed)**: the Xbox visited set keyed a folder by its start sector alone, but every entry
  gives its own size - `xd_share.iso` (root: `b` at sector S with 2048 bytes, `a` at S with 4096
  bytes, top.txt; S holds a1.txt, S + 1 a2.txt): main extracted a/a1.txt, a/a2.txt, b/a1.txt, top.txt;
  400's build extracted b/a1.txt and top.txt only, no window, and the image was deleted (a2.txt lost) -
  a regression against main. Fix: `CXDVDFS::VisitFolder(sector, size)`, key `size << 32 | sector` (the
  root too). UDF is keyed by the file entry, which gives the size itself - not affected. Probe rows
  added from the reviewer's generator (byte-identical images, `img400.py xboxshare` / `xboxmany`):
  XD-SHARE (control: all four files, no window, image deleted) and XD-MANY (one box, both files, kept).
- **SHOULD 1 (Inbox)**: the ISO 9660 walk keys by block alone too (328, not 400) - Inbox item
  `iso-plug-in-an-iso-9660-folder-met-again-with-a-larger` (review:400).
- NOTE 1 (a UDF file entry that cannot be read ends its folder silently) - spec decision, covered by
  Inbox `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`; NOTE 2 (an ISO 9660 damaged folder
  pointing at a later folder's block lists it empty) - marked incomplete, nothing lost, 328's rule;
  NOTE 3 callers / 368's chain box now once per walk (368's probe checks "at least one"); NOTE 4
  saltests total 282,283 in its build vs 282,309 here (not traced by the reviewer; this tree's build
  prints 282,309 at every run - the volume-dependent tests 304 / 305 print host facts), comment
  wrapping in udf.cpp / xdvdfs.cpp and spacing in xdvdfs.h fixed; NOTE 5 no standing-rule violation.
- The tree was clean after the review (`git status --short` empty).
- After the fix: `.\build.cmd` BUILD SUCCEEDED; saltests 282,309 / 0; encoding guard TOTAL: 0;
  `iso400_probe.ps1 -Label after-review1` -> `probe/result_after_review1.txt` 44 / 0 (22 RUN rows,
  XD-SHARE all four files, XD-MANY one box); 329 again (Xbox rows) `probe/regress_329_review1.txt`
  14 / 0. The reviewer's logs kept: `probe/review1_rv_head_e48568c6.txt` (RV-SHARE FAIL on 400's
  first build) and `probe/review1_rv_main_aaf95b94.txt` (RV-SHARE PASS on main, RV-MANY FAIL).
