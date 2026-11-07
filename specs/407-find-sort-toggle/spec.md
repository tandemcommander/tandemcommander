# Feature Specification: Find - a second sort by the same result column reverses the order

**Feature Branch**: `407-find-sort-toggle`
**Created**: 2026-11-07
**Status**: Draft
**Input**: Backlog item `nefunkcni-prepinani-razeni-vysledku-hledani` - "Find: clicking a result column again does not reverse the sort order" (GitHub issue #23). From backlog item nefunkcni-prepinani-razeni-vysledku-hledani.

## Background (measured at 1549e06a)

In *Find Files and Directories* (Ctrl+F) the results can be sorted by Name, Path, Size, Date and
Time: by a click on the column header, by the View menu (Name / Path / Date / Size) and by
Ctrl+F3 / Ctrl+F4 / Ctrl+F5 / Ctrl+F6 in the list. Every route sorts ascending and remembers
nothing, so a second request on the same column re-sorts the same order and "nothing happens".
The header never shows which column is sorted. Folders always come before files, so in a date
sort the oldest file comes after the newest folder - in the reporter's words, the 2006-2016 list
"starts at 2015".

Hidden-desktop probe `probe/find_sort_probe.ps1` on the build of HEAD (folders dB 2008 and dA 2014,
files fC.txt 2006, fA.txt 2010, fD.txt 2012, fB.txt 2016): View > Date once -> dB, dA, fC, fA, fD,
fB; a second and third time -> the same; two clicks on the Date header -> the same; two clicks on
Size -> ascending both times; no header item ever has a sort arrow. 6 / 6 rows FAIL.

The panel is the model the item names. Its View menu commands toggle the direction when the same
column is chosen again; folders stay grouped before files in both directions and each group is
reversed when the order is descending (`ChangeSortType`, `SortFilesAndDirectories`).

## Clarifications

### Session 2026-11-07

- Q: In descending order, do folders stay grouped before files, or is the list sorted purely by the column? → A: Folders stay grouped before files in both directions; inside each group the order is reversed, as in the panel (autonomous run: item - "Directories and files are treated as for the panel")
- Q: Do the View menu commands and Ctrl+F3 / F4 / F5 / F6 toggle the direction too, or only the header click? → A: They toggle too: every user request to sort by a column follows the same rule, as the panel's View menu does (autonomous run: item - "as for the panel")
- Q: Does the first sort by Date or Time follow the panel's option "Newer items on top", and does the folder sort follow "Sort folders by name"? → A: No - the first request on any column sorts ascending (oldest first for Date and Time), as the item's *Expected* says; the panel's options stay panel options (autonomous run: item, conservative)
- Q: What does "Hide duplicate names", which sorts by path internally, do to the remembered sort? → A: It sorts by path ascending as before (never toggles) and the header then shows Path ascending (autonomous run: conservative - its result is unchanged)
- Q: When is the remembered sort forgotten? → A: When a new search starts (Find, Find duplicates, Intersect, Subtract, Append): the list is then in search order again and no column shows an arrow (autonomous run: conservative - an arrow must not claim an order the list no longer has)
- Q: In duplicate-search mode, do the columns that can sort (Name and Size, when the search was by name and size) toggle too? → A: Yes; the whole duplicates order is reversed, so the members of each duplicate group stay together. The columns duplicate mode cannot sort by still do nothing and leave the arrow as it was (autonomous run: item - "keeps its restrictions")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reverse the order with a second click (Priority: P1)

A user searches, clicks the Date header and sees the results oldest first; a second click shows
them newest first, a third click oldest first again. A click on another column sorts by that
column ascending.

**Why this priority**: it is the reported defect - without it there is no descending order at all.

**Independent Test**: probe rows `menu-time`, `click-date`, `click-other`, `click-size`.

**Acceptance Scenarios**:

1. **Given** search results not sorted yet, **When** the user clicks the Date header, **Then** the
   results are sorted by date ascending (folders first, each group oldest first).
2. **Given** results sorted by Date ascending, **When** the user clicks the Date header again,
   **Then** they are sorted by date descending (folders first, each group newest first).
3. **Given** results sorted by Date descending, **When** the user clicks the Name header, **Then**
   they are sorted by name ascending.
4. **Given** results sorted by Date ascending, **When** the user chooses View > Date (or presses
   Ctrl+F5 in the list), **Then** the order is reversed exactly as by a header click.

---

### User Story 2 - See which column is sorted and how (Priority: P2)

The column the results are sorted by shows the standard sort arrow of Windows lists: up for
ascending, down for descending; no other column shows an arrow.

**Why this priority**: without it the user cannot tell which direction the second click chose.

**Independent Test**: the arrow columns of every probe row.

**Acceptance Scenarios**:

1. **Given** results sorted by Size ascending, **Then** only the Size header shows an up arrow.
2. **Given** results sorted descending by Date, **When** a new search starts, **Then** no header
   shows an arrow, and the next sort by Date is ascending.

---

### User Story 3 - Duplicate search keeps its rules (Priority: P3)

After *Find duplicates*, the columns that duplicate mode cannot sort by still do nothing; the ones
it can sort by toggle and keep each duplicate group together.

**Why this priority**: an existing restriction that must not break.

**Independent Test**: `saltests` checks of the column rule and of the reversed duplicates order.

**Acceptance Scenarios**:

1. **Given** duplicates found by name and size, **When** the user clicks the Path header, **Then**
   nothing changes (order and arrow).
2. **Given** duplicates found by name and size, sorted by Name, **When** the user clicks Name
   again, **Then** the groups are listed in reverse name order and each group's files stay together.

### Edge Cases

- A click on the Attributes header: sorting by attributes is not supported; nothing changes.
- An empty result list: nothing to sort, the request changes nothing visible.
- A sort requested while the search still runs: the items found so far are sorted; items found
  later are appended (as before); the next request on the same column reverses all of them.
- Items with equal sort keys: ordered by the other columns (name, path, size, date), all reversed in
  the descending order, so the order is the exact reverse within each group.
- Selection and focus survive a sort, as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The result list MUST remember the column it was last sorted by and the direction.
- **FR-002**: A user request to sort by a column (header click, View menu, Ctrl+F3 / F4 / F5 / F6)
  MUST sort ascending when the column differs from the remembered one (or none is remembered), and
  reverse the remembered direction when it is the same column.
- **FR-003**: Folders MUST stay grouped before files in both directions; inside each group the
  column order (with its tie-breaking columns) MUST be reversed in the descending direction.
- **FR-004**: The header item of the sorted column MUST show the up arrow (ascending) or the down
  arrow (descending); every other header item MUST show none.
- **FR-005**: A new search of any kind MUST forget the remembered sort and clear every arrow.
- **FR-006**: Columns that cannot sort (Attributes always; Path, Date and Time in duplicate mode;
  Name and Size in duplicate mode unless the search was by both name and size) MUST change neither
  the order, nor the remembered sort, nor the arrows.
- **FR-007**: In duplicate mode, a descending order MUST keep the members of each duplicate group
  together and the alternating group shading by group.
- **FR-008**: "Hide duplicate names" MUST keep removing exactly the same items as before (it sorts
  by path ascending, never toggles); the header then shows Path ascending.
- **FR-009**: The rules of FR-002, FR-003, FR-004 and FR-006 MUST be pure functions in a header
  under `src/common/` covered by `saltests` checks.

### Key Entities

- **Sort state of the result list**: the sorted column (or none) and the direction.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, a second request on the same column reverses the order on both routes
  (header click and View menu); a third restores the first order - 6 / 6 rows PASS (from 0 / 6).
- **SC-002**: The sorted column shows its arrow in 100 % of the probe's steps, every other column
  none.
- **SC-003**: Every new `saltests` check passes, and a negative control (the toggle switched off)
  makes them fail.

## Assumptions

- Assumption (autonomous run): The Time column keeps comparing the whole date and time, as the Date
  column (unchanged).
- Assumption (autonomous run): The header arrow is the standard one of Windows list headers; no
  new strings, menus or dialogs are added, so no translation work is needed.
- Assumption (autonomous run): The Registry Editor plug-in has its own Find window with the same
  limitation; it is not part of this item (the item names the core Find only).
