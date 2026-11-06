# Feature Specification: Registry Editor - Move of an HKCR key held by both halves

**Feature Branch**: `406-regedt-hkcr-both-halves`
**Created**: 2026-11-07
**Status**: Draft
**Input**: Backlog item `registry-editor-hkcr-move-both-halves-leaves-machine-half` - "Registry Editor: Move of an HKCR key held by both halves leaves its machine half". From backlog item registry-editor-hkcr-move-both-halves-leaves-machine-half.

## Background (measured at 8bb3c295)

`HKEY_CLASSES_ROOT` (HKCR) is a merged view of the machine's classes (`HKLM\Software\Classes`)
and the user's classes (`HKCU\Software\Classes`). A key can exist in both halves. Measured, not
elevated, with a user's half created for the machine key `HKCR\.386`:

- the merged view lists the values of both halves; a value of the same name in the user's half
  **hides** the machine's (the machine's `PerceivedType = system` was invisible);
- deleting `.386\PersistentHandler` and then `.386` through HKCR succeeds and removes **only the
  user's half**; the machine's half stays and HKCR still shows the key.

The Registry Editor's Move (F6, drag and drop) of such a key copies the merged contents to the
target and then deletes the source through HKCR. Hidden-desktop probe (`probe/hkcr406_probe.ps1`)
on the build of 8bb3c295: no message at all, the copy is complete, the user's half of the source is
deleted, the machine's half is left - a partial Move reported as success, **even without
elevation** (6 PASS / 7 FAIL). Feature 390 fixed the case of a key held by one half only.

## Clarifications

### Session 2026-11-07

- Q: When the machine's half cannot be deleted, should the user's half still be deleted? → A: No - the machine's half is deleted first; when it fails or is refused, nothing of that key is deleted (the merged view of the source stays as it was), the box tells which key and why (autonomous run: conservative)
- Q: Does the hidden-value check (FR-003) also apply to a key held only by the machine's half (feature 390)? → A: No - 390's case had no user's half before the copy, so the copy holds all of it; 390's behaviour stays unchanged (autonomous run: rule - FR-006, keep the existing behaviour for every case the item does not name)
- Q: Are two values "the same" when their text differs only in letter case or a trailing NUL? → A: No - same type, same size, same bytes; anything else counts as hidden (refuses more, never deletes data not copied) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Move of a key held by both halves is complete or says why not (Priority: P1)

A user moves (F6) a key shown under `HKEY_CLASSES_ROOT` that both the machine's and the user's
classes hold to another place. Either both halves of the source are removed after the copy, or the
user is told, in the existing "Unable to remove the original registry key." box, which real key
could not be removed and why.

**Why this priority**: it is the whole item - a Move that leaves half of its source while reporting
success misleads the user about the state of the registry.

**Independent Test**: the probe's rows BOTHMOVE / BOTHSKIP (not elevated): the first box names
`HKEY_LOCAL_MACHINE\Software\Classes\<key>\<subkey>` with "access denied"; the copy equals the merged
view; both halves of the source are unchanged.

**Acceptance Scenarios**:

1. **Given** a key held by both halves and a user who may not delete the machine's half (not
   elevated), **When** the user moves it elsewhere and answers Cancel, **Then** the copy holds the
   merged contents, the box "Unable to remove the original registry key." names the machine's key
   by its real path with the access-denied error, and nothing of the source is deleted.
2. **Given** the same, **When** the user answers Skip, **Then** exactly that key is kept, its parent
   keys are kept too (a skipped subkey keeps its parents), no further box for the parent.
3. **Given** a key held by both halves and a user who may delete both (elevated), **When** the user
   moves it, **Then** both halves of every moved key are removed and HKCR no longer shows it (owed to
   a person: the probe never runs elevated).

---

### User Story 2 - The machine's half is never deleted while it holds data the copy did not take (Priority: P1)

The machine's half of a key may hold a value whose name also exists in the user's half with other
contents (or another class name); the merged view - and so the copy - shows only the user's. Deleting
the machine's half would destroy the machine's value without any copy.

**Why this priority**: the project's rule "never lose the user's data"; deleting both halves without
this check would turn an incomplete Move into data loss for an elevated user.

**Independent Test**: probe row BOTHSHADOW: the user's subkey holds its own (default) value; the
first box names the machine's subkey with "The request is not supported." (50); both halves unchanged.

**Acceptance Scenarios**:

1. **Given** a key held by both halves whose machine's half holds a value hidden by a different
   user's value of the same name, **When** the user moves it, **Then** the machine's half is not
   deleted: the existing "Unable to remove the original registry key." box names it by its real path
   with "The request is not supported."; Retry checks again, Skip keeps it (and its parents), Cancel
   stops.
2. **Given** a value of the same name in both halves with identical type and data, **When** moved,
   **Then** it is not a reason to refuse (the copy holds it).

---

### User Story 3 - Nothing else changes (Priority: P2)

Moves of HKCR keys held by one half (feature 390), of keys under any other root, copies, Delete,
Quick Rename and the refusals of features 292 / 294 / 296 / 297 / 391 behave as before.

**Independent Test**: the probes of 390, 292, 294, 296 and 297 pass unchanged; probe row BOTHSELF
(Move of the key into its own user's half) is still refused by 292's "Can't move a key to itself.".

## Edge Cases

- **Order**: the machine's half is deleted first, then the user's half. When the machine's half
  cannot be deleted (the usual case without elevation) nothing of that key is deleted, so the merged
  view of the source is unchanged; when the user's half then fails, the box names
  `HKEY_CURRENT_USER\Software\Classes\...` and Retry deletes only that half again.
- **A half disappears meanwhile** (deleted by another program between the copy and the delete): the
  error of that delete is shown in the box (not found) - Skip / Cancel as usual. No special case.
- **Access denied when reading the machine's half for the check**: fails closed - the box with that
  error, the machine's half not deleted.
- **Real path too long for the box**: the box names the HKCR key (as 390 does).
- **Neither half found** (only reachable through links): the old delete through HKCR stays.
- **The Move into the key's own user's half** is refused by 292 before anything is written - unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A Move whose source is an HKCR key held by both halves MUST, after the key's contents
  and subkeys were copied without a skip, delete the machine's half
  (`HKEY_LOCAL_MACHINE\Software\Classes\<key>`) and then the user's half
  (`HKEY_CURRENT_USER\Software\Classes\<key>`), each by its real path - never through HKCR.
- **FR-002**: Every failure of FR-001 MUST be shown in the existing `IDS_REMOVESOURCE` box ("Unable to
  remove the original registry key.") naming the real key, with Retry / Skip / Skip All / Cancel as
  today; Retry repeats only the half that failed; Skip keeps the key and its parents.
- **FR-003**: Before deleting the machine's half, the Move MUST check that the copy holds all of it:
  every value of the machine's half either has no value of the same name in the user's half, or one
  of the same type and the same bytes; and the class names of both halves are equal (ignoring case,
  as the copy's own class-name test). Otherwise the machine's half is refused with the same box and
  the error "The request is not supported." (as feature 297 refuses a link); an error while reading
  for the check is shown in the box (fails closed).
- **FR-004**: The pure decision (which halves, in which order; whether two values are the same) MUST
  live in `src/common/salregkeyid.h` with `saltests` checks.
- **FR-005**: No new UI string, no dialog change, no plug-in interface change.
- **FR-006**: Moves of HKCR keys held by one half (390), of other roots, and every other operation
  MUST behave as before.

### Key Entities

- **The halves of an HKCR key**: the machine's key `HKLM\Software\Classes\<path>` and the user's key
  `HKCU\Software\Classes\<path>`; which exist is read before the key is copied (390).
- **A hidden machine value**: a value of the machine's half whose name the user's half also holds with
  another type or other data - the merged view, and so the copy, holds only the user's.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows BOTHMOVE, BOTHSKIP, BOTHSHADOW: 7 FAIL before -> all PASS after (English and
  Czech); BOTHSELF stays PASS.
- **SC-002**: 0 cases where a Move of a key held by both halves ends without a box while a half of the
  source remains (probe rows, not elevated).
- **SC-003**: The probes of 390 (10 rows), 292, 294, 296, 297 show no new FAIL.
- **SC-004**: `saltests` 0 failed, with new checks of the both-halves decision and the value comparison.

## Assumptions

- Assumption (autonomous run): the item offers "remove both halves" or "refuse with a message"; both
  halves are removed (the item's first option), with the machine's half refused when it holds data the
  copy did not take (FR-003) - the rule "never lose the user's data" decides that a hidden machine
  value is never deleted.
- Assumption (autonomous run): the refusal uses the existing box with `ERROR_NOT_SUPPORTED` (feature
  297's precedent) - no new string, so no translation refresh.
- Assumption (autonomous run): the elevated success path (both halves really removed) cannot be driven
  by the probe (it never runs elevated, it would delete a real machine key); it is a line of the
  release checklist, as 390's elevated case.
