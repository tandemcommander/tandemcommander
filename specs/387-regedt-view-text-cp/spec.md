# Feature Specification: Registry Editor View of a text value keeps the whole text on a multi-byte code page

**Feature Branch**: `387-regedt-view-text-cp`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: User description: "Backlog item registry-editor-view-of-a-text-value-cut-text-and-a-stray - implement exactly what it describes." From backlog item registry-editor-view-of-a-text-value-cut-text-and-a-stray.

## Clarifications

### Session 2026-11-02

- Q: When the conversion to the code page fails, should the export show an error or give the viewer the UTF-16 data? → A: the UTF-16 data as stored (no new UI string; the viewer stays usable) (autonomous run: conservative - the item allows either)
- Q: Should the terminating NUL(s) of the text stay in the viewer's copy? → A: yes, converted with the text as before, so a single-byte code page gives the old bytes exactly (autonomous run: conservative)
- Q: When memory for the converted copy is low, error or UTF-16 fallback? → A: the existing low-memory error, as for the value's own buffer (autonomous run: conservative - existing behaviour)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View a non-ASCII text value whole (Priority: P1)

A user on a machine whose ANSI code page is multi-byte (UTF-8 65001, or the DBCS code pages
932 / 936 / 949 / 950) opens the Registry Editor plug-in, selects a text value (REG_SZ,
REG_EXPAND_SZ or REG_MULTI_SZ) that contains a non-ASCII letter and presses View (F3). The
viewer shows the whole text - every character, nothing cut, no garbage byte.

**Why this priority**: This is the defect of the item: today such a text is cut at the first
character that needs more than one byte per UTF-16 unit and padded with uninitialised heap bytes.

**Independent Test**: A `saltests` check with a code-page parameter (65001, 932, 1250) converts a
value's bytes the way the viewer's export does and compares the produced bytes with the whole
code-page form of the text.

**Acceptance Scenarios**:

1. **Given** code page 65001 and REG_SZ `a€` (6 bytes with its NUL), **When** the value is
   exported for the viewer, **Then** the file holds the 5 bytes `61 E2 82 AC 00` - not `a`, a
   stale byte and a NUL.
2. **Given** code page 65001 and REG_SZ `čččč bar`, **When** it is exported, **Then** the file
   holds all 13 bytes and ends with ` bar` and the NUL.
3. **Given** code page 932 and a text of two hiragana letters, **When** it is exported, **Then**
   the file holds their 4 DBCS bytes and the NUL (5 bytes).
4. **Given** a single-byte code page (1250) and any text value, **When** it is exported,
   **Then** the file holds exactly the same bytes as before the change (one byte per unit).

---

### User Story 2 - A text that cannot be converted is never written as stale bytes (Priority: P2)

When the conversion to the code page fails (the code page cannot be used, or the converted size
cannot be had), the viewer gets the value's UTF-16 data as stored - the form used when the
"export strings in ASCII" switch is off - instead of partial or uninitialised bytes. When the
temporary file cannot be written whole, the user gets the existing "cannot write the temporary
file" error instead of a viewer on a short file.

**Why this priority**: The item's *Expected* demands that a failed conversion is reported or
falls back to the UTF-16 data, never stale bytes; the write check belongs to "the written length
is the converted byte count".

**Independent Test**: The `saltests` check with an invalid code page shows the rule asks for the
UTF-16 fallback and produces no bytes.

**Acceptance Scenarios**:

1. **Given** a code page the system cannot convert to, **When** the value is exported, **Then**
   the rule reports "use the UTF-16 data" and allocates nothing.
2. **Given** a write to the temporary file that writes fewer bytes than asked, **When** the
   export ends, **Then** the export reports the write error (no viewer is opened on it).

### Edge Cases

- Empty text value (0 bytes, or 1 odd byte): nothing to convert - the data is written as stored,
  as before.
- A value whose byte count is odd: the last odd byte is not part of any UTF-16 unit and is
  dropped from the conversion, as before.
- REG_MULTI_SZ: the embedded NULs and the final double NUL are converted with the text (each
  NUL is one byte in every code page), as before.
- A lone surrogate or a letter the code page lacks: the system's default replacement is used
  (`?` or U+FFFD), the length is the converted length.
- Low memory for the converted copy: the existing low-memory error is shown and no file is
  written - as for the value's own buffer.
- Non-text types (REG_DWORD, REG_BINARY, ...): untouched, written as stored.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The export of a text value for the viewer MUST size the code-page copy by the
  converted byte count of the whole text (all of its UTF-16 units), not by its unit count.
- **FR-002**: The bytes written to the viewer's temporary file MUST be exactly the converted
  bytes, and their number MUST be the converted byte count.
- **FR-003**: A conversion that fails MUST NOT write partial or uninitialised bytes; the export
  MUST then write the value's UTF-16 data as stored.
- **FR-004**: On a single-byte code page the exported bytes MUST be identical to those of the
  code before the change.
- **FR-005**: A write of the temporary file that does not write all bytes MUST be reported as the
  existing write error.
- **FR-006**: The conversion rule MUST be a pure, header-only rule under `src/common/` with a
  code-page parameter and `saltests` checks for 65001, 932 and 1250, including a negative control
  with the old sizing.

### Key Entities

- **Text value**: a registry value of type REG_SZ / REG_EXPAND_SZ / REG_MULTI_SZ, stored as
  UTF-16LE bytes including its terminating NUL(s).
- **Viewer copy**: the temporary file in the disk cache that the viewer opens; it holds either
  the code-page form of the text (default) or the UTF-16 data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every text in the `saltests` set, the exported bytes on 65001 and 932 equal the
  whole code-page form of the text (0 cut texts, 0 stale bytes).
- **SC-002**: On code page 1250 the exported bytes equal the old export byte for byte.
- **SC-003**: The negative control (the old unit-sized conversion) fails on 65001 in the same
  test run, proving the check can tell the two apart.
- **SC-004**: The build, the encoding guard and `saltests` pass with 0 failures.

## Assumptions

- Assumption (autonomous run): the short-write check (`WriteFile(...) || written != size`
  accepted a short write) is fixed with the written length, because FR-002 asks the written
  length to be the converted count; it is the same statement.
- Assumption (autonomous run): the GUI case (F3 on a machine with a UTF-8 or DBCS ANSI code page)
  cannot be driven on the measuring machine (code page 1250); it is a person's check, recorded
  as a `person-step` item at closing (`who: both`).
- The export switch `ExportStringsForViewerInASCII` stays TRUE by default and keeps its meaning.
