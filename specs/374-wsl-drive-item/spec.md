# Feature Specification: The Change Drive menu and the drive bar offer the WSL distributions

**Feature Branch**: `374-wsl-drive-item`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item change-drive-menu-and-drive-bar-have-no-wsl-item-for-the (backlog/items/change-drive-menu-and-drive-bar-have-no-wsl-item-for-the/desc.md) - implement exactly what it describes." From backlog item change-drive-menu-and-drive-bar-have-no-wsl-item-for-the.

## Background

The Change Drive menu (Alt+F1 / Alt+F2) and the drive bar list the drives, Documents, the
cloud storages (Google Drive, Dropbox, OneDrive) and Network. A user who works with WSL
(Windows Subsystem for Linux) has no entry that leads to the Linux file systems, which File
Explorer shows under its *Linux* node (`\\wsl.localhost\<distribution>`); the user has to
type the path in Change Directory.

Measured at `30268b7c` (by reading the code and on this computer):

- The list builder adds Documents, the cloud storages, Network, plug-in items and hot paths;
  no WSL entry. The only WSL references in the core are feature 372 (background path check)
  and feature 373 (`\\wsl.localhost` offers the distributions as the share list).
- WSL registers each distribution per user in the registry (current user's
  `Software\Microsoft\Windows\CurrentVersion\Lxss\{GUID}`, value `DistributionName`,
  `State` 1 = installed). This computer: `docker-desktop` and `Ubuntu` (WSL 2), none running;
  reading the key does not start WSL.
- The Windows WSL launcher (`System32\wsl.exe`) carries the Tux icon as its first icon
  resource - readable as a resource without running the program.
- OneDrive gives the pattern for several targets: one menu item per storage
  (`OneDrive - <name>`), and on the drive bar one button, or one drop-down button when there
  is more than one storage.

## Clarifications

### Session 2026-11-01

- Q: One entry that opens `\\wsl.localhost` (the share list of 373), or one entry per distribution? → A: One entry per distribution in the Change Drive menu, opening `\\wsl.localhost\<distribution>` directly; on the drive bar one button for a single distribution and one drop-down button listing the distributions when there are several - the OneDrive pattern (autonomous run: item - its *Evidence* names the OneDrive pattern and *Expected* allows "or the chosen distribution"; one step less than a share menu).
- Q: Which distributions are listed - also helper distributions such as `docker-desktop`? → A: Every installed distribution the registry lists, as File Explorer's *Linux* node and the share list of 373 do (autonomous run: conservative - no guessing which distribution is "real").
- Q: What do the entries say? → A: `Linux - <distribution>` (a new text "Linux", the name File Explorer uses), in the style of `OneDrive - <name>`; the drive bar's drop-down button's tooltip is "Linux" (autonomous run: conservative - existing pattern).
- Q: Where do they stand in the list? → A: After the cloud storages, before Network (autonomous run: conservative - with the other "places", the Network item keeps its place last).
- Q: Does the Network option or the "no Network Neighborhood" policy also hide the WSL items? → A: No - only the new WSL option hides them; WSL is a local subsystem, not the network neighbourhood (autonomous run: conservative - the existing options keep exactly their meaning).
- Q: How many distributions can be listed? → A: All usable ones (in practice a handful); the drive bar always holds a single WSL button, so its width does not grow with the count (autonomous run: item - the OneDrive pattern).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a WSL distribution from the Change Drive menu (Priority: P1)

A user with WSL presses Alt+F1, sees `Linux - Ubuntu` (and one item per other installed
distribution) with the penguin icon, picks it, and the left panel shows
`\\wsl.localhost\Ubuntu`.

**Why this priority**: it is what the item asks for.

**Independent Test**: on a computer with at least one distribution, the menu built for
Alt+F1 contains one WSL item per installed distribution; choosing one changes the panel's
path to `\\wsl.localhost\<distribution>`.

**Acceptance Scenarios**:

1. **Given** WSL with the distributions `docker-desktop` and `Ubuntu`, **When** the user opens
   Alt+F1, **Then** the menu holds `Linux - docker-desktop` and `Linux - Ubuntu` (sorted by
   name), between the cloud storages and Network, each with an icon.
2. **Given** that menu, **When** the user chooses `Linux - Ubuntu`, **Then** the panel opens
   `\\wsl.localhost\Ubuntu`.
3. **Given** the panel shows `\\wsl.localhost\Ubuntu\home`, **When** the user opens Alt+F1,
   **Then** the item `Linux - Ubuntu` is the checked (current) item.

---

### User Story 2 - Open a distribution from the drive bar (Priority: P2)

The drive bar shows a penguin button: with one distribution it opens it at once; with
several it drops down a menu of the distributions.

**Why this priority**: the item names the drive bar too; same targets, second surface.

**Independent Test**: show the drive bar(s); the bar holds one WSL button; its tooltip and
its action match the number of distributions.

**Acceptance Scenarios**:

1. **Given** two distributions, **When** the drive bar is shown, **Then** it holds one
   drop-down button with the tooltip "Linux"; choosing a distribution in its menu opens it in
   the bar's panel.
2. **Given** one distribution, **When** the drive bar is shown, **Then** its button's tooltip is
   `Linux - <distribution>` and a click opens it.

---

### User Story 3 - Hide the entry, or no WSL at all (Priority: P2)

A user who does not want the entry turns it off on the *Change Drive Menu and Drive Bar*
page of the configuration; a computer without WSL never shows it.

**Why this priority**: the item requires the option and the absence without WSL.

**Independent Test**: turn the option off - no WSL item in the menu or bar; the option is
saved, loaded and imported from an older configuration like the Network option.

**Acceptance Scenarios**:

1. **Given** the option *Linux Distributions (WSL)* is off, **When** Alt+F1 opens, **Then** no
   WSL item is listed and no registry lookup for WSL is made.
2. **Given** no distribution is registered (no key, an empty key, or only distributions that
   are being installed or removed), **When** Alt+F1 opens, **Then** no WSL item is listed.
3. **Given** the option was turned off and the program restarted, **Then** it is still off;
   an exported configuration imported into a fresh one carries it.

### Edge Cases

- A distribution name that cannot form a path (empty, contains `\`, `/`, `:`, control
  characters, or the path would not fit) is left out of the list - never cut or changed.
- A distribution removed or renamed after the list was built: choosing its item tries the old
  path and shows the ordinary "path not found" error; the next Alt+F1 shows the new list and
  the drive bar is rebuilt when the set of distributions changes.
- Building the list never starts WSL or its virtual machine (it reads the registry and an
  icon resource only); opening a distribution starts it as File Explorer does.
- A non-ASCII distribution name is kept whole (UTF-8 in the program, wide toward Windows).
- The icon cannot be read (no `wsl.exe`): the entry uses the network icon instead.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the WSL option is on and at least one installed distribution is registered
  for the current user, the Change Drive menu MUST list one item `Linux - <distribution>` per
  usable distribution, sorted by name (the file system's case-insensitive order), after the
  cloud storages and before Network.
- **FR-002**: Choosing such an item MUST change the panel's path to
  `\\wsl.localhost\<distribution>` (the ordinary disk path change, with its errors).
- **FR-003**: The drive bar(s) MUST show one WSL button: for a single distribution a button
  opening it (tooltip `Linux - <distribution>`); for several a drop-down button (tooltip
  "Linux") whose menu lists the distributions and opens the chosen one in the bar's panel.
- **FR-004**: The list of distributions MUST be read from the registry only; building the menu
  or the drive bar MUST NOT start WSL, its service's distributions or its virtual machine,
  and MUST NOT add a noticeable delay (the time to build the Alt+F1 list grows by less than
  10 ms).
- **FR-005**: A distribution is usable when its name is non-empty, holds no `\`, `/`, `:`,
  `*`, `?`, `"`, `<`, `>`, `|` or control character, and the path fits; a registered entry
  whose `State` is present and not "installed" is left out.
- **FR-006**: When the panel's path is on a distribution (`\\wsl.localhost\<d>` or
  `\\wsl$\<d>`, with or without a deeper folder), its item MUST be the current (checked)
  item of the menu, as a drive is.
- **FR-007**: A new option *Linux Distributions (WSL)* on the Change Drive configuration page
  (on by default) MUST hide all WSL entries when off (it is the only setting that hides them:
  the Network option and the no-Network-Neighborhood policy do not); it MUST be saved and loaded with the
  configuration and imported from an exported configuration, like the Network option.
- **FR-008**: The drive bars MUST be rebuilt when the set of distributions changed since they
  were built (checked when the Change Drive menu opens, as for the cloud storages).
- **FR-009**: The new texts (the item label "Linux" and the checkbox) MUST be translated into
  every enabled language (two-stage `.slt` refresh).
- **FR-010**: The existing items, their order, their numbers in the probe dump and their
  behaviour MUST be unchanged.

### Key Entities

- **WSL distribution**: a name registered by WSL for the current user, with an install state;
  forms the path `\\wsl.localhost\<name>`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On this computer (docker-desktop, Ubuntu) Alt+F1 lists exactly the two WSL items;
  choosing `Linux - Ubuntu` shows `\\wsl.localhost\Ubuntu` in the panel.
- **SC-002**: With the option off, or with no distribution registered, the list holds no WSL
  item (0 items).
- **SC-003**: No distribution is running after the menu and the drive bar were built (none ran
  before).
- **SC-004**: The Alt+F1 list build takes less than 10 ms longer than before (median of
  repeated builds, before / after).
- **SC-005**: The option survives a restart and an import.

## Assumptions

- Assumption (autonomous run): Windows 11 provides `\\wsl.localhost` (the project's minimum);
  the older alias `\\wsl$` is recognised for the checked item only.
- Assumption (autonomous run): the per-user registry key is the source File Explorer's node
  also reflects; distributions of other users are not shown (they are not reachable as this
  user either).
- Assumption (autonomous run): items carry no hot key (as the cloud storages), and they have
  no context menu (as the cloud storages and Network).
- Assumption (autonomous run): the configuration value is a new value under the existing
  configuration key, as the other Change Drive options (no layout change).
