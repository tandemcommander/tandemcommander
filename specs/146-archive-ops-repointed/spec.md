# Feature Specification: no archive operation through a name that leads elsewhere than when it was listed

**Feature Branch**: `146-archive-ops-repointed`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (two cases 2 / 0 with controls; 109 25 / 0, 108, 112 unchanged)
**Input**: `specs/NEXT-WORK.md` 2b - found by the review of feature 145: "F8 / F5 / F6 on a panel
showing `T:\arc.zip` after the letter was re-pointed (no refresh since) run
`DeleteFromZIPArchive` / `UnpackZIPArchive` against the archive the name names NOW with the OLD
listing's member names."

## Clarifications

### Session 2026-10-14

Decisions by the author (the maintainer asked for the backlog in order without questions).

- Q: What is refused? -> A: Deleting from, unpacking from (copy / move out) and packing into an
  archive a panel shows, while its name leads elsewhere than when the panel listed it (145's
  `ArchiveNameLeadsElsewhere`: another final path or another volume).
- Q: What does the person see? -> A: The existing note "Archive file "%s" has changed. Archive
  will be reopened in panel." and the panel is refreshed - it then shows what the name holds now,
  and the operation can be repeated on that listing. No new string.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - F8 never deletes another archive's member (Priority: P1)

**Independent Test**: 109 probe case `resubst-delete`.

**Acceptance Scenarios**:

1. **Given** a panel on `T:\arc.zip` (folder A) and `T:` re-pointed to folder B (an archive of the
   same size and time), **When** F8 on x.txt, **Then** the note appears, nothing is deleted from
   either archive, and the panel shows B's archive.

### User Story 2 - Copy, move, pack and paste the same way (Priority: P2)

F5 out of such a panel, F3 / F4 / Enter on a member (review), F5 / F6 / paste / drop into it, and
the paste of items copied from it are refused the same way (the probe drives F8 and F4).

### Edge Cases

- The name leads to the same place (also an archive replaced there by an archiver): no change.
- Either final path unknown: no decision (as before).
- Another spelling of the archive (8.3, SUBST twin): no panel matches the name - no guard (as before).

## Requirements *(mandatory)*

- **FR-001**: Delete from, unpack from and pack into an archive MUST be refused while a panel shows
  that archive and its name leads elsewhere than when the panel listed it.
- **FR-002**: The refusal MUST show the existing "has changed, will be reopened" note and refresh
  that panel; nothing in either archive is changed.
- **FR-003**: No new string, interface or registry value.

## Success Criteria *(mandatory)*

- **SC-001**: `resubst-delete` FAIL before (measured: B's x.txt deleted), PASS after.
- **SC-002**: the whole 109 probe, 108, 112 unchanged.
