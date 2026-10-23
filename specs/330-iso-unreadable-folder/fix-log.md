# Fix log - 330-iso-unreadable-folder

Backlog item `iso-plug-in-unpack-deletes-image-with-unreadable-folder` (review 4 of feature 328).

## Measurement before (main at ae41208d)

- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- Review 4 of 328's probe, unchanged, on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\rev328d\rd_before330.txt -CommandLine
  "powershell ... -File %TEMP%\rev328d\rd_probe.ps1 -Exe build\...\tandemcommander.exe -Label before
  -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1"` with `%TEMP%\rev328d\img\rderr.iso`
  (genisoimage `-R` of `a/side.txt`, `top.txt`, `zlast/z.txt`; folder A's directory record pointed at
  sector 0x00100000):
  row RDERR-UNP-DEL: box "Error reading directory structure at sector #00100000. Incomplete content
  of ISO image.", **files 1: top.txt**, **image kept: False** (deleted). Registry restored identical
  (SHA-256 4F221E76...51E7).
- Code at HEAD: `CISO9660::ListDirectoryRe` returns `ERR_TERMINATE` / `ERR_CONTINUE` on every
  failure; the parent turns a nested `ERR_TERMINATE` into `ERR_CONTINUE` and then descends no later
  folder ("descend only when everything is OK"); only `AddFileDir` marks `Image->ListingLeftOut`.
  `CUDF::ListDirectory` / `CUDF::ScanDir` and `CXDVDFS::ScanDir` show the same box after a failed
  directory read without a mark. `UnpackWholeArchive` fails only on the mark.
- Reachability: Alt+F9 on a damaged `.iso` (default configuration: `uniso` is on), "Delete archive
  after unpacking" -> core `UnpackWholeArchive` -> `ListArchive` -> `CISOImage::ListImage` ->
  `CISO9660::ListDirectory` (or `CUDFISO` -> `CUDF` / `CISO9660`; `CXDVDFS` for Xbox images).

## Decisions

- Scope (spec Clarifications): ISO 9660 - every non-OK result of the real walk; UDF / Xbox - every
  "Error reading directory structure" site. Damaged entries skipped by UDF `MapICB` / HFS+ records
  stay with the Inbox item `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`.
- Later folders are still not descended after a read error (the item's "separate question") -> a new
  Inbox idea (T013).
- Analyze: no CRITICAL / HIGH. Accepted MEDIUM C1 - the root-unreadable edge case has no probe row
  (patching the root affects the volume's detection at the open); covered by reading: the root's
  read failure returns `ERR_CONTINUE`, non-OK at the top -> marked. Accepted LOW C2 - a folder cycle
  returns `ERR_OK` from 328's visited set (unchanged code), not marked.

## Probe before the fix (T005)

`probe/iso330_probe.ps1` (new; seeds by `mkimg330.sh` in WSL, damaged copies and Xbox images by
`img330.py`) on the unfixed build at 9552801e -> `probe/result_before.txt`: **PASS 10, FAIL 4** -
controls RD-OK, UD-OK, XD-OK PASS (every file, no window, image deleted); RD-EXT, RD-REC, UD-EXT,
XD-EXT FAIL: the box, the listed files extracted (top.txt; UD-EXT also the three files of the intact
"ISO (TC330)" part), **the image deleted**. Registry restored identical.

## Implementation

- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectory`: the real walk's result other than
  `ERR_OK` -> `Image->ListingLeftOut.SetIncomplete()`; the return value is unchanged
  (`!= ERR_TERMINATE`). The fit-check walk before it is not looked at (it reads the same directories;
  the real walk meets the same failure or is already non-OK).
- `src/plugins/uniso/udf.cpp`: `SetIncomplete()` before the three `Error(IDS_ERROR_LISTING_IMAGE)`
  (`CUDF::ListDirectory` File Set Descriptor read; `CUDF::ScanDir` first and continuation reads).
- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir`: the same before its one site.
- No UI string, resource or dialog changed -> no `.slt` refresh; no manual change (no new behaviour
  visible beyond the image being kept).

## Checks after the fix

- `.\build.cmd` -> BUILD SUCCEEDED (C4267 warnings only on existing lines).
- Probe after -> `probe/result_after.txt`: **PASS 14, FAIL 0** (7 RUN rows + 7 END rows): RD-EXT,
  RD-REC, UD-EXT, XD-EXT now "image kept: True" with the same box and files; controls unchanged
  (image deleted). Registry restored identical.
- Negative control: the same probe on the unfixed build is `result_before.txt` (4 damaged rows FAIL).
- Regressions: `iso328_probe.ps1` -> `probe/regress_328.txt` **20 / 0**; `iso329_probe.ps1` ->
  `probe/regress_329.txt` **14 / 0**.
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); saltests -> 28266 checks, 0 failed
  (no change to `src/common/`; run as a guard).

## Inbox

- `iso-plug-in-after-a-folder-that-cannot-be-read-no-later` (improvement, 4, `leftover:330`): later
  folders are still not descended after a read error.

## Review

### Review 1 (stopped before its report; partial work used)

The reviewer's agent ended with the session (no report). It left its scratch work in
`%TEMP%\rev330` and an interrupted probe: `%TEMP%\tc330_backup.reg` and the fixture `%TEMP%\tc330`
remained. The run restored the registry first (stop-rules 2.8): the backup's SHA-256 was the known
4F221E76...51E7, the live key differed (D982EEE3...); `reg delete` + `reg import`, re-export identical
(4F221E76...51E7); backup and fixture removed.

Its probe outputs (`%TEMP%\rev330\out1..4.txt`):
- `iso330_probe.ps1` re-run on the fixed build: 14 / 0 (the claim reproduced).
- Its own rows (`rev330_probe.ps1`, images `rev330img.py`, `mkhide.sh`) on the fixed build:
  RD-ZERO (folder A data length 0) PASS - image kept, no box; **UD-ICB** (folder a's identifier ICB
  past the end: listed empty, no box), **UD-TAG** (folder a's directory first tag invalid: "Invalid UDF
  Tag ID.") and **UDH-ROOT** (hybrid with side.txt only in the UDF part; the root ICB past the end: "Bad
  root ICB. Cannot read directory structure.") FAIL - **the image deleted**, side.txt lost in UDH-ROOT.
  Pure-UDF rows (ISO 9660 descriptor removed) did not open ("Unknown file format") - not usable.
- Treated as MUST findings (data loss for "a folder that could not be read", inside the item's title).

Fix (second approach for UDF / Xbox, research R2 revised): `CUDF::ListDirectory` and
`CXDVDFS::ListDirectory` take ISO 9660's top-level rule (walk result != `ERR_OK` -> mark); UDF also
marks the early returns (FSD tag not found, root ICB not mapped / not a directory - the FSD read error
mark stays) and, in `ScanDir`, a folder whose `MapICB` fails (now `if (MapICB) { if (ret == ERR_OK)
descend } else mark` - `MapICB` is still called first, as before). The per-site marks of the first
version in `ScanDir` were removed (the top-level rule covers them). Side effect: a UDF *file* whose
entry cannot be read (`ADD_FAILED` ends its directory) is marked too - part of the Inbox item
`iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`; its HFS+ part stays open.

Probe extended with the reviewer's cases (`img330.py` isozero / udficb / udftag / udfroot,
`mkimg330.sh` udh.iso with `-hide side.txt`): rows RD-ZERO, UD-ICB, UD-TAG, UDH-OK, UDH-ROOT; the
damaged rows now take the expected box text (or none). Trap: the row's `$box` was the parameter
`$Box` (PowerShell names ignore case) - the text printed "True"; renamed `$winOk` (verdicts were not
affected).
- Before, on main's build (ae41208d, the reviewer's `%TEMP%\rev330\negtree`) ->
  `probe/result_before_review1.txt`: **PASS 16, FAIL 8** - all eight damaged rows FAIL (image
  deleted), the four controls PASS.
- After, `.\build.cmd` BUILD SUCCEEDED -> `probe/result_after_review1.txt`: **PASS 24, FAIL 0**.
- Regressions again: `regress_328.txt` 20 / 0, `regress_329.txt` 14 / 0; encoding guard TOTAL 0;
  saltests 28266 / 0. Registry restored identical in every run.

### Review 2 (completed) - one MUST, one SHOULD, NOTEs

Re-checked the diff (return values unchanged, every failure path keeps `ret` non-OK to the top, callers
unchanged; no names, strings or buffers touched) and ran its own rows on the HEAD build at 91f37bcf:
UD-ICB, UDH-OK PASS; R2-RD-ROOT (ISO 9660 root past the end) PASS - closes analyze finding C1 by
measurement.
- **MUST 1**: a hybrid whose UDF part does not open (`udh.iso` with the UDF anchor's main volume
  descriptor sequence past the end): "Cannot read sector #00100000." twice, the ISO 9660 part's two
  files extracted, **image deleted**, side.txt (only in the UDF part) lost - `CUDFISO::Open` dropped the
  part silently and `CUDFISO::ListDirectory` returned TRUE. **Fixed**: `CISOImage::OpenTrack` passes the
  declared parts (`hasISO` / `hasUDF` from the track type) to `CUDFISO`; `Open` sets `PartMissing`
  when a declared ISO 9660 or UDF part did not open; `ListDirectory` marks the listing. HFS+ keeps its
  quiet open (NOTE 3).
- SHOULD 2 (by reading; needs a multi-session container): a session track that does not open
  (`CISOImage::ListImage`, `IDS_ERROR_OPENING_MULTISESSION`) and the single-session fallback accept the
  listing as complete - outside this feature's unit (whole tracks, not folders / parts) -> Inbox
  `iso-plug-in-unpack-with-delete-archive-deletes-a-multi` (bug, 7, `review:330`).
- NOTE 3: an HFS+ part that does not open is dropped quietly, no mark -> Inbox
  `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is` (bug, 6, `review:330`; related to the
  xorriso hybrid item - valid hybrids must be measured first).
- NOTE 4: UD-ICB, RD-ZERO and an unreadable UDF file entry show no message - the image is kept and
  nothing says what is missing; the spec's choice (FR-004, no new UI string). Accepted.
- NOTE 5: a folder cycle is listed empty and not marked (analyze C2). Accepted.
- NOTE 6: `%TEMP%\tc330seed` was left by this run's first seed test - removed.

Probe extended (`img330.py` isoroot / udfavdp; rows RD-ROOT, UDH-AVDP):
- before, on main's build (`%TEMP%\rev330\negtree`, ae41208d), `-Only RD-ROOT,UDH-OK,UDH-AVDP` ->
  `probe/result_before_review2.txt`: RD-ROOT FAIL, UDH-AVDP FAIL (image deleted), UDH-OK PASS.
- after, `.\build.cmd` BUILD SUCCEEDED -> `probe/result_after_review2.txt`: **PASS 28, FAIL 0** (14 RUN
  rows).
- Regressions (hybrids are touched now): `regress_322.txt` 18 / 0 (valid xorriso ISO + HFS+ hybrid,
  row HYB), `regress_327.txt` 77 / 0, `regress_328.txt` 20 / 0, `regress_329.txt` 14 / 0; encoding guard
  TOTAL 0; saltests 28266 / 0. Registry restored identical in every run.
