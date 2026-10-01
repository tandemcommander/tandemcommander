# Tasks: Unpredictable salts for encrypted ZIP archives (086)

**Input**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/salrandom.md`, `quickstart.md`
**Tests**: requested — FR-004 requires the shared generator to be unit-tested.
**Protocol**: `specs/069-finish-encoding-fixes/contracts/fix-protocol.md`
(HEAD check first — done in research R1 at `e10dfa2`; independent review
before the commit).

## Phase 1: Setup

- [X] T001 Record the HEAD check and the sites (research R1) as the first section of specs/086-zip-aes-salt/fix-log.md

## Phase 2: Foundational (blocks every story)

- [X] T002 Create the header-only generator `SalGenRandom` per contracts/salrandom.md in src/common/salrandom.h (UTF-8 BOM, CRLF, SPDX header)
- [X] T003 Add `TestRandom086` (16-byte success, len 0, len < 0, NULL buffer, two draws differ, 64 KiB draw holds all 256 values, guard bytes around the range untouched) and its call in `main` in src/saltests/saltests.cpp
- [X] T004 Build Debug (`build.cmd`) and run build\tandemcommander\Debug_x64\saltests\saltests.exe — 0 failed

**Checkpoint**: the shared generator exists and is proven.

## Phase 3: User Story 1 — AES-encrypted archives get unpredictable salts (P1) 🎯 MVP

**Goal**: every AES salt the ZIP plugin writes comes from the system generator.
**Independent test**: quickstart.md steps 1–2, 4–6 (four AES-256 archives,
no repeated salt, all test OK in 7-Zip).

- [X] T005 [US1] Make `FillBufferWithRandomData` call `SalGenRandom`, keeping the old generator only as a `TRACE_E`-traced fallback, in src/plugins/zip/crypt.cpp (include `../../common/salrandom.h`)
- [X] T006 [P] [US1] Write the salt reader with `--selftest` (creates AES-256 and ZipCrypto archives with 7-Zip, reads the salts/headers back, checks the parser) in specs/086-zip-aes-salt/probe/zip_salts.py; run the self-test

**Checkpoint**: US1 complete in code; its GUI round trip is owed (quickstart).

## Phase 4: User Story 2 — ZIP 2.0 encrypted archives no longer carry a predictable header (P2)

**Goal**: the random header bytes (10-11 of 12) come from the same generator.
**Independent test**: quickstart.md steps 3–6 for `z1.zip`, `z2.zip`.

- [X] T007 [US2] Confirm `CryptHeader` draws its random bytes only through `FillBufferWithRandomData` (no other `rand()` left in src/plugins/zip/) and record it in specs/086-zip-aes-salt/fix-log.md

## Phase 5: One generator for the product (FR-004)

- [X] T008 Make the core's `FillBufferWithRandomData` call `SalGenRandom` instead of its own `BCryptGenRandom` call (fallback unchanged) in src/pwdmngr.cpp

## Phase 6: Polish & cross-cutting

- [X] T009 Build Debug and `build.cmd full release`; saltests; `python tools/check_encoding.py`; `bcrypt.dll` in the imports of zip.spl and tandemcommander.exe; `git diff --stat src/plugins/shared/` empty
- [X] T010 Independent review of the diff (an agent that did not write it); fix and re-review until ACCEPT
- [X] T011 [P] CHANGELOG.md *Unreleased* → Fixed: the user-facing description incl. "archives made before keep their salts; re-create sensitive ones" and "ZIP 2.0 stays weak by design"
- [X] T012 [P] specs/NEXT-WORK.md item 7 (ZIP salt done) and a CLAUDE.md *Recent Changes* entry
- [X] T013 Complete specs/086-zip-aes-salt/fix-log.md (evidence, review, owed steps) and commit on branch 086-zip-aes-salt

## Dependencies

- T002 → T003 → T004 → (T005, T008); T006 independent of code.
- US2 (T007) needs T005 (same function).
- T009 needs T005, T008; T010 needs T009; T011–T013 after T010.

## Parallel opportunities

- T006 (probe, Python) alongside T005/T008 (C++).
- T011 and T012 (different record files).

## Implementation strategy

MVP = Phase 2 + US1: the AES salt fix alone delivers the security value. US2
comes for free with the same function; Phase 5 removes the duplicate
definition. Everything ships as one small commit series on one branch.
