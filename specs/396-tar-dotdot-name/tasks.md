# Tasks: A tar member whose name contains `..` goes to the folder its name points to

**Input**: `specs/396-tar-dotdot-name/` - plan.md, spec.md, research.md, data-model.md, contracts/name-rule.md, quickstart.md
**Tests**: required by the spec (FR-005, SC-001..SC-003): saltests checks and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Confirm the measurement before the change is recorded (probe 7 / 5, saltests pin) in specs/396-tar-dotdot-name/fix-log.md

## Phase 2: Foundational (the shared rule - blocks every story)

- [ ] T002 Write the failing saltests first: change the pin `TarNorm309("sub/../a.txt")` to `"a.txt"` in `TestTarLink309` and add `TestTarDotDot396` (the contract table of contracts/name-rule.md; brute force over names of up to 6 characters from `a b . / \` - names without a `..` component equal to a copy of the legacy loop, every name equal to a reference component-stack resolver, output never longer than the input) registered in the test list, in src/saltests/saltests.cpp
- [ ] T003 Build and run saltests; record that the new checks fail on the legacy rule (negative control) in specs/396-tar-dotdot-name/fix-log.md
- [ ] T004 Replace the `..` branch of `SalTarNormalizeNameU8` (drop the trailing separator, walk back to just after the previous separator or to the start; nothing on an empty output) and update the comment of the function and the file header in src/common/saltarlink.h
- [ ] T005 Update the comment at the link-name normalization (309's rule kept, reason now: a link with `..` is never matched - conservative) in src/plugins/tar/untar.cpp
- [ ] T006 Build and run saltests: 0 failed

## Phase 3: User Story 1 - Unpack puts a `..` member where its name points (P1)

**Independent test**: probe rows UNP-ROOT-DEL, UNP-OVER-DEL, UNP-GNU-DEL, UNP-PAX-DEL.

- [ ] T007 [US1] Run specs/396-tar-dotdot-name/probe/dotdot_probe.ps1 on the hidden desktop (label `after`) and record the rows in specs/396-tar-dotdot-name/fix-log.md

## Phase 4: User Story 2 - The panel listing and Copy show the same names (P2)

- [ ] T008 [US2] Check the probe row COPY-ROOT of the `after` run (specs/396-tar-dotdot-name/probe/result_after.txt)

## Phase 5: User Story 3 - Hard links keep feature 309's protection (P3)

- [ ] T009 [US3] Check the probe row UNP-LINK-DEL of the `after` run and run specs/309-tar-link-members/probe/link309_probe.ps1 (16 / 0 expected), result into specs/396-tar-dotdot-name/probe/regress_309.txt

## Phase 6: Polish & cross-cutting

- [ ] T010 [P] Regression probes 306 (`pax306_probe.ps1`), 308 (`unp308_probe.ps1`), 395 (`cpiosolo_probe.ps1`) - results into specs/396-tar-dotdot-name/probe/regress_<NNN>.txt, compared with their recorded numbers
- [ ] T011 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- [ ] T012 Record before / after, commands and results in specs/396-tar-dotdot-name/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> (T008, T009) -> T010 -> T011 -> T012.
US2 and US3 read the same probe run as US1; T010 runs after the build of T006.

## Parallel opportunities

T010's three regression probes are independent of each other but share the product's registry key
and the hidden desktop - run them one after another.

## Implementation strategy

MVP = Phase 2 + US1 (the rule fixed, the unpack right). US2 and US3 are checks of the same build.
