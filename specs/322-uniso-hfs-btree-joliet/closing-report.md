# Closing report - 322-uniso-hfs-btree-joliet
Backlog item: uniso-hfs-btree-trust-and-joliet-cut - ISO plug-in: HFS+ B-tree loader trusts the image; Joliet names cut
Outcome: closed

## What changed

- `src/common/salhfscatalog.h` (new, header-only): `SalHfsCatalogWalk` walks the leaf chain of an
  HFS+ catalog B-tree loaded into memory and uses a node only when it lies wholly inside the
  catalog and has not been met before (a cycle refuses); the node size must hold the header node
  and fit the catalog; the record table must fit its node; every record offset must lie in the
  node's record area. `SalHfsCatalogKeyView` checks a record's key, name and record type.
- `src/plugins/uniso/hfs.cpp` / `hfs.h`: `CHFS::BTree` uses the walk (an empty catalog or one
  larger than its blocks is refused before the allocation; a damaged catalog shows the new
  `IDS_ERR_HFS_BTREE_DAMAGED`, quietly in hybrids as before); `GetRecord` returns each record's
  available bytes; `GetRootName`, `ListDirectory` skip a record whose key / name / folder / file data
  does not fit, `UnpackFile` refuses it before any file is created.
- `src/plugins/uniso/iso9660.cpp` `ExtractExtFileName`: Joliet file names (already UTF-8) are
  copied whole instead of to their UCS-2 byte length.
- `src/plugins/uniso/uniso.rh2`, `lang/lang.rc2`: string 1061; translations of `uniso` refreshed
  (8 languages, 7 pinned to the module's terms), `translations/ui-overrides.json`.
- `src/saltests/saltests.cpp`: `TestHfsCatalog322` (30 checks on catalogs built in memory).
- Probe `specs/322-uniso-hfs-btree-joliet/probe/iso322_probe.ps1` + `mkimg322.sh` (valid images:
  IMAPI2 Joliet, xorriso 1.5.6 in WSL).

## Measurements (before / after, commands)

- `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\322-uniso-hfs-btree-joliet\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`
- Before (build of a222bd88's code): PASS 11, FAIL 3 of 14 rows - J-CJK12 extracted without `.txt`,
  J-CJK40 broken into a 92-unit mojibake name; HYB showed the Xbox reader's message (now recorded,
  not a verdict).
- After review 1: PASS 18, FAIL 0, NOT DRIVEN 0 of 18 rows (RR-LONG and HFS-MANY added; HFS-MANY: a
  valid catalog of 103 leaf nodes, 2084 records); registry restored and identical.
- The HFS+ bounds: measured by code reading at a222bd88 and proven by `TestHfsCatalog322`; no damaged
  image was generated (deviation below).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd full` -> BUILD SUCCEEDED, 189 language modules.
- `saltests: 27776 checks, 0 failed`.
- `iso322_probe` 18 / 0; feature 223's `iso223_probe` ISO-F5 PASS, RR-LONG NOT DRIVEN (Docker not
  running; the case is covered by iso322's RR-LONG row).
- `.slt`: 1 gap a language, 736 DeepL characters, 0 validation failures, `slt --verify` byte-exact.

## Reviews (findings and what was done)

Review 1: no MUST. SHOULD 1 (a probe row with a real many-leaf catalog) taken - row HFS-MANY.
NOTEs 1-6 recorded in `fix-log.md` (redundant / defence-in-depth bounds, the free-space offset in
`Avail`, the allocation still sized from the image's own block count, message wording, MagicISO
tolerance, layout drift). The reviewer's code mutants of each bound fail saltests.

## Deviation (stop-rules §2.14)

The item's "fuzzing pass over HFS+ / ISO9660 / Joliet / Rock Ridge" was not done: this run generated
no mutated or damaged disk images. Recorded in the spec's *Assumptions* and as the Inbox item below
(`who: person`).

## Owed to a person (with the new person-step items)

- The fuzzing pass of the ISO plug-in's readers: `iso-plug-in-a-fuzzing-pass-over-the-hfs-iso-9660-joliet-and`
  (who: person - the maintainer chooses the tool and harness).

## New Inbox items (slug - title)

- iso-plug-in-a-fuzzing-pass-over-the-hfs-iso-9660-joliet-and - ISO plug-in: a fuzzing pass over the HFS+, ISO 9660, Joliet and Rock Ridge readers
- iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot - ISO plug-in: a valid xorriso ISO + HFS+ hybrid opens with Cannot read sector 00000020
- iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read - ISO plug-in: Rock Ridge names of xorriso images are not read, the ISO 9660 names are listed

Test tooling left on the maintainer's machine: `~/tc-xorriso` in WSL Ubuntu (xorriso unpacked
without root; remove with `rm -rf ~/tc-xorriso`).
