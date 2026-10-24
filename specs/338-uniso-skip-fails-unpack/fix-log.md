# Fix log - 338-uniso-skip-fails-unpack

Backlog item `iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success`.

## Measurement before (main at 0cec8e25)

- `.\build.cmd` (Debug x64, up to date). Probe `probe/iso338_probe.ps1` (new; seeds by `mkimg338.sh` in WSL
  Ubuntu genisoimage, damaged copies by `img338.py`) through `tools\run_on_hidden_desktop.ps1` with
  `-NonInteractive -Lib <098 lib>` -> `probe/result_before.txt`: **PASS 10, FAIL 6** - every RUN row but the
  controls OK / O-YES deleted the image: R-SKIP (read error, Skip), R-SKIPALL (Skip all; the second read
  error showed no box), C-SKIP (folder top.txt in the target, Skip), O-SKIP (user's top.txt, overwrite Skip),
  TWINS (two records TOP.TXT, overwrite Yes - top.txt = TOU, TOP lost), D-SKIP (a file zlast in the target:
  "Error Creating Directory" with Retry / Cancel only - closed, then z.txt's box Skip). Registry restored +
  identical.
- Reachability: Alt+F9 on an image in the panel -> core Unpack dialog -> `UnpackWholeArchive` ->
  `ExtractAllItems` -> `CISOImage::UnpackFile` -> reader's `UnpackFile` (default configuration).
- Code read: `ExtractAllItems` keeps only `UNPACK_CANCEL`; `UnpackDir`'s result ignored; the readers'
  silent read errors return `UNPACK_OK` (research R2); HFS+ cases R3; the core's `AddFile` keeps
  same-name files (R4).

## Decisions

See spec *Clarifications* and research R1-R5.

## Analyze

- Run 1: HIGH F1 (FR-003 vs the fail-closed edge case) - FR-003 qualified; MEDIUM E1 (FR-007 without a task)
  - T018 added; LOW E2 / E3 (saltests mutant, no-UI-string check) - named in T003 / T014.
- Run 2: no CRITICAL / HIGH; LOW: T018 not in the dependency line (accepted).

## Implementation

- `src/common/salisounpack.h` (new, header-only): `SAL_ISO_UNPACK_*` (asserted equal to uniso's `UNPACK_*` in
  `isoimage.h`), `SalIsoFileUnpackResult`, `SalIsoUnpackItemWhole`, `CSalIsoWholeUnpackTally`,
  `SalIsoWholeUnpackSucceeded`, `CSalIsoWrittenFiles` (identity keys of `salsamefile.h` in an
  `unordered_set`; a written file without a usable id / not read / no memory -> `Lost`, fails closed).
- Readers: iso9660 / rawfs / udf / xdvdfs / hfs `UnpackFile` end with `SalIsoFileUnpackResult(ret,
  bFileComplete)`; hfs also: extents ending before the size -> incomplete (removed, no box), a listed
  record that is not a file record -> the existing "damaged B-tree" box + error.
- `CISOImage::ExtractAllItems` takes the tally and the written set: any file result but OK -> `NotWhole`,
  a folder `UnpackDir` did not create -> `NotWhole`, Cancel -> `Cancelled`; before each file its target
  (folder + `AppendSafeName`, wide with the long-path prefix) is checked: when it exists, its identity is asked of the set;
  after an OK result `WroteOverOwn` is set if it was one of ours, and the file's identity is noted.
- `UnpackWholeArchive`: `ret = SalIsoWholeUnpackSucceeded(tally, FALSE)`; the listing's `ListingLeftOut`
  check below it unchanged.
- T018 (FR-007), read: `UnpackArchive` (Copy) still breaks only on `UNPACK_CANCEL` - the readers' new
  ERROR results change nothing there; a listed HFS+ entry that is not a file record now shows the damaged
  B-tree box in Copy too (it extracted nothing silently). `UnpackOneFile` returns `err == UNPACK_OK` as
  before; with an overwrite answered All before a read error (silent mask set by `SafeFileCreate`) it now
  fails instead of reporting a missing file as extracted.
- No `.rc` / `.rc2` / `.rh` change (no UI string).

## Checks

- `.\build.cmd` BUILD SUCCEEDED (pre-existing C4267 warnings in uniso unchanged lines only).
- saltests 28,693 -> 28,740 / 0 (`TestIsoWholeUnpack_338`, +47). Negative control: both rules mutated
  (`SalIsoFileUnpackResult` returns `ret`, `SalIsoWholeUnpackSucceeded` ignores NotWhole / WroteOverOwn) ->
  5 FAIL.
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- clang-format `--dry-run` of the changed lines only (session script, `--lines`): two comment alignments in
  saltests fixed; the other files clean; saltests.cpp diff stays +158 / -0.
- Probe after: `probe/result_after.txt` **PASS 18, FAIL 0** (9 RUN rows; R-SILENT added during
  implementation: overwrite answered All, then z.txt's read error shows no box - the only row whose sole
  loss is the readers' silent path; R-SKIPALL alone could not prove it, its first file is a Skip).
- Negative controls on the probe: both rules mutated -> `probe/result_negative.txt` PASS 10 / FAIL 6 (the
  rows of the 'before' run; R-SILENT not yet in the probe); readers' rule alone mutated -> 
  `probe/result_negative_reader.txt` `-Only R-SILENT,R-SKIP`: R-SILENT FAIL (image deleted, z.txt lost),
  R-SKIP PASS (the tally). TWINS failed under the first mutant with no skip in it, so it is kept by
  `WroteOverOwn` alone.
- Regressions on the fixed build: `probe/regress_330.txt` 30 / 0, `probe/regress_337.txt` 74 / 0 (as at
  their closing).
- After clang-format: `.\build.cmd` BUILD SUCCEEDED, saltests 28,740 / 0; `git diff main -- *.rc *.rc2 *.rh`
  empty (FR-005).
