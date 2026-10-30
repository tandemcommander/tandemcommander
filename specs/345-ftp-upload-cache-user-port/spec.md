# Feature Specification: An FTP change made as another user or through another port reaches the running uploads

**Feature Branch**: `345-ftp-upload-cache-user-port`
**Created**: 2026-10-30
**Status**: Draft
**Input**: User description: "Backlog item ftp-upload-cache-other-user-or-port-of-one-server - implement exactly what it describes." From backlog item ftp-upload-cache-other-user-or-port-of-one-server.

## Clarifications

### Session 2026-10-30

- Q: Which other connections count as "maybe the same server" when a change is reported? → A: Every
  other connection identity (host name, user, port) - the client cannot tell which accounts and
  ports share folders (two accounts with a shared home; `anonymous` and a named account of a
  public folder; port 21 and a forwarded 2121; chroot jails that show one folder under different
  paths), just as 341 found it cannot tell two host names apart. Feature 341 already takes every
  other host name with the same user and port as maybe the same server, so a change made as user
  `u` at `127.0.0.1` can also reach an upload as `v` at `localhost`; covering only "the same host
  name with another user or port" (the item's middle way) would leave that combination losing
  data (probe row ALL-REN). (autonomous run: item *Expected* - "the uploads do not trust their
  cached listings after such a change (they list the folder again)"; rule - a safety check fails
  closed, 098; the same reasoning as 341's first clarification)
- Q: Is the change applied to the other connections' cached listings, or do they stop trusting
  them? → A: They stop trusting all their listings (they list again before deciding), as in 341 -
  another account may see another folder under the same path, so applying the report could
  suppress a needed overwrite question; invalidation can never lose data. (autonomous run: item
  *Expected*; conservative)
- Q: A panel's listing used to seed an upload's cache - is it trusted after a change made as
  another user or through another port? → A: No - a panel listing taken before a change reported
  under any other connection identity is not used; the upload lists the folder itself (the panel
  is refreshed only by changes made under its own identity). (autonomous run: item *Expected*;
  341's SEED rule extended; measured as data loss, rows SEED-USER / SEED-PORT)
- Q: What does failing closed cost? → A: While uploads to two connection identities run at the same
  time - also to two unrelated servers - each change made through one makes the other list its
  folder again before its next decision: slower, never less safe. A panel upload after any change
  made elsewhere lists the folder once instead of using the panel's listing. Nothing changes for
  one upload alone or for uploads that all use one identity. (autonomous run: item *Expected*
  accepts it - "they list the folder again"; the item's *Notes* name the cost; 341 accepted the same
  cost for host names)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A panel change made as another user reaches the upload (Priority: P1)

A user has an FTP panel connected to a server as user `u`, and an upload to the same server as user
`v` (an account that sees the same folders) is running - for example waiting at an overwrite
question. In the panel the user renames `a.txt` to `b.txt`. The user then uploads a local `b.txt`
as `v` into the same folder.

**Why this priority**: this is the item's measured data loss: the upload stores `b.txt` without
the overwrite question and the renamed file is gone.

**Independent Test**: probe row USER-REN: upload 1 as `v` held at its question, Quick Rename in the
panel as `u`, upload 2 of `b.txt` as `v`.

**Acceptance Scenarios**:

1. **Given** an upload as `v` running with a cached listing of a folder, **When** a file in that
   folder is renamed in a panel connected as `u` and the upload of a file with the new name starts
   as `v`, **Then** the upload lists the folder again and asks whether to overwrite `b.txt`; the
   server's `b.txt` keeps its content.

---

### User Story 2 - A change made through another port reaches the upload (Priority: P1)

The same as story 1, with the panel connected to port 2145 and the uploads made to port 2146 of the
same server (a forwarded port), and with user, host name and port all different (`u@127.0.0.1:2145`
in the panel, `v@localhost:2146` for the uploads).

**Why this priority**: the same data loss through the second half of the item.

**Independent Test**: probe rows PORT-REN and ALL-REN.

**Acceptance Scenarios**:

1. **Given** an upload to another port of the server running, **When** a file is renamed in the
   panel and an upload of the new name starts, **Then** the overwrite question is asked and the
   server's file keeps its content.
2. **Given** an upload as another user, to another host name and port, **When** the same steps run,
   **Then** the same.

---

### User Story 3 - A panel's old listing is not trusted after a change made elsewhere (Priority: P2)

A user uploads a new file `n.txt` as `v` (or to the other port) into the folder shown in a panel
connected as `u`; that upload ends, and the panel is not refreshed by it. The local `n.txt` changes
and the user uploads it with F5 into the panel.

**Why this priority**: the second measured data-loss path (the upload's cache is seeded from the
panel's listing, which does not yet show `n.txt`).

**Independent Test**: probe rows SEED-USER and SEED-PORT.

**Acceptance Scenarios**:

1. **Given** a panel listing taken before `n.txt` was stored as another user or through another
   port, **When** the user uploads `n.txt` into the panel, **Then** the overwrite question for
   `n.txt` is asked and the server's `n.txt` keeps the first upload's content.

---

### Edge Cases

- Changes made under the same identity as the upload (the same host, user and port) behave as
  before: the cached listing is updated by the report (control rows SAME-REN, SEED-SAME).
- Another host name with the same user and port behaves as after 341 (control row ALIAS-REN).
- `anonymous` and an empty user name are one identity (as before).
- More than 1,000 identities with changes, or low memory while recording a change: no panel
  listing is trusted any more (fails closed, as 341).
- Two uploads to two unrelated servers at once: each lists its folder again after the other's
  changes (the accepted cost).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a change (created folder, rename, delete, stored file, uploaded file, unknown
  change) is reported for one FTP connection identity (host, user, port), every running upload's
  cached listings under any other identity MUST stop being trusted, so that the upload lists the
  folder again before deciding whether a name exists.
- **FR-002**: A panel listing offered to an upload's cache MUST be refused when a change was
  reported under any other identity after that listing started.
- **FR-003**: Changes reported under the upload's own identity MUST keep updating its cached
  listing as before (no extra listing, no lost question).
- **FR-004**: No file on the server is replaced without the overwrite question in the measured rows
  (USER-REN, PORT-REN, ALL-REN, SEED-USER, SEED-PORT); the control rows (ALIAS-REN, SAME-REN,
  SEED-SAME) stay as they are.

### Key Entities

- **Connection identity**: the host name as typed, the user (`anonymous` = none) and the port of an
  FTP connection; the upload listing cache keeps listings per identity.
- **Change stamp**: the latest change reported under one identity (341), compared with the start
  of a panel listing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The feature's probe: rows USER-REN, PORT-REN, ALL-REN, SEED-USER, SEED-PORT go from
  FAIL (measured at ad3eb597) to PASS; ALIAS-REN, SAME-REN, SEED-SAME stay PASS; every END row PASS;
  the product's registry key restored identical.
- **SC-002**: Feature 341's probe (`ftp341_probe.ps1`) and feature 323's (`ftp302_probe.ps1`) keep
  all their rows PASS.
- **SC-003**: A negative control (the fix reverted) makes the five rows of SC-001 FAIL again.

## Assumptions

- Assumption (autonomous run): the cost of failing closed (Clarifications, last bullet) is
  accepted per the item's *Expected*; it lasts only while uploads under two identities run, or for
  the one listing of a panel upload after a change made elsewhere.
- Out of scope: the opened-file lock under two names (`ftp-opened-file-lock-two-names-of-one-server`),
  the refresh of panels under other identities.
- No UI string, dialog, setting, stored data or network communication changes (no translation
  refresh, no `PRIVACY.md` change): the uploads only list folders they already list, more often.
