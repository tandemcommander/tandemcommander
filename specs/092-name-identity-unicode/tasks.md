# Tasks: name identity (encoding cluster B-2)

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [contracts/name-identity.md](contracts/name-identity.md)

## Phase 1: Setup

- [ ] T001 Baseline: saltests count; strict and draft `tools/check_encoding.py` totals; timing of a 100,000-file folder refresh with the branch base (specs/092-name-identity-unicode/probe/timing_probe.ps1); record in fix-log.md

## Phase 2: Foundational — helpers (S1)

- [ ] T002 `SalNameCompareOrdinalCI`, `SalNameEqualOrdinalCI`, `SalPathEqualOrdinalCI`, `SalPathHasPrefixOrdinalCI` in src/common/salunicode.{h,cpp} per contracts/name-identity.md
- [ ] T003 `TestNameIdentity092` in src/saltests/saltests.cpp: ASCII parity, the motivating pairs, generated case pairs of four Unicode blocks, linguistically-equal-but-different pairs, WTF-8, legacy text, long names, path rules, prefixes, order properties, real NTFS agreement
- [ ] T004 Commit `[092] S1 …` (with the spec artefacts)

## Phase 3: Guard (S0)

- [ ] T005 tools/check_encoding.py: exclude drive-letter look-ups from `acp-byte-table-on-name`; annotate the intentional sites (masks.cpp ASCII path, pack3.cpp bucket); make the rule strict
- [ ] T006 tools/check_encoding.py: new strict rule `byte-fold-on-name` for converted files; prove it fires on a planted defect; record

## Phase 4: User Story 1 — finding an item by name (S2, P1)

- [ ] T007 [US1] Convert the panel look-ups listed in research.md §6 S2 (src/fileswn0.cpp, fileswn1.cpp, fileswn2.cpp, fileswnb.cpp, fileswn6.cpp, shellsup.cpp, mainwnd3.cpp, finddlg1.cpp) to `SalNameEqualOrdinalCI`; each site: read the function, confirm both operands are file names, keep the surrounding logic
- [ ] T008 [US1] GUI probe specs/092-name-identity-unicode/probe/focus_probe.ps1: a folder with `Č.txt`, and with `ĥ.txt` + `Ĺ.txt`; drive a focus-by-name path of the built program; the focused file is observed through the viewer title; before/after
- [ ] T009 [US1] Independent review; fixes; commit `[092] S2 …`

## Phase 5: User Story 2 — only a change of case (S3, P1)

- [ ] T010 [US2] Convert the sites of research.md §6 S3 (src/fileswn5.cpp, worker.cpp, fileswn6.cpp, safefile.cpp, pack2.cpp, cache.cpp); each gates an overwrite or rename decision — trace the consumers before changing
- [ ] T011 [US2] Evidence probe specs/092-name-identity-unicode/probe/ (the 075 pattern): verbatim pre-/post-fix predicate bodies over a table of name pairs
- [ ] T012 [US2] Independent review; fixes; commit `[092] S3 …`

## Phase 6: User Story 3 — path identity (S4, P2)

- [ ] T013 [US3] Core-internal `IsTheSamePath` callers → `SalPathEqualOrdinalCI`; `StrNICmp(path, prefix, len)` prefix tests → `SalPathHasPrefixOrdinalCI` with the returned byte count (research.md §6 S4, §5 T2); the exported `CSalamanderGeneral::IsTheSamePath` keeps the legacy function
- [ ] T014 [US3] Independent review; fixes; commit `[092] S4 …`

## Phase 7: User Story 4 — sorted pairs (S5, P3)

- [ ] T015 [US4] Verify research.md §5 T5 (are stored tab selections re-sorted on load?) before touching `CNames`
- [ ] T016 [US4] Pairs, one at a time, both sides together: `SortNames` + `FindNameInArray` (src/salamdr6.cpp), `CDirectorySizes::Sort` + `GetIndex`, `ContainsString` and its insert side (src/fileswn6.cpp), disk-cache key producers + comparators (src/fileswn2.cpp, fileswn5.cpp, fileswn6.cpp, fileswn9.cpp, src/cache.*)
- [ ] T017 [US4] Independent review; fixes; commit `[092] S5 …`

## Phase 8: Polish (S6)

- [ ] T018 Timing: 100,000-file refresh after (SC-005)
- [ ] T019 Gates: Debug + full Release builds, saltests, strict guard 0 + planted defect, probes of 087 (engine), 088 (viewers), 089 (associations)
- [ ] T020 Records: CHANGELOG, specs/NEXT-WORK.md item 5 (+ the new backlog items: sort intransitivity, `CSalamanderDirectory`, exported services), specs/069-…/REMAINING-WORK.md B-2, CLAUDE.md, fix-log.md, quickstart.md
- [ ] T021 Final independent review; commit

## Dependencies

S1 blocks everything. S2, S3, S4 touch overlapping files (fileswn*.cpp) —
sequential. A stage whose review finds a conversion unsafe is reduced to the
proven part; the rest is recorded as deferred.
