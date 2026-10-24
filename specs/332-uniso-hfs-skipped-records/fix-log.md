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

## speckit-analyze

- Run 1: F1 HIGH - FR-003 exempted every U+0000-named record, data-model marks an unknown-type one
  (fixed: FR-003 and the edge case name folder / file records); F2 LOW (covered by F1), C1 LOW (FR-005
  "no message" has no own task - T004 adds no box, the probe checks "no window").
- Run 2: 0 CRITICAL, 0 HIGH; F2 / C1 accepted as above.

## Implementation

- `src/common/salhfscatalog.h`: `SalHfsCatalogRecordClass` (FOLDER / FILE / NOT_ENTRY / DAMAGED /
  UNKNOWN, order as `data-model.md`), `SAL_HFSCAT_FOLDER_REC_SIZE` 88 / `SAL_HFSCAT_FILE_REC_SIZE` 248.
- `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory`: the rule replaces 322's / 223's separate checks;
  NOT_ENTRY skipped; DAMAGED - `ListingLeftOut.SetIncomplete()`, skipped; UNKNOWN - `SetIncomplete()`,
  `return FALSE` (the listing ends as before); a name that does not convert - `SetIncomplete()`,
  skipped. `static_assert` of the two record sizes (first placed at file scope: the structs are
  members of `CHFS` - C2065; moved into the member function).
- `src/saltests/saltests.cpp`: `TestHfsRecordClass332` (35 checks, 322's `Hfs322Record` builder).

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| unit rules | `saltests.exe` | 28,304 -> 28,339 checks, 0 failed |
| negative control | rule mutant: thread records DAMAGED (`(parent == 1)` only) | 3 failed (lines of the thread checks); reverted, 0 failed |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| clang-format | VS 2022 `clang-format --style=file` on the three files | no hunk in the changed lines (the files' other hunks are older) |
| probe after | `iso332_probe.ps1` -> `probe/result_after.txt` | PASS 14 / FAIL 0 (before 10 / 4): H-TYPE / KEY / LONG / SHORT image kept |
| regression | 322 / 328 / 329 / 330 probes -> `probe/regress_*.txt` | 18/0, 20/0, 14/0, 30/0 (as their features recorded) |

Registry restored and identical after every probe run (SHA-256 F92E573A...).
