# Fix log - 332-uniso-hfs-skipped-records

Backlog item `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let` (source review:329).

## Measurement before (main at 6070ac51, Debug build up to date - `build.cmd` BUILD SUCCEEDED)

Probe `probe/iso332_probe.ps1` (built on 330's `iso330_probe.ps1`; seeds by `probe/mkimg332.sh` in WSL
Ubuntu - `xorriso -hfsplus` and `genisoimage -udf`; damaged copies by `probe/img332.py`), run with
`tools/run_on_hidden_desktop.ps1` -> `probe/result_before.txt`:

| Row | Image | Result at 6070ac51 |
|---|---|---|
| H-OK | hdh.iso (ISO 9660 + HFS+, a/side.txt only in the HFS+ part) | PASS - 5 files, image deleted |
| H-TYPE | side.txt's record type 5 | FAIL - HFS top.txt only (listing ends), image DELETED |
| H-KEY | side.txt's key length 0xFFFF | FAIL - side.txt missing, image DELETED |
| H-LONG | side.txt's name 256 units in a key that fits | FAIL - side.txt missing, image DELETED |
| H-SHORT | side.txt's record shorter than a file record | FAIL - side.txt missing, image DELETED |
| U-OK | ud.iso (genisoimage -udf) | PASS - 6 files, image deleted |
| U-FILE | a/side.txt's UDF identifier: file entry past the end | PASS - image KEPT (feature 330) |

PASS 10 / FAIL 4 (the END rows of every case pass: no crash, no report). Every HFS+ row shows the known
"Cannot read sector #00000020" box at the open (Inbox `iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot`,
also in 329's probe results) - the probe does not count that box as a window.

- HFS+ part of the item: present. Reachability: `CUDFISO::ListDirectory` calls `CHFS::ListDirectory`
  and ignores its result; `UnpackWholeArchive` fails only on `ListingLeftOut` (uniso.cpp), so the mark
  is the only signal.
- UDF part: fixed by feature 330 - `CUDF::AddFileDir` `MapICB` failure -> `ADD_FAILED` -> `ScanDir`
  `ERR_TERMINATE` (nested: `ERR_CONTINUE`) -> `CUDF::ListDirectory` marks a walk result other than
  `ERR_OK`. U-FILE confirms it. No UDF change in this feature.

### The xorriso catalog (img332.py dump of hdh.iso)

One leaf node (4096 bytes), 12 records: root folder (parent 1, "TC332"), thread records (key length 6,
empty name, types 3 / 4), folders a / zlast, files top.txt / side.txt / z.txt.

## Decisions

- Record kinds (TN1150): thread records (empty name) and the root folder's record (parent 1, the
  volume label) are not entries; a name starting with U+0000 is HFS+ metadata ("\0\0\0\0HFS+ Private
  Data", created by macOS) - today skipped as an "empty name", stays unmarked (marking it would make
  every Mac-made image with that folder fail to unpack).
- An unknown record type still ends the HFS+ listing (existing behaviour) - only the mark is added.
- No message, no UI string (as 330's silent cases).
