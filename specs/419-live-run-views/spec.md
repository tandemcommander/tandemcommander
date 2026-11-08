# Feature Specification: Backlog app live run: one switchable view at a time, no page scrolling

**Feature Branch**: `419-live-run-views`
**Created**: 2026-11-08
**Status**: Draft
**Input**: User description: "Backlog item backlog-app-live-run-switchable-views (backlog/items/backlog-app-live-run-switchable-views/desc.md) - implement exactly what it describes." From backlog item backlog-app-live-run-switchable-views.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The page never scrolls; one scrollbar per view (Priority: P1)

The maintainer opens the backlog app's *Live run* page while the loop works on an item. The page fits the window
under the app's top bar: the page itself never scrolls. A row of views (tabs) sits at the top. The chosen view
fills the rest of the window and, when its content is longer than the window, scrolls inside itself with one
scrollbar. There are never two vertical scrollbars on top of each other.

**Why this priority**: the maintainer's main complaint. Measured at cbf0cf1f: the page scrolled on every view
at every window size (57 to 982 px), and the story and the raw transcript added a second scrollbar inside it.

**Independent Test**: with a long live run, open every view at 1920x1200, 1280x800, 1024x700 and 820x640. The
page has nothing to scroll, and each view shows at most one vertical scroll area.

**Acceptance Scenarios**:

1. **Given** a live run with a long story, **When** the Story view is shown at any measured size, **Then** the
   page does not scroll and the story list is the only vertical scroll area, ending at the window's bottom
   edge.
2. **Given** the same run, **When** Raw trace is shown, **Then** the transcript list is the only scroll area.
3. **Given** the same run, **When** Overview, Critical, Decisions, Gallery, Architecture, Files or Documents is
   shown and its content is taller than the space left, **Then** that view scrolls in one area of its own and
   the page stays still.
4. **Given** an opened story line with a long detail, or the agent's long latest message on Overview, **When**
   it is shown, **Then** it grows inside its view's one scroll area and opens no second scroll area.

---

### User Story 2 - Every part is a switchable view, the chat at full width (Priority: P1)

The overview of the run (progress head, what happens now, live figures) and the chat with Claude about the run
are views of their own in the same row as Story, Critical, Decisions, Gallery, Architecture, Files, Documents
and Raw trace. Only one view is shown at a time. The chat view uses the whole width of the page: the
conversation scrolls inside its own log and the composer stays at the bottom.

**Why this priority**: the maintainer's request: "there is too much information on the page now; switching
between everything is enough for me". Below 1280 px the chat used to cover the right part of the page (9 of 32
measured view/size cases could not be reached without closing it).

**Independent Test**: open the live page. The first view is Overview. Switching to Chat shows the conversation
across the full width. A ready question is sent, the answer appears in the log, and nothing outside the log
moves.

**Acceptance Scenarios**:

1. **Given** a live run, **When** the page opens, **Then** the row of views holds Overview, Story, Critical,
   Decisions, Gallery, Architecture, Files, Documents, Raw trace and Chat, and Overview is shown.
2. **Given** the Chat view, **When** a message is sent and answered, **Then** the log scrolls to the answer, and
   the page and the other views do not move.
3. **Given** a draft typed in the chat, **When** the maintainer switches to Story and back, **Then** the draft is
   still there.
4. **Given** the Chat view is not shown, **When** Claude's answer arrives, **Then** the Chat tab shows that
   something new waits there until the Chat view is opened.
5. **Given** an ended run's page, **When** it opens, **Then** it has the same views without Chat (the
   conversation belongs to an item that is running).
6. **Given** any view at 1024x700 or 820x640, **When** the maintainer clicks any other tab, **Then** the click
   reaches it (nothing covers the row of views).

---

### User Story 3 - Where the run is stays in sight, and the chosen view is kept (Priority: P2)

While another view is shown, one compact line above the views says which item runs, its step, the percentage,
the elapsed time and the expected remaining time. The chosen view is part of the page's address, so a reload,
the browser's Back button or a copied link opens the same view.

**Why this priority**: with the overview moved into its own view, the maintainer reading the story or chatting
must still see at a glance how far the run is.

**Independent Test**: on the Story view, the compact line shows the item's title and the percentage. Reloading
the page on Documents opens Documents again.

**Acceptance Scenarios**:

1. **Given** the Story or Chat view of a live run, **When** the run moves on, **Then** the compact line's step,
   percentage and times follow it.
2. **Given** the page opened with an unknown or unavailable view in its address (e.g. Chat on an ended run),
   **When** it loads, **Then** Overview is shown.

### Edge Cases

- No run in progress: the *Live run* page keeps its short message (what the loop does, which item it would
  take). It is short and needs no scrolling rule.
- A run without a trace (journal row only): the run page keeps its summary; it has no views.
- The connection to the app is lost or the write gate is closed: the banners above the page take their height,
  and the views get the rest. The page still does not scroll.
- The window is so narrow that the tabs wrap onto two rows: the views get the rest of the height.
- The gallery's full-screen viewer and the raw trace's event dialog are overlays above the page. They keep their
  own behaviour.
- The conversation page in its own window (feature 371) shares the chat's scrolling fix: a new answer scrolls
  only the conversation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The *Live run* page and the page of a run with a trace MUST fit the window below the app's top bar
  and banners. The page itself MUST have nothing to scroll at 1920x1200, 1280x800, 1024x700 and 820x640.
- **FR-002**: All parts of the run dashboard MUST be views in one row of tabs, in this order: Overview, Story,
  Critical, Decisions, Gallery, Architecture, Files, Documents, Raw trace, and Chat (Chat only while the run's
  item runs). Only the chosen view is shown.
- **FR-003**: Overview MUST hold the progress head, what happens now and the live figures, with the accessible
  names they had (*Run progress*, *What happens now*, *Live figures*).
- **FR-004**: The chosen view MUST fill the height left below the tab row. Each view MUST have at most one
  visible vertical scroll area. Story and Raw trace MUST use their lists as that area. The other views scroll
  as a whole.
- **FR-005**: An opened story line's detail, the agent's latest message on Overview and the tool-use list of a
  chat answer MUST NOT open a scroll area of their own.
- **FR-006**: Chat MUST use the full width of the page. Its log is its only scroll area, and the composer with
  the ready questions stays below the log.
- **FR-007**: A chat update MUST scroll only the conversation's log, never the page or another element. This
  applies on the live page and in the conversation's own window.
- **FR-008**: The chat MUST stay mounted while another view is shown: a draft and a running answer survive a
  view switch.
- **FR-009**: When a chat answer arrives or finishes while the Chat view is not shown, the Chat tab MUST show a
  mark until the Chat view is opened.
- **FR-010**: Above the tab row, one compact line MUST show the item's title (or its slug), the current step,
  the percentage, the elapsed time and the expected remaining time, for a live run and for an ended one.
- **FR-011**: The chosen view MUST be kept in the page's address. A reload or link MUST open it. An unknown or
  unavailable view MUST fall back to Overview.
- **FR-012**: Nothing the 415 dashboard showed may be lost. Every region, list, tab and button keeps its
  accessible name, and both themes pass the accessibility check without a serious or critical finding.
- **FR-013**: The chat's former column and its open / close button (with its remembered state) MUST be removed,
  so nothing covers the page at any width.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across all 10 views at the 4 measured window sizes (40 cases on a live run), the page scrolls by 0
  px in every case. Before: it scrolled in all 23 reachable cases, by 57 to 982 px.
- **SC-002**: In every one of those cases, at most one vertical scroll area is visible, and none sits inside
  another. Before: 2 on Story and Raw trace in every reachable case, counting the page.
- **SC-003**: Every view is reachable with one click at every measured size. Before: 9 of 32 cases were covered
  by the chat.
- **SC-004**: After a chat answer, the page has moved by 0 px.
- **SC-005**: The existing end-to-end tests of the live dashboard (415) and of the conversation (371) pass, as
  does the accessibility check in both themes.

## Assumptions

- Assumption (autonomous run): the window sizes the app supports for this rule are the four measured sizes,
  down to 820x640. A smaller window may make a view's single scroll area very short, but the page still does
  not scroll.
- Assumption (autonomous run): the default view is Overview (the item's *Approach*). A view chosen earlier is
  kept only in the address, not in browser storage.
- Assumption (autonomous run): the optional mark on the Chat tab (item *Approach*) is included (FR-009),
  because it is cheap and replaces the always-visible chat.
- Only the web client of the backlog app changes. The server, the trace folding and the chat service are
  unchanged.
