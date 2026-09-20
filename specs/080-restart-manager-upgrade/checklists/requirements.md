# Specification Quality Checklist: Upgrading Over a Running Instance (Restart Manager)

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-20
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

Validation pass 1 (2026-09-20), all items pass. Remarks on the judgement calls:

- **Implementation details.** The *Input* line quotes the user's description
  verbatim, including Windows message names; that is the record of what was
  asked, not part of the specification. The body describes the mechanism in
  terms of a "close request" with a question stage and an instruction stage
  and names no API. Repository paths appear only where a requirement is
  *about* a file (the changelog section, the backlog records, the fix-log) —
  the convention of this project's earlier specifications (075, 077, 079).
- **No clarification markers.** The user is away for the whole flow, so the
  three decisions that would normally be asked were made and written into
  *Assumptions* with their reasoning, each reversible later:
  1. the restart has no switch in the program (the installer's switch is the
     control) — a documented exception to the opt-in principle;
  2. state survives through the stored configuration, not the command line;
  3. restart after reboot / sign-out is excluded.
- **Testability of FR-006.** The list of states is "at minimum" by design:
  the complete per-state decision table is a deliverable of the plan
  (research) because it has to be derived from the code paths of the existing
  exit sequence, and FR-006 requires that table to exist.
- **FR-009 contains an escape clause** ("if the evidence shows…"). It is kept
  deliberately: the existing sequence closes at the question stage, and
  whether that can be changed safely for the update case is exactly what the
  baseline has to show. The clause demands a recorded justification, so the
  requirement stays verifiable either way.
- **Owed human steps are in scope of the spec** (Assumptions, FR-019): the
  elevated machine-wide variant and a real `winget upgrade` cannot be run
  autonomously.

Revision after the baseline (2026-09-20, during `/speckit-plan`): the
reproduction showed that the failure described in the input was caused by the
removed helper process and no longer occurs in the idle case. The spec gained
a *What the baseline showed* subsection, acceptance scenario 1.5 (upgrade over
the published 0.1.7), **User Story 5** with **FR-021 / FR-022** (the stale
helper file left behind by upgrades, and why the obvious remedy is a trap),
**SC-009 / SC-010**, a rewritten FR-017 and SC-001, and the assumption that an
open plug-in window declines the request. All checklist items were
re-evaluated against the revised text and still pass; the new requirements are
testable (quickstart V12, V15, V16, V3, V4).
