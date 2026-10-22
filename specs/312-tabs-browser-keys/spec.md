# Feature Specification: Panel tabs - a Tabs settings page, opt-in browser-like shortcuts, Reopen Closed Tab

**Feature Branch**: `312-tabs-browser-keys`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item panel-tabs-chrome-shortcuts-and-reopen-closed-tab (backlog/items/panel-tabs-chrome-shortcuts-and-reopen-closed-tab/desc.md) - implement exactly what it describes. From backlog item panel-tabs-chrome-shortcuts-and-reopen-closed-tab.

## Background

Panel tabs (feature 078) use Chrome's tab keys with Shift added (Ctrl+Shift+T new, Ctrl+Shift+W
close, Ctrl+Shift+Page Down / Page Up next / previous), because 078 kept the meaning of every
existing shortcut. Users who know the plain browser keys cannot have them, a tab closed by mistake
cannot be brought back, and the tab settings are one checkbox on the Appearance page.

**Maintainer decisions (2026-10-22)** - the classic keys stay the default:

1. A new **Tabs** page in Configuration holds everything about tabs; *Show tabs in panels* moves
   there from Appearance.
2. A new option **Browser-like tab shortcuts**, **off by default**. With it on (and tabs on):

   | Key | Browser-like (option on) | Classic (option off, as in 0.1.10) |
   |---|---|---|
   | Ctrl+T | New Tab | Go to Shortcut or Link Target |
   | Ctrl+W | Close Tab | Restore Selection |
   | Ctrl+Page Down | Next Tab | go into the focused folder or archive |
   | Ctrl+Page Up | Previous Tab | go to the parent folder |
   | Ctrl+Shift+T | Reopen Closed Tab | New Tab (078) |
   | Ctrl+Shift+W | Restore Selection | Close Tab (078) |
   | Ctrl+Shift+G | Go to Shortcut or Link Target | (free) |
   | Ctrl+Shift+Page Down / Up | Next / Previous Tab (kept) | Next / Previous Tab (078) |

   In the browser-like mode Ctrl+Page Up / Down have no replacement key (Backspace and Enter
   remain).
3. Ctrl+Tab stays exactly as it is in both modes.
4. The Tabs page lists the tab shortcuts and what they do; switching the option's checkbox updates
   the list at once (before OK).
5. A new command **Reopen Closed Tab** in both modes; in the classic mode it has no key.
6. **Tabs** is added to the toolbar context menu next to the other bars and under
   **Options > Show**, both toggling *Show tabs in panels*.

Measured at 4a7d5595 (reading the sites at HEAD): none of the above exists. In the panel the 078
tab keys are dispatched first (guarded by *Show tabs in panels*), Ctrl+Page Down / Up go to
"enter" / "parent", Ctrl+letters to the main window's Ctrl+letter handler (Ctrl+T Go to Shortcut,
Ctrl+W Restore Selection). The command line does not run the Ctrl+letter handler at all: Ctrl+T,
Ctrl+W, Ctrl+Shift+T and Ctrl+Shift+W do nothing there today; Page Up / Page Down with any
modifier are forwarded to the panel's key handler. Ctrl+Tab is a main-window accelerator (focus the
command line). Ctrl+Shift+G is handled nowhere in the core and not reserved against plug-ins; the
reservation check is also used at load time to *clear* a plug-in hot key that collides with a
reserved key.

## Clarifications

### Session 2026-10-22

- Q: How many closed tabs does a panel remember? → A: 10 per panel; the oldest is forgotten when an 11th is closed (autonomous run: item - "capped (10-20, decide in the spec)"; conservative - the lower bound, a remembered tab can hold a long location)
- Q: Does Reopen Closed Tab make the reopened tab the active one? → A: yes, as in browsers; it is inserted at its old position (clamped to the current number of tabs) and shown (autonomous run: item - "restores the whole remembered state ... in the panel it was closed from, at its old position where possible")
- Q: What if showing the reopened tab is refused (the user cancels leaving an archive that has unsaved changes, or a plug-in refuses to leave)? → A: the reopened tab is taken out again and goes back to the top of the closed-tab list - nothing is lost (autonomous run: conservative)
- Q: What happens to the closed-tab list when tabs are turned off? → A: it is emptied; closing background tabs by turning tabs off is not a *Close Tab* and is not remembered (the existing confirmation stays) (autonomous run: conservative - existing behaviour of turning tabs off unchanged)
- Q: What happens to a plug-in hot key the user assigned to Ctrl+Shift+G before this feature? → A: it is kept: in the classic mode it works as before; in the browser-like mode (tabs on) the tab key wins in the panel and the command line; Plugins Manager refuses assigning Ctrl+Shift+G anew and settings import skips it (autonomous run: item - "With the option off every key does exactly what it does in 0.1.10"; the item leaves the choice to the spec)
- Q: Where does the Tabs page go in the Configuration tree, and what about the remembered last page? → A: right after Appearance; a configuration saved before this feature (it has no value of the new option) has its remembered page index moved by one for every page after Appearance, so the same page opens (autonomous run: item - Approach "map old indexes")
- Q: Which keys does the list on the Tabs page show? → A: every key of the decision table (nine rows) with its action in the mode the checkbox shows, plus Reopen Closed Tab with its key or "no shortcut", and Ctrl+Tab with its unchanged action (autonomous run: item - "lists the tab shortcuts and what they do")
- Q: Do toolbar tooltips that name Ctrl+T / Ctrl+W, and the strip's New Tab tooltip, follow the mode too? → A: yes, the same rule as the menu labels (autonomous run: item - "Menu labels show the key of the active mode"; a tooltip naming a wrong key would mislead the same way)
- Q: Is the *Tabs* entry in the toolbar context menu and Options > Show subject to the "N tab(s) will be closed" question when it turns tabs off? → A: yes, the same question as the Configuration dialog; No keeps tabs on (autonomous run: conservative - never close tabs without the question 078 asks)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing changes for a user who does not opt in (Priority: P1)

A user upgrading from 0.1.10 keeps every key, menu label and tooltip exactly as before. New things
they can see: the Tabs page in Configuration (with *Show tabs in panels* moved there), *Reopen
Closed Tab* in the *Tabs* submenus and the strip's context menu, *Tabs* in the toolbar context
menu and under Options > Show, and *Go to Shortcut or Link Target* in the Commands menu at every
skill level.

**Why this priority**: the maintainer's first decision - the classic behaviour is valued.

**Independent Test**: probe rows `classic-keys` (each key of the table in the panel with tabs on
and off: the 0.1.10 meaning), `classic-labels` (menu labels unchanged byte for byte).

**Acceptance Scenarios**:

1. **Given** a 0.1.10 configuration, **When** the program starts, **Then** the option is off and
   Ctrl+T, Ctrl+W, Ctrl+Page Down / Up, Ctrl+Shift+T / W / Page Down / Up do what they did.
2. **Given** tabs on and the option off, **When** Ctrl+Shift+G is pressed, **Then** nothing
   happens unless the user assigned it to a plug-in command (then that command runs).
3. **Given** the option off, **When** the *Tabs* submenu opens, **Then** the 078 labels are shown
   unchanged and *Reopen Closed Tab* has no key.

---

### User Story 2 - Browser-like tab shortcuts (Priority: P1)

A user turns on *Browser-like tab shortcuts* on the Tabs page. With tabs on, the keys of the table
do the browser-like meanings, in the panel and with the focus in the command line. Menu labels and
tooltips show the keys of the mode. With tabs off the option has no effect and its checkbox is
disabled.

**Why this priority**: the core of the request.

**Independent Test**: probe rows `browser-keys` (each key in the panel), `browser-cmdline` (each
key with the focus in the command line), `browser-labels`, `tabs-off` (option on, tabs off:
classic keys).

**Acceptance Scenarios**:

1. **Given** tabs on and the option on, **When** Ctrl+T, **Then** a new tab opens; **When** Ctrl+W,
   **Then** the active tab closes (not the only one); **When** Ctrl+Page Down / Up, **Then** the
   next / previous tab is shown; **When** Ctrl+Shift+T, **Then** the last closed tab comes back;
   **When** Ctrl+Shift+W, **Then** the selection is restored; **When** Ctrl+Shift+G on a shortcut,
   **Then** its target is focused; Ctrl+Shift+Page Down / Up still switch tabs.
2. **Given** the same, with the focus in the command line, **Then** the same keys do the same and
   the typed command text is kept.
3. **Given** the option on and tabs off, **When** any key of the table, **Then** the classic
   meaning.
4. **Given** the option on, **When** the *Tabs* submenu opens, **Then** New Tab shows Ctrl+T,
   Close Tab Ctrl+W, Next Tab Ctrl+Page Down, Previous Tab Ctrl+Page Up, Reopen Closed Tab
   Ctrl+Shift+T; Restore Selection shows Ctrl+Shift+W and Go to Shortcut or Link Target
   Ctrl+Shift+G.
5. **Given** Ctrl+Tab in either mode, **Then** it does exactly what it did.

---

### User Story 3 - Reopen Closed Tab (Priority: P1)

A user closes a tab by mistake (Close Tab, Close Other Tabs, Close Tabs to the Right, middle
click) and brings it back with *Reopen Closed Tab* - with its location, view, sort, filter,
cursor, selection, scroll and its own Back/Forward history, at its old position, in the same
panel. Several closed tabs come back one by one, the last closed first.

**Why this priority**: losing a carefully set-up tab is the most annoying tab mistake.

**Independent Test**: probe rows `reopen-one`, `reopen-others`, `reopen-right`, `reopen-empty`
(disabled), `reopen-archive`; saltests for the stack and the index rules.

**Acceptance Scenarios**:

1. **Given** tabs A B C with B active and a selection in C, **When** C is closed and reopened,
   **Then** C is third again, active, with its folder, sort, filter, view, cursor, selection and
   Back history.
2. **Given** A B C D and Close Other Tabs on B, **When** Reopen three times, **Then** the order is
   A B C D again.
3. **Given** no tab closed in the panel, **Then** Reopen Closed Tab is disabled in the menus and
   its key does nothing.
4. **Given** a closed tab inside an archive or on a plug-in file system, **When** reopened,
   **Then** it opens like a tab restored at start-up (nothing was kept open while closed).
5. **Given** 11 tabs closed one by one, **Then** the 10 most recent can be reopened.
6. **Given** the program is restarted, **Then** nothing closed before can be reopened (memory
   only; never written to the registry).

---

### User Story 4 - The Tabs page and the Tabs toggles (Priority: P2)

Configuration has a Tabs page right after Appearance with *Show tabs in panels*, *Browser-like tab
shortcuts* and a read-only list of the tab shortcuts and their actions; the list follows the
option's checkbox at once. The Appearance page no longer has the checkbox (its groups move back up).
*Tabs* in the toolbar context menu and under Options > Show toggles tabs, with a check mark.

**Why this priority**: the maintainer's decisions 1, 4 and 6; the keys work without the page only
through a hand-edited registry.

**Independent Test**: probe rows `page-list` (list rows before and after clicking the checkbox),
`page-disable` (option disabled while tabs unchecked), `page-lastpage` (a 0.1.10 configuration
remembering a page after Appearance opens that page), `toggle-menus`.

**Acceptance Scenarios**:

1. **Given** the Tabs page, **When** the option's checkbox is clicked, **Then** the list shows the
   other mode's actions before OK; Cancel keeps the stored option.
2. **Given** *Show tabs in panels* unchecked on the page, **Then** the option's checkbox is
   disabled (its value is kept).
3. **Given** a 0.1.10 configuration whose remembered page was Keyboard, **When** Configuration
   opens, **Then** the Keyboard page is shown.
4. **Given** tabs on with three tabs, **When** *Tabs* is chosen in Options > Show, **Then** the
   "2 tab(s) will be closed" question comes; Yes turns tabs off, No keeps them.

### Edge Cases

- Closing the active tab pushes it after the switch to the neighbour succeeded; a refused switch
  pushes nothing (the tab stays).
- Reopen while a file operation runs or the panel's UI is locked: refused like other tab switches;
  the closed tab stays in the list.
- The closed-tab list belongs to the panel's tab set: when the panels are swapped (Ctrl+U), the
  list goes with the tabs.
- A remembered tab's location no longer exists: it opens like any tab whose location is gone
  (the panel falls back to an existing parent).
- Browser-like mode and quick search: a key of the table ends the quick search first, as the 078
  tab keys do.
- Ctrl+Page Down / Up in the browser-like mode with only one tab: nothing happens (not "enter" /
  "parent").
- A user plug-in hot key on Ctrl+T / Ctrl+W cannot exist (reserved since before 078).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A new Configuration value *Browser-like tab shortcuts* MUST exist, default off,
  saved and loaded with the configuration; a configuration without it MUST read as off.
- **FR-002**: With the option off, or with tabs off, every key MUST keep its 0.1.10 meaning in the
  panel and in the command line.
- **FR-003**: With the option on and tabs on, the keys of the decision table MUST do their
  browser-like meanings in the panel and with the focus in the command line; Ctrl+Tab MUST be
  unchanged.
- **FR-004**: One table MUST decide the key dispatch, the keys shown in menu labels and tooltips,
  and the list on the Tabs page.
- **FR-005**: A command *Reopen Closed Tab* MUST exist for the active, left and right panel; it
  MUST be in the *Tabs* submenus and the strip's context menu, enabled only when the panel has a
  closed tab to reopen; it has no key in the classic mode and Ctrl+Shift+T in the browser-like
  mode.
- **FR-006**: Close Tab, Close Other Tabs and Close Tabs to the Right MUST remember each closed tab
  separately in a per-panel list of at most 10 (oldest dropped); the list MUST live in memory only.
- **FR-007**: Reopen MUST insert the most recently closed tab at its old position (clamped) in the
  same panel, with its whole remembered state including its own Back/Forward history, and show
  it; when showing it is refused, the tab MUST go back to the list.
- **FR-008**: Menu labels and toolbar / strip tooltips that name a tab key or a key moved by the
  mode MUST show the key of the active mode, updated when the option or *Show tabs in panels*
  changes; in the classic mode they MUST be the 0.1.10 texts.
- **FR-009**: *Go to Shortcut or Link Target* MUST be in the Commands menu at every skill level.
- **FR-010**: Plugins Manager MUST refuse Ctrl+Shift+G as a plug-in hot key and settings import
  MUST skip it; a plug-in hot key on Ctrl+Shift+G the user assigned before MUST be kept.
- **FR-011**: A Tabs page MUST follow Appearance in Configuration with *Show tabs in panels*,
  *Browser-like tab shortcuts* (disabled while *Show tabs in panels* is unchecked) and a read-only
  list of shortcuts and actions that follows the option's checkbox at once.
- **FR-012**: The Appearance page MUST no longer show *Show tabs in panels*; its groups below MUST
  move back up by the space the checkbox took.
- **FR-013**: The remembered Configuration page of a configuration saved before this feature MUST
  open the same page.
- **FR-014**: *Tabs* MUST be in the toolbar context menu and under Options > Show, checked while
  tabs are on, toggling *Show tabs in panels* with the 078 question before tabs are closed.
- **FR-015**: Turning tabs off MUST empty the closed-tab lists.
- **FR-016**: All new texts MUST be translatable UI strings; the manual MUST describe the Tabs page,
  the two key modes and Reopen Closed Tab; the changelog MUST get an entry under the unreleased
  section.
- **FR-017**: The pure rules (the key table per mode, the label key replacement, the closed-tab list
  cap and the reopen position, the remembered-page mapping) MUST be covered by saltests.

### Key Entities

- **Tab key table**: for each key combination and mode, the action (New Tab, Close Tab, Next Tab,
  Previous Tab, Reopen Closed Tab, Restore Selection, Go to Shortcut or Link Target, or "not a tab
  key - classic handling") and the key text shown in labels.
- **Closed tab**: a panel tab taken out of the strip with its whole remembered state and the
  position it had; per panel, newest first, at most 10.
- **Browser-like tab shortcuts**: a yes/no configuration value, default no.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With the option off, 100% of the keys of the decision table do their 0.1.10 meaning
  (probe rows, tabs on and off).
- **SC-002**: With the option on and tabs on, 100% of the keys of the table do the browser-like
  meaning in the panel and the command line (probe rows; the real keyboard owed to a person).
- **SC-003**: A tab closed by any of the three close commands comes back with the same location,
  sort, filter, view, cursor and selection in 100% of the probe cases.
- **SC-004**: The list on the Tabs page changes within the same click of the checkbox.
- **SC-005**: A 0.1.10 configuration opens the page it remembered.

## Assumptions

- Assumption (autonomous run): a new yes/no setting is covered by PRIVACY.md's "settings" wording
  (it lists kinds of data, not options); the closed-tab list is never stored - PRIVACY.md is not
  changed.
- Assumption (autonomous run): key texts added by the browser-like mode are written in the 078
  form ("Ctrl+Shift+T", "Ctrl+Page Down") in every language, as the 078 strings are in all eight
  translations; the classic mode shows the translated 0.1.10 strings unchanged.
- Assumption (autonomous run): the plug-in interface is untouched (no new callback; a plug-in
  sees the panel as before); no configuration version bump - the new value is simply absent in
  older configurations.
- Assumption (autonomous run): new UI strings need the two-stage `.slt` refresh, which an
  autonomous run does not do (stop-rules §3 #2): the run implements and verifies everything else
  and stops before closing, with the refresh owed to the maintainer.
- Assumption (autonomous run): the real keyboard in the panel and the command line in both modes
  and the look of the Tabs page in eight languages are owed to a person (hidden desktop has no
  keyboard); the probe drives keys by posted key messages.
