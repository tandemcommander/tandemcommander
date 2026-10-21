# Feature Specification: FTP - names go to each server in that server's own encoding

**Feature Branch**: `288-ftp-per-server-encoding`
**Created**: 2026-10-21
**Status**: Draft
**Input**: From backlog item ftp-per-server-encoding-flag. User description: "Backlog item ftp-per-server-encoding-flag (backlog/items/ftp-per-server-encoding-flag/desc.md) - implement exactly what it describes." (full input: title, problem, evidence, expected, measurement at f9da572f - see *Background* below)

## Background

An FTP server either speaks UTF-8 in file names (the common case today) or a legacy code page
(old servers that convert names through the system's ANSI code page). Feature 224 taught the FTP
plug-in to send a name in the code page only when a listing (or the server's working-path reply)
had given that very name in the code page; every other non-ASCII name goes in UTF-8. It kept those
names in **one set for the whole program**, so:

- a **new** name - a folder the user creates, the new name of a Quick Rename, an uploaded local
  file, a typed path, a bookmark - goes in UTF-8 even to a server whose listings show that it
  speaks the code page: the server stores a garbled name;
- a name seen in the code page on **one** server goes in the code page to **another** server
  (for example a migration from an old server to a new one): the other server does not find it.

**Measured at f9da572f** (hidden-desktop probe `probe/ftp288_probe.ps1`, the Debug build of HEAD,
two local test servers at once - a legacy cp1250 one and a UTF-8 one; system code page 1250;
`probe/result_before.txt`, 8 PASS / 4 FAIL):

- LEG-MKD FAIL - the legacy server's folder lists `café.txt` in cp1250; Create Directory `nový`
  sent `MKD` in UTF-8: the server created `novĂ˝`;
- LEG-REN FAIL - Quick Rename `a.txt` -> `čaj.txt`: `RNTO` in UTF-8, the server has `ÄŤaj.txt`;
- LEG-UP FAIL - F5 upload of the local `čaj.txt` (done by an operation's worker): `STOR` in UTF-8,
  `ÄŤaj.txt` on the server;
- CROSS-DEL FAIL - one program lists `café.txt` on the legacy server, then opens the UTF-8 server's
  folder holding a file of the same name; F8 sent `DELE` in cp1250: "550 No such file";
- UTF-MKD PASS (control: the UTF-8 server gets `MKD` in UTF-8); UNK-MKD PASS (the legacy server, a
  folder of ASCII names only: nothing tells its encoding yet, `MKD` goes in UTF-8 - a limit that
  stays).

The plug-in sends no `FEAT` command today; the only evidence it has without new traffic to the
server is the bytes of its listings and of its working-path / created-folder replies (257).

## Clarifications

### Session 2026-10-21

- Q: Should the plug-in start sending `FEAT` (and read its `UTF8` line) as evidence? → A: no - that is a change of the product's network communication, owned by the maintainer; evidence comes from listings and 257 replies only, the question is recorded as a decision item (autonomous run: rule - stop-rules §1 maintainer-owned "Network"; the item allows "FEAT UTF8 or a listing")
- Q: Is a server's encoding state kept after the program ends? → A: no - in memory for the life of the plug-in only; nothing new is stored (autonomous run: rule - stored data is maintainer-owned; conservative)
- Q: What does a server whose listings show both UTF-8 and code-page names get for a new name? → A: UTF-8, as since feature 224 (names that one of its listings gave in the code page still go back in the code page) (autonomous run: conservative)
- Q: Does a path in a 257 reply (PWD, MKD) that is valid UTF-8 count as UTF-8 evidence? → A: no - such a reply can echo the bytes the client itself sent (a path typed while the state was unknown went in UTF-8); only listing fields give UTF-8 evidence; a 257 path read in the code page still gives legacy evidence and its names are remembered (feature 224's home-folder case) (autonomous run: conservative)
- Q: What does a legacy server get for a new name its code page cannot hold (CJK)? → A: UTF-8, as before - there is no better form (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - New names reach a legacy server in its code page (Priority: P1)

A user works on an old FTP server whose listings show accented names in the system code page. When
they create a folder, rename a file to a new name or upload a local file with letters outside
ASCII, the server receives the name in its code page and stores it under the name the user typed.

**Why this priority**: today every new non-ASCII name on such a server is garbled - the main
defect of the item.

**Independent Test**: probe rows LEG-MKD, LEG-REN, LEG-UP: the legacy test server ends up with
`nový`, `čaj.txt` (renamed) and `čaj.txt` (uploaded, with its content).

**Acceptance Scenarios**:

1. **Given** a panel on a legacy server whose listing gave a non-ASCII name in the code page,
   **When** the user creates the folder `nový`, **Then** the server creates `nový`.
2. **Given** the same panel, **When** the user Quick-Renames `a.txt` to `čaj.txt`, **Then** the
   server has `čaj.txt` and no `a.txt`.
3. **Given** the same server, **When** the user uploads the local `čaj.txt` into that folder (an
   operation run by a worker), **Then** the server has `čaj.txt` with the file's content.

---

### User Story 2 - What one server showed does not decide another server (Priority: P1)

A user who has listed a legacy server and then works on a UTF-8 server (or the other way round)
gets each server's names in that server's encoding.

**Why this priority**: the shared set makes commands on the second server reach no file (or,
with other names, another file) - delete, rename, download fail.

**Independent Test**: probe row CROSS-DEL.

**Acceptance Scenarios**:

1. **Given** one program that listed `café.txt` on the legacy server, **When** it opens the
   UTF-8 server's folder holding `café.txt` and deletes it, **Then** the UTF-8 server's file is
   deleted (the command went in UTF-8) and the legacy server's file is untouched.

---

### User Story 3 - Everything that worked keeps working (Priority: P2)

UTF-8 servers keep getting UTF-8; a legacy server's listed names keep going back in the code page
(also inside paths and a home folder known only from the working-path reply, feature 224); a
server about which nothing is known yet gets UTF-8 as before.

**Independent Test**: probe rows UTF-MKD, UNK-MKD; feature 224's probe (16 / 0), 269's and 277's
probes as recorded.

**Acceptance Scenarios**:

1. **Given** a UTF-8 server whose listing shows `café.txt` in UTF-8, **When** the user creates
   `nový`, **Then** the server gets the name in UTF-8.
2. **Given** a legacy server of which only ASCII names were seen, **When** the user creates
   `nový`, **Then** the name goes in UTF-8 (unchanged; the limit is documented).

### Edge Cases

- A name the code page cannot hold (CJK) goes in UTF-8 to any server, also to a legacy one (as
  before).
- A path typed while the server is unknown goes in UTF-8; the PWD reply that echoes it does not
  make the server a UTF-8 one.
- Pure ASCII names and paths are identical in every encoding and go unchanged.
- Two logins to the same host and port with different user names are two servers; the anonymous
  login and an empty user name are the same server (the upload listing cache's identity rule);
  the host name is compared without regard to ASCII case.
- A server listed through a proxy is identified by the FTP server's host, port and user, not the
  proxy's.
- A listing read in the server-type test dialog (no connection) records no evidence.
- A server whose listings show both UTF-8 and code-page names: its code-page names go back in the
  code page, new names go in UTF-8.
- Memory: the remembered names keep feature 224's bound (200,000 names in total); past it, a name
  is not remembered (it goes as a new name of its server). At most 1,000 servers are tracked; a
  further one is treated as unknown (UTF-8, no remembered names).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plug-in MUST keep, for each FTP server identified by host (ASCII case
  ignored), port and user (anonymous = none), an encoding state: unknown, UTF-8, legacy (code
  page) or mixed, for the life of the plug-in.
- **FR-002**: A listing name field or a 257 reply path with bytes outside ASCII MUST count as
  evidence for the server it came from: a name field that is valid UTF-8 (WTF-8, feature 269) =
  UTF-8 evidence - unless it is a name this client sent that server in UTF-8 (a legacy server
  lists such bytes back; review of 288), and a 257 reply path never is (it may echo what the
  client sent); a name field or a 257 path read in the code page = legacy evidence. Every field
  read in the code page (also owner, group, ...) is remembered as one of that server's code-page
  texts (224); fields other than the name do not change the state.
- **FR-003**: A non-ASCII name or path sent to a server MUST go in the code page when it is, or
  contains as a component or leading part, a code-page name of **that** server (feature 224's
  rule, now per server), or when the server's state is legacy - provided the code page holds it
  **exactly** (no best-fit look-alike: `señor` is never sent as `senor`, another file; review of
  288); otherwise in UTF-8.
- **FR-004**: The state of a server MUST NOT be influenced by listings or replies of any other
  server.
- **FR-005**: Every command that carries a name or path (CWD, DELE, RMD, SITE CHMOD, RETR, STOR,
  APPE, MKD, RNFR, RNTO, SIZE) MUST use the state of the server the command goes to - from the
  panel's connection and from every operation's worker.
- **FR-006**: Nothing new is sent to a server and nothing new is stored on disk or in the
  registry.

### Key Entities

- **Server encoding state**: identity (host, port, user); evidence seen (UTF-8, code page); the
  set of names its listings or replies gave in the code page.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's rows LEG-MKD, LEG-REN, LEG-UP and CROSS-DEL go from FAIL to PASS; all
  six rows pass.
- **SC-002**: Feature 224's probe stays 16 / 0; 269's and 277's probes keep their recorded results.
- **SC-003**: The pure decision (state from evidence, which encoding a name goes in, the server
  identity) is covered by unit checks; saltests 0 failed.

## Assumptions

- Assumption (autonomous run): the evidence is listings and 257 replies only; `FEAT UTF8` would
  need a new command to the server (maintainer-owned) - recorded as a decision item.
- Assumption (autonomous run): an unknown server gets UTF-8 for new names (feature 224's policy);
  the first listing with a non-ASCII name decides. A typed path or bookmark used before any such
  listing goes in UTF-8.
- Assumption (autonomous run): a legacy server's code page is the system ANSI code page (as
  since feature 224; no per-server code page choice).
- Assumption (autonomous run): states live in memory until the plug-in is released; a reconnect
  to the same server in the same session keeps its state.
