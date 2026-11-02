# Tasks: Viewer Find pre-fills the selection as the text the viewer shows

**Input**: `specs/398-viewer-find-seed/` (plan.md, spec.md, research.md, data-model.md, contracts/find-seed.md, quickstart.md)
**Tests**: requested by the spec (FR-007, SC-001..003): saltests checks and the hidden-desktop probe.

## Phase 1: Setup

- [X] T001 Start `specs/398-viewer-find-seed/fix-log.md` with the measurement of step 3 (probe `result_before.txt`: PASS 8 / FAIL 4)

## Phase 2: Foundational (the pure rule)

- [X] T002 Write `src/common/salfindseed.h` with `SalFindSeedDecodeW` per `contracts/find-seed.md` (UTF-8, UTF-16 LE/BE, code page; whole characters; limits in units and UTF-8 bytes; NUL ends)
- [X] T003 Add `TestFindSeed398` to `src/saltests/saltests.cpp` (include, call in `main`): `café`, 199 `a` + `é…` -> 199 `a`, 70 CJK -> 66, 198 `a` + U+1F600 -> 198 `a`, 199 `a` + U+1F600 -> 199 `a` (pair not split by units), incomplete UTF-8 tail dropped, invalid byte -> U+FFFD, NUL ends, UTF-16 LE/BE + odd byte + lone/trailing surrogate, code page 1250 `E9` -> U+00E9, code page 932 trailing lead byte dropped, outCap limit, NULL / zero arguments, a tab and CR LF passed on (FR-008); plus a round-trip loop: for UTF-8 input the result's UTF-8 equals a prefix of the input bytes

## Phase 3: User Story 1 + 2 - the seed decoded and shortened (P1)

**Goal**: the field shows the selection as the viewer shows it, shortened to fit; OK finds it.
**Independent test**: probe rows u8-word, u8-long, u8-cjk, u8-astral.

- [X] T004 [US1] `src/viewer.h` / `src/viewer2.cpp`: `GetFindText(char* buf, int bufSize, int& len)` reads at most `bufSize - 1` bytes (was `FIND_TEXT_LEN - 1`)
- [X] T005 [US1] `src/viewer.cpp` `CFindSetDialog::Transfer`: read `2 * (FIND_TEXT_LEN - 1) + 2` bytes; hex mode as before from those bytes; otherwise `SalFindSeedDecodeW(bytes, len, view->GetContentEncoding(), CP_ACP, out, FIND_TEXT_LEN, FIND_TEXT_LEN - 1, FIND_TEXT_LEN - 1)` (code-page content as the viewer draws it, the code page passed explicitly) and `SetWindowTextW` on the combo box; no selection or a read error (GetFindText FALSE) leaves the field as it is (FR-006)
- [X] T006 [US1] `src/viewer.h`: a public accessor for the content encoding (`GetContentEncoding()`)

## Phase 4: User Story 3 - code page and hex unchanged (P2)

- [X] T007 [US3] Probe rows `legacy` and `hex` in `specs/398-viewer-find-seed/probe/seed398_probe.ps1` still PASS

## Phase 5: Polish

- [X] T008 `.\build.cmd` -> BUILD SUCCEEDED; saltests 0 failed; `python tools/check_encoding.py --strict` TOTAL 0
- [X] T009 Probe after (`probe/result_after.txt`) all PASS; negative control: saltests against the old rule (byte-wise ANSI) fails the checks - recorded in fix-log
- [X] T010 Inbox item (leftover:398): the viewer's Find does not find non-ASCII text in code-page content (search compares UTF-8 bytes with code-page bytes)
- [X] T011 fix-log, FEATURE-HISTORY, CHANGELOG, closing report

## Dependencies

T001 -> T002 -> T003; T002 -> T004..T006 -> T007 -> T008 -> T009 -> T010 -> T011. T004 and T006 touch the same header and are done together.

## Implementation strategy

MVP = Phase 2 + Phase 3 (the defect). No UI strings: no translation refresh.
