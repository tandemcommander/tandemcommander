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
