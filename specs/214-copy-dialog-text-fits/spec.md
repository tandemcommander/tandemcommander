# Feature Specification: the Copy / Move dialog never cuts the typed text

**Feature Branch**: `214-copy-dialog-text-fits`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a target, folder or name typed (or picked from the history) in the Copy / Move,
  Unpack, Create Directory, Quick Rename and Edit New dialogs that does not fit the operation is
  refused with "The path specified is too long." and the dialog stays open - the operation never
  acts on a shortened text (another folder or name).
- **FR-002**: no new string; text that fits behaves as before.
