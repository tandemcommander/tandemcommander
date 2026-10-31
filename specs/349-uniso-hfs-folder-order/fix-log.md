# Fix log - 349-uniso-hfs-folder-order

Backlog item `iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent`.

## Measurement before (main at 5cf6564a)

- Site unchanged at HEAD: `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory` - the loop over `pFolders`
  ("The items are sorted according to parentID which means our parent must have been parsed already"),
  falling back to `rootPath`. Reachable: open an ISO 9660 + HFS+ hybrid in a panel, Copy / Unpack.
- Images: `probe/mkimg349.sh` (WSL Ubuntu, xorriso -hfsplus, volume id TC349, ISO 9660 part only
  top.txt). Catalog dump of the seed (`python -I img349.py dump`): a 16, sub 18, b 20, c 22, k 24, kd 26,
  n1 28, n2 29, n3 30, n4 31 - IDs rise depth first in name order; the catalog has two leaf nodes (4096
  bytes) and an index node (depth 2), so `img349.py` re-lays all leaf records and rewrites the index
  keys.
- `probe/img349.py` copies: `move a:b b:c` (hfs_move), `move k:n1/n2/n3/n4` (hfs_long), `cycle a:b`
  (hfs_cycle) - the moved folder's key parent, its thread record's parent, the valences; leaf records
  sorted by (parent ID, name).
- `.\build.cmd` (Debug, up to date) then
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File ...\iso349_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`
  (run from the scratchpad before the branch existed; `probe/result_before.txt`):
  - H-OK PASS (8 files in place, image deleted)
  - H-MOVE FAIL: `HFS (TC349)/a.txt`, `b.txt`, `sub/s.txt` at the HFS+ root; image deleted
  - H-LONG FAIL: "(206)" names `...\n4<60x>\k`, but `HFS (TC349)/k.txt` and `kd/kd.txt` written at the root
  - H-CYCLE FAIL: `a.txt`, `sub/s.txt`, `b/b.txt` at the root; image deleted
  - 5 PASS / 3 FAIL (END rows PASS), registry restored identical.
  The UI language of the profile is Czech (the "(206)" text is Czech) - the probe matches only "(206)".

## Decisions

- The ancestors of a record that are not listed yet are taken first ("on demand"), outermost first,
  then the record; the catalog loop otherwise stays as it is (record classes 332, left-out IDs 329, the
  listing rule, Extent = record index). Their own records are skipped when the loop reaches them.
- A loop of parents: its folders (and the chain below them that led into it) are left out, their IDs kept
  in 329's left-out set (the subtrees follow), the listing marked incomplete; no message (as 332).
- A parent that is no listed folder record (volume root used as the label, metadata folder, damaged
  record, unknown ID) - unchanged, the HFS+ root.

## Analyze

- Pass 1: F1 MEDIUM (T008 changed the skipped-name case against FR-006) - fixed in tasks.md; C1 LOW
  (FR-005 has a unit check, no own probe row) - accepted: H-OK's `top.txt` under the root used as the
  label is that case.
- Pass 2: 0 CRITICAL, 0 HIGH, 0 MEDIUM.

## Implementation

- `src/common/salisonamefit.h`: `CSalHfsFolderOrder` (Add / Seal / IsTaken / Take / Pending,
  `SAL_HFS_PENDING_OK / _LOOP / _NO_MEMORY`) beside 329's `CSalLeftOutIds`. Pending walks up from a
  parent ID through folder records not taken yet, stamping each (the stamp of the current walk = a
  loop), and returns them outermost first; iterative; the first record of a duplicate ID is found.
- `src/plugins/uniso/hfs.cpp`: `CHFS::ListDirectory` collects the `SAL_HFSREC_FOLDER` records first
  (out of memory -> incomplete + "insufficient memory", the listing ends); in the loop a taken record is
  skipped; a listable / not-handled record first gets `TakePending(parentID)`, then (unless it was in a
  loop) `Take(i)` and the old per-record code, now `CHFS::ListRecord` (moved unchanged by a script:
  `continue` -> `return TRUE`, dedented, the "parent must have been parsed already" comment replaced).
  `TakePending`: OK -> each pending folder taken through `ListRecord`; LOOP -> each taken, its ID into
  `leftOutFolders`, listing incomplete, `TRACE_E`, no box. `hfs.h`: the two declarations, forward
  declarations of the two classes.
- `src/saltests/saltests.cpp`: `TestHfsFolderOrder349` - direct cases (in order, moved chain, taken
  middle, unknown parent, self loop, two-folder loop reached from below, the same walk twice, duplicate
  IDs, a 10,000-level reversed chain, Add out of order refused, Take of a record not added) and
  `HfsListing349`, a model of the reader's loop over the probe's three catalogs + the seed.

## Checks

- `.\build.cmd` -> BUILD SUCCEEDED (the C4267 at `fd.NameLen = strlen(...)` in hfs.cpp is the old line,
  also in xdvdfs / audio / udf / iso9660).
- saltests: 29,154 checks, 0 failed (after T003).
- Mutants of `Pending` (each built and run, then `git checkout HEAD -- src/common/salisonamefit.h`):
  A "no walk" (Find replaced by NONE) -> 17 failed; B "no loop guard" (a stamped folder ends the walk as
  OK) -> 17 failed.
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- Probe after (`probe/result_after.txt`): 8 PASS / 0 FAIL - H-MOVE writes `c/b/a/a.txt`, `c/b/a/sub/s.txt`,
  `c/b/b.txt`, image deleted; H-LONG: 6 files, k.txt / kd.txt nowhere, one "(206)" naming `...\n4<60x>\k`,
  image kept; H-CYCLE: 5 files (c, k, top), no box, image kept; registry restored identical. Before
  (main): 5 / 3.
- Regression probes on the fixed build (`probe/regress_<n>.txt`, each registry restored identical): 322 18 / 0,
  329 14 / 0, 332 16 / 0, 333 20 / 0, 339 20 / 0 - the results their features recorded. saltests 29,154 / 0.
- No UI string, dialog or resource changed: no `.slt` refresh (stop-rules 2.13 not triggered).
