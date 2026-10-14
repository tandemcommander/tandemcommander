# Feature Specification: a panel opening an archive never takes the other panel's copies of another file, also across a re-pointed drive letter

**Feature Branch**: `144-archive-key-repointed-drive`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (109 probe 19 / 0 incl. `resubst-both`; 108, 112 unchanged); the pack-back side is feature 145 (see Scope)
**Input**: `specs/NEXT-WORK.md`, *Open items at a glance*, A.2 (queue 108, entry 3 - the two
items of 109's re-review): "two panels whose archives have the same spelling, size and 100-ns time
under a re-pointed SUBST or network letter still share copies; the out-of-memory fallback of the
cache key can re-create sharing without a check."

## Clarifications

### Session 2026-10-14

Decisions by the author (the maintainer asked for the backlog in order without questions).

- Q: How bad is it? -> A: Measured on 0.1.10 (`research.md` R1): with both panels on `T:\arc.zip`
  and `T:` re-pointed from folder A to folder B between the two opens (the archives of equal size
  and time), F3 in the second panel showed A's member and F4 packed the edited copy of A's member
  into B's archive - B's own member was replaced silently. Data loss, narrow conditions.
- Q: What decides "the same file" for the second panel? -> A: The identity of the first panel's
  archive **as read when that panel opened it**, not read again through its name (the name may
  name another file now). Each panel stores its archive's identity at the open.
- Q: The out-of-memory fallback? -> A: When the key cannot be built (memory), the panel builds no
  key from the name later either: F3 / F4 / the flush of that archive's copies are refused (as
  every other low-memory failure of the key) until the archive is opened again.
- Q: New strings, interface, registry? -> A: None.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The second panel gets its own archive's members (Priority: P1)

A user opens an archive through a SUBST (or network) drive letter in one panel, re-points the
letter, and opens the archive of the same name through the letter in the other panel. Viewing or
editing a member in the second panel works on the second archive's member; the first archive is
not touched.

**Why this priority**: today the edit of the second panel lands in the second archive with the
first archive's content - silently.

**Independent Test**: 109 probe case `resubst-both` (new).

**Acceptance Scenarios**:

1. **Given** panel R on `T:\arc.zip` (folder A) with x.txt viewed, `T:` re-pointed to folder B
   whose `arc.zip` has the same size and time, **When** panel L opens `T:\arc.zip` and views
   x.txt, **Then** L shows B's x.txt.
2. **Given** the same, **When** L edits x.txt and leaves the archive, **Then** B's archive holds
   the edit of B's x.txt and A's archive is unchanged.

### User Story 2 - One file under two spellings still shares (Priority: P1)

The behaviour 109 established stays: one archive opened through `A\arc.zip` and `T:\arc.zip`
(the same file) shares the copies; two different archives never do.

**Independent Test**: the 109 probe's other cases (`resubst`, `alias-*`, `stale-*`, `reuse`, ...).

### Edge Cases

- The first panel's identity could not be read at its open (a file system without ids, e.g.
  WebDAV): the rule of 109 for an unknown identity stays (the same name with nothing saying
  "another file" shares).
- The archive is reopened by a refresh: its identity is read again.
- Low memory while building the key: nothing is shared and nothing is built from the name later.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A panel MUST record the identity of its archive's file when it opens the archive
  (and forget it when it leaves the archive or opens another).
- **FR-002**: The key choice of a panel opening an archive MUST compare its own freshly read
  identity with the identity the other panel recorded at its open; it MUST NOT read the other
  panel's archive by name.
- **FR-003**: When the key cannot be built for lack of memory, the panel MUST NOT build a key
  from the archive's name later; uses of the key fail (refused) until the archive is opened again.
- **FR-004**: No new string, interface or registry value; the plug-in cache services unchanged.

## Success Criteria *(mandatory)*

- **SC-001**: 109 probe `resubst-both`: FAIL on the build before (measured), PASS on this build.
- **SC-002**: The whole 109 probe and its regressions (108 `namecoll`, 112 `diskcache_edit`)
  unchanged on this build.
- **SC-003**: `saltests` and `check_encoding.py` unchanged.

## Scope

The key choice at the open. NOT covered (review of 144, its own feature 145): a panel that
has F4 edits pending when its letter is re-pointed packs them, on leaving, into the file the
name names now (`CFileTimeStamps` keeps the name); a refresh does not notice a twin.

## Assumptions

- The identity read at the open is that of the file the panel lists (the archive was just read
  through the same name).
- Network-drive re-mapping (`renet`) is not driven on the hidden desktop (109 recorded the same).
