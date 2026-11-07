# Feature Specification: FTP panel refreshed after a change made under another name of its server

**Feature Branch**: `410-ftp-alias-refresh`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item ftp-panel-refresh-misses-change-under-another-name - a panel is not refreshed after a change made under another name of its server (localhost vs 127.0.0.1)." From backlog item ftp-panel-refresh-misses-change-under-another-name.

## Clarifications

### Session 2026-11-07

- Q: Which other connections count as "another name of its server" - another host only, or also another user / port (feature 345's rule for the upload cache)? → A: another host with the same user and port (autonomous run: item - its *Expected* names "the same user and port")
- Q: Refresh the panel, or only mark its listing outdated? → A: refresh a panel showing the changed folder (same timing as under its own name); drop cached listings of folders not shown, so their next use lists them again (autonomous run: item - both options it allows, the refresh where the stale listing is on screen)
- Q: May the refresh under another name reuse the panel's cached data of that path? → A: yes - the notification now drops that path's cached listings (any host) and viewed files (every other-host connection) itself, so the refresh is the same as under the panel's own name (autonomous run: review 1, NOTE 2 - a first answer "no, as Ctrl+R" was redundant, no probe row told them apart)
- Q: Refresh a panel of another host whose connection is closed? → A: no - only its caches are dropped; a refresh would ask to reconnect, or log in again, for a change perhaps made on another server (autonomous run: review 1, SHOULD 1; conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The panel shows a change made through another name of its server (Priority: P1)

A user has an FTP panel open on a server through one name (`127.0.0.1`). They upload a file,
rename or delete one through another name of the same server (`localhost`, typed as the target of
a copy, or the other panel connected under that name) with the same user and port. The panel
showing the changed folder lists it again, as it does today when the change is made under its own
name: the new file appears, the renamed file has its new name, the deleted file is gone - without
Ctrl+R.

**Why this priority**: this is the item's defect - the wrong display.

**Independent Test**: hidden-desktop probe row REFRESH-ALIAS: panel at `ftp://u@127.0.0.1:<port>/F`,
upload of a new `n.txt` typed to `ftp://u:p@localhost:<port>/F`; the panel's control connection
lists `F` again after the upload. Before the change: it sends nothing.

**Acceptance Scenarios**:

1. **Given** a panel at `127.0.0.1:/F`, **When** a file is uploaded into `/F` through `localhost`
   (same user, same port), **Then** the panel lists `/F` again and shows the file.
2. **Given** a panel at `127.0.0.1:/F`, **When** a file is uploaded through `localhost` into another
   folder `/G` that is neither `/F` nor a folder containing it, **Then** the panel is not refreshed
   (no extra listing).
3. **Given** a panel at `127.0.0.1:/F`, **When** the change is made under `127.0.0.1` itself,
   **Then** the panel is refreshed as before (unchanged behaviour).

---

### User Story 2 - A folder entered later is listed again, not taken from the stale cache (Priority: P2)

The FTP plug-in keeps listings of visited folders (the listing cache, on by default). After a
change made through another name of the server, a folder visited earlier under the panel's name is
not shown from that cache: the next time the user enters it, it is listed again ("the next use
lists it again", the item's *Expected*).

**Why this priority**: the same stale display, reached one step later (measured at HEAD: row
CACHE-ALIAS).

**Independent Test**: probe row CACHE-ALIAS: the panel lists `/C/sub`, goes up to `/C`, an upload
typed to `localhost` stores `sub/n.txt`, Enter on `sub`: the panel's connection lists `sub` again.

**Acceptance Scenarios**:

1. **Given** a cached listing of `127.0.0.1:/C/sub`, **When** a change in `/C/sub` is made through
   `localhost` (same user and port), **Then** the cached listing is dropped and entering `sub`
   lists it on the server.
2. **Given** the same under `127.0.0.1` itself, **Then** behaviour is unchanged (row CACHE-SAME).

### Edge Cases

- FTP and FTPS: a notification about either scheme already applies to both for the same name; the
  same holds under another name.
- A different user or a different port is not "another name of the server" in the item's sense:
  such panels and cached listings keep today's behaviour (Assumption below).
- Two unrelated servers with the same user and port (e.g. anonymous on 21) and the same folder: a
  change on one also refreshes a panel at that folder on the other (one extra listing; the client
  cannot tell names of one server from two servers - feature 341's rule).
- A panel at a parent folder of the changed one is not refreshed (as for its own name); only the
  changed folder and, when the change includes subfolders, the folders below it.
- Under another host name a panel whose connection is closed is not refreshed (no reconnect
  question); its caches are dropped, so its next use lists the folder again.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A change-on-path notification for an FTP / FTPS path MUST refresh every FTP panel
  whose connection has the same user and port and whose path the notification covers (the same
  path rule as today), also when the host name differs from the notified one - except a panel of
  another host whose connection is closed (FR-003).
- **FR-002**: The refresh for a panel under another host name MUST use the same timing as today's
  refresh under the same name (soft refresh: now when the main window is active, else on its
  activation; otherwise the delayed refresh).
- **FR-003**: Under another host name a panel whose connection is closed (e.g. keep-alive ended)
  MUST NOT be refreshed - no reconnect question and no new login for a change that may have been
  made on another server; its caches of the path are dropped (FR-004, FR-007), so its next refresh
  or entering the path lists it again (the "outdated" mark of the item; review 1).
- **FR-004**: A change-on-path notification MUST drop the plug-in's cached listings of the notified
  path (and subpaths when the notification includes subfolders) also for every other host with the
  same user and port.
- **FR-005**: Panels and cached listings with another user or another port, and panels whose path
  the notification does not cover, MUST keep today's behaviour.
- **FR-006**: The rule "same user, same port, any host" MUST be one decision, testable without the GUI: its
  user / port part is used by every site (panel refresh, viewer cache, listing cache), its host
  verdict where the host matters (panel refresh and viewer cache: same name vs another name).
- **FR-007**: A change-on-path notification MUST also drop the files downloaded for viewing under
  the notified path for every open FTP connection (panel or detached) with the same user and port
  and another host, so that viewing a changed file again downloads it (found while reading:
  the viewer cache is keyed by the name as typed, like the listing cache; severity 4, fixed here
  by stop-rules rule 11).
### Key Entities

- **Connection root**: user, host, port of an FTP path (`//user@host:port`); the password is never
  part of the comparison.
- **Change-on-path notification**: a path and "including subfolders", sent after an operation
  changed the server.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe row REFRESH-ALIAS passes (FAIL at 2ce004b9): the panel lists its folder again
  after an upload through another name.
- **SC-002**: Probe row CACHE-ALIAS passes (FAIL at 2ce004b9).
- **SC-003**: Control rows REFRESH-SAME, CACHE-SAME and the path rule row REFRESH-ELSE stay PASS;
  feature 341's probe (`ftp341_probe.ps1`) stays 12 / 0; row REFRESH-CLOSED (review 1) passes: no
  reconnect question and no new login for a panel of another host whose connection is closed.
- **SC-005**: Probe row VIEW-ALIAS passes: a file viewed under one name is downloaded again
  after a change under another name (VIEW-SAME control stays PASS).
- **SC-004**: the shared decision has `saltests` checks (same / other host, other user, anonymous,
  other port, default port 21); the password is split off in `FTPRootPathMatch`, which saltests
  cannot link (the probe's uploads carry `u:p@`).

## Assumptions

- Assumption (autonomous run): "another name of its server" = another host name with the same
  user and port, as the item's *Expected* says; another user or port of a server (feature 345's
  wider rule for the upload cache) is not refreshed - the item names only the host, and its *Notes*
  weigh the cost of extra listings (§1 step 2: item).
- Assumption (autonomous run): the item's two options ("refreshes the panel, or marks its listing
  outdated") - the refresh is chosen for panels showing the changed folder (the same mechanism and
  cost as a change under the panel's own name: at most one listing per panel showing that folder);
  for cached listings of folders not shown, dropping them is the "outdated mark" (no listing until
  the next use).
- The plug-in interface, the registry and the network behaviour (beyond the extra listing of a
  refreshed panel) do not change; no UI strings change.
