# Feature Specification: Panel tabs - taller rounded look with icons and Chrome-like mouse handling

**Feature Branch**: `404-panel-tabs-rounded-look`
**Created**: 2026-11-06
**Status**: Draft
**Input**: User description: "Backlog item panel-tabs-rounded-windows-11-look-with-icons-and-roomier - implement exactly what it describes (variant F of the 2026-11-06 mockups, live drag reorder, close on release, Move to Other Panel, New Tab as Other Panel)." From backlog item panel-tabs-rounded-windows-11-look-with-icons-and-roomier.

## Clarifications

### Session 2026-11-06

- Q: What exactly does "anti-aliased edges may differ by a shade" allow in the comparison with the evidence images? → A: a captured pixel may differ from the evidence pixel only where the evidence's 3x3 neighbourhood of that pixel is not one uniform colour (an edge), and then by at most 64 in any colour channel; every pixel whose neighbourhood is uniform (solid areas) must be equal. The probe reports exact / edge-tolerated / failing counts (autonomous run: recommended)
- Q: How does the strip see Esc while dragging, given it never has the keyboard focus? → A: the drag animation timer, which runs while a drag is active, checks `GetAsyncKeyState(VK_ESCAPE)` and cancels the drag (autonomous run: recommended - the item offers this option first and it needs no change to the panel's key handling)
- Q: When the left button goes down on the close glyph and the capture is then lost (a menu, another window), what happens? → A: the press is forgotten and nothing closes, as with a release off the glyph (autonomous run: conservative)
- Q: Where does a tab moved to the other panel go, and which panel is active afterwards? → A: at the end of the other panel's tabs, active there; which panel is active follows the existing `SwitchToTab` rules (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The tab strip looks like a current Windows 11 program (Priority: P1)

A user who keeps several folders open as panel tabs sees a strip that matches Windows 11,
Explorer and the browsers: the active tab is a rounded tab that grows out of the panel below it
(caption colour, rounded top corners, small outward "feet"), inactive tabs are plain text on a
slightly darker strip, a light rounded highlight follows the mouse, thin separators divide
plain tabs, the close and new-tab glyphs are smooth, and there is room around the text.

**Why this priority**: it is what the maintainer chose (variant F) and the main point of the item.

**Independent Test**: start the program with six tabs in the left panel (the evidence set:
Downloads, fonts, tandemcommander, src, a long name starting `2021_silon_bubble_s`, `E:\`) in a
786-px-wide strip at 96 DPI, capture the strip and compare it with
`evidence/variantF_light_*.png` (normal, inactive panel, hovered tab, hovered close glyph,
hovered plus) and the Dark theme images.

**Acceptance Scenarios**:

1. **Given** the Default theme at 96 DPI and the evidence tab set, **When** the strip is captured,
   **Then** text pixels and solid rectangles equal the evidence image; anti-aliased edges differ
   by at most a shade.
2. **Given** the same set in the Dark theme, **When** captured, **Then** it matches
   `variantF_dark_*.png` in the same way.
3. **Given** the left panel is not the active panel, **When** captured, **Then** the active tab
   uses the inactive caption colours (`variantF_*_inactive.png`).
4. **Given** the mouse over an inactive tab, over the active tab's close glyph, or over the plus
   button, **When** captured, **Then** the hover pill, the close circle or the plus circle appear
   as in the `hovertab`, `hoverclose`, `hoverplus` images.

---

### User Story 2 - A tab shows where it points (Priority: P1)

Each tab shows a 16-px icon before its title: a drive icon for a drive root, a folder icon for a
folder, the archive icon for a location inside an archive, the plug-in's icon for a plug-in file
system. Tabs whose names are shortened can be told apart.

**Why this priority**: part of variant F (the images show the icons).

**Independent Test**: tabs on a folder, a drive root, an archive path and a plug-in file system
path; each shows its icon; no tab paint waits on a disk or network.

**Acceptance Scenarios**:

1. **Given** a tab on `E:\`, **When** painted, **Then** it shows the drive icon the program uses
   for that drive elsewhere.
2. **Given** a tab on a folder, **When** painted, **Then** it shows the program's folder icon.
3. **Given** a remembered tab on an unreachable network path, **When** the strip is painted,
   **Then** painting does not touch that path (a generic icon from the location type).

---

### User Story 3 - Dragging a tab moves it live (Priority: P2)

Pressing a tab activates it as today. Once the mouse moves past the system drag threshold the
grabbed tab follows the cursor horizontally (held where it was grabbed, drawn on top, kept inside
the tab area); neighbours slide aside with a short ease-out (about 150 ms) when the dragged tab's
centre crosses theirs; on release the tab glides into its slot and the order changes once. Esc,
losing the mouse capture or a cancel-mode message cancel the drag and the tabs glide back. Moving
above or below the strip keeps the tab in it. With Windows animation effects off the tabs jump.
With the overflow list button shown, dragging stays within the visible run.

**Why this priority**: the maintainer's Chrome wish; reordering already works, this changes how.

**Independent Test**: posted mouse messages on the hidden desktop: press tab 0, move past the
threshold to the place of tab 2, release - order changes once; a drag cancelled by taking the
capture leaves the order unchanged.

**Acceptance Scenarios**:

1. **Given** tabs A B C D, **When** A is dragged past C's centre and released, **Then** the
   order is B C A D (one `MoveTab`, persistence unchanged).
2. **Given** a drag in progress, **When** the capture is lost or `WM_CANCELMODE` arrives,
   **Then** the order is unchanged.
3. **Given** a drag in progress, **When** the cursor leaves the strip vertically, **Then** the tab
   stays in the strip (no tear-off).

---

### User Story 4 - Close on release (Priority: P2)

A press on a tab's X never switches or drags the tab; it shows the X pressed (the hover circle,
darker). The tab closes only when the left button is released over the same X. Moving off shows it
unpressed and a release there does nothing; moving back presses it again. Middle-click close stays
on button up.

**Why this priority**: a slipped press can no longer close a tab by accident.

**Independent Test**: posted `WM_LBUTTONDOWN` on the X without an up - the tab is still there;
then `WM_LBUTTONUP` on the X - it closes; a down on the X, a move off and an up off the X - nothing.

**Acceptance Scenarios**:

1. **Given** two tabs, **When** the left button goes down on the X of tab 1, **Then** the tab
   count stays 2 and the active tab does not change.
2. **When** the button is then released over the same X, **Then** tab 1 closes.
3. **Given** a press on the X, **When** the mouse moves off it and the button is released there,
   **Then** nothing closes.

---

### User Story 5 - Move a tab to the other panel; open the other panel's location as a tab (Priority: P2)

The tab context menu gains *Move to Other Panel* (after *Duplicate Tab*) and *New Tab as Other
Panel* (after *New Tab*). Move closes the tab here and opens it in the other panel as its active
tab at the end of its tabs, with the same location, view, sort and filter; the other panel opens it
first, and only then is it closed here; a refused close here (archive or plug-in leave rules)
removes the new tab there again and both panels stay as they were; a moved tab is not offered by
Reopen Closed Tab. New Tab as Other Panel opens, in this panel, a new tab at the location the
other panel shows now, with the view, sort and filter that *New Tab* gives.

**Why this priority**: the maintainer's own wish; built from existing pieces.

**Independent Test**: the probe runs both commands (the commands the menu posts) and checks the
tab lists of both panels; a refused leave keeps both panels unchanged.

**Acceptance Scenarios**:

1. **Given** left tabs A B (B active) and right tab R, **When** *Move to Other Panel* runs on A,
   **Then** left holds B, right holds R A with A active, and Reopen Closed Tab in the left panel
   has nothing new.
2. **Given** a single tab in this panel, or the menu opened on the empty strip, **Then**
   *Move to Other Panel* is greyed (tabs are shown in both panels or in neither).
3. **Given** the right panel shows R, **When** *New Tab as Other Panel* runs in the left panel,
   **Then** the left panel gets a new active tab on R.
4. **Given** the leave of the moved active tab is refused, **When** Move runs, **Then** both panels
   keep their tabs and active tabs.

### Edge Cases

- A narrow strip (overflow list button shown): live drag stays within the visible run; the list
  button and its menu keep working.
- A single tab: no close glyph, no drag, Move to Other Panel greyed.
- Tabs off (*Show tabs in panels* off): no strip, nothing of this feature runs.
- A press on the X followed by losing the capture (a menu, another window): the press is forgotten
  and nothing closes.
- A right-button press during a drag cancels it (as today).
- 125 % / 150 % DPI: every metric scales; the icon size is the program's DPI icon size.
- High Contrast: colours come from the system colours; texts stay readable.
- The moved tab's location is a plug-in file system (e.g. SFTP): the other panel opens it the way
  *Duplicate Tab* would, with its own connection.

## Requirements *(mandatory)*

### Functional Requirements

**Look (variant F)** - values in pixels at 96 DPI, scaled at other DPI:

- **FR-001**: The strip height MUST be `2 + font height + 2 + 2 + 8` (29 px at 96 DPI with
  Segoe UI 9 pt). Text, icon, X and + MUST be centred vertically in the area from y = 3 to the
  bottom. The first tab MUST start 8 px from the left. There MUST be no baseline line.
- **FR-002**: The strip background MUST be the button face colour mixed 22 % toward the button
  shadow colour (50 % in the Dark theme).
- **FR-003**: The active tab MUST be a rounded tab (top corners radius 6, outward bottom feet
  radius 6) from y = 3 to the bottom, filled with the active caption background in the active
  panel while the window is active, else the inactive caption background, its text in the
  matching caption foreground; it MUST be painted after the other tabs.
- **FR-004**: Inactive tabs MUST have no background; their text MUST be the button text colour
  mixed 38 % (Dark 30 %) toward the strip background.
- **FR-005**: A hovered inactive tab MUST show a rounded rectangle (radius 5; x from the tab's
  left + 3 to its right - 2; y 4 .. H - 3) in the strip background mixed 7 % (Dark 10 %) toward
  the button text colour, with its text in the button text colour.
- **FR-006**: A 1-px separator MUST stand between two tabs that are neither active nor hovered,
  at y `8 + g .. H - 6 - g` with `g = (H - 25) / 2`; colour button shadow mixed 30 % toward the
  strip background (Dark: the button highlight colour).
- **FR-007**: Padding: icon (or text) 10 px from the tab's left edge; 16-px icon then a 6-px gap;
  the 8-px close glyph box ends 8 px before the right edge; the title ends 6 px before the glyph.
  Tab width limits: 6 / 20 average characters + 2 x 10 + 8 + 16 + 6.
- **FR-008**: Glyphs MUST be anti-aliased: close = X of half size 3.5 and stroke 1.2, 25 % toward
  the background, full colour on hover, with a 16-px circle 14 % (Dark 20 %) toward the
  foreground on hover; plus = half size 4.5 in the inactive-text colour (button text on hover),
  with an 18-px circle in the hover colour on hover.
- **FR-009**: Text MUST stay GDI text in the program's environment font (ClearType as today).
- **FR-010**: Hit-testing, middle-click close, tooltips, the overflow list button, the context
  menu and *Show tabs in panels* off MUST behave as before (with the new metrics).

**Icons**:

- **FR-011**: Each tab MUST show the icon of its location type: drive root -> the drive icon the
  program uses for that drive; folder -> the program's folder icon; inside an archive -> the
  archive icon; plug-in file system -> the plug-in's icon (its Change Drive menu icon, else the
  generic plug-in file system icon).
- **FR-012**: Painting MUST never block on a slow or network path: icons are cached and derived
  from the location text and the panel type remembered when the tab was last shown.

**Mouse and menus**:

- **FR-013**: Live reordering as in User Story 3 (threshold `SM_CXDRAG` / `SM_CYDRAG`, follow the
  cursor keeping the grab point, clamp to the tab area, neighbour slide ~150 ms ease-out, glide on
  release, one `MoveTab`, cancel by Esc / capture loss / `WM_CANCELMODE` gliding back, no
  tear-off, no animation with `SPI_GETCLIENTAREAANIMATION` off, visible run only when overflowing).
  No insert mark.
- **FR-014**: Close on release as in User Story 4.
- **FR-015**: *Move to Other Panel* as in User Story 5; greyed when this panel has a single tab,
  on the empty strip, and when the other panel shows no tabs.
- **FR-016**: *New Tab as Other Panel* as in User Story 5; shown on a tab and on the empty strip;
  greyed when the other panel has no location to give.
- **FR-017**: Both commands MUST be `CM_LEFT_*` / `CM_RIGHT_*` commands with new ids; the
  `TabStripMenu` comment for `export_mnu.py` MUST list them.
- **FR-018**: The two new strings MUST use free slots of an existing string bundle; the `.slt`
  files of every enabled language MUST be refreshed in this feature, with pins for the formal
  register in de / fr / nl / es.

**Verification**:

- **FR-019**: A probe on the hidden desktop MUST compare the captured strip with the evidence
  images and drive (posted messages) the drag order, the cancel by capture loss, no close on a
  press without release, close on release, both menu commands and a refused leave. Esc during a
  drag and the feel of the animation are NOT DRIVEN and owed to a person.
- **FR-020**: Pure decisions (slot from the cursor, threshold, target index, order after a drag
  and after a cancel, the enabling rules of the two menu items, the colour mixes and metrics) MUST
  live in `src/common/saltabs.*` under `saltests`.

### Key Entities

- **Tab record** (`CSalTabRecord` / `CPanelTab`): location, view, sort, filter; gains a session-only
  remembered location kind (and drive type) for the icon - never persisted.
- **Drag state** of the strip: pressed tab, grab offset, current slot, per-tab drawn offset and
  animation targets.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For each of the 10 evidence images (5 states x 2 themes), the captured strip differs
  from the image only in edge pixels (the evidence's 3x3 neighbourhood is not uniform) and by at
  most 64 per colour channel there; every pixel of a uniform neighbourhood is equal.
- **SC-002**: The `tabs312_probe` stays at 33 PASS / 0 FAIL.
- **SC-003**: Every driven mouse/menu row of the probe passes; before the change the close-on-press
  and the menu rows fail (negative control).
- **SC-004**: `saltests` gains checks for every pure rule of FR-020 and stays at 0 failed.
- **SC-005**: Painting the strip performs no file system call on a background tab's location.

## Assumptions

- Assumption (autonomous run): the classic look is not kept as an option - the item asks to keep it
  only if the implementation finds a reason, and none was found (one look, as with every other
  0.2 surface).
- Assumption (autonomous run): the two new commands are only in the strip's context menu (no
  `CM_ACTIVE_*`, the Left / Right *Tabs* submenus unchanged) - the item makes the submenus optional;
  the conservative choice changes the fewest menus and strings.
- Assumption (autonomous run): Esc during a drag is detected by checking `GetAsyncKeyState(VK_ESCAPE)`
  in the drag's animation timer (the strip never has the focus); recorded in the fix-log.
- Assumption (autonomous run, item Notes): a moved tab goes to the end of the other panel's tabs and
  becomes active there; which panel is active afterwards follows the existing `SwitchToTab` rules;
  *New Tab as Other Panel* copies only the location.
- Assumption (autonomous run): tabs are shown in both panels or in neither (one option), so "the
  other panel shows no tabs" means the option is off - then no strip and no menu exist.
- Assumption (autonomous run): under Windows High Contrast the mixes are skipped (plain system
  colours: inactive text = button text, hover and separators in system colours), so the strip stays
  readable.
- The strip is 8 px higher than today (a panel shows about half a list row less) - accepted by the
  maintainer.
- The 078 GUI driver (`drive.ps1`) was never committed; `tabs312_probe` and this feature's probe
  stand for it.
- A person judges the final look on a real screen (hover with a real mouse, Dark, 125 / 150 % DPI,
  High Contrast) - lines of the release checklist.
