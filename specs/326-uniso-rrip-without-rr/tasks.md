# Tasks: The ISO plug-in reads Rock Ridge names of images that carry no `RR` entry

**Input**: `specs/326-uniso-rrip-without-rr/` (plan.md, spec.md, research.md, data-model.md, contracts/salsusp.md, quickstart.md)
**Tests**: requested by the project rules (pure rule -> saltests; GUI probe on the hidden desktop).

## Phase 1: Setup

- [X] T001 Write the seed image script `specs/326-uniso-rrip-without-rr/probe/mkimg326.sh` (xorriso in WSL as feature 322's `mkimg322.sh`): `rr.iso` (folder/note.txt, top.txt; `-joliet off`), `rrlong.iso` (one file, a 200-letter name), `oldrr.iso` (`-compliance old_rr`), `plain.iso` (`-rockridge off`)
- [X] T002 Write the probe `specs/326-uniso-rrip-without-rr/probe/iso326_probe.ps1` in the style of `specs/322-uniso-hfs-btree-joliet/probe/iso322_probe.ps1` (registry backup / restore, fixture under `%TEMP%\tc326`): rows RR, RR-DIR, RR-LONG, OLDRR, LEGACY-RR (a copy of `rr.iso` patched: the root's `SP` check bytes broken, `top.txt`'s first entry `PX` renamed `RR`), PLAIN, J-ASCII (IMAPI2 Joliet); names compared case-sensitively
- [X] T003 Run the probe on the build of `main` (before the fix) on the hidden desktop -> `specs/326-uniso-rrip-without-rr/probe/result_before.txt`; expected FAIL on RR, RR-DIR, RR-LONG, OLDRR; record in `fix-log.md`

## Phase 2: Foundational (the pure rule)

- [X] T004 Create `src/common/salsusp.h` per `contracts/salsusp.md`: `SalSuspSystemUseArea`, `SalSuspIsSp`, `SalSuspRootHasSp`, `SalSuspRockRidgeStart` (header-only, bounds-checked)
- [X] T005 Add `TestSusp326()` to `src/saltests/saltests.cpp` (include `salsusp.h`, call from `main`): the xorriso root `.` record (SP + PX + TF + CE) -> SP, LEN_SKP 0; wrong check bytes / length 6 / version 2 / a cut area -> no SP; a record with an even-length identifier (padding byte); a record whose lengths do not fit -> false; `RockRidgeStart`: `RR` first on a non-SUSP volume -> 0; `PX` first on a non-SUSP volume -> false; `PX` first on a SUSP volume -> 0; LEN_SKP 3 -> 3; LEN_SKP leaving < 4 bytes -> false; `RR` first with LEN_SKP 3 -> 0; an empty area -> false

## Phase 3: User Story 1 - Files of an xorriso Rock Ridge image keep their names (P1)

**Goal**: xorriso Rock Ridge names listed and extracted whole, with their case.
**Independent test**: probe rows RR, RR-DIR, RR-LONG, OLDRR.

- [X] T006 [US1] `src/plugins/uniso/iso9660.h`: members `BOOL SuspVolume; BYTE SuspSkip;` in `CISO9660` (with a feature 326 comment), include `../../common/salsusp.h`
- [X] T007 [US1] `src/plugins/uniso/iso9660.cpp` `CISO9660::CISO9660`: initialise them; `CISO9660::Open`: when not Joliet, read the root extent's first sector (the block `ListDirectoryRe` reads) and set them from `SalSuspRootHasSp` (a failed read -> no SUSP, silently)
- [X] T008 [US1] `src/plugins/uniso/iso9660.cpp` `CISO9660::ExtractExtFileName`: replace the first-entry `RR` check by `SalSuspRockRidgeStart` over the area `[srcSU, srcEnd)` as computed today (empty when `srcSU > srcEnd`; Joliet excluded as today); the entry parsing starts at the returned offset; keep the `CE` / `NM` / `ST` handling of feature 223 unchanged

## Phase 4: User Story 2 - Images that worked keep working (P2)

**Goal**: `RR` images, plain ISO 9660 and Joliet unchanged.
**Independent test**: saltests rule checks; probe rows LEGACY-RR, PLAIN, J-ASCII; feature 322's probe.

- [X] T009 [US2] Build (`.\build.cmd`), run `saltests` -> 0 failed; negative control: break one branch of `SalSuspRockRidgeStart` / `SalSuspIsSp` in a scratch copy and see its checks fail (record in `fix-log.md`)
- [X] T010 [US2] Run `iso326_probe.ps1` after the fix -> `specs/326-uniso-rrip-without-rr/probe/result_after.txt`, every row PASS
- [X] T011 [US2] Run feature 322's probe `specs/322-uniso-hfs-btree-joliet/probe/iso322_probe.ps1` -> `specs/326-uniso-rrip-without-rr/probe/result_322_after.txt`, 18 / 0

## Phase 5: Polish

- [X] T012 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T014 clang-format the changed sources (`src/common/salsusp.h`, `src/plugins/uniso/iso9660.*`, the new part of `src/saltests/saltests.cpp`)
- [X] T015 `CHANGELOG.md`: an entry under the `— unreleased` heading (feature 326), or the entry in `closing-report.md` when no such heading exists
- [X] T013 Update `specs/326-uniso-rrip-without-rr/fix-log.md` (before / after, commands, results)

## Dependencies

T001 -> T002 -> T003 (on `main`'s build, before T006-T008). T004 -> T005, T006 -> T007 -> T008 -> T009 -> T010, T011. US2 verifies US1's change.

## Parallel opportunities

T004/T005 (rule + tests) can be written while the probe (T001/T002) is written; different files.

## Implementation strategy

MVP = US1 (T004-T008) proven by the probe; US2 is the regression proof of the same change.

## Review 1 (MUST M1 and the DEEP measurement)

- [X] T016 `src/common/salsusp.h`: `SalSuspCleanRockRidgeName`; `iso9660.cpp` cleans every `NM` name (FR-008); saltests cases and mutants
- [X] T017 `iso9660.cpp` / `.h`: the fit check pass of `ListDirectory` (`FitCheck`, `FitRefused`, quiet errors) - a volume whose Rock Ridge names the listing would refuse is listed as before 326 (FR-009)
- [X] T018 probe rows DEEP, ESC, COLON, TDOT, DEV (`mkimg326.sh`, `iso326_probe.ps1`); measured before the fix on the branch build and after it
- [X] T019 Inbox items for the parts outside the item (Joliet / ISO 9660 names not cleaned; a refused entry ends the listing)

## Review 2 (partial work of stopped reviewers: case-only twins)

- [X] T020 `src/plugins/uniso/uniso.cpp` `ListArchive`: built case-sensitively, the flag kept only with case twins (`salcasetwins.h`, as `tardll.cpp` since 252) (FR-010)
- [X] T021 probe `probe/twins326_probe.ps1` (from 252's `arc252_probe.ps1`, ISO kind by `probe/mkiso326.sh`): before 3 FAIL / 8, after 8 / 0
