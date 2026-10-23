# Closing report - 328-uniso-refused-entry
Backlog item: iso-plug-in-an-entry-the-listing-refuses-ends-the-listing - ISO plug-in: an entry the listing refuses ends the listing with Error, a folder lost
Outcome: closed

## What changed

- `src/common/salisonamefit.h` (new, header-only): `SalIsoPickFileName` (Rock Ridge name when the
  listing takes it, else ISO 9660, else left out), `SalIsoFolderKeepsRockRidge` (subtree fits / not
  longer / no fewer entries listed with ISO 9660 names below), `CSalListingLeftOut` (count, first 10
  whole paths, `Incomplete`, report text).
- `src/plugins/uniso/iso9660.cpp/.h`: `AddFileDir` asks the listing's rule first and returns listed /
  left out / failed - a refused entry is noted on the image, never `dir->Clear`, no "Error", later
  folders still descended; the whole-volume fit check runs for every non-Joliet volume and switches on
  a decision mode (`PickDirName`, `CountUnder`, `MakeIsoName`) instead of 326's whole-volume ISO 9660
  names; each walk meets a directory once (`Visited`, count walks undo theirs via `VisitedLog`); the
  walk's name buffers on the heap.
- `src/plugins/uniso/isoimage.h`: `CISOImage::ListingLeftOut`.
- `src/plugins/uniso/uniso.cpp/.h`: `ListArchive` reports left-out entries (system text 206 + paths,
  heap text) and sets `CPluginDataInterface::ListingLeftOut`; `UnpackWholeArchive` then fails (the
  core keeps the image with "Delete archive after unpacking").
- `src/saltests/saltests.cpp`: `TestIsoNameFit328` (rules at their bounds, a simulator of the walk on
  the probe's tree and on 400 random trees, the report text).
- No UI string, dialog or resource changed (the report uses the system's error text) - no `.slt`
  refresh; the plug-in interface is unchanged.

## Measurements (before / after, commands)

Probe `probe/iso328_probe.ps1` (hidden desktop, `tools\run_on_hidden_desktop.ps1`; seeds by
`probe/mkimg328.sh` in WSL: genisoimage -R / -J, xorriso, patched copies):

- before (main d61d0612): `probe/result_before.txt` - 0 of 6 RUN rows: "UnISO: Error", the deep tree
  and `zlast\z.txt` lost (genisoimage -R, no-SP, Joliet); xorriso under ISO 9660 names; Unpack +
  Delete deleted the image after 2 of 4 files.
- after: `probe/result_final.txt` - **PASS 20, FAIL 0** (G/X/L-COPY, J-COPY, J-UNP-DEL, G-UNP-DEL,
  LONG-G, LONG-X, LOOP-RR, LOOP-J, each with its END row).
- negative controls: decision mode off + unpack not failing `probe/result_negctl.txt` 7 / 5; no visited
  set `probe/result_negctl_loop.txt` LOOP 0 / 2; the reach rule of review 2's build
  `probe/result_review3_before.txt` (8.3 names); a mutant of the folder rule in saltests 6 failed.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (no `full`: no resources, strings or language files changed).
- saltests: 27,986 (main) -> **28,018 checks, 0 failed**.
- Regression probes (`probe/regress_*.txt`): 326 `iso326_probe` 28 / 0, 326 `twins326_probe` 8 / 0,
  327 `iso327_probe` 77 / 0, 322 `iso322_probe` 18 / 0.
- Stress (fix-log, Review 2): 20,000 wide Rock Ridge folders 11.3 s CPU (main 16.4 s), a 120-level
  chain 0.7 s (main 0.7 s), all responsive.

## Reviews (findings and what was done)

- Review 1 - the agent stopped with the session; its partial work: MUST, crafted folder cycles hung
  the listing (main's "Error" had ended the walk by accident) - fixed (visited set), rows LOOP-RR/J.
- Review 2 - stopped; its stress images showed two costs of that fix - fixed (undo log; no count walk
  for names not longer than the ISO 9660 ones).
- Review 3 - MUST: a reach rule (in-image path below MAX_PATH) renamed listed Rock Ridge files to 8.3
  names - reverted to the listing's rule only; rows LONG-G/X; saltests.
- Review 4 - no MUST; SHOULD: out-of-memory entries mark the listing incomplete (taken), spec US3
  corrected to what is delivered; read errors (pre-existing) to Inbox; NOTEs recorded as limits.

## Owed to a person (with the new person-step items)

- Nothing: every probe row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses` - ISO plug-in: UDF, Xbox and HFS+ entries
  the listing refuses end their folder with Error (`measure:328`).
- `iso-plug-in-unpack-deletes-image-with-unreadable-folder` - ISO plug-in: Unpack with Delete archive
  deletes an image whose folder could not be read (`review:328`).
