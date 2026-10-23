# Tasks: The ISO plug-in checks an HFS+ catalog against the image; Joliet file names kept whole

**Input**: `specs/322-uniso-hfs-btree-joliet/` (spec, plan, research, data-model, contracts, quickstart)
**Tests**: requested by the spec (FR-007, FR-010, SC-001..SC-005) - `saltests` checks and a probe.

## Phase 1: Setup

- [ ] T001 Start `specs/322-uniso-hfs-btree-joliet/fix-log.md` with the measurement of a222bd88 (code reading, callers) and the test-image tooling (`~/tc-xorriso` in WSL)
- [ ] T002 [P] Write the WSL image script `specs/322-uniso-hfs-btree-joliet/probe/mkimg322.sh` (fetch xorriso without root if missing; make the hybrid ISO 9660 + Joliet + Rock Ridge + HFS+ seed of a given tree)
- [ ] T003 [P] Write the mutation script `specs/322-uniso-hfs-btree-joliet/probe/mut322.py` (locate the HFS+ volume header and catalog in a seed, write an HFS+-only image, write targeted catalog damages and seeded random mutations of the catalog and of the ISO 9660 / Joliet / Rock Ridge descriptor and directory sectors)
- [ ] T004 Write the probe `specs/322-uniso-hfs-btree-joliet/probe/iso322_probe.ps1` in the style of `specs/223-uniso-crafted-image/probe/iso223_probe.ps1` (registry backup / restore, fixture under `%TEMP%\tc322`, rows: valid controls, targeted damages, Joliet CJK, fuzz)

## Phase 2: Foundational (measure before the fix)

- [ ] T005 Build Debug x64 of the unchanged branch (`.\build.cmd`) and run the probe as `result_before.txt`; record in `fix-log.md` which rows fail before the fix (expected: Joliet CJK cut; targeted damages close or hang the program)

## Phase 3: User Story 1 - a damaged HFS+ catalog is refused (P1)

**Independent test**: the targeted-damage rows and the HFS+ valid controls of the probe; `TestHfsCatalog322`.

- [ ] T006 [US1] Create `src/common/salhfscatalog.h` per `contracts/salhfscatalog.md` (walk with bounds, cycle bitmap, record table bounds; key view)
- [ ] T007 [US1] Add `TestHfsCatalog322` to `src/saltests/saltests.cpp` (hand-built valid catalogs of 1 and 3 leaf nodes; each single-field damage of research R1; key view cases; empty tree) and register it in `main`
- [ ] T008 [US1] Use the walk in `CHFS::BTree::BTree` (`src/plugins/uniso/hfs.cpp`): bound `logicalSize` by `totalBlocks * blockSize`, refuse a short / damaged catalog with `IDS_ERR_HFS_BTREE_DAMAGED`, keep `IDS_ERR_HFS_BTREE_NODETYPE` for a non-header first node; `GetRecord` returns the record's available bytes (`src/plugins/uniso/hfs.h`)
- [ ] T009 [US1] Check the key, name and folder / file data of each record in `CHFS::GetRootName`, `CHFS::ListDirectory` and `CHFS::UnpackFile` (`src/plugins/uniso/hfs.cpp`) with `SalHfsCatalogKeyView`; skip (listing) or refuse (extraction) a record that does not fit
- [ ] T010 [US1] Add `IDS_ERR_HFS_BTREE_DAMAGED 1061` to `src/plugins/uniso/uniso.rh2` and its English text to `src/plugins/uniso/lang/lang.rc2`

## Phase 4: User Story 2 - Joliet names kept whole (P2)

**Independent test**: the probe's Joliet CJK row (IMAPI2 image, 12-letter CJK names extracted whole).

- [ ] T011 [US2] In `CISO9660::ExtractExtFileName` (`src/plugins/uniso/iso9660.cpp`) copy a Joliet name (already UTF-8) whole instead of to `LengthOfFileIdentifier` bytes

## Phase 5: User Story 3 - the fuzzing pass (P3)

**Independent test**: `TestHfsCatalog322`'s mutation loop and the probe's fuzz rows.

- [ ] T012 [US3] Add the deterministic mutation fuzz (>= 10,000 mutations, exact-size heap copies, every returned record inside the buffer) to `TestHfsCatalog322` in `src/saltests/saltests.cpp`
- [ ] T013 [US3] Run the probe's fuzz rows (>= 100 mutated images over HFS+, ISO 9660, Joliet, Rock Ridge); fix every out-of-bounds read or endless loop they find in those readers in `src/plugins/uniso/` (FR-011), other findings to the Inbox

## Phase 6: Polish & cross-cutting

- [ ] T014 `.slt` refresh of module `uniso` for the new string (stop-rules §2.13), pins if needed, `slt --verify`
- [ ] T015 Checks: `python tools/check_encoding.py --strict`, `.\build.cmd full`, `saltests`, the probe `result_after.txt`, feature 223's `iso223_probe.ps1` as a regression
- [ ] T016 Complete `fix-log.md` (before / after, commands, translations)

## Dependencies

T001-T004 -> T005 (before-measurement) -> US1 (T006 -> T007, T008 -> T009; T010 with T008) and
US2 (T011, independent of US1) -> US3 (T012 needs T006; T013 needs US1 + US2) -> T014-T016.

## Parallel opportunities

T002 / T003; T011 alongside T006-T010 (different files).

## Implementation strategy

MVP = US1 (the item's main point). Then US2, then the fuzz pass, then translations and checks.
