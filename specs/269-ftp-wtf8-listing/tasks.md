# Tasks: An FTP file name with an unpaired surrogate keeps its name on a UTF-8 server

**Input**: Design documents from `specs/269-ftp-wtf8-listing/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/listing-field-rule.md, quickstart.md

**Tests**: requested by the spec (FR-003 unit checks; SC-001..SC-003 probe rows).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Start `specs/269-ftp-wtf8-listing/fix-log.md` with the before measurement (probe `probe/result_before.txt`: DL FAIL, UP-ASK FAIL, controls PASS; checker finding `ftputils.cpp:3627`)
- [X] T002 [P] Add the additive ENC `wtf-8` mode (UTF-8 with `surrogatepass`, FEAT announces UTF8) to `specs/215-ftp-long-name-command/probe/ftpmini.py`; the other modes unchanged

## Phase 2: Foundational (the rule)

- [X] T003 Create the header-only pure rule `SalFtpListingFieldIsU8(const char* s, int len)` in `src/common/salftplisting.h` per `contracts/listing-field-rule.md` (UTF-8 BOM, SPDX header, English comments)
- [X] T004 Add `TestFtpListingField269` to `src/saltests/saltests.cpp`: named cases (empty, ASCII, NUL inside, café UTF-8, CJK, 4-byte emoji, lone high and low surrogate `ED A0 80` / `ED BF BF`, CESU pair, overlong `C0 AF` / `E0 80 AF` / `F0 80 80 80`, `F4 90 80 80`, truncated sequences, stray continuation, cp1250 bytes `E9`) and an exhaustive comparison with `SplUnicodeDetail::Wtf8ToW` for every byte string of length 1..4 over an alphabet covering every byte class; register it in the test list

## Phase 3: User Story 1 - the server's file keeps its name (P1)

**Goal**: listing and PWD names in WTF-8 are kept byte for byte, not read in the code page.
**Independent Test**: probe row DL (+ controls DL-ACC, LEG-DL).

- [X] T005 [US1] In `src/plugins/ftp/ftputils.cpp` `FTPListingFieldToU8`, replace the ASCII loop + strict `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)` keep-test by `SalFtpListingFieldIsU8(beg, len)`; include `../../common/salftplisting.h`; the code-page branch, `FTPAddCodePageName` and the raw fallback unchanged

## Phase 4: User Story 2 - uploading over the same name asks first (P1)

**Goal**: the upload's existence check finds the server's file (it uses the same decode - no own change).
**Independent Test**: probe rows UP-ASK and UP-NEW.

- [X] T006 [US2] Confirm by the probe that `CUploadPathListing` (`src/plugins/ftp/operats9.cpp`) gets the name through `FTPListingFieldToU8` (row UP-ASK asks and keeps the server's file); no code change expected - record in `fix-log.md`

## Phase 5: Polish & verification

- [X] T007 Build `.\build.cmd` -> `BUILD SUCCEEDED`; run `saltests` -> 0 failed; record numbers in `fix-log.md`
- [X] T008 [P] `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `python tools/check_encoding.py --plugins` -> no `ftputils.cpp` line; record
- [X] T009 Run the probe `specs/269-ftp-wtf8-listing/probe/ftp269_probe.ps1` on the hidden desktop -> `probe/result_after.txt`, 5 rows PASS, registry identical
- [X] T010 Run feature 224's probe as the regression -> `probe/regress_224.txt`, 16 / 0
- [X] T011 Negative control: the saltests rule with the old strict behaviour would fail the surrogate cases (record that `MultiByteToWideChar` strict refuses `61 ED A0 80` - a saltests check of the strict call); record in `fix-log.md`

## Dependencies

- T003 -> T004, T005; T002 -> T009, T010; T005 -> T007 -> T009, T010; T006 follows T009.
- US2 has no code of its own; it depends on US1.

## Parallel examples

- T002 with T003; T008 with T009.

## Implementation strategy

MVP = US1 (T003-T005); US2 is proven by the same change through the probe.
