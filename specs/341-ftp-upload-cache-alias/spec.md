# Feature Specification: FTP upload listing cache recognises a server reached under another name

**Feature Branch**: `341-ftp-upload-cache-alias`
**Created**: 2026-10-24
**Status**: Draft
**Input**: User description: "Backlog item ftp-an-upload-to-a-server-named-another-way-localhost-vs-127 - FTP: an upload to a server named another way (localhost vs 127.0.0.1) misses the panel changes." From backlog item ftp-an-upload-to-a-server-named-another-way-localhost-vs-127.

## Background

While an upload to an FTP server is in progress, the FTP plug-in keeps a cache of that server's
folder listings; the upload consults it to decide whether a target name already exists (and so
whether to ask the overwrite question). Every change made to the server through the plug-in -
the panel's Create Directory, Quick Rename, Delete, Send FTP Command, and the stores and deletes
of operations - is reported to that cache by user, host and port. The cache matches the host as
typed, so a server reached under two names (`localhost` and `127.0.0.1`, a name and its address,
two names of one machine) is two servers to it: a change made through one name never reaches the
upload that uses the other name, and the upload trusts a listing that is no longer true.

Measured at 3034d82f (hidden-desktop probe `probe/ftp341_probe.ps1`, Debug build of `main`,
`probe/result_main.txt`):

- ALIAS-REN: upload 1 to `ftp://u:p@localhost:2141/ALIAS-REN` kept open at its overwrite
  question; Quick Rename `a.txt` -> `b.txt` in the panel connected as `127.0.0.1`; upload 2 of the
  local `b.txt` to `localhost` sent `STOR b.txt` without the question - the server's `b.txt`
  (the renamed file, `SRV-A`) was replaced by `LOCAL-B`. **Data loss.**
- ALIAS-UP: upload 1 kept open at `localhost`; upload 2 stored a new `n.txt` through `127.0.0.1`;
  upload 3 of a changed local `n.txt` to `localhost` sent `STOR n.txt` without the question.
  **Data loss** - so the gap covers every change report, not only the panel's.
- SAME-REN (control, one name everywhere): PASS.

## Clarifications

### Session 2026-10-24

- Q: How is "the same server under another name" recognised? → A: It is not - the client cannot
  tell: neither equal nor different addresses prove it (a server answers on several addresses -
  127.0.0.1 and 127.0.0.2, its LAN and its public address; a proxy hides the server's address).
  Every other host name with the same user and port is taken as maybe the same server; nothing
  is looked up and nothing is remembered. (autonomous run: item Expected - "when the identity of
  the server cannot be told, the upload does not trust its cached listings"; rule - a safety
  check fails closed, 098). Revised after the independent review (M1): the first design
  remembered the addresses of the plug-in's own lookups and took names with known, disjoint
  addresses as two servers; the review reproduced the data loss with one folder served on
  127.0.0.1 and 127.0.0.2 (probe row MULTI-REN).
- Q: When two names may be one server, is the change applied to the other upload's cache as
  reported, or does that cache stop trusting its listings? → A: The other cache stops trusting
  all of its listings (the upload lists the folder again before deciding). An equal address does
  not prove the same file system (e.g. a proxy in between), and a wrongly applied delete report
  could suppress a needed question; invalidation can never lose data. (autonomous run: item
  Expected - "or ... the upload does not trust its cached listings"; conservative)
- Q: What does fail closed cost? → A: While uploads run under two names with the same user and
  port - also of two different servers (e.g. user `admin` on two machines, port 21) - each change
  through one makes the other list the folder again before deciding; slower, never less safe.
  (autonomous run: item Expected)
- Q: Do two different user names, or two different ports, count as maybe the same server? → A: No
  - the item is about server names; user and port keep identifying the server as before.
  (autonomous run: conservative - keeps existing behaviour for every case the item does not name)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A panel change reaches an upload made under another name of the server (Priority: P1)

A user uploads to a server they reached as `localhost` (the upload is still running, e.g. waiting
at a question), and in an FTP panel connected to the same server as `127.0.0.1` renames a file to
`b.txt`. They then upload a local `b.txt` to the same folder through `localhost`. The program
must ask before overwriting the server's `b.txt`.

**Why this priority**: without it the renamed file is silently replaced - data loss.

**Independent Test**: probe row ALIAS-REN.

**Acceptance Scenarios**:

1. **Given** upload 1 to `localhost` open and a panel at `127.0.0.1` in the same folder, **When**
   Quick Rename `a.txt` -> `b.txt` is done in the panel and the local `b.txt` is uploaded to
   `localhost`, **Then** no `STOR b.txt` is sent before the user answers, the overwrite question
   for `b.txt` appears, and the server's `b.txt` keeps its content.
2. **Given** the same, **When** the panel creates a folder, deletes a file or sends a command
   instead, **Then** the upload under the other name lists the folder again before deciding.

---

### User Story 2 - An upload's own store reaches an upload under another name (Priority: P2)

Two uploads run to one server under two names; a file stored by one is not missing from the
other's knowledge: the other asks before overwriting it.

**Why this priority**: the same data loss through another path (measured, ALIAS-UP).

**Independent Test**: probe row ALIAS-UP.

**Acceptance Scenarios**:

1. **Given** upload 1 to `localhost` open, **When** upload 2 stores a new `n.txt` through
   `127.0.0.1` and upload 3 sends a local `n.txt` to `localhost`, **Then** the question for `n.txt`
   appears and the server's `n.txt` keeps upload 2's content.

---

### User Story 3 - One server answering on addresses that share nothing (Priority: P3)

A server reached as `localhost` (127.0.0.1) by an upload and as `127.0.0.2` (or its LAN and public
address) by a panel: a change through one still reaches the upload through the other.

**Why this priority**: the same data loss; found by the review (M1).

**Independent Test**: probe row MULTI-REN (one folder served on 127.0.0.1 and 127.0.0.2).

**Acceptance Scenarios**:

1. **Given** upload 1 to `localhost` open and a panel at `127.0.0.2` on the same folder, **When**
   Quick Rename `a.txt` -> `b.txt` is done in the panel and the local `b.txt` is uploaded to
   `localhost`, **Then** the overwrite question appears and the server's `b.txt` keeps its content.
2. **Given** one name everywhere (feature 323's rows), **Then** behaviour is unchanged.

### Edge Cases

- Equal or different addresses, a name with several addresses, a proxy: all the same - another
  host name with the same user and port is maybe the same server.
- Two uploads under two names (of one server or of two servers with the same user and port)
  running at once: each change through one makes the other list again (correct; slower).
- Different user or port: unchanged behaviour (not taken as the same server).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A change reported for a server (user, host, port) MUST, besides the cache entry of
  exactly that host as before, invalidate every cached listing of every other cache entry with the
  same user and port that may be the same server.
- **FR-002**: Another host name (not equal as the cache compares hosts) with the same user and
  port MUST count as maybe the same server - the client cannot tell two servers apart.
- **FR-003**: No name lookup or other network communication is added; nothing is stored.
- **FR-004**: The reports covered: Create Directory, Rename, Delete, store started, file uploaded,
  unknown change (Send FTP Command). Listing bookkeeping (a listing received, failed, updated
  from the panel, invalidated by the upload itself) stays per exact host.
- **FR-005**: Behaviour for one name everywhere MUST stay unchanged (feature 323's probe rows).
- **FR-006**: The decision is one condition inside the cache (same user and port, another host);
  no pure rule beyond it - the probe proves it (rows ALIAS-REN, ALIAS-UP, MULTI-REN, and the
  negative control with the fan-out disabled).

### Key Entities

- **Cached server entry**: user, host as typed, port; its cached folder listings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows ALIAS-REN and ALIAS-UP: FAIL on `main` -> PASS (question shown, server
  file unchanged, no store sent before the answer); MULTI-REN (review M1) PASS, FAIL with the
  fan-out disabled.
- **SC-002**: Control SAME-REN and feature 323's probe `ftp302_probe` (16 rows) stay PASS.
- **SC-003**: saltests: 0 failed (unchanged count - no new pure rule).
- **SC-004**: No new network request: the change adds no lookup call.

## Assumptions

- Out of scope: two user accounts sharing folders on one server; the same server on two ports.
- Assumption (autonomous run): the cost of failing closed (FR-002) is accepted per the item's
  *Expected*; it lasts only while uploads under two names with the same user and port run.
