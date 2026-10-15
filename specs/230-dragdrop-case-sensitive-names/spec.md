# Feature Specification: drag & drop / paste into an archive takes exactly the dragged names

**Feature Branch**: `230-dragdrop-case-sensitive-names`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md (not driven: needs drag & drop or the clipboard)

## Requirements *(mandatory)*

- **FR-001**: an item that was not dragged or pasted is never packed, moved or deleted - also in a
  folder that tells "a.txt" and "A.txt" apart.
- **FR-002**: a name given in another case than the disk lists it is still found in a folder that
  does not tell case apart.
- **FR-003**: never more items than names (no overrun).
