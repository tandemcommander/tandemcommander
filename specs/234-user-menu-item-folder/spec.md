# Feature Specification: a User Menu command runs in its item's folder

**Feature Branch**: `234-user-menu-item-folder`
**Created**: 2026-10-16
**Status**: Implemented - see fix-log.md (the Find window route not driven)

## Requirements *(mandatory)*

- **FR-001**: a User Menu command without an Initial Directory runs in the folder of the item it
  was given - from the panel and from the Find window, for every item.
- **FR-002**: an item whose folder the batch file cannot enter (UNC) is refused rather than run in
  another item's folder.
