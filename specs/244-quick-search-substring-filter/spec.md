# Feature Specification: Quick search that finds text anywhere in a name and filters the panel

**Feature Branch**: `244-quick-search-substring-filter`
**Created**: 2026-10-17
**Status**: Draft
**Input**: User description (Czech, summarised): "Change how the user finds an
item in the current directory by typing. Today typing finds an item whose
name *starts* with the typed text, so an item that has the text *inside* its
name cannot be found that way. Analyse it in detail and implement this: as the
user types, the item is still found and focused from the start of the name as
before, but every item that contains the text anywhere in its name is taken
into account too — e.g. a folder `2024_chatbot` is found when the user types
`chat` and nothing starts with `chat`. The program must clearly but lightly
show (a colour difference) that a search is running. As the user types, the
items that do not match are hidden, so the panel shows only the items that
match by prefix and then by substring. The user moves to an item with the
Up/Down arrows and opens it (e.g. enters a directory). Esc cancels the search
as it does now."

## Clarifications

### Session 2026-10-17

- Q: What happens when the user starts a command on items (copy, move, delete, pack …) while the panel is filtered and some selected items are hidden? → A: The filter and the search stay; the command acts only on the visible items; hidden items are never touched, keep their selection and show again after the search ends.
- Q: Is the new behaviour on by default, given Constitution II ("user-facing behaviour changes MUST be opt-in")? → A: On by default, with a Configuration option that returns to the prefix-only search without hiding; this is a deliberate, documented exception to Principle II (see *Constitution note*).

## Current behaviour (baseline, read from the 0.1.10 tree)

This is what the feature changes; it was read from the code of the release
tree and is to be confirmed on the build before the fix (*measure first*).

- Typing a printable character in the active panel starts *quick search*
  (or Alt+character, when the setting *Quick search starts with Alt+letter*
  is on; plain typing then goes to the command line). A thin caret is drawn
  inside the focused item's name, after the part that matched.
- An item matches when its name **starts with** the typed text (case is
  ignored; characters written differently but canonically equal match, e.g.
  composed and decomposed accented letters). The characters `/`, `\` and `<`
  stand for "any run of characters", so typing `/chat` already finds
  `2024_chatbot` today — but few users know it, and nothing on screen says so.
- A typed character that would leave **no** item matching is silently
  ignored: the typed text never grows past the last match.
- All items stay visible. Up/Down/PgUp/PgDn/Home/End jump only between
  matching items; Shift with them selects; Alt with them jumps between
  matching *selected* items. Left shortens the typed text, Right extends it
  with the next character of the focused name, Backspace deletes the last
  typed character (the search stays on with empty text). Space is part of
  the text (it does not select while searching).
- The search ends with Esc, with Insert (which then selects), when the
  directory changes, and when almost any command runs (copy, delete, view,
  panel switch, menu commands …); it survives a refresh of the listing.
- The typed text itself is not shown anywhere; the only sign of the search is
  the caret inside the focused name. The panel looks otherwise the same.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find an item by a word inside its name (Priority: P1)

The user knows a part of a name that is not its beginning (`chat` of
`2024_chatbot`, `invoice` of `2025-03 invoice ACME.pdf`, `pdf` of every PDF
file). They type it in the panel and the focus lands on an item that contains
it, without knowing or typing any wildcard.

**Why this priority**: This is the defect the user reports — such items cannot
be found by typing today without a hidden wildcard. Alone it is already a
complete, useful change.

**Independent Test**: In a fixture directory where `2024_chatbot` is the only
name containing `chat` and no name starts with `c`, type `chat`; the focus is
on `2024_chatbot`. Repeat with a name that does start with `chat` added; the
focus is on that one.

**Acceptance Scenarios**:

1. **Given** a directory with `2024_chatbot`, `alpha`, `beta` and no name starting with `c`, **When** the user types `chat`, **Then** all four characters are accepted and the focus is on `2024_chatbot`.
2. **Given** a directory with `chat.txt` and `2024_chatbot`, **When** the user types `chat`, **Then** the focus is on `chat.txt` (a name that starts with the text is preferred, as before).
3. **Given** a directory with `Report.PDF`, **When** the user types `pdf`, **Then** `Report.PDF` matches (case is ignored; the extension is part of the name).
4. **Given** a directory where no name contains `q`, **When** the user types `q`, **Then** the character is ignored and nothing else changes (as today).
5. **Given** names in any script (Czech `Účetnictví 2024`, Japanese, emoji), **When** the user types a part from inside the name, **Then** it matches under the same equality rules as prefix search today.

---

### User Story 2 - The panel shows only what matches (Priority: P1)

As the user types, the items that do not contain the text disappear from the
panel; the remaining items are exactly the matches. The user walks them with
the arrows and opens one with Enter.

**Why this priority**: The user asks for it explicitly; with substring
matching many items match, and hiding the rest is what makes the result
readable.

**Independent Test**: In a fixture directory with 200 items of which 3
contain `chat`, type `chat`: exactly the 3 items are visible, in the panel's
sort order; Down moves through them; Enter on a directory enters it and the
new directory shows in full.

**Acceptance Scenarios**:

1. **Given** 200 items of which 3 contain `chat`, **When** the user types `c`, `h`, `a`, `t`, **Then** after each character the panel shows only the items containing the text typed so far, and after `t` exactly the 3 items.
2. **Given** the filtered panel, **When** the user presses Down / Up / Home / End / PgDn / PgUp, **Then** the focus moves among the visible items only.
3. **Given** the focus on a matching directory, **When** the user presses Enter, **Then** the directory opens, the search ends and the new directory is shown complete and unfiltered.
4. **Given** the focus on a matching file, **When** the user presses Enter, **Then** the file is opened/run exactly as Enter does today.
5. **Given** the text `chat`, **When** the user presses Backspace, **Then** items containing `cha` reappear in their places.
6. **Given** the filtered panel, **When** the user presses Esc, **Then** all items are visible again in their original order, the focus stays on the item that was focused, and the selection is unchanged.
7. **Given** `old.log` selected before the search and the text `pdf` hiding it, **When** the user selects two visible PDF files and presses F5 (or F8), **Then** only the two PDF files are copied (deleted), the search stays on, and after Esc `old.log` is visible, untouched and still selected.
8. **Given** the text `pdf`, **When** the user selects all (Ctrl+A or Num +), **Then** only the visible PDF files become selected and the search stays on.

---

### User Story 3 - The user can see that a search is running (Priority: P2)

While a search runs, the panel looks slightly different (a light tint), and
the typed text and the number of matches are visible, so the user always
knows why some items are missing and how to get them back.

**Why this priority**: Hiding items without a visible reason is confusing and
can look like lost files; the user asks for a light but recognisable signal.

**Independent Test**: Start a search in each built-in colour scheme: the panel
is recognisably different from the idle panel, the text and the match count
are readable, focused and selected items remain distinguishable; after Esc
the panel looks exactly as before.

**Acceptance Scenarios**:

1. **Given** an idle panel, **When** the user types the first character, **Then** the searching panel is lightly tinted and shows the search text and the match count.
2. **Given** a running search, **When** it ends (Esc, Enter into a directory, any other end), **Then** the tint, text and count disappear at once.
3. **Given** a running search in the left panel, **When** the user looks at the right panel, **Then** the right panel is unchanged.
4. **Given** a running search with a selected item among the matches, **When** the user looks at it, **Then** selected, focused and selected-and-focused items are as distinguishable as in the idle panel.

---

### User Story 4 - Existing quick-search habits keep working (Priority: P2)

Users who type the beginning of a name, use the wildcards, the Alt+letter
start, Shift+arrows to select matches, Left/Right to edit the text, keep
getting the same results.

**Why this priority**: Quick search is one of the most used keyboard
features; the change must not break muscle memory (Constitution II).

**Independent Test**: Re-run the baseline keystroke sequences of *Current
behaviour* on a fixture; whenever a name starts with the typed text, the
focus lands where it lands today.

**Acceptance Scenarios**:

1. **Given** the setting *Quick search starts with Alt+letter* on, **When** the user presses Alt+c, Alt+h …, **Then** the search runs with the new matching and filtering.
2. **Given** the typed text `a/b` (a wildcard), **When** the panel filters, **Then** an item matches when `a` and later `b` occur in its name in that order.
3. **Given** a running search, **When** the user presses Shift+Down, **Then** the focused match is selected and the focus moves to the next match, as today.
4. **Given** the focused match `2024_chatbot` and the text `chat`, **When** the user presses Right, **Then** the text becomes `chatb` (the next character after the matched part).

---

### Edge Cases

- The focused item before typing does not match: the focus moves to the first match at or after it (wrapping to the top), preferring a name that starts with the text.
- Only `..` and no other item: typing starts nothing (as today, a panel needs an item to search).
- The up-directory item `..` never matches and is hidden while filtering.
- Items hidden by the panel filter, by *Hide hidden and system files* or by *Hide selected names* are not candidates and are not revealed by the search.
- Selected items that do not match are hidden but stay selected; no command acts on them while they are hidden; they are visible and selected again after the search ends.
- A command changes the listing (a visible match is deleted, renamed so that it no longer matches, or moved away): it disappears from the filtered view; if no match is left, the search ends and the full list is shown.
- A command creates or names an item to be focused that does not match (F7 creates `new folder` while the text is `chat`, a rename gives a non-matching name): the search ends so that the item is visible and focused.
- The listing refreshes while searching (a file is created, deleted or renamed by another program): the filter is applied to the new listing; a new matching item appears, a vanished one disappears; the focus stays on the same item if it still exists and matches.
- The focused item is deleted by another program while filtered: the focus moves to the nearest remaining match.
- A very long search text (up to the longest name allowed) is handled without truncating a character; a text that cannot be accepted is refused, never cut.
- Thousands of matches (typing `.` in a large directory): the panel stays responsive.
- Archives (ZIP, 7z …) and plug-in file systems (FTP, SFTP …) listed in the panel behave the same as disk directories.
- All view modes (Brief, Detailed, Icons, Thumbnails, Tiles …): filtering, scrolling to the focus and the indication work in each.
- Mouse while filtered: a click focuses a visible item, a double-click opens it like Enter, the wheel scrolls the visible items.
- Panel tabs: switching to another tab ends the search; the tab that is returned to shows its items complete.
- Esc outside a search keeps every meaning it has today.

## Requirements *(mandatory)*

### Functional Requirements

**Matching**

- **FR-001**: Typing in the active panel MUST start and continue the search exactly as today (plain typing, or Alt+character when *Quick search starts with Alt+letter* is on).
- **FR-002**: An item MUST match when its whole name (including the extension) contains the search text anywhere, using the same equality rules as today's quick search (case ignored, canonically equal characters equal).
- **FR-003**: The wildcard characters `/`, `\` and `<` MUST keep meaning "any run of characters"; a text with wildcards matches when its literal parts occur in its name in order, starting anywhere.
- **FR-004**: After each change of the search text the focus MUST go to a match whose name **starts** with the text whenever one exists (staying on the focused item if it is one, otherwise the next such item downwards, then upwards); only when no name starts with the text does the focus go to a match that contains it (same order rule).
- **FR-005**: A typed character that would leave no item matching MUST be ignored, as today; typing never empties the panel.

**Filtering**

- **FR-006**: While the search text is not empty, the panel MUST show only the matching items; every non-matching item, including `..`, is hidden from view. Nothing on disk, in the selection or in the panel's settings changes.
- **FR-007**: The visible items MUST keep the panel's current sort order (directories and files as the sort places them); hiding leaves no gaps.
- **FR-008**: Only items the panel would show without the search are candidates; the search MUST NOT reveal items hidden by the panel filter, by the hidden/system-files setting or by hidden names, and MUST NOT change those settings.
- **FR-009**: When the search text becomes shorter (Backspace, Left), items that match again MUST reappear at their places.
- **FR-010**: When the listing refreshes during a search, the filter MUST be applied to the new listing; the focus stays on the same item when it still exists and matches, otherwise it goes to the nearest match.
- **FR-011**: Filtering MUST work the same for disk directories, archives and plug-in file systems, and in every view mode.

**Navigation and opening**

- **FR-012**: Up, Down, PgUp, PgDn, Home and End MUST move the focus among the visible items; Shift with them selects as today; Alt with them jumps between visible *selected* items as today.
- **FR-013**: Enter on the focused item MUST do what Enter does today; when it changes the panel's directory, the search ends and the new directory is shown complete.
- **FR-014**: Left MUST shorten the search text by one character and Right extend it by the next character of the focused name after the matched part; Backspace deletes the last character; Space is part of the text, as today.
- **FR-015**: Mouse click, double-click and wheel MUST act on the visible items (focus, open, scroll) and MUST NOT end the search; opening a dialog, a viewer, a menu or another application does not end it either.

**Ending the search**

- **FR-016**: Esc MUST end the search: all items become visible in their original order, the focus stays on the item that was focused (scrolled into view), the selection is unchanged.
- **FR-017**: Deleting the last character of the search text with Backspace MUST end the search the same way as Esc.
- **FR-018**: The search MUST also end, restoring the full list, when the panel's directory changes (also by a command such as Back or a hot path), when another panel tab is shown, and when the other panel becomes the active one. Commands that act on items do **not** end it (FR-019).
- **FR-019**: A command that acts on items (copy, move, delete, pack, unpack, view, edit, rename, attributes, properties, drag and drop …) started while the panel is filtered MUST keep the filter and the search, and MUST act only on visible items: the visible selected items, or the focused item when no visible item is selected. Hidden items MUST never be touched by it, even when selected; they keep their selection.
- **FR-020**: Selection commands (Insert, Select all, Unselect all, Invert selection, Select/Unselect by mask) used while the panel is filtered MUST act only on the visible items and keep the search running; Insert selects the focused match and moves to the next one.
- **FR-021**: While the panel is filtered, the panel's summary of selected items MUST describe the visible selected items, so that it matches what a command would act on.
- **FR-022**: When a command finishes and the listing refreshes, the panel MUST stay filtered by the same search text (FR-010).
- **FR-023**: Ending the search MUST NOT change the selection, the panel filter, the sort, the view mode, or anything stored in the configuration.

**Indication**

- **FR-024**: While a search runs, the searching panel MUST be lightly but recognisably distinguished from an idle panel (a tint of the item area derived from the current colour scheme), only that panel, in every built-in colour scheme and in user-defined schemes.
- **FR-025**: The distinction MUST keep the panel readable: item text, focused, selected and selected-and-focused items stay as distinguishable as without the search.
- **FR-026**: While a search runs, the panel MUST show the current search text and the number of matching items out of all items, readable in full (a long text is shown so that the user can see where it was shortened, never by cutting a character) — in the panel's directory line, or in its information line when the directory line is hidden.
- **FR-027**: The focused item MUST show where the match ends inside its name (today's caret, now placed after a match that may start inside the name).
- **FR-028**: The indication MUST disappear at the moment the search ends.

**Setting and compatibility**

- **FR-029**: The new matching and filtering MUST be on by default. Configuration MUST offer one option that returns to the 0.1.10 behaviour (prefix-only matching, nothing hidden, no tint, the search ending as in *Current behaviour*); the option is stored with the other panel settings and takes effect at the next search.
- **FR-030**: Every quick-search behaviour of *Current behaviour* not changed by FR-002–FR-028 MUST stay as it is (the search survives a refresh; the Alt+letter start; Shift/Alt with the movement keys).
- **FR-031**: The change MUST be described for users in `CHANGELOG.md` under the unreleased heading, including how to return to the previous behaviour.

### Key Entities

- **Search text**: the characters the user typed in this search (may contain wildcards); exists only while the search runs, never stored.
- **Match**: an item whose name contains the search text; a *prefix match* contains it at the start of the name.
- **Filtered view**: the panel's listing limited to the matches, in the panel's sort order; a view over the listing, not a change of it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a directory of 1,000 items, a user finds and opens an item whose name contains a known word not at its start by typing the word, at most 3 arrow presses and Enter — without any wildcard.
- **SC-002**: For every search text of a fixture run, the visible items are exactly the items whose names contain the text: 0 missing, 0 extra.
- **SC-003**: Each keystroke updates the panel without perceptible delay: under 0.1 s for a directory of 10,000 items and under 0.3 s for 100,000 items on the maintainer's machine.
- **SC-004**: After Esc, the panel's items, order, selection, filter, sort and view are identical to those before the search in 100 % of the probe scenarios.
- **SC-005**: For every keystroke sequence in which some name starts with the typed text, the focus lands on the same item as in 0.1.10 (prefix behaviour preserved).
- **SC-006**: In every built-in colour scheme, a person tells at a glance whether a search is running in a panel, and reads the search text and the count; focused and selected items stay distinguishable (person check, recorded per scheme).
- **SC-007**: No command started on a filtered panel touches an item hidden by the search: in a probe with selected items hidden by the search, copy, move, delete and pack act on the visible selected items only, and the hidden items are unchanged on disk and still selected after Esc.
- **SC-008**: With the Configuration option set to the previous behaviour, every keystroke sequence of the baseline gives the same focus, the same visible items and the same end of search as in 0.1.10.

## Assumptions

- Matching uses the whole displayed name including the extension; there is no option to match only the base name.
- The visible matches keep the panel's sort order; prefix matches are **not** moved to the top — the preference for prefix matches decides only where the focus lands.
- Today's silent refusal of a character that matches nothing is kept (no sound, no message); the count shown by FR-026 makes the state visible.
- Because commands no longer end the search, the search lives until Esc, emptying the text, a change of directory, a tab switch or activating the other panel (FR-016–FR-018); this is a deliberate change from 0.1.10, where nearly every command ended it.
- Commands that do not act on items (opening a menu, changing sort or view mode, the command line, opening Configuration) keep the search; a change of sort re-orders the visible matches.
- The search text and the filtered view are never stored; a restart, a tab switch or a directory change always shows complete listings.
- The other panel is never affected.
- Fuzzy matching (letters in order with gaps, typos), regular expressions, searching in subdirectories and highlighting the match in every visible name (not only the focused one) are out of scope; they can go to the backlog.
- The tint and the search text/count are new visible elements; any new UI text is a new string and goes through the two-stage translation refresh (Standing rules).
- Quick search in dialogs or plug-in windows other than the panels is out of scope.

## Constitution note

Principle II requires user-facing behaviour changes to be opt-in. The
maintainer decided (Clarifications, 2026-10-17) that this change is **on by
default**: the feature exists to make items findable that users cannot find
today, and an opt-in hidden in Configuration would leave most users without
it. The exception is bounded and documented: one Configuration option restores
the 0.1.10 behaviour exactly (FR-029, SC-008), and the changelog says so
(FR-031). The plan's Constitution Check records this as a justified deviation.
