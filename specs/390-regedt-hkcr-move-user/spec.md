# Feature Specification: Registry Editor - Move from HKCR into the user's Classes key does nothing

**Feature Branch**: `390-regedt-hkcr-move-user`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item registry-editor-move-from-hkcr-to-user-classes-does-nothing - implement exactly what it describes." From backlog item registry-editor-move-from-hkcr-to-user-classes-does-nothing.

## Background

`HKEY_CLASSES_ROOT` (HKCR) is a merged view of two real keys: the machine's classes
(`HKEY_LOCAL_MACHINE\Software\Classes`) and the user's classes
(`HKEY_CURRENT_USER\Software\Classes`, the same key as `HKEY_USERS\<SID>_Classes`). A key held by
both halves is reached through HKCR as the user's half; deleting through HKCR reaches the user's half
first.

The Registry Editor plug-in's Move (F6, also drag and drop) copies the key and then deletes the
source by its name. When the source is an HKCR key held only by the machine's half and the target is
the user's Classes key, the copy creates the user's half of that very HKCR path - and the delete
through HKCR then removes that new copy instead of the machine's key. Measured at 129136b4 (probe
`hkcr390_probe.ps1`, not elevated, real machine-only key `HKEY_CLASSES_ROOT\.386`, only read): no
box, the user's copy is gone again, the machine's key unchanged - the Move reported success and did
nothing. The same through `\HKEY_USERS\<SID>_Classes\`. Nothing is lost.

## Clarifications

### Session 2026-11-02

- Q: Should such a Move delete the machine's half it copied, or be refused before anything is copied? → A: Delete the half that held the key before the copy, by its real path; without elevation the existing "Unable to remove the original registry key." box appears after the copy (autonomous run: recommended - the item allows both; this one makes the elevated Move work and adds no string)
- Q: Should a key held by both halves when it is copied also be deleted by real path? → A: No - such a key keeps today's delete through HKCR (autonomous run: conservative - the item does not name it)
- Q: What happens when it cannot be told which halves hold the key (an open error other than "not found")? → A: The existing open-error box (Retry / Skip / Skip All / Cancel), nothing of that key is copied or deleted (autonomous run: rule - fails closed, CLAUDE.md *Never lose the user's data*)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Move out of the merged view moves, or says why it cannot (Priority: P1)

A user browses `HKEY_CLASSES_ROOT`, selects a key that exists only for the whole machine and moves it
(F6) into `\HKEY_CURRENT_USER\Software\Classes\` (or `\HKEY_USERS\<SID>_Classes\`) to make it a
per-user key.

**Why this priority**: it is the whole item - a function that silently does not work and reports
success.

**Independent Test**: probe row MACHUSER / MACHUSERU on the hidden desktop, not elevated.

**Acceptance Scenarios**:

1. **Given** a key held only by the machine's half, **When** the user moves it from HKCR into the
   user's Classes key without administrator rights, **Then** the copy is made in the user's half and
   the editor tries to delete the machine's key - the existing error box "Unable to remove the
   original registry key." with the access-denied reason names
   `HKEY_LOCAL_MACHINE\Software\Classes\<key>\...`; Cancel leaves the user's copy and the machine's
   key unchanged (an honest copy, never a silent no-op).
2. **Given** the same key, **When** the user does it with administrator rights, **Then** the key ends
   in the user's half and is gone from the machine's half (a real Move).

---

### User Story 2 - Other Moves out of HKCR behave as before (Priority: P2)

Moves of HKCR keys held by the user's half only, to any target, keep moving the key whole and
deleting the source; keys held by both halves keep today's behaviour.

**Why this priority**: regression guard of the changed delete path.

**Independent Test**: probe rows USERMOVE (into `HKCU\Software\...`) and USERCLS (into another key of
`HKCU\Software\Classes`), and the probes of 292 / 294 / 296 / 297.

**Acceptance Scenarios**:

1. **Given** an HKCR key held only by the user's half, **When** it is moved to another HKCU key,
   **Then** it is moved whole without a box and the source is gone.

### Edge Cases

- A key held by both halves at the moment it is copied: deleted through HKCR as today (unchanged;
  not named by the item).
- The key path of the machine's half is longer than the editor can show in a box: the box names the
  HKCR source instead; the path itself is never cut.
- Retry / Skip / Skip All / Cancel in the delete error box behave as for every other delete error
  (Skip keeps the key and its parents in the source).
- Values: a Move of a value between HKCR and one half is already refused (feature 292) - unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A Move whose source is under `HKEY_CLASSES_ROOT` MUST delete, at each key level, the
  half that held that key before the copy of that level wrote anything, when exactly one half held
  it - by that half's real path (`HKEY_LOCAL_MACHINE\Software\Classes\...` or
  `HKEY_CURRENT_USER\Software\Classes\...`), never through the merged view, so the delete can never
  reach the copy just made.
- **FR-002**: When both halves held the key before the copy, the delete MUST stay as today (through
  HKCR).
- **FR-003**: A failure of that delete MUST be shown with the existing "Unable to remove the original
  registry key." box (Retry / Skip / Skip All / Cancel) naming the real key; no new UI text.
- **FR-004**: When the halves cannot be determined (an open error other than "not found"), the Move
  MUST not copy or delete anything of that key: the existing open-error box is shown (fails closed;
  Skip keeps the key and its parents in the source).
- **FR-005**: Moves whose source is not under HKCR, and every Copy, MUST be unchanged.
- **FR-006**: A key path MUST never be cut: a joined path that does not fit is refused, not shortened.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows MACHUSER and MACHUSERU: before the fix FAIL (no box, user's copy deleted),
  after it PASS (the box naming the machine's key, the user's copy equal to the machine's key, the
  machine's key unchanged).
- **SC-002**: Control rows USERMOVE / USERCLS PASS before and after; the probes of features 292, 294,
  296 and 297 keep their results.
- **SC-003**: Build, encoding guard (0 findings) and saltests (0 failed) green.

## Assumptions

- Assumption (autonomous run): of the two outcomes the item allows ("deletes the key it copied" or
  "refused with a message"), the run deletes the half that was copied - it makes the elevated Move
  work and, without elevation, shows the existing error box after the copy (the same outcome as any
  Move whose source cannot be deleted). Conservative: no new string, no new question.
- Assumption (autonomous run): keys held by both halves are not named by the item and keep today's
  delete (rule §1 step 4: keep existing behaviour for every case the item does not name).
- The elevated Move (User Story 1, scenario 2) cannot be driven by the run (the probe never runs
  elevated: it would delete a real machine key); it is owed to a person.
- A Move into a new subkey through `\HKEY_CLASSES_ROOT\` creates it in the machine's half (Windows
  behaviour, measured: access denied without elevation) - existing behaviour, not this item.
