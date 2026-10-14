# Feature Specification: PictView's print preview shows the picture

**Feature Branch**: `152-pictview-print-preview`
**Created**: 2026-10-14
**Status**: Implemented - probe 19/0 on the fix, every preview row FAIL on the control
**Input**: `specs/NEXT-WORK.md` A.6 (queue 104, entry 1; feature 120): "PictView's print preview is
empty in every release since 006."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The preview shows what will be printed (Priority: P1)

A user opens a picture in PictView and chooses Print. The preview in the Print dialog shows the
picture on the page - mirrored or turned as the viewer shows it, only the selection when *Print
selected area* is checked - in the size and place the print will have.

**Independent Test**: `probe/print_preview_probe.ps1` - a four-color picture; the preview is
captured and every color located.

**Acceptance Scenarios**:

1. **Given** the picture in the viewer, **When** Print opens, **Then** the preview shows all four
   quadrants in their places, in the picture's proportions.
2. **Given** the viewer mirrored (either way) or turned, **Then** the preview is mirrored / turned
   the same way.
3. **Given** a selection and *Print selected area*, **Then** only the selected part, in its
   proportions.
4. **Given** the dialog closed (or opened again), **Then** the viewer shows its picture exactly as
   before.

### Edge Cases

- Toggling *Print selected area* when the preview keeps its size (fit without keeping the aspect):
  the preview follows (it kept the old picture before).
- The preview cannot be drawn: the page without the picture, as before; the viewer's own size is
  given back in every case.

## Requirements *(mandatory)*

- **FR-001**: The preview MUST be drawn the way the print draws the picture (the same placement,
  mirroring and selection arithmetic).
- **FR-002**: The viewer's displayed picture MUST be unchanged by the preview.
- **FR-003**: No interface, string or registry change.

## Success Criteria *(mandatory)*

- **SC-001**: Every preview row of the probe passes on the fix and fails on the build before.
- **SC-002**: The viewer rows pass, and fail on a build that does not give the viewer's size back.

## Assumptions

- A person prints once to a real printer or *Microsoft Print to PDF* and compares the paper with
  the preview (the probe cancels every dialog; nothing is printed) - a step owed to a person.
