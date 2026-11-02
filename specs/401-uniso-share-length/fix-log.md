# Fix log - 401-uniso-share-length

Backlog item `iso-plug-in-an-iso-9660-folder-met-again-with-a-larger` - ISO plug-in: an ISO 9660 folder
met again with a larger length is listed empty.

## Measurement before (main 53eb98ab)

- Read: `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` - `block` and `size` from the
  record; `if (!Visited->insert(block).second) return ERR_OK;` - the key is the block alone.
  `Visited` is `std::set<DWORD>*` (`iso9660.h`), the count walks' log `std::vector<DWORD>*`
  (`VisitedLog`, `CountUnder` erases its entries); the fit walk in `ListDirectory` uses its own
  `std::set<DWORD> fitVisited`, the listing walk `std::set<DWORD> visited`.
- Reachable: Unpack (Alt+F9) / panel listing of an image -> `CISOImage::ListImage` ->
  `CISO9660::ListDirectory` -> `ListDirectoryRe` (default configuration, uniso on).
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- New images `probe/img401.py` (plain ISO 9660 written from scratch, no WSL) and probe
  `probe/iso401_probe.ps1` (style of 400's `iso400_probe.ps1`).
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File ...\iso401_probe.ps1 -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib ..."` -> PASS 6 / FAIL 4
  (`probe/result_before.txt`; registry restored, identical):
  - IS-SHARE: A/A1.TXT, TOP.TXT only (b/a1.txt, b/a2.txt missing), no window, image deleted
  - IS-SHARE2: b/a1.txt missing, image deleted
  - IS-LOOP: a/l/a1.txt, a/l/a2.txt missing, image deleted
  - IS-MANY: only A/A1.TXT, TOP.TXT, image deleted
  - IS-HLINK (control, 328's rule): PASS
- Defect confirmed: `BL verify` recorded.

## Implementation

- `src/common/salisowalk.h`: `SalIsoFolderVisitKey(start, length)` = `(length << 32) | start`.
- `src/plugins/uniso/iso9660.h`: `Visited` `std::set<unsigned long long>*`, `VisitedLog`
  `std::vector<unsigned long long>*`.
- `src/plugins/uniso/iso9660.cpp`: `ListDirectoryRe` inserts / logs / erases
  `SalIsoFolderVisitKey(block, size)`; `ListDirectory`'s `fitVisited` / `visited` and `CountUnder`'s
  `countLog` take the 64-bit keys (count walks still take out exactly what they added).
- `src/plugins/uniso/xdvdfs.cpp`: `VisitFolder` uses the shared function (the same value as its
  inline `((unsigned long long)size << 32) | sector`).
- `src/saltests/saltests.cpp`: `TestIsoWalk401` - the key (8 checks) and a model walk of the probe's
  images and a 30-length chain (11 checks), with the key and with 328's key by start alone.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (the three C4267 warnings of uniso are pre-existing lines:
  iso9660.cpp 466, udf.cpp 859, xdvdfs.cpp 118).
- saltests -> `saltests: 282328 checks, 0 failed` (400 recorded 282,309; +19 = TestIsoWalk401).
- Mutant (the key returns the start alone, build + saltests): `282328 checks, 11 failed` (every
  length-dependent check and model row) - restored, rebuilt, 0 failed.
- Probe after: `probe/result_after.txt` -> PASS 10 / FAIL 0 (IS-SHARE: A/A1, B/A1, B/A2, TOP; IS-SHARE2;
  IS-LOOP: A/L/A1, A/L/A2 and the loop ends; IS-HLINK unchanged; IS-MANY: 42 files), no window, the
  images deleted (nothing damaged, everything extracted), registry restored identical.
- Negative control: the same probe on main's build (`probe/result_before.txt`) 6 / 4.
- Regressions (same build, hidden desktop): `iso328_probe.ps1` -> `probe/regress_328.txt` PASS 20 / FAIL 0
  (LOOP-RR, LOOP-J included; recorded 20 / 0); `iso400_probe.ps1` -> `probe/regress_400.txt` PASS 48 /
  FAIL 0 (XD-SHARE, XD-HLINK, UD-HLINK included; recorded 48 / 0); registry restored identical each time.

## Decisions

- The item's *Approach*: key by block and data length (walk again), as 400's `CXDVDFS::VisitFolder`.
- Same block and same length met again: 328's behaviour kept (listed empty, not marked) - not named by
  the item (stop-rules §1 step 4); UDF / Xbox mark it since 400 - inconsistency -> Inbox item.

## Inbox

- `iso-plug-in-an-iso-9660-folder-met-again-is-listed-empty-and` (measure:401) - same block and same
  length met again: listed empty, not marked, the image deleted (UDF / Xbox mark it since 400).

## Review

### Review 1 (refute-first, general-purpose agent) - no MUST

Built `uniso.spl` of main (53eb98ab) and HEAD (d8f5358f) in its own worktrees and build folders, swapped
into copies of the Debug tree. `iso401_probe.ps1`: main fails IS-SHARE, IS-SHARE2, IS-LOOP, IS-MANY
(as result_before), HEAD passes all five. saltests of HEAD 282,302 / 0 (the 26 fewer than here are 305's
volume-dependent checks). Callers enumerated (fit walk, listing walk, `CountUnder`, recursion,
`CUDFISO::ListDirectory` for hybrids) - all take the 64-bit key; `CountUnder` removes only its keys; the
Xbox key value unchanged; extraction reads the listing's extents (B/A2.TXT right). Registry restored
identical; its worktrees removed.

- S1 (SHOULD) - the bound is quadratic in folder records: N = 2,000 folders at one block with 2,000
  lengths, 2,000 file records - open 19.4 s / 525 MB private (main 0.3 s / 50 MB, which dropped the
  folders silently). Done: the bound stated in FR-003 and in the `SalIsoFolderVisitKey` comment;
  Inbox item `iso-plug-in-a-crafted-image-of-folders-naming-one-directory` (review:401) for a listing
  budget. Keying by start alone again would bring back the data loss - not done.
- S2 (SHOULD) - a folder length of 2 GiB or more (`int size` negative -> `new char[size]`) shows the
  core's "Insufficient memory" Abort / Retry / Ignore box; reachable before 401 through a fresh block
  (control `isonegfresh`), 401 widens it to a block met before; no data loss (image kept). Done: Inbox
  item `iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows` (review:401), outside the item.
- N1 - saltests check the shared key and a model walk, not `ListDirectoryRe`'s use of it; the GUI probe
  is the proof for the plug-in (its negative control: main's build 6 / 4). Accepted.
- N2 - a longer length past the end of the image now fails closed (one "Error reading directory
  structure" box, image kept; main: listed empty, image deleted) - the spec's edge case, measured.
- N3 - Rock Ridge decision mode with two lengths at one block not probed; code read, no defect.
- N4 - FEATURE-HISTORY / CHANGELOG entries come at closing (step 8).

After review 1: comment and spec changes only (no code); rebuilt, checks below repeated.
- Checks after review 1: `.\build.cmd` BUILD SUCCEEDED; saltests 282,328 / 0; encoding guard 0;
  `probe/result_after_review1.txt` PASS 10 / FAIL 0, registry restored identical.
