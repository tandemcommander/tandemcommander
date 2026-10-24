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

## Review

### Review 1 (refute-first agent, on e135085e)

Confirmed: build, saltests 28,339 / 0, probe 14 / 0 (re-run, registry identical), the mark reaches
`UnpackWholeArchive` through `ListArchive` for the hybrid; no record skipped before is listed now;
intact `mkfs.hfsplus` volumes (plain and journaled: root, threads, `.journal`, `.journal_info_block`)
give no DAMAGED / UNKNOWN record.

- MUST 1: every folder / file record whose name starts with U+0000 was NOT_ENTRY - a damaged
  `side.txt` with its first unit zeroed was skipped silently and the image deleted (reviewer's row
  H-NUL). Fixed: NOT_ENTRY only for the folder in the root (parent 2) named exactly
  "<4 x U+0000>HFS+ Private Data" (the only such name Apple writes); every other U+0000-first record is
  DAMAGED. Unit checks: other parent, 20 / 21 units with another last letter, the name as a file,
  "\0ide.txt", "\0x" folder - DAMAGED; the dotted name - FOLDER. Probe row H-NUL added
  (`img332.py nul`): on the review-1 build FAIL - image deleted (`probe/result_review1_nul.txt`), after
  the fix PASS. Mutant (no parent check): 1 failed.
- SHOULD 2: a catalog that 322's walk refuses drops the whole HFS+ part silently and the image is
  deleted (`udfiso.cpp`, HFS opened quietly, no `PartMissing`). Already the Inbox item
  `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is` (330) - not part of this feature.
- NOTE 3: the mark for a name that does not convert cannot be reached any more (U+0000-first names are
  classified before; the buffer takes 255 units; CP_UTF8 without flags replaces lone surrogates) - kept
  as a fail-closed guard, comment added.
- NOTE 4: an UNKNOWN record inside a folder left out by 329 ended the listing (before: skipped with the
  folder). Fixed: `leftOutFolders.Under(parent, false, 0) == SAL_ISO_UNDER_SKIPPED` -> skipped (the
  listing marked). Children of a DAMAGED folder record still land at the HFS+ root (old, spec edge case).
- NOTE 5: U+0000 inside a name lists it cut ("a\0b" -> "a"); lone surrogates -> U+FFFD. Old; new Inbox
  item `iso-plug-in-an-hfs-name-with-u-0000-inside-is-listed-cut-at` (review:332), the surrogates are
  `uniso-hfs-names-lossy-surrogates`.
- NOTE 6: no message when only damaged records were skipped - the recorded decision (FR-005, as 330).

After the fixes: build BUILD SUCCEEDED; saltests 28,345 / 0; probe `result_after.txt` PASS 16 / FAIL 0
(H-NUL added); regression 322 18 / 0, 329 14 / 0 (re-run on this build; 328 20 / 0 and 330 30 / 0 on the
first build - the change since touches only the HFS+ reader they do not open).

### Review 2 (refute-first agent, on d8e666a7)

The first review-2 agent stopped when the session ended, in the middle of its negative-control probe:
`%TEMP%\tc332_backup.reg` (hash F92E573A..., the clean state) was left and the live key differed - restored
from it first (identical F92E573A...), the fixture `%TEMP%\tc332` removed. Its partial work (scratch
`%TEMP%\rev332`) was handed to a fresh review-2 agent (not a new round).

Result: no MUST, no SHOULD.
- saltests 28,345 / 0; its probe copy with rows R2-PRIV (a folder renamed to the exact metadata name:
  image deleted, its contents at the HFS+ root - correct), R2-PRIVX (a near-miss of that name: kept) and
  R2-EMPTY (an empty-named file record: kept) on the branch build 22 PASS / 0 FAIL; on a main build
  (worktree at 6070ac51, own build folder) 15 PASS / 7 FAIL - H-TYPE, H-KEY, H-LONG, H-SHORT, H-NUL,
  R2-PRIVX, R2-EMPTY delete the image there (negative control); registry identical after both.
- Differential test of `SalHfsCatalogRecordClass` against a model of main's loop: 20,000,000 random
  records, 0 mismatches - every record listed before gets the same class, every record that ended the
  listing is UNKNOWN, every skipped record is NOT_ENTRY or DAMAGED (only the exact metadata folder stays
  NOT_ENTRY among the U+0000-first names): an image without such records lists as before (FR-006).
- UDF: every other early exit of `ScanDir` returns a non-OK result and is marked by 330.
- `Under(parent, false, 0)` never allocates or changes state.
- NOTE 1 (old): hard-link data (`iNode<n>` in the metadata folder) listed at the HFS+ root, the link
  records extract empty - new Inbox item `iso-plug-in-hfs-hard-links-extract-as-empty-files-their-data`
  (review:332).
- NOTE 2 (old, narrow): with the volume label in use any record whose parent reads 1 is skipped unmarked.
- NOTE 3: FR-005, no message (recorded decision). NOTE 4: no Mac-made image tried (WSL has no hfsplus).
