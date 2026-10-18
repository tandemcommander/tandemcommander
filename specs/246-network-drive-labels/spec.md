# Feature Specification: Network drive names and disconnected-drive icons

**Feature Branch**: `246-network-drive-labels`
**Created**: 2026-10-18
**Status**: Draft
**Input**: User description (Czech, summarised): "Based on the context and the initial
report, analyse the program's behaviour in great detail with several independent agents,
find the cause, design and implement a fix, and test everything in great detail."
The initial report (a user, relayed by the maintainer): "Another defect that was in Altap
Salamander too: Tandem Commander does not show the names of network drives. In Windows a
network drive (added over SMB, a Samba server) has a name like local drives, e.g.
'Archiv', but Tandem Commander shows the path instead, e.g. '\\SHARE_SAMBA\Share\Storage'.
Also the icons of these drives do not change to the disconnected-drive icon when the drive
is disconnected. Can this be fixed?"

The evidence behind every statement about today's product is in
[analysis.md](analysis.md) (file:line references, live measurement on Windows 11).

## Current behaviour (baseline, the 0.1.10 tree)

- The Change Drive menu (Alt+F1 / Alt+F2) and the drive bar tooltip show a mapped network
  drive as its network path only. The name the user sees in Explorer is never read.
- In Explorer, a mapped drive has a name of its own only when the user renamed it (or an
  administrator's policy named it); otherwise Explorer shows the last part of the network
  path followed by the rest of the path. The name is stored per network path, survives
  reconnecting, and applies to whatever letter the path is mapped to. The server's volume
  label is not used by Explorer.
- A remembered network drive whose connection Windows could not restore ("Unavailable" in
  `net use`, a red cross in Explorer) gets the disconnected icon **in the Change Drive
  menu**, which is rebuilt at every opening. **The drive bar** keeps the icon it had when it
  was last built: its change detection cannot see a remembered drive changing between
  connected and unavailable, so the icon stays wrong until something else rebuilds the bar.
- A drive letter that Windows still lists, whose connection Windows reports as unavailable
  or disconnected, is always shown as connected (menu and bar). This state could not be
  produced on the test machine; Windows reports it through the same connection-status
  queries Explorer's state is based on.
- Picking a disconnected drive in the menu or bar reconnects it using the path text shown
  in the menu; a share name containing `&` is reconnected under a wrong name (the menu's
  doubled `&` reaches the reconnection), and a very long path can be cut.

## Clarifications

### Session 2026-10-18 (autonomous — the maintainer delegated the decisions)

The maintainer asked for the whole flow to run autonomously while away from the machine;
each question was decided by the agent on the evidence, and the decision is recorded here
for the maintainer's review.

- Q: How should a drive with a Windows name be shown — the name alone, the name with the
  path, or the name in one column and the path in another? → A: **The name followed by the
  path in parentheses**, in the name column of the Change Drive menu and in the drive bar
  tooltip (e.g. `Archiv (\\SHARE_SAMBA\Share\Storage)`). The path stays visible (users of
  a two-panel file manager rely on it, and two drives may have the same name); the third
  column keeps its meaning (free space of local drives) and its width. A drive without a
  name of its own keeps today's text exactly (the path only) — no change for users who
  never named a drive.
- Q: Which name — Explorer's own text (including its default form for unnamed drives),
  the user-given name, or the server's volume label? → A: **The user-given (or
  policy-given) name only**, read where Explorer keeps it, without contacting the server.
  Explorer's default form is only a reformatting of the path (showing it would change
  every user's menu without adding information); the server's volume label is not what
  Explorer shows and would need a network round trip per drive.
- Q: When should a drive count as disconnected, and when should the drive bar catch up? →
  A: A network drive counts as disconnected when its letter is missing (today's rule) **or**
  Windows reports its connection as unavailable or disconnected — both answers Windows
  gives locally, without contacting the server. The drive bars are rebuilt whenever the set
  of disconnected network drives changes, checked at the moments the bars are already
  checked (opening and closing the Change Drive menu, refresh) and additionally when
  Tandem Commander's window is activated. No periodic polling.
- Q: Does this need an option (Principle II: user-facing changes opt-in)? → A: No. It
  corrects a defect (a wrong icon, a missing name that Windows shows everywhere else)
  without removing information: the path stays visible and unnamed drives look exactly as
  before. Recorded as the justification under Principle II.
- Q: Should the drive bar tooltip read the drive's Windows name when it is shown, or use
  the name captured when the bar was last built? → A: **When it is shown** — a cheap local
  read, so a rename in Explorer appears in the tooltip without waiting for a bar rebuild.
- Q: Should a disconnected network drive also be marked in the menu text (e.g.
  "(disconnected)") or only by its icon? → A: **Icon only**, as in Explorer — no new UI
  text, and the item text of a drive does not depend on its connection state.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recognise a named network drive (Priority: P1)

A user mapped a network share to a drive letter and gave it a name in Explorer (or the
company's policy did). When choosing a drive in Tandem Commander, the user sees that name
next to the path and can pick the drive by the name they know.

**Why this priority**: It is the first and most visible part of the report; without it the
user must remember which path belongs to which named drive.

**Independent Test**: Map a share, rename the drive in Explorer, open the Change Drive menu
and hover the drive bar button — the name and the path are shown.

**Acceptance Scenarios**:

1. **Given** a mapped drive Z: to `\\server\share\Storage` that Explorer shows as
   "Archiv", **When** the user opens the Change Drive menu, **Then** the Z: item reads
   `Archiv (\\server\share\Storage)`.
2. **Given** the same drive, **When** the user hovers its drive bar button, **Then** the
   tooltip reads `Archiv (\\server\share\Storage)`.
3. **Given** a mapped drive that was never named, **When** the menu opens, **Then** the item
   reads exactly as today (the path only).
4. **Given** a named drive whose connection is currently unavailable, **When** the menu
   opens, **Then** the name is still shown (Explorer keeps it too) and no network access
   delays the menu.
5. **Given** a name with characters outside the system code page (e.g. `ž`, `Ж`, `中`) or
   with `&`, **When** the menu opens, **Then** the name is shown exactly as in Explorer.
6. **Given** the user renames the drive in Explorer while Tandem Commander runs, **When**
   the menu is opened again or the drive bar tooltip appears again, **Then** the new name
   is shown.

---

### User Story 2 - See at a glance that a network drive is disconnected (Priority: P1)

A user's network drive becomes unavailable (the server or the network is down, or Windows
could not restore it at logon). In the drive bar and the Change Drive menu its icon is the
disconnected-drive icon, as in Explorer, and changes back when the drive is connected
again.

**Why this priority**: It is the second half of the report; a wrong icon makes the user try
a drive that cannot answer, or avoid one that works.

**Independent Test**: With the drive bar visible, switch a remembered mapping between
connected and unavailable; activate Tandem Commander's window — the drive bar icon
follows; open the Change Drive menu — the icon matches.

**Acceptance Scenarios**:

1. **Given** a remembered mapping shown as connected in the drive bar, **When** its
   connection becomes unavailable and the user activates Tandem Commander's window (or
   opens the Change Drive menu, or refreshes), **Then** the drive bar shows the
   disconnected icon.
2. **Given** a drive shown as disconnected, **When** it is connected again (by Explorer,
   `net use`, or by Tandem Commander itself) and the user returns to Tandem Commander,
   **Then** the drive bar shows the connected icon.
3. **Given** a drive letter that Windows still lists but whose connection Windows reports
   as unavailable or disconnected, **When** the menu or the bar is built, **Then** the drive
   has the disconnected icon.
4. **Given** both drive bars are shown, **When** the state changes, **Then** both show the
   same icon.
5. **Given** no network drive changed state, **When** the window is activated, **Then** the
   drive bars are not rebuilt (no flicker, no work beyond the local status query).

---

### User Story 3 - Reconnect a disconnected drive reliably (Priority: P2)

A user picks a disconnected network drive in the menu or the drive bar. Tandem Commander
reconnects it with its real network path — also when the share's name contains `&`, the
path is long, or the menu shows a name instead of the path.

**Why this priority**: Showing names must not break reconnection (today it depends on the
displayed text); the `&` defect sits in the same place.

**Independent Test**: Make a remembered mapping to a share whose path contains `&`
unavailable, pick it in the menu — it reconnects and the panel shows its contents.

**Acceptance Scenarios**:

1. **Given** a named, remembered, unavailable drive, **When** the user picks it, **Then**
   it reconnects to its network path (not to its name) and the panel lists it.
2. **Given** a remembered, unavailable drive mapped to a path with `&`, **When** the user
   picks it, **Then** it reconnects to the exact path.
3. **Given** a drive whose letter Windows still lists but which is reported disconnected,
   **When** the user picks it, **Then** the panel changes to it and the existing
   reconnection on access applies (no error about the letter being in use).

### Edge Cases

- The name stored by Explorer is empty or only spaces → treated as no name (path only).
- The name contains a tab, line break or other control character → shown with spaces in
  their place; the menu's columns stay intact.
- The name equals the path (case-insensitively) → the path is shown once.
- The network path cannot be obtained → the item reads as today, without a name.
- The path ends with a backslash or differs in letter case from the stored name's key →
  the name is still found (Explorer finds it too).
- A path containing `#` → looked up exactly as Explorer stores it.
- Names and paths are never cut: a long name with a long path is shown whole.
- A drive mapped to a WebDAV or other non-SMB network location → same rules (name if
  Explorer has one; icon from Windows' connection status).
- No network or the network provider reports an error while the window is activated → no
  message box appears on activation (the existing message on opening the menu stays).
- A SUBST drive pointing to a network path keeps today's text.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: For a mapped network drive that has a user- or policy-given name in Windows,
  the Change Drive menu MUST show the name followed by the network path in parentheses in
  the item's name column.
- **FR-002**: The drive bar tooltip of such a drive MUST show the same text, with the name
  as it is at the moment the tooltip appears.
- **FR-003**: A drive without such a name MUST be shown exactly as before the change.
- **FR-004**: The name MUST be read without contacting the server, also for a drive whose
  connection is unavailable; obtaining it MUST NOT add a noticeable delay to opening the
  menu or building the drive bar.
- **FR-005**: The name and the path MUST be shown exactly (any Unicode character, `&`
  shown literally), never cut; control characters in the name are replaced with spaces;
  an empty or blank name counts as none; a name equal to the path is not repeated.
- **FR-006**: A network drive MUST be shown with the disconnected icon when its letter is
  missing from the drives Windows lists (as today) or when Windows reports its connection
  as unavailable or disconnected; otherwise with the connected icon. The connection state
  changes only the icon, never the item's text.
- **FR-007**: The drive bars MUST be rebuilt when the set of disconnected network drives
  changes, detected when the Change Drive menu opens or closes, on refresh, and when
  Tandem Commander's main window is activated; both drive bars MUST agree.
- **FR-008**: The check on window activation MUST NOT show any message box and MUST NOT
  rebuild the bars when nothing changed.
- **FR-009**: Reconnecting a disconnected drive picked in the menu or bar MUST use the
  drive's real network path as Windows records it — not the displayed text — so that
  names, `&` in paths and long paths reconnect correctly.
- **FR-010**: Picking a drive whose letter Windows still lists but which is reported
  disconnected MUST open it through the existing reconnection on access, without an error.
- **FR-011**: Local, removable, optical and RAM drives, cloud storages, plug-in items and
  hot paths MUST be shown exactly as before.
- **FR-012**: The pure rules (where the name is kept for a given path, how the shown text
  is composed, when a drive counts as disconnected) MUST be covered by automated checks.

### Key Entities

- **Mapped network drive**: a drive letter, its network path as Windows records it,
  whether Windows remembers it, its connection status.
- **Windows drive name**: a per-user, per-network-path name given in Explorer or by policy;
  independent of the letter.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For 100% of named mapped drives in the test matrix (ASCII, Czech diacritics,
  Cyrillic, CJK, `&`, `#`, long path, renamed while running), the menu and the tooltip show
  the name and the path exactly as specified.
- **SC-002**: 100% of unnamed mapped drives and of all other drive kinds show the same text
  as the 0.1.10 build (byte-identical menu text).
- **SC-003**: After a remembered drive changes between connected and unavailable, the drive
  bar shows the right icon at the next window activation in 100% of the test runs (today:
  0%, negative control).
- **SC-004**: Opening the Change Drive menu with four network drives (connected, unavailable
  and unreachable among them) takes no longer than with the 0.1.10 build plus 50 ms.
- **SC-005**: A remembered, unavailable drive whose path contains `&` reconnects when picked
  in 100% of the runs (today: fails).
- **SC-006**: No message box appears on window activation in any test scenario.

## Assumptions

- The reporter's "Archiv" is a name given in Explorer (or by policy); the share path ends
  in "Storage". If the reporter's server supplies the name some other way, the feature does
  not show it — to be confirmed with the reporter after the release.
- The state "letter listed, connection reported disconnected" is handled by Windows'
  connection status; it could not be produced on the test machine and is a step owed to a
  person with a real network server (switch the server off with a drive mapped).
- Windows sends no notification when a server becomes unreachable; activation of the
  window is the moment the user looks at the bar again, so it is the check point. A drive
  that changes state while the user keeps working in Tandem Commander is updated at the
  next menu opening, refresh or activation.
- The Disconnect dialog, the Drive Information dialog and the panel's path line keep their
  current texts (out of scope).
- The remaining code-page texts of the drive list are the backlog item
  `drive-list-code-page-texts`; this feature makes only the network drive texts it touches
  Unicode-exact.
