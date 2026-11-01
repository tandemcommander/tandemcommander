# Specification Analysis Report - 371 (2026-11-01)

Cross-artifact check of `spec.md`, `plan.md`, `tasks.md` (with `research.md`, `data-model.md`,
`contracts/`) against `.specify/memory/constitution.md` v4.1.0.

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| I1 | Inconsistency | HIGH | spec.md FR-002, US1; research.md R2; data-model.md row 7 | The spec promised every change lands on the main line while a run holds the lock; the design (R2) keeps the backlog read-only while the run itself is on the main line (its start until it has a branch, its return). | Amend FR-002 and add the window to US1's scenarios and the edge cases (applied, see below). |
| U1 | Underspecification | LOW | spec.md edge cases; data-model.md row 11 | A run interrupted without a lock (waiting to be continued) freezes its item in the design; the spec did not name the case. | One sentence in the edge cases (applied). |
| C1 | Coverage | LOW | spec.md SC-005; tasks.md T044 | "essentials without scrolling at 1920 x 1080" has no explicit assertion. | T044 sets the viewport and asserts the header fits (applied to tasks.md). |
| T1 | Terminology | LOW | spec.md "conversation" vs. routes/files "chat" | Two names for one thing. | Kept: "conversation" in prose, `chat` as the technical name (route, folder, file); the UI label is "Chat about this item" in both. |
| A1 | Ambiguity | LOW | spec.md FR-004 "neither waits longer than the other's step takes" | Not a number. | The contracts bound it (the app waits at most 30 s for a loop-held lock, the `returning` command at most 300 s for the app); no spec change. |

**Coverage Summary Table:**

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|
| FR-001 | yes | T015, T018, T019, T025 | every operation through the queue's channels |
| FR-002 | yes | T012, T015, T019, T025 | amended for the run-on-main window |
| FR-003 | yes | T015, T018, T019, T022 | own and indirect changes |
| FR-004 | yes | T005, T006, T007, T015, T020, T026 | loop holds; `returning`; soak |
| FR-005 | yes | T015, T016, T019, T023 | commit at once; tray shows it |
| FR-006 | yes | T010, T011, T021 | reasons per state |
| FR-007 | yes | T015, T019 | changed-underneath, also after a CAS failure |
| FR-008 | yes | T027, T028, T029, T030, T031 | overlay |
| FR-009 | yes | T002, T014, T027, T028 | `next --except` |
| FR-010 | yes | T027, T028, T031 | overlay off without a lock |
| FR-011 | yes | T032, T033, T034 | |
| FR-012 | yes | T032, T035 | |
| FR-013 | yes | T032, T034 | |
| FR-014 | yes | T042, T044 | |
| FR-015 | yes | T038, T041, T044 | |
| FR-016 | yes | T037, T038, T040, T048 | allow-list reviewed |
| FR-017 | yes | T037, T041, T040 | |
| FR-018 | yes | T037, T040, T044 | |
| FR-019 | yes | T037, T040 | |
| FR-020 | yes | T037, T039, T041, T043 | |
| FR-021 | yes | T001, T047 | |
| FR-022 | yes | T039, T046, T048 | gate test lists the routes |
| FR-023 | yes | T012, T046, T048 | the worktree's git write calls are the only ones added |
| SC-001 | yes | T025 | |
| SC-002 | yes | T026 | |
| SC-003 | yes | T028, T031 | |
| SC-004 | yes | T035 | |
| SC-005 | yes | T044 | viewport assertion added |
| SC-006 | yes | T001, T047 | |
| SC-007 | yes | T026 | |

**Constitution Alignment Issues:** none (the product is not touched; the tools' additions are
backward compatible; dependencies stay pinned; nothing is published).

**Unmapped Tasks:** none (T008 serves FR-004 through the wrapper; T045/T046 serve US5; T048/T049
are the project's closing rules).

**Metrics:**

- Total Requirements: 23 FR + 7 SC
- Total Tasks: 49
- Coverage: 100 % (every FR and SC has at least one task)
- Ambiguity Count: 1 (bounded in the contracts)
- Duplication Count: 0
- Critical Issues Count: 0

## Next Actions

- I1 was a HIGH inconsistency between the spec and the design; the spec is amended in the same
  change (the maintainer is away; the amendment records the design's limitation rather than
  changing the design). No CRITICAL issue: proceed with `/speckit-implement`.
