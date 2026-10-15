# Feature Specification: selections restored by name in a case-sensitive folder

**Feature Branch**: `231-case-sensitive-reselect`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: in a folder that tells "a.txt" and "A.txt" apart, Reselect, Restore Selection, panel
  tabs and Hide Selected Names act on the item that was selected - never on its other-case twin.
- **FR-002**: in ordinary folders nothing changes.
