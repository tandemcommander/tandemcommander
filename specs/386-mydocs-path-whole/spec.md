# Feature Specification: The Documents folder is opened whole, never cut

**Feature Branch**: `386-mydocs-path-whole`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item my-documents-drive-opens-a-cut-path-when-documents-needs - implement exactly what it describes." From backlog item my-documents-drive-opens-a-cut-path-when-documents-needs.

## Clarifications

### Session 2026-11-02

- Q: When the Documents path exists but does not fit the asking part's buffer, is the Desktop used instead or is the request refused? → A: refused ("not available"); the Desktop is used only when Documents has no file-system path (autonomous run: item)
- Q: Should the rescue path ("If the path is inaccessible, go to Documents") be widened to hold a long Documents path? → A: no; it keeps its 260-byte limit and takes its existing fallback (widening touches the settings layout and the plug-in configuration value, maintainer-owned) (autonomous run: conservative)
- Q: Should the Documents drive and Ctrl+; show a message when the Documents path is refused? → A: no new message; they hold every path the system reports, so a refusal cannot occur there, and on any other failure they keep their existing silent route (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Documents drive opens the Documents folder (Priority: P1)

A user whose Documents folder has a long name in letters that need several bytes each (for example
a Documents folder inside a folder named with 90 Chinese letters: fewer than 260 characters, but
more than 259 bytes in the program's internal UTF-8 form) presses the Documents button of the
drive bar, picks *Documents* in the Alt+F1 / Alt+F2 drive menu, or presses Ctrl+; in a panel.
Today the panel opens a folder whose name is the first part of the real one (the path is cut at
259 bytes) - another folder, or an error about a folder that does not exist. The panel must open
the Documents folder itself.

**Why this priority**: it is the defect the item describes: an action named "Documents" opens
another folder silently.

**Independent Test**: a Debug build started with a probe seam that names a long Documents folder;
the drive bar's Documents button is pressed; the panel's path is read back.

**Acceptance Scenarios**:

1. **Given** Documents is a folder whose path needs 260 or more bytes of UTF-8 but fewer than 260
   UTF-16 units, **When** the user presses the drive bar's Documents button, **Then** the panel
   shows exactly that folder.
2. **Given** the same Documents folder **and** an existing folder named like its 259-byte prefix,
   **When** the user presses the Documents button, **Then** the panel does not show the prefix
   folder.
3. **Given** a Documents folder with a short path, **When** the user presses the Documents
   button, **Then** the panel shows it (unchanged behaviour).

---

### User Story 2 - Callers with a short buffer refuse instead of cutting (Priority: P2)

Program parts that can hold only a short path (for example the "If the path is inaccessible, go
to Documents" rescue path, whose value is also handed to plug-ins limited to 260 bytes) ask for
the Documents folder. When the Documents path does not fit, they get "not available" and take
their existing fallback; they never get a cut path.

**Why this priority**: the same helper serves them; the rule "a path is never cut" applies to all.

**Independent Test**: code reading of every caller plus the rescue-path row of the probe (a panel
whose drive is not reachable, with the rescue path set to Documents).

**Acceptance Scenarios**:

1. **Given** a long Documents folder (as in story 1) and a panel path whose drive does not exist,
   **When** the panel falls back to the rescue path "Documents", **Then** the panel never shows
   the cut prefix folder (it shows the program's existing fallback, the root of the Windows
   drive).

---

### Edge Cases

- Documents has no file-system path (a virtual or unreachable location): the Desktop is used, as
  today.
- Documents has a path that does not fit the caller's buffer: refused - the Desktop is **not**
  used instead (it would be another folder than the one asked for).
- Documents and Desktop both missing: "not available" as today (the callers' existing routes).
- A Documents path of 260 or more UTF-16 units: the system call that reads it is limited to 259
  units and reports no path; the Desktop is used (existing behaviour, outside this item).
- File Open / Save dialogs that refuse their initial folder fall back to Documents; this initial
  folder is the Documents path whole too.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Asking for the Documents (or Desktop) folder MUST give the whole path or "not
  available"; a path is never cut at the size of the asking part's buffer.
- **FR-002**: When the Documents path exists but does not fit the asking part's buffer, the answer
  MUST be "not available" (the Desktop is not used instead).
- **FR-003**: The Documents drive (drive bar button, Alt+F1 / Alt+F2 menu item) and Ctrl+; MUST
  hold any Documents path the system reports (long-path capable) and open it whole.
- **FR-004**: The fallback initial folder of the File Open / Save dialogs (the wide variants) MUST
  get the Documents path whole.
- **FR-005**: The rescue path ("If the path is inaccessible, go to Documents") keeps its 260-byte
  limit (settings, plug-in interface); for a longer Documents path it MUST take its existing
  fallback (the Windows drive root), never the cut prefix.
- **FR-006**: The internal reading of the folder MUST NOT itself limit the path below what the
  system reports (the 520-byte intermediate buffer goes).
- **FR-007**: A Debug-only probe seam MAY replace the Documents folder the system reports with a
  given path, so that a probe can test the rule without redirecting the user's real Documents.

### Key Entities

- **Documents path**: the user's Documents folder as the system reports it (up to 259 UTF-16
  units, up to 778 bytes of UTF-8).
- **Caller buffer**: the space the asking part has for the path (260 bytes for the rescue path,
  the full long-path size for the drive and dialog callers).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a 90-letter CJK Documents folder, the Documents drive opens that folder in 100%
  of probe runs (before the change: the cut prefix folder).
- **SC-002**: No caller of the helper ever receives a path that is a strict prefix of the real
  Documents path (probe rows and code reading of all callers).
- **SC-003**: Short Documents paths behave exactly as before (control row PASS before and after).

## Assumptions

- Assumption (autonomous run): the rescue path and its consumers (settings page edit field,
  configuration value, plug-in configuration value `SALCFG_IFPATHISINACCESSIBLEGOTO`) stay limited
  to 260 bytes - widening them changes the settings layout and the plug-in interface
  (maintainer-owned); FR-005 (refusal -> existing fallback) meets the item's *Expected*.
- Assumption (autonomous run): the code-page File Open / Save variants already pass the full
  long-path size and convert to the code page themselves; they stay as they are.
- Assumption (autonomous run): a Documents path the system reports as "too long" for the caller
  is not replaced by the Desktop (the item's *Expected*: refused).
- Assumption (autonomous run): the GUI reproduction uses a Debug-only environment seam
  (`TC_PROBE_MYDOCS_PATH`) instead of redirecting the real Documents folder (which would change
  the maintainer's live profile); the seam is committed before the fix so the "before" run shows
  the defect.
- No UI string, dialog or menu changes; no translation refresh is needed.
