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
