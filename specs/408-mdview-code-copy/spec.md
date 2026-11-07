# Feature Specification: Markdown Viewer — copy a code block to the clipboard

**Feature Branch**: `408-mdview-code-copy`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item drobna-uprava-markdown-preview — Markdown Viewer: a button to copy a code block to the clipboard (GitHub issue #20)." From backlog item drobna-uprava-markdown-preview.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copy a code block with one click (Priority: P1)

A user reads a Markdown file (README, notes, documentation) in the Markdown Viewer
(F3). The document shows a command or a code sample in a code block. The user moves
the mouse over the block, a small *Copy* control appears in the block's top-right
corner, the user clicks it, and the block's code is on the clipboard, ready to paste
into a terminal or an editor. A short confirmation (*Copied*) shows that it worked.

**Why this priority**: it is the whole request of GitHub issue #20; without it the
user must select the text by mouse, which is error-prone for long or scrolled blocks.

**Independent Test**: open a Markdown file with a fenced code block, activate the
control, paste into Notepad: the pasted text is exactly the code between the fences.

**Acceptance Scenarios**:

1. **Given** a document with a fenced code block in a language the viewer highlights,
   **When** the user activates the block's *Copy* control, **Then** the clipboard holds
   the code as written in the Markdown (no colours, no markup), with its line breaks,
   and nothing else.
2. **Given** a document with several code blocks, **When** the user activates the
   control of the third block, **Then** the clipboard holds the third block's code.
3. **Given** a successful copy, **When** it happens, **Then** a brief *Copied*
   confirmation is shown and disappears by itself, and the page does not scroll.
4. **Given** the mouse is not over a block and the control has no focus, **Then** the
   control is not visible and the document looks as before.

---

### User Story 2 - Keyboard and themes (Priority: P2)

A keyboard user moves through the document's links with Tab; the code block's
control receives focus, becomes visible, and Enter copies the block. The control is
readable in the Default and Dark colour schemes.

**Why this priority**: accessibility and theme consistency of the new control
(constitution, UI consistency).

**Independent Test**: Tab to the control, press Enter, paste; switch the colour scheme
(F9) and check the control's look.

**Acceptance Scenarios**:

1. **Given** the control has keyboard focus, **Then** it is visible; **When** Enter is
   pressed, **Then** the block is copied as in User Story 1.
2. **Given** the Dark scheme, **Then** the control and the confirmation are readable
   against the code block and the page.

---

### User Story 3 - The viewer stays locked down (Priority: P1)

The Markdown Viewer shows documents from anywhere (downloads, archives, the network).
Its safety comes from running no script and talking to nothing (feature 021). The copy
control must not weaken that: no script, no messages from the page, and a document
must not be able to fill the clipboard on its own or through a link it writes itself.

**Why this priority**: a security property the item makes a condition; changing it is
the maintainer's decision, which this feature does not assume.

**Independent Test**: inspect the served document and the viewer's configuration
(scripts and web messages off, the content policy unchanged); a document containing its
own link to a copy address does not copy anything when clicked.

**Acceptance Scenarios**:

1. **Given** the feature is in place, **Then** the viewer's scripts and web messages
   are still off and the shared WebView2 host is unchanged.
2. **Given** a document that writes its own link (Markdown or raw HTML) to an address
   that looks like a copy address, **When** the user clicks it, **Then** nothing is
   copied and no message box or browser opens.
3. **Given** a document that tries to navigate by itself (a refresh), **Then** nothing
   is copied (only a navigation the user started is acted upon).

### Edge Cases

- A code block inside a list item or a block quote: its control copies the code without
  the list or quote indentation markers.
- An indented (four-space) code block: the code without the four-space indentation.
- An empty code block: the control is shown and copies an empty text; the confirmation
  is shown.
- A code block whose last line ends the block: the copied text does not end with an
  extra line break that the block does not show.
- Non-ASCII code (Czech, CJK, emoji): copied as Unicode, exactly.
- A NUL character in the Markdown source: copied as the replacement character the page
  shows.
- The clipboard is busy (another program holds it): no *Copied* confirmation; nothing
  else happens.
- View Source mode (Ctrl+U) shows the whole file as text: no copy controls there.
- Raw HTML `<pre>` written by the document itself is not a Markdown code block: no
  control.
- Find (Ctrl+F) highlighting, page width levels and colour schemes keep working; a
  find after a copy still jumps to its match.
- A document re-rendered (scheme change, find, remote images allowed) while the old page
  is shown: a click on the old page's control copies nothing wrong — at most nothing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every fenced or indented code block of the rendered Markdown document
  MUST carry a *Copy* control in its top-right corner.
- **FR-002**: The control MUST be invisible until the pointer is over its code block or
  the control has keyboard focus; it MUST be reachable by keyboard (Tab) and activated
  by click or Enter.
- **FR-003**: Activating the control MUST put the block's source text on the clipboard
  as Unicode text: the code content as the Markdown defines it, without highlighting,
  with each line break kept (as the Windows line break), without the line break that
  closes the block's last line, and nothing else.
- **FR-004**: After a successful copy the viewer MUST show a brief *Copied*
  confirmation that disappears by itself and MUST NOT scroll or reload the page.
- **FR-005**: A failed copy (clipboard unavailable) MUST NOT show the confirmation.
- **FR-006**: The viewer MUST stay script-free and send no web messages; the shared
  WebView2 host MUST NOT be copied, forked or relaxed.
- **FR-007**: Only an activation the user started MUST copy, and only through the
  control the viewer generated for the current window: a copy address written by the
  document itself MUST copy nothing and MUST NOT fall through to another link action
  (message box, browser, another viewer).
- **FR-008**: The control's label, tooltip and the confirmation MUST be localized UI
  texts of the Markdown Viewer, in every shipped language.
- **FR-009**: The control and the confirmation MUST be readable in every colour scheme
  of the viewer (light and dark).
- **FR-010**: Documents without code blocks MUST render as before; View Source mode
  MUST show no control.
- **FR-011**: Existing link behaviour (in-document anchors, `.md` links, other local
  targets, http/https/mailto) MUST be unchanged.

### Key Entities

- **Code block source table**: for each rendered code block, in document order, its
  source text; the control of block *n* refers to entry *n* of the table of the
  document currently shown.
- **Copy address**: the address the control activates; it carries a token unknown to
  the document and the block number.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a fixture of code blocks (fenced with and without a language,
  indented, in a list, in a quote, empty, non-ASCII), the copied text equals the
  expected code exactly in 100% of the cases.
- **SC-002**: Copying a block takes one click (or Tab + Enter) and the confirmation
  appears within one second.
- **SC-003**: The page's scroll position is the same before and after a copy.
- **SC-004**: A document's own copy-looking links copy nothing in 100% of the tested
  forms (Markdown link, raw HTML link, wrong token, out-of-range number).
- **SC-005**: The generator's existing assertions all still pass and a document
  without code blocks is unchanged byte for byte.

## Assumptions

- Assumption (autonomous run): the host's existing hook for a user-initiated
  navigation outside the document (feature 085) is how the control reaches the viewer;
  the shared host needs no change (measured at 924e7c82, see the item's measurement).
- Assumption (autonomous run): the copied text uses the Windows line break (CR LF) for
  every line break, as the Code Viewer's copy does; the Markdown parser does not keep
  the file's own line-break form, and the Windows clipboard convention is CR LF.
- Assumption (autonomous run): the line break that ends a block's last line is not
  copied (the block shows no empty last line; documentation sites copy the same way).
- Assumption (autonomous run): the confirmation is a small notice in a corner of the
  viewer rather than the control's own text changing, if the control's own text cannot
  change without scrolling or reloading the page under the script-free lockdown.
- Assumption (autonomous run): if the operating system's random generator fails when
  the window opens, the window shows no copy controls (fail closed) rather than a
  guessable address.
- Clipboard content on a real desktop and the control's look are a person's check
  (no real clipboard on the hidden desktop); probes use a Debug-only seam instead.
