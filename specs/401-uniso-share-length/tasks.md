# Tasks: An ISO 9660 folder met again with another length is walked for its own length

**Input**: `specs/401-uniso-share-length/` - plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: the spec's success criteria require the probe and saltests checks - included.

## Phase 1: Setup

- [ ] T001 Record the measurement before (probe `iso401_probe.ps1` PASS 6 / FAIL 4 at 53eb98ab) in specs/401-uniso-share-length/fix-log.md and keep `probe/result_before.txt`

## Phase 2: Foundational

- [ ] T002 Add `SalIsoFolderVisitKey(unsigned long start, unsigned long length)` (64-bit `(length << 32) | start`) to src/common/salisowalk.h with a feature 401 comment
- [ ] T003 Add `TestIsoWalk401` to src/saltests/saltests.cpp (one start with two lengths gives two keys; one pair gives one key; start and length never alias; a `std::set` of the keys of IS-LOOP's records holds 2 entries, IS-MANY's 41) and call it next to `TestIsoWalk400`

## Phase 3: User Story 1 - every folder listed with the files its own record covers (P1)

**Independent test**: probe rows IS-SHARE, IS-SHARE2.

- [ ] T004 [US1] Change `Visited` to `std::set<unsigned long long>*` and `VisitedLog` to `std::vector<unsigned long long>*` in src/plugins/uniso/iso9660.h (comments name feature 401)
- [ ] T005 [US1] In src/plugins/uniso/iso9660.cpp `CISO9660::ListDirectoryRe`: insert / log / erase `SalIsoFolderVisitKey(block, (unsigned long)size)` instead of `block`; update the 328 comment
- [ ] T006 [US1] In src/plugins/uniso/iso9660.cpp `CISO9660::ListDirectory` (`fitVisited`, `visited`) and `CISO9660::CountUnder` (`countLog`): the 64-bit key types

## Phase 4: User Story 2 - crafted loops still end (P1)

**Independent test**: probe rows IS-LOOP, IS-MANY; 328's LOOP-RR / LOOP-J rows.

- [ ] T007 [US2] In src/plugins/uniso/xdvdfs.cpp `CXDVDFS::VisitFolder`: use `SalIsoFolderVisitKey(sector, size)` (the same value as its inline formula - one rule for both walks)

## Phase 5: User Story 3 - same block and length behave as before (P2)

**Independent test**: probe row IS-HLINK; 400's XD-HLINK.

- [ ] T008 [US3] Confirm by reading src/plugins/uniso/iso9660.cpp that a key met again still returns ERR_OK without marking (328's rule) - no code change

## Phase 6: Polish & checks

- [ ] T009 `python tools/check_encoding.py --strict` → TOTAL: 0 finding(s)
- [ ] T010 `.\build.cmd` → BUILD SUCCEEDED; saltests → 0 failed (record the counts in specs/401-uniso-share-length/fix-log.md)
- [ ] T011 Probe specs/401-uniso-share-length/probe/iso401_probe.ps1 after → PASS 10 / FAIL 0 (`result_after.txt`)
- [ ] T012 Regression probes specs/328-uniso-refused-entry/probe/iso328_probe.ps1 and specs/400-uniso-walk-after-unreadable/probe/iso400_probe.ps1 (results into specs/401-uniso-share-length/probe/regress_328.txt, regress_400.txt)
- [ ] T013 Negative control: the probe against the build before the change (result_before.txt) fails 4 rows - recorded in specs/401-uniso-share-length/fix-log.md
- [ ] T014 Inbox item for the ISO 9660 same-pair "met again" not marking the listing (UDF / Xbox mark it since 400) via `bin/backlog.sh new` (source measure:401)

## Dependencies

T001 → T002 → T003; T002 → T004 → T005 → T006 → T007 → T008 → T009..T013; T014 any time.
Parallel: T003 with T004 (different files).

## Implementation strategy

MVP = US1 (T002, T004-T006); US2 and US3 are proven by the same build through the probe.
