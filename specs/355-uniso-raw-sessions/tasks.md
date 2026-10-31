# Tasks: A raw disc image is kept when it holds more than its listing shows, whatever its name

**Input**: `specs/355-uniso-raw-sessions/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-006 saltests checks, SC-001..SC-004 probe rows).

## Phase 1: Setup

- [X] T001 Start `specs/355-uniso-raw-sessions/fix-log.md` with the measurement before (4cc97934, probe 30 / 10, `probe/result_before_debug.txt`) and the decisions of the spec's Clarifications

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `SalIsoRawRestDecision` (data-model.md table; reuses `SAL_ISO_REST_*`, `SAL_ISO_LATER_VOLUME_SECTOR`, `SAL_ISO_ZERO_REST_SECTORS`) after `SalIsoBytesAllZero` in `src/common/salisotrack.h`
- [X] T003 Add `TestIsoRawRest_355` (MARK for unknown size / sector size <= 0 / negative file size or offset / file within the volume; KEEP at 0 and 16 sectors past; CHECK at 17 and 512 with firstSector / sectors; MARK at 513; a data offset and a 2336 / 2448 sector size; a partial last sector not counted) and call it next to `TestIsoCookedRest_354` in `src/saltests/saltests.cpp`

## Phase 3: User Story 1 - a raw multi-session image is kept (P1)

**Independent test**: the probe's R rows keep the image.

- [X] T004 [US1] In `CISOImage::Open`'s plain branch, after 353's `CcdMissing && rawStart` block, add a block for `rawStart && !CcdMissing`: read `SAL_ISO_PVD_BYTES` at `GetSectorOffset(16)`, `SalIsoPvdVolumeSectors`, `SalIsoRawRestDecision`; for CHECK read 2048 bytes of user data per sector (`DataOffset + n * SectorRawSize + SectorHeaderSize`, 64-bit arithmetic) and mark on a short read or a non-zero byte (`SalIsoBytesAllZero`); `ListingLeftOut.SetIncomplete()` with a `TRACE_I` when marked, in `src/plugins/uniso/isoimage.cpp`
- [X] T005 [US1] Build (`.\build.cmd`) and run saltests; then a mutant of the rule that never marks: saltests must fail, record the count in `fix-log.md`

## Phase 4: User Story 2 - one-session raw images unchanged (P2)

**Independent test**: the probe's C rows and 353's U rows.

- [X] T006 [US2] Run `probe/iso355_probe.ps1` on the hidden desktop (quickstart.md step 3) -> `probe/result_after_debug.txt`, every row PASS; with the never-marking mutant build -> the R rows FAIL (`probe/result_mutant_never_marks.txt`)

## Phase 5: Polish

- [X] T007 Regression probes of 354, 353, 352 and 334 on the fixed build -> `probe/regress_<n>.txt`
- [X] T008 `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format `--dry-run` on the changed line ranges only
- [X] T009 `fix-log.md`: after-measurements, the deviation of Notes (no real dump on the machine), limits

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009. T002 and T003 share no file with T004
but T004 calls the rule. MVP: through T006.
