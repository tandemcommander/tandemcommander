# Feature Specification: a popup menu item is chosen by its accented hot key

**Feature Branch**: `237-popup-menu-mnemonics`
**Created**: 2026-10-16
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a typed letter selects the popup item whose hot key (or, without one, first letter)
  is that letter - compared as characters, also for letters outside ASCII in UTF-8 items.
- **FR-002**: a letter never selects an item whose hot key is another letter.
