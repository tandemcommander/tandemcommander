# Tasks: The ISO plug-in checks an HFS+ catalog against the image; Joliet file names kept whole

**Input**: `specs/322-uniso-hfs-btree-joliet/` (spec, plan, research, data-model, contracts, quickstart)
**Tests**: requested by the spec (FR-007, SC-001, SC-004, SC-005) - `saltests` checks on catalogs
built in memory, a probe with valid images. No mutated or damaged images are generated (spec,
Clarifications; the fuzzing pass is an Inbox item).

## Phase 1: Setup

- [X] T001 Start `specs/322-uniso-hfs-btree-joliet/fix-log.md` with the measurement of a222bd88 (code reading, callers), the test-image tooling (`~/tc-xorriso` in WSL) and the scope decision
- [X] T002 [P] Write the WSL image script `specs/322-uniso-hfs-btree-joliet/probe/mkimg322.sh` (fetch xorriso without root if missing; make valid hybrid / Rock Ridge / plain seeds)
- [X] T003 Write the probe `specs/322-uniso-hfs-btree-joliet/probe/iso322_probe.ps1` in the style of `specs/223-uniso-crafted-image/probe/iso223_probe.ps1` (registry backup / restore, fixture under `%TEMP%\tc322`; valid rows only: Joliet ASCII, Joliet CJK 12 and 40 letters (IMAPI2), Rock Ridge, plain ISO 9660, HFS+-only (the partition of the hybrid seed) list + extract, hybrid open; a row fails on a program exit, a bug report, or a main window that does not answer within 30 s)

## Phase 2: Foundational (measure before the fix)

- [X] T004 Build Debug x64 of the unchanged branch (`.\build.cmd`) and run the probe as `result_before.txt`; record in `fix-log.md` (expected: the Joliet CJK rows cut, the other rows pass)

## Phase 3: User Story 1 - the HFS+ catalog is bounds-checked (P1)

**Independent test**: `TestHfsCatalog322`; the HFS+ valid rows of the probe.

- [X] T005 [US1] Create `src/common/salhfscatalog.h` per `contracts/salhfscatalog.md` (walk with bounds, cycle bitmap, record table bounds; key view)
- [X] T006 [US1] Add `TestHfsCatalog322` to `src/saltests/saltests.cpp` (catalogs of 1 and 3 leaf nodes built in memory; each single field of research R1 out of range refused; key view cases; empty tree) and register it in `main`
- [X] T007 [US1] Use the walk in `CHFS::BTree::BTree` (`src/plugins/uniso/hfs.cpp`): bound `logicalSize` by `totalBlocks * blockSize`, refuse a short / damaged catalog with `IDS_ERR_HFS_BTREE_DAMAGED`, keep `IDS_ERR_HFS_BTREE_NODETYPE` for a non-header first node; `GetRecord` returns the record's available bytes (`src/plugins/uniso/hfs.h`)
- [X] T008 [US1] Check the key, name and folder / file data of each record in `CHFS::GetRootName`, `CHFS::ListDirectory` and `CHFS::UnpackFile` (`src/plugins/uniso/hfs.cpp`) with `SalHfsCatalogKeyView`; skip (listing) or refuse (extraction) a record that does not fit
- [X] T009 [US1] Add `IDS_ERR_HFS_BTREE_DAMAGED 1061` to `src/plugins/uniso/uniso.rh2` and its English text to `src/plugins/uniso/lang/lang.rc2`

## Phase 4: User Story 2 - Joliet names kept whole (P2)

**Independent test**: the probe's Joliet CJK rows.

- [X] T010 [US2] In `CISO9660::ExtractExtFileName` (`src/plugins/uniso/iso9660.cpp`) copy a Joliet name (already UTF-8) whole instead of to `LengthOfFileIdentifier` bytes

## Phase 5: Polish & cross-cutting

- [X] T011 `.slt` refresh of module `uniso` for the new string (stop-rules §2.13), pins if needed, `slt --verify`
- [X] T012 Checks: `python tools/check_encoding.py --strict`, `.\build.cmd full`, `saltests`, the probe `result_after.txt`, feature 223's `iso223_probe.ps1` as a regression
- [X] T013 Complete `fix-log.md` (before / after, commands, translations, the deviation: no fuzzing pass)

## Dependencies

T001-T003 -> T004 (before-measurement) -> US1 (T005 -> T006, T007 -> T008; T009 with T007) and
US2 (T010, independent of US1) -> T011-T013.

## Parallel opportunities

T002 alongside T001; T010 alongside T005-T009 (different files).

## Implementation strategy

MVP = US1 (the item's main point). Then US2, then translations and checks.
