# Feature Specification: Archives - F3 / F4 of long member names, the gzip name read whole

**Feature Branch**: `260-archive-cache-long-names`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item archive-long-names-cache-folders-tar - implement exactly what it describes: F3 / F4 of a member with a long valid name works (or the refusal names the limit); a skipped folder is reported; a gzip member name that does not fit is refused, never extracted under a cut name." From backlog item archive-long-names-cache-folders-tar.

## Measured before (b8d1f7d0)

- **F3 / F4 of an archive member with a long valid name**: probe
  `specs/222-name-length-units/probe/editname222_probe.ps1` on the current Debug build, row LONG:
  a ZIP member of 90 CJK letters + ".txt" (274 bytes of UTF-8, 94 UTF-16 units - a name every
  Windows file system takes) - F4 shows "Unable to unpack file from archive to temporary directory
  because resulting filename is too long." The program's temporary copy of the member (its folder
  under %TEMP% + the name) is limited to 259 BYTES of UTF-8, although Windows takes the path (about
  144 UTF-16 units). F3 (view) of archive members goes through the same limit. The way an edited
  copy goes back into the archive (the change check, "copy the edited files elsewhere") also holds
  the copy's path in byte-limited buffers - one of them cuts the path silently.
- **Folders whose name is over 255 bytes inside an archive**: every archive route already reports a
  folder it cannot list - ZIP (the 222 probe's DIRLONG row at HEAD: "Cannot add 1 or more files to
  the list. The total path is too long. Some directories or files may be missing in the archive
  listing."; the rest of the archive is listed), 7-Zip, the ISO plug-in, tar, CAB, the external
  packers: each shows a message. Nothing is skipped silently - this part of the item is **not
  present** at HEAD and needs no change.
- **gzip name**: a `.gz` file stores the original file name in its header; the tar plug-in reads it
  into a 260-byte buffer, keeps the first 259 bytes and drops the rest. The member is listed and
  extracted under the cut name (a cut UTF-8 name may also end inside a letter and is then decoded
  as code-page text: another, garbled name). By reading; reproduced by the probe of this feature.

## Clarifications

### Session 2026-10-20

- Q: When even the Windows path limit is too short for the temporary copy (the member's name close to 255 UTF-16 units plus the temporary folder over 259 UTF-16 units), what does F3 / F4 show? → A: The existing refusal "Unable to unpack file from archive to temporary directory because resulting filename is too long." - nothing is extracted, nothing is cut; a new or reworded message would need the translation refresh a run does not do (autonomous run: conservative - the item allows "or the refusal names the limit", and the existing message names the cause)
- Q: Do the disk-cache services offered to plug-ins (a plug-in's own view of a file of its file system, the User Menu's batch file) also get temporary paths longer than 259 bytes? → A: No - they keep the byte limit they have always had; plug-ins built against the interface may copy the returned path into a 260-byte buffer, and changing what the plug-in interface hands out is the maintainer's decision. Only the core's own F3 / F4 of archive members take the longer paths (autonomous run: conservative / rule - plug-in interface is maintainer-owned)
- Q: What does a gzip file whose stored name is longer than any file system takes (over 255 UTF-16 units) do? → A: It is refused: the archive is not opened, with the system's message "The filename or extension is too long." - no member is listed under a cut name and nothing is extracted (autonomous run: item - "refused, never extracted under a cut name"; the system's text avoids a new UI string)
- Q: Is anything changed for long folder names inside archives? → A: No - measured: every route reports the folder it cannot list (autonomous run: item - "a skipped folder is reported" holds at HEAD)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View and edit an archive member with a long name (Priority: P1)

A user opens a ZIP (or any archive a plug-in reads) whose member has a long valid name - e.g. 90
Chinese letters - and presses F3 to view it or F4 to edit it.

**Why this priority**: it is the measured refusal of a valid, common operation; names of 70+ CJK
letters (or 128+ Cyrillic letters) are ordinary, and since feature 222 such archives open.

**Independent Test**: probe rows VIEWLONG, EDITLONG, OVERLIMIT, CTL of this feature.

**Acceptance Scenarios**:

1. **Given** a ZIP with a member of 90 CJK letters + ".txt", **When** the user presses F3 on it,
   **Then** the viewer opens with the member's content.
2. **Given** the same ZIP, **When** the user presses F4, edits the copy and leaves the archive,
   **Then** the "update the archive" question appears, and after confirming the archive holds the
   member under its whole name with the new content - and no second member under any other name.
3. **Given** a member whose temporary copy would exceed what Windows takes in a path (a name of
   250 Latin letters), **When** the user presses F3 or F4, **Then** the existing message
   "...resulting filename is too long." appears and nothing is extracted.
4. **Given** a member with a short name, **When** the user presses F3 / F4, **Then** the viewer /
   editor opens as before (control).

---

### User Story 2 - A gzip file with a long stored name (Priority: P2)

A user opens a `.gz` file whose header stores an original name longer than 259 bytes.

**Why this priority**: the member is extracted under a wrong (cut, possibly garbled) name - the
user gets a file named differently than the one packed.

**Independent Test**: probe rows GZLONG, GZOVER, GZCTL of this feature.

**Acceptance Scenarios**:

1. **Given** a `.gz` whose stored name is 90 CJK letters + ".txt" (274 bytes), **When** the user
   opens it and extracts the member (F5), **Then** the file is created under exactly that name.
2. **Given** a `.gz` whose stored name has more than 255 UTF-16 units, **When** the user opens it,
   **Then** the archive is refused with "The filename or extension is too long." and no member
   is listed or extracted.
3. **Given** a `.gz` with a short stored name, **When** the user extracts it, **Then** it is
   extracted under that name as before (control).

---

### Edge Cases

- Two members with the same long name in different archives or panels: the temporary copies stay
  separate as before (the cache's identity rules are not changed).
- A member name that is invalid on Windows (a trailing dot): F3 keeps its existing valid
  temporary name; F4 keeps its existing refusal.
- A temporary folder on a long %TEMP% path: the limit is measured on the whole path, so a long
  %TEMP% only lowers the name length that fits; beyond it the existing refusal appears.
- The edited copy cannot be packed back (the archive is read-only): the "copy the edited files
  elsewhere" choice takes the long name too, or says "too long name" when the target path is over
  what Windows takes - the copy is never silently skipped or cut.
- A gzip stored name with a path ("dir/name"): only the last part is the name, as before.
- A gzip stored name that is not valid UTF-8: decoded as before (code page); the length check is
  made on the decoded name.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: F3 and F4 of an archive member MUST create the temporary copy under the member's
  whole name whenever the copy's full path fits the Windows path limit (259 UTF-16 units),
  regardless of how many UTF-8 bytes the path has.
- **FR-002**: When the temporary copy's full path does not fit, F3 / F4 MUST refuse with the
  existing "resulting filename is too long" message; no shortened name may be used for a file that
  F4 packs back.
- **FR-003**: Every place the edited copy's path is held on its way back into the archive (the
  change check, packing, "copy the edited files elsewhere") MUST hold the whole path; a path that
  cannot be held MUST be refused with a message, never cut.
- **FR-004**: The disk-cache services used by plug-ins and the User Menu MUST keep their current
  limit (unchanged behaviour).
- **FR-005**: The tar plug-in MUST read a gzip file's stored name whole (no 259-byte cut).
- **FR-006**: A gzip stored name with more than 255 UTF-16 units (after decoding) MUST make the
  archive refuse to open with a message; it MUST NOT be listed or extracted under any cut form.
- **FR-007**: Existing behaviour for short names, invalid names and long folder names inside
  archives MUST stay unchanged.
- **FR-008**: The length decision of FR-001 / FR-002 MUST be a pure rule with unit checks.

### Key Entities

- **Temporary copy**: the file the program extracts a member into for viewing or editing; its
  path = the cache's temporary folder + the member's name.
- **gzip stored name**: the original file name in a `.gz` header, the member's name in the panel.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: F3 and F4 of a member of 90 CJK letters + ".txt" work (probe rows VIEWLONG, EDITLONG
  PASS; both FAIL on the build before).
- **SC-002**: The edit round trip of that member leaves exactly one member in the archive, under
  its whole name, with the edited content.
- **SC-003**: A gzip with a 274-byte stored name is extracted under exactly that name; one whose
  name is over 255 UTF-16 units is refused and nothing is written (probe rows GZLONG, GZOVER PASS;
  FAIL before).
- **SC-004**: All control rows and the regression probe of feature 222 still PASS; unit checks of
  the length rule pass.

## Assumptions

- Assumption (autonomous run): the cache's temporary folder is created by the program under %TEMP%
  (or a plug-in's configured folder) and is short; the limit applies to the whole path.
- Assumption (autonomous run): viewers and editors already receive paths of more than 259 bytes
  from disk panels (feature 222 lets such names exist on disk), so handing them the temporary copy
  of a long name is not a new kind of input for them.
- Assumption (autonomous run): packers already pack disk files with such names (F5 into an
  archive); the edit's way back is the same packing route.
- Out of scope: names whose temporary path exceeds 259 UTF-16 units (they would need long-path
  support in every archiver plug-in, viewer and editor); the plug-in disk-cache services.
