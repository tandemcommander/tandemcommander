# Feature Specification: An FTP upload asks before replacing a server file whose name differs only in case

**Feature Branch**: `303-ftp-upload-case-only`
**Created**: 2026-10-22
**Status**: Draft
**Input**: User description: "Backlog item ftp-an-upload-to-a-case-insensitive-server-with-unix-paths - FTP: an upload to a case-insensitive server with Unix paths replaces b.txt by B.txt without the question." From backlog item ftp-an-upload-to-a-case-insensitive-server-with-unix-paths.

## Background

Before an FTP upload sends a file, it looks the target name up in the listing of the target
folder (taken from the panel or fetched for the upload) to decide whether the file already exists
and so whether to ask the "Target File Already Exists" question (or apply the configured answer).
For servers whose paths look like Unix paths the plug-in compares names byte for byte. Many such
servers (FileZilla Server and other Windows-backed servers) store files on a case-insensitive file
system: uploading `B.txt` into a folder that holds `b.txt` is, on the server, writing `b.txt`.
The upload did not see the collision, sent the file without the question, and the server replaced
its `b.txt` - data loss. The plug-in cannot know whether a Unix-style server is case-insensitive.

Measured at 17febaaf (see `fix-log.md`): a hidden-desktop probe with a local test server on NTFS
(Unix-style listings): server `b.txt` = `SRV-B`, upload of a local `B.txt` - no question,
`STOR B.txt`, the server's file now holds the uploaded content. The same for `Čaj.txt` /
`čaj.txt`. A control upload of `c.txt` beside `b.txt` went through without a question, as it
should.

## Clarifications

### Session 2026-10-22

- Q: Which name rule decides "differs only in case"? → A: the file system's name rule of feature
  092 (`salnameorder.h`, header-only for plug-ins) - what Windows calls one file name; it covers
  non-ASCII letters (`Č` / `č`) and keeps NFC / NFD forms and look-alikes apart (autonomous run:
  rule - CLAUDE.md "The same name is the file system's rule").
- Q: On which server types? → A: every server path type: on a case-sensitive (Unix) type a
  case-only match is a possible collision; on the case-insensitive types it adds the non-ASCII
  matches their code-page fold misses (autonomous run: item - *Expected*, "the conservative rule
  ... on every server type").
- Q: Does it change folder uploads (an existing folder `Docs` when uploading a local `docs`), the
  cache's path identity or "the same folder"? → A: No - only the decision whether a target *file*
  name exists (the overwrite question) and the auto-rename's check that a new name is free; folder
  creation / joining and path comparisons stay as they are (autonomous run: item - *Notes*, "only
  for the overwrite decision, not for path identity"; conservative).
- Q: The listed item found only by case - may its size be used as the target's size (resume, the
  "was the file transferred?" test)? → A: No; such an item's size counts as unknown, so resume
  reports that it cannot determine the size (or "resume or overwrite" overwrites), as it does today
  for an unknown size (autonomous run: conservative - on a case-sensitive server it is another
  file's size; appending at that offset would make a corrupt file).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The overwrite question for a case-only name (Priority: P1)

A user uploads a local `B.txt` into a server folder that holds `b.txt`, on a server that shows
Unix-style paths.

**Why this priority**: it is the data loss of the item: on a case-insensitive server the existing
file is replaced without any question.

**Independent Test**: hidden-desktop probe with 215's `ftpmini.py` on NTFS: server `b.txt` =
`SRV-B`, F5 of the local `B.txt` into the server panel's folder - the "Target File Already Exists"
question for `B.txt` appears, no `STOR` is sent, the server's file keeps `SRV-B`.

**Acceptance Scenarios**:

1. **Given** a server folder holding `b.txt` and no `B.txt`, **When** the user uploads `B.txt`
   into it with the default settings, **Then** the "Target File Already Exists" question appears
   and nothing is sent until the user answers.
2. **Given** a server folder holding `Čaj.txt`, **When** the user uploads `čaj.txt`, **Then** the
   same question appears.
3. **Given** the question of scenario 1, **When** the user chooses Overwrite, **Then** the file is
   uploaded under the name `B.txt` (the user's choice is carried out).
4. **Given** the configured answer for an existing file is not "ask" (overwrite, skip, auto-rename,
   resume), **When** the upload meets a case-only match, **Then** that configured answer is
   applied, as for an exact match.

---

### User Story 2 - Unrelated names upload as before (Priority: P2)

A user uploads `c.txt` into a server folder holding `b.txt`, or `B.txt` into a folder on a
case-sensitive server that holds both `b.txt` and `B.txt`.

**Why this priority**: the fix must not ask about names that do not collide, nor pick the wrong
twin where the server lists both.

**Independent Test**: the probe's control row: `c.txt` beside `b.txt` - `STOR c.txt`, no question,
`b.txt` kept; the pure rule's checks for the exact twin.

**Acceptance Scenarios**:

1. **Given** a folder without any name equal to `c.txt` in any case, **When** `c.txt` is uploaded,
   **Then** it is sent without a question.
2. **Given** a listing holding both `b.txt` and `B.txt`, **When** `B.txt` is uploaded, **Then** the
   decision is made for the listed `B.txt` (the exact name), as today.

---

### User Story 3 - Auto-rename and resume stay safe (Priority: P3)

A user answers the question with Auto-rename, or with Resume.

**Why this priority**: both continue from the collision; neither may pick a name that collides by
case nor append to the wrong file.

**Independent Test**: by reading and by the pure rule's checks (the probe drives Overwrite only).

**Acceptance Scenarios**:

1. **Given** auto-rename generates a new name, **When** the listing holds that name in another
   case, **Then** another name is generated.
2. **Given** Resume is chosen for a case-only match and the server does not answer the size
   query, **Then** the upload does not append at the listed item's size; it reports that the size
   cannot be determined (Resume) or overwrites (Resume or Overwrite).

### Edge Cases

- A listed folder or link whose name differs from the target file only by case: handled as an
  exact folder / link of that name is handled today ("cannot create file", or the link is
  resolved).
- Several listed names equal to the target in different cases (a case-sensitive server with
  `b.txt` and `b.TXT`, target `B.txt`): any one of them makes the target "existing" - the question
  is asked once.
- Names that are not valid UTF-8 (a legacy server): compared by the legacy byte fold of the rule;
  never equal to a valid UTF-8 name.
- NFC vs NFD forms (`é` precomposed vs `e` + accent): different names, as the file system rule
  says - no question.
- A large folder: the extra comparison runs only when the exact lookup finds nothing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before a file upload sends a file, a listed item whose name is the same as the
  target name under the file system's name rule (case ignored, feature 092) MUST count as an
  existing item when the exact lookup finds none, on every server path type.
- **FR-002**: Such an item MUST be handled as an existing item of its kind is handled today (file:
  the "Target File Already Exists" question or the configured answer; folder: "cannot create
  file"; link: resolved).
- **FR-003**: Auto-rename MUST treat a new name that matches a listed name under the same rule as
  taken.
- **FR-004**: The size of an item found only by the case-ignoring rule MUST NOT be used as the
  target file's size (resume offset, the "transferred whole?" test); it counts as unknown.
- **FR-005**: An exact match MUST keep priority: when the listing holds the target name exactly,
  the decision uses that item, as today.
- **FR-006**: Folder uploads (create / join), the listing cache's path identity, its update reports
  and every other lookup MUST stay as they are.
- **FR-007**: No user-visible text changes (no new or removed strings).
- **FR-008**: The rule "is there a listed name equal to this one under the file system rule" MUST
  be a pure decision in a header under `src/common/` with `saltests` checks.

### Key Entities

- **Target folder listing**: the names, kinds and sizes of the items of the upload's target
  folder as the upload knows them (from the panel or a listing fetched for the upload).
- **Case-only match**: a listed item whose name differs from the target name's bytes but is the
  same name under the file system's rule.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, an upload of `B.txt` into a folder holding `b.txt` (and `čaj.txt`
  into `Čaj.txt`) on a case-insensitive server with Unix-style listings asks the question in 2 of
  2 rows and the server files keep their contents (before: 0 of 2).
- **SC-002**: The control upload of a non-colliding name is sent without a question (1 of 1, as
  before).
- **SC-003**: Answering the question with Overwrite uploads the file (1 of 1).
- **SC-004**: The pure rule passes its `saltests` checks, and a negative control (the byte-exact
  lookup) fails them.
- **SC-005**: The existing FTP probes used as regressions (302's is on an unmerged branch; 288's,
  224's) show no new failures.

## Assumptions

- Assumption (autonomous run): on a truly case-sensitive server the question for a case-only match
  is a false alarm the user answers once (Overwrite creates `B.txt` beside `b.txt`); asking one
  question too many is preferred to replacing a file silently.
- Assumption (autonomous run): the target name the upload sends is unchanged (`B.txt`); the user
  chose that name.
- Assumption (autonomous run): server-name encoding (feature 288) is not affected; listed names
  are compared as the upload holds them (UTF-8 for UTF-8 servers).
- Out of scope: folders differing by case (`Docs` / `docs`) in uploads and Create Directory (item
  302's MUST and the related item `ftp-server-path-compare-code-page-fold`).
