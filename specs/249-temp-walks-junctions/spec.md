# Feature Specification: the external unpacker's walk and the temporary-folder cleanups never go through a link

**Feature Branch**: `249-temp-walks-junctions`
**Created**: 2026-10-19
**Status**: Draft
**Input**: Backlog item `temp-dir-walks-follow-junctions` (SFX temp cleanup and the external unpacker's walk follow junctions). From backlog item temp-dir-walks-follow-junctions.

## Measured before the work (at 1c8140a0)

- **External unpacker, subfolder of an archive** (`PackUniversalUncompress`, `src/pack1.cpp`): to
  find the extracted subfolder in its temporary folder, the unpack takes the first directory it
  finds at every level - also a junction - and then moves the **content** of that folder into the
  target. Probe row UNPACK (hidden desktop; a fake `7z.exe` set as the 7-Zip executable, `l` runs
  the real 7-Zip, `x` restores a junction `top` -> a fixture folder; F5 out of `t.arj\top`): the
  fixture folder's `keep.txt` was moved into the panel's target, with no question. FAIL. The control
  PLAIN (a real folder `top\a.txt`) unpacks as before.
- **Reachability**: 7-Zip 22.01's own `x` (the default command) refuses "dangerous" links and
  re-targets a WIM junction inside its output folder; a junction pointing outside appears only with
  an unpacker that restores it (another or older 7-Zip-compatible executable configured as the
  7-Zip executable). Narrow, but a silent move of files from outside the selection.
- **Start-up sweep of `SAL*.tmp` folders** (feature 212, by reading until now): driven with TMP set
  to a fixture holding `SAL249A.tmp\{plain.txt, lnk -> victim}` - the folder removed, the junction's
  target kept. PASS (212 holds).
- **ZIP self-extractor** (`src/plugins/zip/selfextr/selfextr.cpp`, `_RemoveTemporaryDir`): walks into
  every subdirectory, also a junction (ANSI calls) - but no project of the solution compiles it and
  no SFX package is shipped: unreachable in the product.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpacking from inside an archive never moves files from behind a link (Priority: P1)

A user browses an archive through an external unpacker (Archive associations -> 7-Zip archiver)
and copies files out of a folder inside the archive (F5). If the unpacker restored a junction or a
directory symbolic link where that folder should be, the user's files behind the link must stay
where they are.

**Why this priority**: it is the only reachable defect of the item - a silent relocation of files
outside the selection (rule 099's class of loss).

**Independent Test**: probe row UNPACK: the fake unpacker restores `top` as a junction to a
fixture folder; after F5 the fixture folder still holds `keep.txt`, the target does not, no
temporary `PACK*.tmp` folder is left, and the user is told the unpack could not be completed.

**Acceptance Scenarios**:

1. **Given** an archive browsed through the external 7-Zip archiver and an unpacker that restores
   the requested folder as a junction to another folder, **When** the user copies files out of that
   folder, **Then** nothing is moved from the junction's target, the operation ends with an error
   message, and the temporary folder is removed (the junction as a link only).
2. **Given** the same archive unpacked by an unpacker that extracts a real folder, **When** the user
   copies files out of it, **Then** the files arrive in the target exactly as before (control PLAIN).

---

### User Story 2 - The start-up cleanup of temporary folders is proven on the build (Priority: P2)

When the program offers at start to delete temporary folders left by earlier instances and the user
answers Yes, a junction inside such a folder is removed as a link; its target keeps its files.

**Why this priority**: feature 212 fixed it by reading only; the item owes driving it.

**Independent Test**: probe row SWEEP (TMP of the started program = a fixture holding
`SAL249A.tmp` with a plain file and a junction): after Yes the folder is gone (the sweep ran) and
the junction's target keeps `keep.txt`.

**Acceptance Scenarios**:

1. **Given** a `SAL*.tmp` folder holding a junction to a folder with files, **When** the user
   answers Yes to the start-up question, **Then** the `SAL*.tmp` folder is removed and the target's
   files are untouched.

---

### User Story 3 - The self-extractor's cleanup source does not walk a link (Priority: P3)

The ZIP self-extractor's own temporary cleanup (source only - not built, not shipped) removes a
directory link as a link instead of walking it, so the defect does not come back if the
self-extractor is built again.

**Why this priority**: unreachable in the product today; a cheap, contained source change.

**Independent Test**: by reading and a compile-only syntax check of the file; it cannot be driven.

**Acceptance Scenarios**:

1. **Given** the self-extractor's cleanup meets a directory carrying a reparse point, **When** it
   empties its temporary folder, **Then** it removes that directory entry as a link and never lists
   its content.

### Edge Cases

- A junction at a deeper level of the archive path (`a\b\` with `b` a link): refused the same way at
  every level.
- A reparse directory that is not a link (a cloud placeholder of a synced folder used as the
  target): still entered, as before (feature 197's decision: only name surrogates and unreadable
  tags count as links).
- A reparse point whose tag cannot be read: counts as a link (fail closed) - refused.
- The extracted entry is a file instead of a folder: unchanged (the existing "unexpected" error).
- Links inside the extracted subfolder (not on the archive path): unchanged - the ordinary move
  moves a link as a link on the same volume, and asks before copying a link's content otherwise.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The external unpacker's walk to the extracted subfolder MUST NOT enter a directory
  link (junction, directory symbolic link, volume mount point, any name surrogate, or a reparse
  point whose tag cannot be read); it MUST refuse the operation instead, before anything is moved.
- **FR-002**: On that refusal the user MUST see an error message naming the folder and the reason
  (an existing message text - no new UI strings), and the temporary folder MUST be removed with the
  link removed as a link only (feature 212's cleanup).
- **FR-003**: Unpacking where every folder on the archive path is a real folder (or a cloud
  placeholder) MUST behave exactly as before.
- **FR-004**: The start-up sweep of `SAL*.tmp` folders MUST be shown by a probe on the build to
  remove a junction as a link and keep its target's files.
- **FR-005**: The ZIP self-extractor's `_RemoveTemporaryDir` source MUST remove a directory carrying
  a reparse point as a directory entry (never list its content); the change MUST compile as C/C++
  (syntax check) even though no project builds it.
- **FR-006**: No data loss: no path where a file behind a link is moved, deleted or overwritten by
  these routes.

### Key Entities

- **Temporary unpack folder**: `PACK*.tmp`, created in the target folder for one external unpack;
  everything in it was written by the unpacker.
- **Directory link**: a directory entry carrying a reparse point that the file system resolves
  elsewhere; its target is not part of the temporary folder.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe row UNPACK: FAIL before (target's file moved) -> PASS after (target's file kept,
  nothing moved, no `PACK*.tmp` left, an error shown).
- **SC-002**: Probe rows PLAIN and SWEEP PASS before and after.
- **SC-003**: Encoding guard `TOTAL: 0`, `BUILD SUCCEEDED`, `saltests` 0 failed.

## Assumptions

- Assumption (autonomous run): the refusal uses the existing message `IDS_PACKERR_GENERAL`
  ("System error: %1") with the folder's path and the system text of
  `ERROR_REPARSE_POINT_ENCOUNTERED` - adding a string would need the `.slt` refresh a run cannot do
  (conservative).
- Assumption (autonomous run): refusing (rather than unpacking through the link or skipping it) is
  the answer of the standing rules - "refuse rather than guess" and rule 099 (a link is never a
  route for moving the user's files) (rule).
- Assumption (autonomous run): the link decision is feature 197's `DeleteAsDirLink` (fail closed,
  cloud placeholders are folders), the same as 212 and 213 use (rule).
- Assumption (autonomous run): `selfextr.cpp` is fixed in source because the item's *Expected*
  names it; it is recorded as neither built nor driven (item).
- Out of scope: the similar cleanup in `src/sfx7zip/install.c` (not named by the item) - checked
  for reachability and recorded in the Inbox if it is reachable; the general Move's handling of a
  link inside a moved folder (asks the user - existing behaviour).
