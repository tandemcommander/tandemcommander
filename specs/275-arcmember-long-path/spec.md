# Feature Specification: F3 / F4 take archive members whose path inside the archive has 520 bytes or more

**Feature Branch**: `275-arcmember-long-path`  
**Created**: 2026-10-21  
**Status**: Draft  
**Input**: User description: "Backlog item f3-f4-refuse-archive-members-whose-path-inside-the-archive - implement exactly what it describes: F3 / F4 of a member whose path inside the archive is longer than 519 bytes works whenever its temporary copy fits the cache's rule, with every enabled archiver plug-in; a plug-in that cannot take the name refuses it with a message, never cuts it; probe row ARCCAP turns into a PASS of the viewer / editor." From backlog item f3-f4-refuse-archive-members-whose-path-inside-the-archive.

## Measured before (66245537)

- Probe `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` on the hidden desktop on the
  Debug x64 build of HEAD: 16 PASS / 0 FAIL; row ARCCAP (a ZIP member of 200 CJK letters + ".txt",
  604 bytes / 204 UTF-16 units, its temporary path about 249 units - it fits the 259-unit rule):
  F3 shows "Unable to unpack file from archive to temporary directory because resulting filename
  is too long." - the defect (the row expected the refusal, as feature 260 kept the limit).
- By reading: the limit is feature 095's test of the path inside the archive (folders + name)
  against 520 bytes, in F3 (View) and in F4 / Enter (Edit, open by association) of an archive
  member - the only two routes that hand one member to an archiver for a temporary copy.
- The archive listing bounds what can reach the test: a folder part of at most 255 bytes and a
  name of at most 255 UTF-16 units (765 bytes) - a path inside the archive has at most about
  1,021 bytes.
- Every plug-in the program loads is built for plug-in interface 104 or later, whose promise is
  names of up to 3 x 255 bytes and long paths; F5 (extract) has handed such names to archivers
  since feature 222.
- Audit of the archivers (by reading): ZIP, 7-Zip, tar (with deb / rpm / cpio / single-file
  streams) and the ISO plug-in take any such path (heap buffers, refusing joins with a message).
  The CAB plug-in copies the path into a 769-byte buffer with a silent cut - unreachable (a CAB
  holds at most 255 code-page bytes = at most 765 UTF-8 bytes), but a cut. External archivers
  (a user-configured program): the command line has 1,040 bytes and a longer one is refused with
  a message - no cut. The disabled RAR and CHM plug-ins overflow at 260+ bytes already today
  (outside this feature).

## Clarifications

### Session 2026-10-21

- Q: Do F3 / F4 keep any length limit of their own on the path inside the archive once the 520-byte test is gone? → A: No - the listing already bounds it (a folder part of at most 255 bytes + a name of at most 255 UTF-16 units, about 1,021 bytes); the disk cache's rule for the temporary copy is the only length refusal before extraction (autonomous run: item - *Expected*)
- Q: Which message does the CAB plug-in show when the path inside the cabinet does not fit its buffer? → A: Its existing "too long name" message (the one it already shows for a too-long cabinet path); no new text (autonomous run: rule - no new UI string without the `.slt` refresh; conservative)
- Q: Does feature 260's probe row ARCCAP keep expecting the refusal? → A: No - it now expects the viewer (the item: "Probe row ARCCAP turns into a PASS of the viewer / editor"); the row is changed in that probe and repeated in this feature's probe (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View a member with a long path inside the archive (Priority: P1)

A user opens an archive whose member has a long valid name (e.g. 200 CJK letters) or sits in
folders with long names, so that its path inside the archive has 520 bytes or more, and presses
F3.

**Why this priority**: it is the measured refusal of valid work; F5 already extracts such
members.

**Independent Test**: probe rows VIEWCAP (the former ARCCAP), VIEWDEEP, 7Z, TAR.

**Acceptance Scenarios**:

1. **Given** a ZIP with a member of 200 CJK letters + ".txt" (604 bytes) at its top, **When**
   the user focuses it and presses F3, **Then** the viewer opens the temporary copy under the
   member's whole name.
2. **Given** a ZIP with a member of 100 CJK letters + ".txt" inside a folder of 84 CJK letters
   (a path of more than 520 bytes inside the archive), **When** the user enters the folder and
   presses F3 on the member, **Then** the viewer opens it.
3. **Given** a 7-Zip archive and a tar archive with the 604-byte member, **When** the user
   presses F3 on it, **Then** the viewer opens it.
4. **Given** a member whose temporary copy would not fit the Windows path limit (259 UTF-16
   units), **When** the user presses F3, **Then** the "resulting filename is too long" message
   is shown as before and nothing is extracted.

---

### User Story 2 - Edit such a member and pack the change back (Priority: P2)

**Why this priority**: F4 had the same limit; an edit must reach the archive under the member's
whole name.

**Independent Test**: probe row EDITCAP.

**Acceptance Scenarios**:

1. **Given** the ZIP with the 604-byte member, **When** the user presses F4, edits the temporary
   copy and leaves the archive confirming the update, **Then** the archive holds one member,
   under exactly the same name, with the new content.

---

### User Story 3 - An archiver that cannot take the path refuses it with a message (Priority: P3)

**Why this priority**: lifting the core limit must never let a plug-in cut the path.

**Independent Test**: by reading (the CAB plug-in's case cannot be produced with a real CAB).

**Acceptance Scenarios**:

1. **Given** the CAB plug-in is handed a path inside the archive longer than its buffer, **When**
   it unpacks the member, **Then** it refuses with a message and extracts nothing (instead of
   cutting the path and then reporting "not found").

### Edge Cases

- Short members (the control) keep working exactly as before.
- A member whose name is not a valid Windows name (F3's shortened view copy, feature 222) keeps
  its behaviour.
- External archivers: a command line that does not fit is refused with a message, as before.
- Archivers that are not shipped enabled (RAR, CHM) are not changed here; their overflows are
  recorded as backlog items (RAR already has one).
- Two members whose names differ only by case keep their separate disk-cache keys as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: F3 and F4 / Enter of an archive member MUST NOT refuse the member because its path
  inside the archive has 520 bytes or more; the only length refusal before extraction is the
  disk cache's rule for the temporary copy (feature 260), with its existing message.
- **FR-002**: The member is extracted and viewed / edited under its whole name; an edit is packed
  back under the whole name (no cut anywhere on the route).
- **FR-003**: The CAB plug-in MUST refuse a path inside the archive that does not fit its buffer
  with its existing "too long name" message, never cut it.
- **FR-004**: Every other case (short names, the cache's refusal, invalid names, case twins,
  external archivers, F5) MUST behave as before.
- **FR-005**: No new UI string; the plug-in interface and its version are unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The new probe's rows VIEWCAP, VIEWDEEP, 7Z, TAR and EDITCAP refuse on the build
  before (the 520-byte message) and pass on the build after; the controls (CTL, OVERLIMIT) pass
  on both.
- **SC-002**: Feature 260's probe (with ARCCAP changed to expect the viewer) and feature 222's
  probe pass on the build after; ARCCAP fails on the build before (negative control).

## Assumptions

- Assumption (autonomous run): the limit is lifted for every archiver plug-in, not only for the
  shipped ones - the plug-in interface 104 promise (long names and paths) already covers it and
  F5 hands such names to every archiver since feature 222 (rule: the item's *Notes*; constitution
  principle II - nothing in the interface changes).
- Assumption (autonomous run): the uniso listing's fixed path buffers, which would overflow only
  if the core's listing ever accepted folder parts over 255 bytes, are not touched (not reachable;
  recorded in the contract note).
