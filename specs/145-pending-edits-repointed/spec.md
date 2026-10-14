# Feature Specification: a pending edit is never packed into the archive a re-pointed name leads to now

**Feature Branch**: `145-pending-edits-repointed`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (four cases 4 / 0, control 1 / 3; 109 23 / 0, 108, 112 unchanged)
**Input**: `specs/NEXT-WORK.md`, *Open items at a glance*, A.2a - found by the review of feature
144: "a panel with an F4 edit of a member pending packs it, on leaving the archive, into the file
the archive's name names now; after a SUBST / network letter re-point to a twin nothing notices."

## Clarifications

### Session 2026-10-14

Decisions by the author (the maintainer asked for the backlog in order without questions).

- Q: What tells "another archive" from "this archive, updated"? -> A: **Where the name leads**, not
  the file id. An archiver (7-Zip, WinRAR, the ZIP plug-in) updates an archive by writing a new
  file and renaming it over the old one: a new file id at the same place, and the edit must still
  go in (measured as the control `replace-pending`). A re-pointed letter leads the same name to
  another folder: the final path (SUBST and network letters resolved) differs.
- Q: What happens to the edit then? -> A: The pack is refused as a failed pack with the existing
  question ("Packing of updated file(s) into archive has failed. Do you want to try it again? If
  you choose NO, you'll get back to the Archive Update dialog, so you'll be able to copy updated
  file(s) to chosen disk folder"): Yes retries (after the person points the letter back it works),
  No leads to *Copy Selected To...*. No new string - the message does not say why.
- Q: The listing? -> A: The refresh's "archive changed?" test also asks where the name leads; a
  re-pointed name reopens the archive (the listing shows what the name holds now).
- Q: Either final path unknown? -> A: No decision - the behaviour before (pack).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An edit is not packed into another archive (Priority: P1)

A panel shows `T:\arc.zip` (folder A); the user edits a member with F4; meanwhile `T:` is
re-pointed to folder B (an archive of the same size and time). When the panel leaves the archive
and the update is offered, the edit is not packed into B; the person is told the packing failed
and can retry (after pointing the letter back) or copy the edited file to a folder.

**Independent Test**: 109 probe case `resubst-pending`.

**Acceptance Scenarios**:

1. **Given** the state above, **When** the person chooses *Update All*, **Then** B's archive is
   unchanged and the failure question appears; **When** No, **Then** the Archive Update dialog
   offers *Copy Selected To...* with the edited file.

### User Story 2 - An archive updated in place still takes the edit (Priority: P1)

**Independent Test**: 109 probe case `replace-pending` (the archive replaced by a renamed new file
while an edit is pending): the edit is packed into it, as before.

### Edge Cases

- The final path cannot be read at the open or now (a redirector without it): as before.
- The letter is pointed back before *Try again*: the pack goes through.
- The other panel's update offered by `OfferArchiveUpdateIfNeeded`: guarded by its own stored path.

## Requirements *(mandatory)*

- **FR-001**: A panel MUST record where its archive's name led (final path) at the open, from the
  open that gives the archive's date and size.
- **FR-002**: Packing pending edits MUST be refused, as a failed pack, when the name leads to
  another final path than at the open; it MUST NOT be refused when the final path is the same or
  unknown.
- **FR-003**: The refresh's change test MUST treat a name that leads elsewhere as a changed archive.
- **FR-004**: No new string, interface or registry value.

## Success Criteria *(mandatory)*

- **SC-001**: `resubst-pending` FAIL on the build before (measured), PASS on this build;
  `replace-pending` PASS on both.
- **SC-002**: The whole 109 probe, 108 (`namecoll`, `-CacheKeyRows`) and 112 unchanged.
- **SC-003**: `saltests`, `check_encoding.py` unchanged.
