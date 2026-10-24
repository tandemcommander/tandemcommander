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

- Q: How is "the same server under another name" recognised - by resolving names anew? → A: No
  new name lookups and no new network communication: the plug-in already obtains the address of
  every server it connects to (a typed IPv4 address is read as it is; a name is looked up when a
  connection is opened). The addresses of those lookups are remembered in memory for the
  session only and compared. (autonomous run: item Notes + rule - network behaviour is
  maintainer-owned, so the conservative option that changes none)
- Q: When two names may be one server, is the change applied to the other upload's cache as
  reported, or does that cache stop trusting its listings? → A: The other cache stops trusting
  all of its listings (the upload lists the folder again before deciding). An equal address does
  not prove the same file system (e.g. a proxy in between), and a wrongly applied delete report
  could suppress a needed question; invalidation can never lose data. (autonomous run: item
  Expected - "or ... the upload does not trust its cached listings"; conservative)
- Q: What when the address of one of the two names is not known (a connection through a proxy,
  where the plug-in looks up only the proxy)? → A: The identity cannot be told: treated as maybe
  the same server - the other cache is invalidated. (autonomous run: item Expected)
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

### User Story 3 - Different servers keep their caches (Priority: P3)

Uploads to two servers whose known addresses differ do not make each other list folders again.

**Why this priority**: keeps the cache's purpose (fewer listings) for the common case.

**Independent Test**: unit checks of the identity rule (saltests).

**Acceptance Scenarios**:

1. **Given** two cached servers with the same user and port whose known addresses have none in
   common, **When** a change is reported for one, **Then** the other's listings stay trusted.
2. **Given** one name everywhere (feature 323's rows), **Then** behaviour is unchanged.

### Edge Cases

- A name that resolves to several addresses: any address in common counts as maybe the same.
- A host typed as an IPv4 address (also short forms the plug-in accepts, e.g. `127.1`): its
  address is known without any lookup.
- An address not known for either name (proxy, a name never looked up in this session): maybe
  the same - invalidated.
- A name whose address changed during the session: the latest lookup counts; an outdated
  "different" only keeps today's behaviour, an outdated "same" only costs a listing.
- Two uploads under two names of one server running at once: each store makes the other list
  again (correct; slower than one name).
- Different user or port: unchanged behaviour (not identified as the same server).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A change reported for a server (user, host, port) MUST, besides the cache entry of
  exactly that host as before, invalidate every cached listing of every other cache entry with the
  same user and port that may be the same server.
- **FR-002**: Two host names MUST count as maybe the same server when their known addresses have
  one in common, or when the address of either is not known; as different when both are known
  and have none in common; equal host text keeps today's exact match.
- **FR-003**: A host's known addresses MUST come only from what the plug-in already does: a
  typed IPv4 address read as it is, or the result of a lookup the plug-in made to connect. No new
  lookup or other network communication is added; nothing is stored beyond the running process.
- **FR-004**: The reports covered: Create Directory, Rename, Delete, store started, file uploaded,
  unknown change (Send FTP Command). Listing bookkeeping (a listing received, failed, updated
  from the panel, invalidated by the upload itself) stays per exact host.
- **FR-005**: Behaviour for one name everywhere MUST stay unchanged (feature 323's probe rows).
- **FR-006**: The identity rule MUST be a pure, unit-tested rule (header under `src/common/`).

### Key Entities

- **Cached server entry**: user, host as typed, port; its cached folder listings.
- **Known addresses of a host**: zero or more IPv4 addresses, from a typed address or a lookup
  the plug-in made in this session.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows ALIAS-REN and ALIAS-UP: FAIL on `main` -> PASS (question shown, server
  file unchanged, no store sent before the answer).
- **SC-002**: Control SAME-REN and feature 323's probe `ftp302_probe` (16 rows) stay PASS.
- **SC-003**: saltests: the identity rule's checks pass, 0 failed overall.
- **SC-004**: No new network request: no new lookup call site; the only new code on the lookup
  path records a result already received.

## Assumptions

- Assumption (autonomous run): IPv4 only - the plug-in's connections use IPv4 addresses
  (`gethostbyname`, 32-bit addresses); IPv6 does not arise.
- Assumption (autonomous run): the remembered addresses are a small in-memory table (bounded) for
  the life of the plug-in; not a stored setting, so `PRIVACY.md` (what is stored) is unaffected.
- Assumption (autonomous run): host names compare case-insensitively in ASCII (DNS rule).
- Out of scope: two user accounts sharing folders on one server; the same server on two ports.
