# Feature Specification: Undelete numbers equal names without taking a name the list already has

**Feature Branch**: `148-undelete-numbering`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (114 probe row `num`; 114 33 / 0 / 4, 115 23 / 0 / 2)
**Input**: `specs/NEXT-WORK.md`, *Open items at a glance*, A.4 (queue 104 entry 2, found by 115):
"Undelete numbering can produce a name another listed item already has (`a.txt` twice and
`a (1).txt` -> an overwrite prompt; every release)."

## Clarifications

### Session 2026-10-14

- Q: Which numbers? -> A: As before - " (n)" before a three-character extension, counted from 1 per
  name, every item of a group (the restore list) or every DELETED item of a group (the FAT listing) -
  but a number whose result is a name the list holds (a kept item's or one chosen before) is skipped.
- Q: Names in the target folder? -> A: Out of scope (as before: the restore asks).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restoring equal names never overwrites another restored file (Priority: P1)

**Independent Test**: 114 probe row `num` (exFAT image: deleted `a.txt` twice and a deleted `a (1).txt`,
restored together): three files, three contents, `a (1).txt` keeps its own content, no question.

### Edge Cases

- Equal by the file system's rule (case, non-ASCII case): one group, taken names too.
- A group whose own name is renumbered away (two `a (1).txt`) frees that name for another group.
- Large lists ({All Deleted Files} with thousands of `Thumbs.db`): no quadratic cost.

## Requirements *(mandatory)*

- **FR-001**: A numbered name MUST differ from every name the list will hold.
- **FR-002**: Without a collision the names MUST be the same as before.
- **FR-003**: No new string, interface or registry value.

## Success Criteria *(mandatory)*

- **SC-001**: row `num` FAIL before (measured: the overwrite question), PASS after.
- **SC-002**: 114 and 115 probes unchanged otherwise; `saltests` +13.
