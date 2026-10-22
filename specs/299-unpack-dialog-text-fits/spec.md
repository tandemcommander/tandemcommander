# Feature Specification: The Unpack dialog never cuts a long target path or mask

**Feature Branch**: `299-unpack-dialog-text-fits`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item unpack-with-an-external-unpacker-cuts-a-long-target-path-and (backlog/items/unpack-with-an-external-unpacker-cuts-a-long-target-path-and/desc.md) - implement exactly what it describes. From backlog item unpack-with-an-external-unpacker-cuts-a-long-target-path-and.

## Background

The Unpack command (Alt+F9) on an archive in a disk panel opens the Unpack dialog: a target path
(a combo box offering the panel paths), the unpacker, "Delete archive after unpacking" and the
"Unpack files" mask. The program reads the path and the mask into 260-byte buffers; text whose
UTF-8 form is longer than 259 bytes is cut at a whole character and the cut text is used. The path
field has no length limit at all (even an ASCII path is cut); the mask field limits its text in
UTF-16 units (259), so CJK text (three bytes a letter) passes the field and is cut. Nothing refuses
the text. Features 214 (Copy / Move dialogs) and 291 (masks) fixed the same cut elsewhere by
refusing ("The path specified is too long.").

The item's title says "external unpacker"; measured, the dialog serves every unpacker, the default
ZIP plug-in included.

Measured at 4787b56b (hidden-desktop probe `unpack299_probe.ps1`, the ZIP plug-in unpacking a.zip
holding a.k and a.kp), 3 rows FAIL:
- path-cjk: target "<tgt>\" + CJK letters padded to 258 bytes + "\sub" (262 bytes): a.k and a.kp
  were unpacked into the 258-byte folder - "\sub" cut away - nothing asked.
- path-ascii: the same with an ASCII path of 262 characters: unpacked into the cut folder.
- mask-cjk: mask of 85 CJK letters + ";*.kp" (260 bytes) cut to "...;*.k": a.k unpacked instead of
  a.kp.
Controls (a mask of 259 bytes, a path of 255 bytes) were accepted and unpacked as typed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long target path is refused, never cut (Priority: P1)

A user unpacks an archive with Alt+F9 and types (or pastes) a target path whose UTF-8 form is
longer than 259 bytes, then presses OK. The program shows "The path specified is too long.", the
dialog stays open with the whole text in the path field; nothing is created or unpacked.

**Why this priority**: the files otherwise land in another folder than the one typed (a shorter
path, possibly an existing folder of the user's).

**Independent Test**: probe rows `path-cjk`, `path-ascii`; control `ctl-path`.

**Acceptance Scenarios**:

1. **Given** the Unpack dialog and a target path of more than 259 bytes (CJK or ASCII), **When** OK
   is pressed, **Then** "The path specified is too long." is shown, the dialog stays, the path field
   holds the whole text, and no folder or file appears under the target's parent.
2. **Given** a target path that fits (255 bytes), **When** OK is pressed, **Then** the archive is
   unpacked into exactly that folder, nothing asked - as before.

---

### User Story 2 - A long mask is refused, never cut (Priority: P1)

A user types an "Unpack files" mask whose UTF-8 form is longer than 259 bytes and presses OK. The
program refuses it the same way; the mask field keeps the whole text; nothing is unpacked.

**Why this priority**: a cut mask unpacks other files than the ones asked for.

**Independent Test**: probe row `mask-cjk`; control `ctl`.

**Acceptance Scenarios**:

1. **Given** a mask of more than 259 bytes, **When** OK is pressed, **Then** the refusal, the
   dialog stays, the mask field whole, nothing unpacked.
2. **Given** a mask of exactly 259 bytes, **When** OK is pressed, **Then** the files it names are
   unpacked, nothing asked - as before.

---

### Edge Cases

- Both fields too long: one refusal, for the path field first; after the path is fixed, OK refuses
  the mask.
- The user cancels after a refusal: nothing happens, as with any cancel.
- A path that fits the dialog but fails later (an invalid path, a folder that cannot be created):
  unchanged - the existing errors and the dialog's re-opening stay as they are.
- Text that is not valid UTF-16 (an unpaired surrogate): measured by the same rule as every other
  field (WTF-8 length).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When OK is pressed in the Unpack dialog, the program MUST measure the whole target
  path text and refuse it with "The path specified is too long." when its UTF-8 form does not fit
  the buffer the caller provides (260 bytes with the terminating NUL); the dialog MUST stay open
  with the path field focused and holding the whole text.
- **FR-002**: The same MUST hold for the "Unpack files" mask field.
- **FR-003**: After a refusal nothing MUST be created, unpacked or deleted (the archive is not
  deleted either).
- **FR-004**: Text that fits MUST behave exactly as before (same target, same mask, no new
  question).
- **FR-005**: No new UI string; the existing "The path specified is too long." message is used.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe rows `path-cjk`, `path-ascii` and `mask-cjk` go from FAIL to PASS (refused,
  field whole, nothing under the target).
- **SC-002**: The controls `ctl` and `ctl-path` stay PASS (unpacked as typed, nothing asked).
- **SC-003**: The 204 probe's Alt+F9 row (`f9-zip`) still PASS, if driven.
- **SC-004**: Encoding guard `TOTAL: 0`, build succeeds, `saltests` 0 failed.

## Assumptions

- Assumption (autonomous run): the buffer sizes are the caller's (`CFilesWindow::Unpack`, `path` and
  `mask` of MAX_PATH bytes), which the dialog already uses for its reads; no buffer is grown and no
  limit is put on the path combo box (conservative - changes least, the refusal covers it).
- Assumption (autonomous run): the refusal follows features 214 / 291 (`DlgItemTextFitsU8`, the
  dialog's validation before its data is read) - the item names this pattern.
- Out of scope: other cuts downstream of the dialog (later path handling with fixed buffers), the
  plug-in archive Unpack (F5 out of an archive, fixed in 214), other dialogs.
