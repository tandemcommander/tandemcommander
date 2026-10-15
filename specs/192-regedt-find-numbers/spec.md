# Feature Specification: the Registry Editor's Find compares numbers as its help says

**Feature Branch**: `192-regedt-find-numbers`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: "0x" before a hexadecimal number makes it a number to search for.
- **FR-002**: a hexadecimal number that does not fit 64 bits is not searched for as a number.
- **FR-003**: a number value shorter than its type is not compared with the bytes after it.
