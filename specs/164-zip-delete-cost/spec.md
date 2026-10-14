# Feature Specification: deleting many members from a large ZIP archive is fast

**Feature Branch**: `164-zip-delete-cost`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 15 (113, queue 108 entry 2): "ZIP: the bound and
`UpdateCentrDir` walk the central directory once per deleted member (n x d); one sorted offset
array would serve both." Measure first whether it is slow enough to matter.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user deletes half of the files of a ZIP archive with tens of thousands of members (a source
tree, a backup). Before: 30,000 members, 15,000 deleted took 22 s (Debug), growing with the
square of the size (100,000 members: minutes). Now the time grows with the size, and the
archive is the same, byte for byte, as the per-member algorithm leaves it.

**Independent Test**: `probe/zip_delete_cost_probe.ps1` (the time from the question's Yes to the
end; the archive checked by Python's zipfile: exactly the kept members with their content, a clean
test) and saltests `TestZipDelete164` (the new algorithm against the old one on random
directories, part-way breaks included).

## Requirements *(mandatory)*

- **FR-001**: The result (archive, central directory, entry counts, the feature 113 bound and its
  refusal) is identical to the per-member algorithm; the fast path runs only when that is proven
  (the directory reads whole, the members ascend strictly, memory suffices) - else the old code.
- **FR-002**: No string, interface, registry or format change.

## Success Criteria

- **SC-001**: 30,000 members / 15,000 deleted in under 2 s (Debug); 100,000 / 50,000 in a few
  seconds.
