# Feature Specification: popup menu hot keys and the Find window's hidden hot keys compare whole characters

**Feature Branch**: `256-popup-wide-mnemonics`
**Created**: 2026-10-20
**Status**: Draft
**Input**: User description: "Backlog item menu-popup-loop-wide-mnemonics - implement exactly what it describes." From backlog item menu-popup-loop-wide-mnemonics.

## Background (measured at 084744e0)

- (a) The program's own popup menus (context menus, User Menu, drive menu, menus of the menu bar,
  plug-in menus) read the keyboard through a code-page message loop. A typed character reaches the
  popup as a code-page byte: measured, a character posted as UTF-16 arrives as `?` (0x3F) for
  U+0416 and U+4E2D and as `c` (0x63) for U+010D (the conversion uses the keyboard layout's code page);
  a wide loop receives every character exactly. So a hot key outside that code page never matches,
  a character the code page cannot hold can select the item whose hot key is `?`, and a DBCS
  character arrives as two bytes that match nothing (or, a trail byte in 0x40-0x7E, an ASCII letter's
  item).
- (b) When no item matches, the popup asks its owner (`WM_MENUCHAR`) - the route by which owner-drawn
  shell-extension items (TortoiseSVN) answer a hot key. The question carries no character
  (`wParam = MF_POPUP`: the low word, the character by the message's contract, is 0x10, the high word,
  the menu kind, is 0), and of the answers only "select" is honoured - "execute" (a handler's answer
  for a single match) is ignored.
- (c) The Find window expands its collapsed Options when Alt + the hot key of a hidden option control
  is pressed. The check compares the code-page byte after `&` with the key's virtual-key code; "&&"
  (a literal `&`) is not skipped. With the shipped languages the five watched controls have ASCII hot
  keys (the comparison works); Russian and Ukrainian (not shipped) have Cyrillic ones, which never
  match.

## Clarifications

### Session 2026-10-20

- Q: Should the popup carry out an owner's "execute item n" answer (select and choose), not only "select"? → A: Yes - select it and choose it as Enter would; the fallback must work for a single match, which extensions answer with "execute" (autonomous run: item)
- Q: In the Find window, should the character check replace the virtual-key check of ASCII hot keys? → A: No - keep the virtual-key check for ASCII letters and digits and add a character check; nothing that works today changes (autonomous run: conservative)
- Q: Should code-page owner windows (main window, Find window) convert the character back to UTF-16 before passing it to the shell extension? → A: No - they forward what they receive, as today; the popup sends in their own kind so that what they receive is the UTF-16 unit (review 1) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A popup item is chosen by the character typed (Priority: P1)

A user whose menu items carry hot keys outside the system code page (a UTF-8 plug-in menu, a User
Menu item named in another script, a DBCS or UTF-8 code-page system) types the item's hot key in an
open popup menu and the item is selected (or run, when it is the only one with that key) - not
another item, and not nothing.

**Why this priority**: it is the item's main defect - the function does not work there.

**Independent Test**: open a popup menu holding items with hot keys `Ж`, `Č`, `Q` and `?`, post each
character as UTF-16 to the popup; the matching item runs and no other.

**Acceptance Scenarios**:

1. **Given** a popup with items "&Ж", "&Č", "&Q", "&?", **When** `Ж` is typed, **Then** the "&Ж" item
   runs and the "&?" item does not.
2. **Given** the same popup, **When** `č` (lower case) is typed, **Then** the "&Č" item runs.
3. **Given** the same popup, **When** `q` is typed, **Then** the "&Q" item runs (ASCII unchanged).

---

### User Story 2 - Owner-drawn items answer the typed character (Priority: P2)

A shell extension that draws its own context-menu items (TortoiseSVN) and answers hot keys itself
receives the typed character when the program's own matching finds no item, and its answer -
select an item, or execute it - is carried out.

**Why this priority**: the fallback exists only for these extensions; it can never work today.

**Independent Test**: by reading and by a pure-rule test of the answer handling; a real extension
with a real keyboard is a person's check.

**Acceptance Scenarios**:

1. **Given** no item of the popup matches the key, **When** the owner is asked, **Then** the question
   carries the typed character and the popup kind as the message's contract describes.
2. **Given** the owner answers "select item n" (n a valid, selectable item), **Then** item n is
   selected; **given** it answers "execute item n", **Then** item n is selected and chosen as if
   Enter were pressed.
3. **Given** the owner answers anything else, or an item index that does not exist or is a
   separator, **Then** nothing happens (as before for every answer but "select").

---

### User Story 3 - The Find window's hidden hot keys compare characters (Priority: P3)

In the Find window with Options collapsed, Alt + the hot key of a hidden option control expands
Options, also when that hot key is a letter outside ASCII.

**Why this priority**: not reachable with the shipped languages; cheap and asked by the item.

**Independent Test**: pure-rule tests of the hot-key reading and comparison (saltests); a real Alt
key is a person's check.

**Acceptance Scenarios**:

1. **Given** a control "&Текст" (Russian translation), **When** Alt+`т` is typed, **Then** Options
   expand.
2. **Given** a control "HE&X-mode", **When** Alt+X is pressed, **Then** Options expand (as before).
3. **Given** a control "R&&D", **Then** it has no hot key ("&&" is a literal `&`).

### Edge Cases

- A character outside the Basic Multilingual Plane (two UTF-16 units) as a hot key: matches nothing
  (as before, feature 237's rule).
- A typed key that matches no item and the owner does not handle the question: nothing happens.
- Keys other than characters (arrows, Enter, Escape, F10, Alt) behave exactly as before.
- Messages of other windows that arrive while a popup is open are delivered to them unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An open popup menu MUST receive typed characters as UTF-16 (whole characters), not as
  code-page bytes, and match them against item hot keys with the existing rule (feature 237).
- **FR-002**: Every other message the popup's loop takes from the queue MUST reach its window as
  before (navigation keys, mouse, timers, messages of other windows).
- **FR-003**: When no item matches, the owner MUST be asked with the typed character in the low word
  and the popup kind in the high word of the question, as the message's contract describes.
- **FR-004**: An owner's answer "select n" MUST select item n and "execute n" MUST select and choose
  it, only for an existing, non-separator item visible at the current skill level; any other answer
  MUST be ignored.
- **FR-005**: The Find window's check of hidden hot keys MUST read the control's text as UTF-16, skip
  "&&", and compare the hot key with the typed character case-insensitively as characters; the
  existing virtual-key match for ASCII letter and digit hot keys MUST keep working.
- **FR-006**: No plug-in interface, stored data, UI string or translation changes.

### Key Entities

- **Hot key of an item / control**: the character after a single `&` of its text ("&&" is a literal
  `&`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe's popup, typing `Ж`, `č` and `q` runs exactly the matching item in 3 of 3
  rows (before: `Ж` ran the `?` item).
- **SC-002**: saltests checks of the owner-answer rule and of the dialog hot-key rule pass; existing
  saltests stay green.
- **SC-003**: ASCII hot keys in popups and the Find window behave as before (the probe's `q` row; the
  rules' ASCII checks).

## Assumptions

- Assumption (autonomous run): the menu bar's own loop (F10, then a letter, before any popup opens -
  `CMenuBar::EnterMenuInternal`) has the same code-page defect but is not named by the item; it stays
  unchanged and is recorded as a new Inbox item (stop-rules §2.11).
- Assumption (autonomous run): the owner windows forward the question's wParam to the shell
  extension unchanged, so the popup sends it in the owner's own kind (wide to a Unicode window, code
  page to a code-page one) and Windows converts nothing - every owner forwards the UTF-16 unit (review 1;
  a wide send to a code-page window was measured to scramble it). A code-page owner thus gets a UTF-16
  unit where a native Windows menu would give it a code-page byte; no owner in the tree reads it
  itself (review 2, N1) - a third-party plug-in owner that did would misread a non-ASCII key. Owner-side routing gaps (the panel's
  background / New menus, the Find window's dialog result) are outside the item: Inbox
  `menuchar-owner-routing`.
- Assumption (autonomous run): the Find window keeps its virtual-key check on the key-down for
  ASCII letter and digit hot keys (unchanged behaviour, also with a non-Latin keyboard layout), and
  adds a character check on the character message the dialog manager uses for mnemonics.
- Real keyboards, IMEs, DBCS / UTF-8 code-page systems and TortoiseSVN are a person's checks
  (stop-rules §2.9); the hidden-desktop probe posts characters.
