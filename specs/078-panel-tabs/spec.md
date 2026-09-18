# Feature Specification: Panel Tabs

**Feature Branch**: `078-panel-tabs`  
**Created**: 2026-09-18  
**Status**: Draft  
**Input**: User description: "Proved detailni analyzu a priprav implementaci rozsireni zobrazeni panelu se soubory tak, aby bylo mozne vytvaret zalozky, tedy taby. Diky tomu bude mozne na kazdem ze dvou panelu (levy a pravy) mit vice tabu. Fungovani bude analogicke jako taby napr. v Google Chrome. Ve vychozim pohledu bude zobrazen jeden tab - tedy tak jak je nyni, ale pomoci nove ikony s + bude mozne pridat novy tab. Tab bude nadepsany nazvem adresare, ktery reprezentuje. Proved detailni analyzu a pripravu implementace. Zasadnim cilem je, aby nebylo rozbito fungovani celeho programu. System tabu je mozne vypnout, resp. zapnout v nastaveni aplikace. Pokud bude vypnuto, vzhled a fungovani bude takove jake je nyni."

**Companion document**: `analysis.md` in this directory records the codebase
analysis behind this specification (how the two panels work today, what
assumes there are exactly two of them, and the design direction that keeps
the rest of the program untouched). The specification below states *what*
the user gets; the analysis is input for planning.

## Background *(today's behaviour)*

Tandem Commander shows two file panels side by side, **left** and **right**.
Each panel is exactly one directory view: a Directory Line with the full path
on top, an optional Header Line, the list of items, and an optional
Information Line at the bottom. A panel can show a disk directory, a folder
inside an archive (ZIP, 7-Zip, …), or a location on a plugin file system
(FTP, SFTP, network neighbourhood, …).

To look at another directory the user *replaces* the one in the panel. Ways
back are the panel's Back/Forward history, the hot paths, the *List of
Working Directories*, and the other panel. Two directories that the user
needs to alternate between therefore cost a navigation every time — the
classic reason file managers grew tabs.

Every command, dialog, plugin service and setting in the program is built
around "the left panel", "the right panel", "the active (source) panel" and
"the other (target) panel". Copy and Move go from the active panel to the
other one, *Compare Directories* compares left with right, *Swap Panels*
exchanges the two, *Zoom* enlarges one, the two optional Drive Bars mirror
the two panels, and plugins receive left/right identifiers in their
interface. At exit (or on *Save Configuration*) each panel's path, view mode,
sort order, filter and line visibility are stored and restored at the next
start. None of this is to change.

## Clarifications

### Session 2026-09-18

- Q: Should the tab option ship off (constitution principle II: user-facing
  changes are opt-in) or on? → A: **On by default.** A fresh installation and
  an upgraded configuration show one tab per panel plus the **+** button; the
  option to turn tabs off stays one click away. Recorded as a deliberate,
  documented exception to the opt-in rule: with a single tab the strip is the
  only visible difference and every behaviour is identical (FR-002, FR-025,
  US1, US2).
- Q: Chrome's Ctrl+T / Ctrl+W / Ctrl+Tab are already bound (*Go to Shortcut
  Target*, *Restore Selection*, command-line focus). Keep them, or let
  Chrome's keys take over while tabs are on? → A: **Keep every existing
  binding.** Tab commands get shortcuts from combinations that change no
  documented shortcut. Planning fixed them as "Chrome's tab keys with Shift
  added": Ctrl+Shift+T, Ctrl+Shift+W, Ctrl+Shift+PgUp, Ctrl+Shift+PgDn
  (research R11). Ctrl+Shift+Tab, first thought free, turned out to switch
  panels today and stays untouched (FR-031).
- Q: When the user closes a tab that shows an FTP or SFTP location, should
  the connection be closed, or handled exactly as navigating away from that
  location is today? → A: **Same as navigating away today.** The plugin's own
  leave rule applies (FTP keeps a detached connection listed in the Change
  Drive menu, other plugins close or ask); the tab closes regardless.
  Ending a connection remains an explicit *Disconnect* (F12, Change Drive
  menu), as today (FR-019, Edge Cases).
- Q: After a restart, should archive and FTP/SFTP tabs come back as tabs
  (opened only when clicked), or should only disk-directory tabs be
  restored? → A: **Restore every tab.** An archive or file-system tab is
  restored as its remembered location and opened only when first activated
  (archive reopened, connection established as when entering the path anew,
  with any login prompt the plugin shows). The stored location is the text
  the Directory Line shows — never a password (FR-027, FR-028, US3).
- Q: When a panel has more tabs than fit in one row even at minimum width,
  how does the user reach the hidden tabs? → A: **A tab-list button.** The
  strip shows as many tabs as fit at minimum width plus a button that opens
  a list of all tabs with the current one marked; the active tab is always
  among the visible ones. No horizontal scrolling (FR-009, Edge Cases).
- Q: At which *Skill Level* settings (Beginner / Intermediate / Advanced)
  should the tab commands appear in the menus, given the existing
  panel-chrome toggles are Advanced-only? → A: **All skill levels.** Every
  tab command is listed at every skill level while tabs are on; the strip is
  visible to everyone by default, so its commands are too (FR-030).
- Q: When is the tab layout written to the saved configuration — only when
  the configuration is saved, or also immediately on every tab change? → A:
  **Only with the configuration** — at exit when *Save configuration on
  exit* is on, and on *Save Configuration* — the rule the panel paths follow
  today. No registry writes on tab changes; a crash loses tab changes made
  since the last save, as it loses panel-path changes today (FR-027, US3).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Several directories in one panel (Priority: P1)

A user who keeps returning to the same few directories starts the program
and finds a tab strip at the top of each panel (tabs are on by default),
showing one tab titled with the current directory's name and a **+** button.
Pressing **+** adds a tab; clicking a tab shows its directory in that panel,
with everything the user left there — the cursor, the scroll position, the
selection, the view mode, the sort order and the filter. Closing a tab
removes it; the last tab of a panel cannot be closed. The rest of the program
behaves exactly as before, because at every moment each panel *is* its
active tab.

**Why this priority**: This is the whole request. A user who opens a second
tab and switches between two directories has received the complete value even if nothing else in this specification ships.

**Independent Test**: In the left panel press **+**, go to a different
directory in the new tab, then click back and forth between the
two tabs — each shows its own directory with its own cursor position. Copy a
file with F5 from the left panel's active tab to the right panel — it lands
in the right panel's directory. Disable tabs — the strips disappear and the
program looks like version 0.1.7.

**Acceptance Scenarios**:

1. **Given** tabs are enabled and the left panel shows `D:\Work`, **When**
   the user presses **+** in the left panel, **Then** a second tab titled
   `Work` appears after the first, becomes the active tab and shows
   `D:\Work` with the cursor on the first item.
2. **Given** two tabs in a panel showing `D:\Work` and `C:\Users\Me`,
   **When** the user clicks the first tab, **Then** the panel shows
   `D:\Work` again with the cursor on the item it was on, the same items
   selected (those that still exist) and the same scroll position.
3. **Given** a tab whose directory is `D:\Work\Reports`, **When** it is
   shown, **Then** its title is `Reports`; **When** the user navigates that
   tab to `D:\Work`, **Then** the title changes to `Work`; **When** it shows
   the root of drive `D:`, **Then** the title is `D:\`.
4. **Given** a panel with three tabs, **When** the user closes the active
   (middle) tab, **Then** the tab to its right becomes active; **When** the
   user closes the last remaining tab's neighbours until one tab is left,
   **Then** that tab shows no close control and cannot be closed.
5. **Given** the left panel's active tab shows `D:\Work` and a background
   tab shows `E:\Archive`, **When** the user selects files and presses F5,
   **Then** the copy goes to the *right* panel's active tab directory — the
   background tab plays no part.
6. **Given** the right panel is inactive, **When** the user clicks one of
   its tabs, **Then** the right panel becomes the active panel *and* that
   tab becomes its active tab, in one click.
7. **Given** tabs are enabled with a single tab in each panel, **When** the
   user compares the program with version 0.1.7 (menus, dialogs, panel
   contents, Drive Bars, title bar), **Then** the only difference is the
   tab strip with one tab and the **+** button.
8. **Given** tabs are disabled in the Configuration dialog, **When** the
   dialog is confirmed with OK, **Then** the tab strips disappear at once
   (no restart) and the program's appearance and behaviour are those of
   version 0.1.7; **Given** a panel had more than one tab, **Then** the
   dialog first tells the user those tabs will be closed and lets them
   cancel.

---

### User Story 2 - Nothing else changes (Priority: P1)

A user who turns tabs off, a user who keeps the default single tab, a user
who works with plugins (FTP, SFTP, archives), and a plugin author all see the
program work exactly as it did. With tabs off, no code path behaves
differently. With tabs on, every
existing command, dialog, plugin service and setting that refers to a panel
refers to that panel's active tab, and background tabs are invisible to all
of them.

**Why this priority**: The request names it as the principal goal
("zásadním cílem je, aby nebylo rozbito fungování celého programu"). A tab
feature that changed Copy, Compare, Swap or a plugin's behaviour would be
worse than no tabs.

**Independent Test**: With tabs *off*, run the existing manual test matrix
(copy, move, delete, compare directories, swap, zoom, drive bars, hot paths,
history, an FTP or SFTP session, an archive) — no difference from version
0.1.7. With tabs *on* and several tabs open, run the same matrix against the
active tabs — identical results; the plugins load unchanged.

**Acceptance Scenarios**:

1. **Given** the user turned tabs off, **When** the program is used, **Then**
   nothing looks or behaves differently from version 0.1.7 — no strip, no new
   shortcuts in effect, no new menu commands offered.
2. **Given** tabs are on and the left panel's active tab is an SFTP
   location, **When** the user presses F5 on a file, **Then** the transfer
   goes to the right panel's active tab directory, exactly as it would from
   a plain SFTP panel today.
3. **Given** tabs are on, **When** the user runs *Swap Panels*, **Then** the
   whole tab sets change sides — every tab and which one is active — and the
   plugins are told the panels were swapped as today.
4. **Given** tabs are on and the left panel is zoomed, **When** the user
   restores the layout, **Then** both panels still have all their tabs.
5. **Given** tabs are on and both Drive Bars are shown, **When** the user
   activates a tab on a different drive, **Then** that panel's Drive Bar
   highlights the new drive, as it does after any path change today.
6. **Given** tabs are on, **When** *Compare Directories* runs, **Then** it
   compares the left panel's active tab with the right panel's active tab.
7. **Given** any shipped plugin, **When** it is loaded with tabs on, **Then**
   it loads and works without change — the plugin interface version is
   unchanged and nothing a plugin can ask about a panel answers differently
   from today.
8. **Given** a background tab shows a directory, **When** that directory is
   renamed or deleted by another program, **Then** nothing happens until the
   tab is activated; on activation the tab falls back the way a panel does
   today when its directory has disappeared (nearest existing parent, or the
   configured rescue path) and its title follows.

---

### User Story 3 - Tabs come back after a restart (Priority: P2)

A user who arranged tabs in both panels closes the program in the evening and
finds the same tabs, in the same order, with the same active tab, the next
morning — the way the panel's path already comes back today.

**Why this priority**: Without it, tabs are a session convenience; with it,
they become the user's working layout. It builds on User Story 1 and can ship
after it.

**Independent Test**: Open three tabs in the left panel and two in the right,
activate the second one on each side, exit, start again — the same tabs and
active tabs are there.

**Acceptance Scenarios**:

1. **Given** the user exits with *Save configuration on exit* on (the
   default), **When** the program starts again, **Then** each panel has the
   same tabs in the same order with the same active tab, and each tab's view
   mode, sort order and filter are as they were.
2. **Given** the active tab of a panel was a disk directory, **When** the
   program starts, **Then** it starts in that directory under exactly
   today's start-up rules (inaccessible path → fallback as today).
3. **Given** a background tab was inside an archive or on a plugin file
   system, **When** the program starts, **Then** the tab is present with its
   title, and its location is opened when the tab is first activated — an
   archive is reopened, a file-system connection is established as when
   entering that path anew (including any login prompt the plugin shows).
4. **Given** a background tab's location no longer exists at the time it is
   activated, **When** the user clicks it, **Then** today's inaccessible-path
   handling applies to that tab and the tab stays open at the fallback
   location.
5. **Given** a configuration exported with tabs open, **When** it is imported
   on another machine, **Then** the tabs come along.
6. **Given** a configuration saved by a version without tabs (an upgrade),
   **When** the program starts with tabs enabled, **Then** each panel has one
   tab at the path that version had stored.
7. **Given** the program is closed without saving the configuration, or ends
   in a crash, **When** it starts again, **Then** the tabs are those of the
   last saved configuration — the same rule that applies to panel paths
   today; tab changes made since then are not recovered.

---

### User Story 4 - Keyboard-driven tab work (Priority: P2)

A keyboard user opens a new tab, closes the current one and cycles through the
tabs of the active panel without touching the mouse; the commands are in the
menus with their shortcuts shown, so they are discoverable.

**Why this priority**: The program is keyboard-centric; tabs that need the
mouse would feel foreign. Independent of persistence and of mouse
conveniences.

**Independent Test**: With tabs on, use the *New Tab* shortcut, then the
*Next Tab* / *Previous Tab* shortcuts, then *Close Tab* — the strip follows
each step; with tabs off, the same key presses do exactly what they did in
version 0.1.7.

**Acceptance Scenarios**:

1. **Given** tabs are on and the left panel is active, **When** the user
   presses the *New Tab* shortcut, **Then** a new tab opens in the left panel
   at the current directory and becomes active; the *Close Tab* shortcut
   closes it again.
2. **Given** a panel with three tabs and the first active, **When** the user
   presses *Next Tab* three times, **Then** the active tab cycles
   2 → 3 → 1; *Previous Tab* cycles the other way.
3. **Given** tabs are on, **When** the user opens the *Left* or *Right* menu,
   **Then** the tab commands are listed with their shortcuts; **Given** tabs
   are off, **Then** the commands are not offered.
4. **Given** any keyboard shortcut that exists in version 0.1.7, **When**
   tabs are on, **Then** it still does what it did — no existing shortcut
   changes meaning.
5. **Given** the keyboard focus is in a panel, **When** the user presses
   Tab, **Then** the other *panel* is activated, as today — the tab strip
   itself never takes keyboard focus.

---

### User Story 5 - Chrome-style mouse conveniences (Priority: P3)

A mouse user opens a folder in a new tab with a middle click, closes a tab
with a middle click on it, drags tabs into a different order, reads the full
path in a tooltip and finds *Duplicate*, *Close Other Tabs* and *Close Tabs
to the Right* in the tab's context menu.

**Why this priority**: These are the habits the Chrome analogy brings along;
they make tabs pleasant but none of them is needed to use tabs.

**Independent Test**: Middle-click a folder — it opens in a new background
tab; middle-click that tab — it closes; drag a tab past another — the order
changes; hover a tab — the tooltip shows the full path.

**Acceptance Scenarios**:

1. **Given** tabs are on, **When** the user middle-clicks a folder (including
   the parent-directory entry) in a panel, **Then** that folder opens in a
   new tab of the same panel *behind* the current one, and the current tab
   stays active; a middle click on a file does nothing.
2. **Given** a panel with several tabs, **When** the user middle-clicks a
   tab, **Then** it closes (never the last one).
3. **Given** a panel with tabs `Work`, `Photos`, `Music`, **When** the user
   drags `Music` before `Work`, **Then** the order becomes `Music`, `Work`,
   `Photos` and nothing else changes.
4. **Given** a tab whose title is shortened, **When** the mouse rests on it,
   **Then** a tooltip shows the full location (path, archive path or
   file-system path as the Directory Line would show it).
5. **Given** a tab's context menu, **When** opened, **Then** it offers at
   least *New Tab*, *Duplicate Tab*, *Close Tab*, *Close Other Tabs* and
   *Close Tabs to the Right*, each doing what its name says and each
   disabled when it cannot apply (e.g. *Close Tab* on the only tab).
6. **Given** *Duplicate Tab*, **When** used, **Then** the new tab opens right
   after the original with the same location, view mode, sort order and
   filter, and becomes active.

---

### Edge Cases

- **Same directory in several tabs**: allowed; each tab keeps its own cursor,
  selection and scroll position. A change made through one tab is visible in
  the other when it is activated (the listing is re-read on activation).
- **Directory of a background tab removed, renamed or its drive unplugged**:
  nothing happens while the tab is in the background; on activation today's
  inaccessible-path handling applies (nearest existing parent, then the
  rescue path / fixed drive), the tab stays open there and its title follows.
- **Leaving a tab that is inside an archive**: exactly what leaving that
  archive is today — if files from it were edited, the same "update the
  archive?" prompt appears; the archive is closed. Returning reopens it and
  reads its current content.
- **Leaving a tab that is on a plugin file system** (FTP, SFTP, …): exactly
  what leaving that location is today — the plugin decides whether its
  connection is closed or kept (FTP keeps a detached connection that is
  listed in the Change Drive menu, as today). Returning re-uses a kept
  connection or connects anew, with any login prompt the plugin shows.
- **Closing a tab that is on a plugin file system**: the same as navigating
  away from it today — the plugin's leave rule decides (FTP keeps a detached
  connection, listed in the Change Drive menu; others close or ask), the tab
  closes, and *Disconnect* (F12, Change Drive menu) remains the explicit way
  to end the connection. Closing a *background* file-system tab touches no
  connection at all (the tab held none).
- **Leaving the current location is refused or cancelled** (a plugin asks
  whether to close its connection and the user cancels; an archive update
  fails): the tab switch does not happen and the current tab stays active —
  there is never a half-switched state.
- **An operation is in progress in the panel** (a file operation is being
  prepared, Quick Rename is open, a drag is under way): switching tabs is
  handled the way a path change is handled in that state today — Quick
  Search and Quick Rename are cancelled first; while the panel is locked the
  switch is not possible.
- **Many tabs**: the strip never grows beyond one row. Tabs share the width,
  shrinking to a minimum with titles shortened by an ellipsis; when even that
  does not fit, the strip shows the tabs that fit (the active one always
  among them) and a tab-list button opens a list of all tabs, the current
  one marked, to activate any of them — no tab is ever unreachable by mouse
  or keyboard. The strip does not scroll.
- **Very narrow panel** (the other panel zoomed or the splitter dragged far):
  the strip shows at least the active tab, the **+** button and, when tabs
  are hidden, the tab-list button; the panel is otherwise as usable as it is
  today at that width.
- **Long or non-ASCII directory names** (`G:\Můj disk\Nový projekt`,
  Chinese names, names with unpaired surrogates): titles render correctly
  under the same rules as the Directory Line (feature 004/066 house rules) —
  never garbled or replaced by `?`.
- **Themes and colour schemes**: the strip follows the current colour scheme
  and the Dark theme, and marks the active tab of the active panel and of the
  inactive panel with the same active/inactive distinction the panel caption
  uses.
- **Turning tabs off while extra tabs are open**: the Configuration dialog
  states how many tabs will be closed and asks for confirmation; on OK only
  each panel's active tab remains (as the panel's single view).
- **Configuration from a version without tabs** (upgrade) or an imported
  configuration lacking tab data: one tab per panel at the stored panel path,
  shown with the strip (the option defaults to on); no message.
- **Program closed without saving** (or a crash): tabs are those of the last
  saved configuration — the same rule as for panel paths today.
- **Both panels show the same directory with several tabs each**: Cut/Copy
  ghosting and after-operation refresh behave exactly as they do for two
  panels on the same directory today — they concern only the active tabs.
- **Bug report / crash dump**: unaffected; it describes the two panels
  (their active tabs) as today.

## Requirements *(mandatory)*

### Functional Requirements

**The switch**

- **FR-001**: The Configuration dialog MUST offer one on/off option that
  enables the tab system for both panels (page placement is a planning
  decision; the page holding the other panel-appearance switches is the
  expected home). The option MUST take effect immediately after the dialog
  is confirmed, without restart.
- **FR-002**: The option MUST default to **on**: a fresh installation, and an
  existing configuration that has no value for it (upgrade), show one tab
  per panel plus the **+** button from the first start. This is a deliberate,
  documented exception to constitution principle II's opt-in rule (see
  Clarifications): with a single tab the strip is the only visible
  difference, every behaviour is identical (FR-025), and turning tabs off
  restores version 0.1.7 exactly (FR-003).
- **FR-003**: With the option off, the program MUST look and behave exactly
  as version 0.1.7: no tab strip, no tab commands offered in any menu, no
  tab shortcut in effect, no change in layout, timing or resource use.
- **FR-004**: With the option on, each panel MUST show a tab strip at its
  top, above the Directory Line, even when it holds a single tab.
- **FR-005**: Turning the option off while a panel holds more than one tab
  MUST first tell the user how many tabs will be closed and let them cancel;
  on confirmation only each panel's active tab survives.

**The strip**

- **FR-006**: The strip MUST show one tab per open directory view of that
  panel, in the user's order, plus a **+** button after the last tab that
  opens a new tab.
- **FR-007**: A tab's title MUST be the name of the directory it shows: the
  last component of the location as the Directory Line displays it; at a
  root, the root itself (`C:\`, `\\server\share`, the file system's root
  display). Inside an archive the innermost folder name applies, or the
  archive file's name at the archive root. The title MUST follow every path
  change of that tab.
- **FR-008**: Titles that do not fit MUST be shortened with an ellipsis; the
  full location MUST be available as a tooltip.
- **FR-009**: The strip MUST occupy exactly one row. Tabs MUST shrink to a
  minimum width as tabs are added; when they no longer fit, the strip MUST
  show as many tabs as fit at minimum width — the active tab always among
  them — plus a tab-list button that opens a list of all tabs of that panel
  with the current one marked, from which any tab can be activated. The
  strip MUST NOT scroll horizontally.
- **FR-010**: The active tab MUST be visibly distinct, and the strip of the
  active panel MUST be distinguishable from the strip of the inactive panel
  using the same active/inactive colours the panel caption uses; the strip
  MUST follow the colour scheme, the Dark theme and the environment font like
  the rest of the panel chrome (constitution principle VI).
- **FR-011**: Clicking a tab MUST make it the active tab of its panel; if
  that panel was not the active panel, the click MUST also activate the
  panel.
- **FR-012**: A tab MUST show a close control (on the active tab and on
  hover, in the manner of Chrome) except when it is the only tab of its
  panel; the only tab MUST NOT be closable by any means.
- **FR-013**: The strip MUST never take keyboard focus; the Tab key MUST keep
  switching panels as today.

**What a tab is**

- **FR-014**: A tab MUST be able to hold any location a panel can show today:
  a disk directory, a folder inside an archive, or a plugin file-system path.
- **FR-015**: Each tab MUST have its own location, view mode, sort order,
  filter, cursor position, selection, scroll position and Back/Forward
  history. Directory Line, Header Line and Information Line visibility, and
  column widths, remain per panel as today.
- **FR-016**: A new tab opened with **+** or the *New Tab* command MUST open
  at the current tab's location with a fresh cursor and history, be placed
  after the last tab and become active. *Duplicate Tab* MUST place the copy
  right after the original and copy its view mode, sort order and filter.
- **FR-017**: Closing the active tab MUST activate the tab to its right, or
  the tab to its left when there is none.
- **FR-018**: Activating a tab MUST show its location's *current* content
  (the listing is re-read), then restore the cursor to the item it was on,
  the scroll position, and the selection for items that still exist.
- **FR-019**: A background tab MUST hold nothing open: it does not watch its
  directory, keeps no archive open and holds no file-system connection of
  its own. Leaving a tab — by switching to another tab **or by closing it** —
  MUST be, for the location it shows, exactly what leaving that location is
  today (archive closed with today's update prompts; plugin file system
  closed or kept connected by the plugin's own rules — closing a tab never
  forces a disconnect, and a connection the plugin kept stays listed in the
  Change Drive menu until the user disconnects it as today). Returning MUST
  re-use a connection the plugin kept, otherwise connect anew as when
  entering the path.
- **FR-020**: If leaving the current location is refused or cancelled, the
  tab switch MUST NOT happen and the current tab MUST stay active with its
  content intact.
- **FR-021**: If a tab's location is inaccessible when it is activated,
  today's inaccessible-path handling MUST apply to that tab and the tab MUST
  stay open at the fallback location.

**Nothing else changes**

- **FR-022**: At every moment each panel MUST have exactly one active tab,
  and every existing command, dialog, plugin service and setting that refers
  to "the left panel", "the right panel", "the active/source panel" or "the
  other/target panel" MUST refer to that panel's active tab. Background tabs
  MUST be invisible to all of them.
- **FR-023**: The plugin interface MUST NOT change (no new or altered plugin
  interface methods, identifiers or events; interface version unchanged).
  Every shipped plugin MUST load and behave as in version 0.1.7 with tabs on
  or off.
- **FR-024**: *Swap Panels* MUST exchange the panels' whole tab sets (tabs,
  order and active tab). *Zoom* MUST keep both panels' tabs. The Drive
  Bar(s), the title bar, hot paths, the Back/Forward and *List of Working
  Directories* commands, and every path-changing action (typing a path,
  Change Directory, a plugin changing the panel path, the command line) MUST
  act on the active tab.
- **FR-025**: With tabs on and one tab per panel, the program's behaviour
  MUST be indistinguishable from version 0.1.7 apart from the presence of the
  strip.
- **FR-026**: Tabs MUST NOT add background work: with any number of
  background tabs, directory watching, icon reading and refresh activity
  MUST be that of two panels.

**Persistence**

- **FR-027**: Each panel's tab list (locations in order, the active tab, and
  each tab's view mode, sort order and filter) MUST be stored with the rest
  of the configuration whenever the configuration is saved (*Save
  configuration on exit*, *Save Configuration*), MUST survive restart, and
  MUST be carried by *Export Configuration* / *Import Configuration*. A
  stored location is the text the Directory Line shows for it (disk path,
  archive path, or file-system path with server and user name as the plugin
  displays it) and MUST NOT contain a password; credentials stay where the
  plugins keep them today. The tab layout MUST NOT be written at any other
  time — opening, closing, moving or navigating a tab causes no
  configuration write — so that users who save manually see no writes they
  did not ask for.
- **FR-028**: At start-up the active tab of each panel MUST start exactly
  where the panel starts today (today's rules for a stored disk path and for
  inaccessible paths; command-line paths win as today). Background tabs MUST
  be restored as remembered locations and opened on first activation
  (archive reopened, file system connected anew); an unreachable location
  then follows FR-021.
- **FR-029**: A configuration without tab data (a version before this
  feature, or an import lacking it) MUST yield one tab per panel at the
  stored panel path, without any message. The stored per-panel values used
  by earlier versions MUST keep being written for the active tab, so that
  turning tabs off — or an older version reading the configuration — finds
  the panel path where it always was.

**Keyboard, mouse and menus**

- **FR-030**: There MUST be commands for *New Tab*, *Close Tab*, *Next Tab*,
  *Previous Tab*, *Duplicate Tab*, *Close Other Tabs* and *Close Tabs to the
  Right*; the first four MUST have keyboard shortcuts. The commands MUST
  appear in the *Left* and *Right* menus (for the respective panel) with
  their shortcuts shown, at **every** *Skill Level* setting (Beginner,
  Intermediate, Advanced — unlike the Advanced-only panel-chrome toggles),
  MUST be offered only while tabs are on, and MUST be disabled when they
  cannot apply.
- **FR-031**: The shortcuts MUST NOT change the meaning of any keyboard
  shortcut that exists in version 0.1.7 — Chrome's own Ctrl+T, Ctrl+W and
  Ctrl+Tab stay with *Go to Shortcut Target*, *Restore Selection* and the
  command line. The tab shortcuts are Chrome's tab keys with Shift added —
  *New Tab* Ctrl+Shift+T, *Close Tab* Ctrl+Shift+W, *Previous Tab*
  Ctrl+Shift+PgUp, *Next Tab* Ctrl+Shift+PgDn (research R11). Ctrl+Shift+T
  and Ctrl+Shift+W do nothing today; Ctrl+Shift+PgUp/PgDn are undocumented
  duplicates of Shift+PgUp/PgDn, which keep working, and they revert to that
  duplicate meaning while tabs are off. No plugin may claim these
  combinations afterwards.
- **FR-032**: A middle click on a folder in a panel MUST open that folder in
  a new background tab of the same panel; a middle click on a tab MUST close
  it (except the only tab); dragging a tab MUST reorder it within its panel.
- **FR-033**: A right click on a tab MUST open a context menu with the tab
  commands of FR-030; the existing right-click menus of the Directory Line,
  Header Line, Information Line and the item list MUST be unchanged.

**Text, languages, documentation**

- **FR-034**: All new user-visible text (option, commands, tooltips, the
  confirmation of FR-005) MUST be available in every shipped UI language.
- **FR-035**: The user manual MUST describe the tab strip as a panel
  component, the tab commands and shortcuts, and the option; the keyboard
  shortcuts page MUST list the new shortcuts.
- **FR-036**: Tab titles and tooltips MUST handle names as Unicode end to
  end (feature 004/066 house rules): a name outside the system code page is
  displayed correctly, never garbled or replaced by `?`.

### Key Entities *(include if feature involves data)*

- **Tab**: one remembered directory view within a panel — its location (disk
  directory, archive folder or plugin file-system path, as text; never a
  password), its view
  mode, sort order and filter, its cursor item, selection and scroll
  position, and its Back/Forward history. Exactly one tab per panel is
  *active* and is what the panel shows; the others are *background* tabs
  that hold nothing open.
- **Tab set**: the ordered list of a panel's tabs plus which one is active.
  There are two, one per panel; *Swap Panels* exchanges them. Stored with the
  configuration (locations, order, active tab, per-tab view/sort/filter —
  cursor and selection are session-only, as the panel's are today).
- **Tab-system option**: the single on/off setting; global, stored with the
  configuration; on by default.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With the option off, a side-by-side comparison with version
  0.1.7 over the manual test matrix (copy/move/delete, Compare Directories,
  Swap, Zoom, Drive Bars, hot paths, history, Change Directory, an FTP and an
  SFTP session, an archive, every menu, the Configuration dialog) shows zero
  differences other than the new option in the Configuration dialog.
- **SC-002**: With the option on (the default) and several tabs open, the
  same matrix run
  against the active tabs shows zero divergence from the option-off run, and
  every shipped plugin loads with the unchanged interface version.
- **SC-003**: A user switches between two directories in one panel with one
  click or one key press, and switching between two local tabs of up to
  10,000 items completes in under one second.
- **SC-004**: Tabs, their order, the active tab and per-tab view/sort/filter
  survive a restart and an *Export → Import* round trip unchanged in 100% of
  trials; a pre-feature configuration yields exactly one tab per panel at
  the stored path.
- **SC-005**: No keyboard shortcut of version 0.1.7 changes meaning (zero
  entries changed in the shortcut inventory), and every tab command is
  reachable by keyboard and by mouse.
- **SC-006**: With 20 tabs open in each panel, the program is as responsive
  as with one tab, and background tabs cause no disk or network activity
  (measurable with a file-system or network monitor during a five-minute
  idle period).
- **SC-007**: Leaving a tab never leaves a half-switched state: in every
  cancel/refuse case of the test matrix (plugin refuses to close, archive
  update cancelled), the strip and the panel content agree in 100% of
  trials.
- **SC-008**: All new text appears fully translated in all 8 shipped UI
  languages — no English text in a non-English UI.
- **SC-009**: Directory names with non-ASCII characters and names with
  unpaired surrogates appear in tab titles and tooltips exactly as in the
  Directory Line, in 100% of the encoding fixtures used by features 004 and
  066.

## Assumptions

- **Design direction (from the analysis)**: each panel stays the single
  directory view it is today; a tab is the remembered state of that view,
  and switching tabs is, from the rest of the program's point of view, an
  ordinary path change of that panel. This is what makes FR-022 to FR-026
  achievable without touching the ~770 places that assume exactly two panels
  and without changing the plugin interface. See `analysis.md`.
- **Default on** (decided in Clarifications): the option ships on. The
  constitution's opt-in rule for user-facing changes is consciously set
  aside for this one change, on the grounds that the single-tab strip alters
  appearance only; the planning constitution check records the deviation,
  and the changelog states it in the user's terms together with how to turn
  tabs off.
- **What + opens**: the current tab's location (the convention of Total
  Commander and Directory Opus; Chrome's "new tab page" has no file-manager
  equivalent). New tabs go to the end of the strip; *Duplicate Tab* goes next
  to its original, like Chrome.
- **Restoring tabs across restarts** is expected of a file manager (the
  panel path already comes back); locations of archive and plugin
  file-system tabs are restored lazily so that no connection is made at
  start-up without the user activating the tab.
- **The listing is re-read on activation** rather than kept alive in the
  background; this is what keeps background tabs free of directory watches,
  open archives and connections (FR-019, FR-026) and is the behaviour users
  of other tabbed file managers know. Keeping listings cached for faster
  switching is a possible later improvement, not part of this feature.
- **Shortcut policy** (decided in Clarifications, keys fixed in planning):
  existing bindings keep their meaning (constitution principle II).
  Ctrl+Shift+T, Ctrl+Shift+W and the middle mouse button are unclaimed;
  Ctrl+Shift+PgUp/PgDn are undocumented duplicates of Shift+PgUp/PgDn and are
  taken over only while tabs are on (research R11).
- **Per-visit memories are not carried by a tab**: the names hidden with the
  *Hide* command and the *Restore Selection* memory are cleared whenever a
  panel leaves a location today, and a tab switch is such a leave; restoring
  hidden names would require reading the directory twice. Both stay per visit
  (research R3).
- **Column widths stay per panel side** (they are shared by both panels'
  view templates today); a tab does not carry its own column widths.
- **Out of scope for this feature**: dropping files onto a tab to copy them
  there, pinned or locked tabs, tab groups or colours, dragging a tab to the
  other panel, reopening a closed tab, a tab-search box, per-tab column
  widths, and a "new tab" toolbar button (may follow as small increments).
- **Help pages** are authored (FR-035) following feature 071's pattern even
  though the manual is not currently built into the shipped product
  (feature 019); the keyboard page and the panel-components page are the
  ones affected.
- New strings go through the existing translation pipeline (machine
  translation with usage context, feature 055) and are pinned by hand where
  the automatic result is wrong; new controls follow the house style
  (constitution principle VI).
- No plugin interface change and no configuration-version bump are needed:
  new configuration values default when absent, as in feature 071.
