# Feature Specification: names that differ only in case are one name again

**Feature Branch**: `232-compare-dirs-case-only-names`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: Compare Directories pairs "Readme.txt" with "README.txt" in ordinary folders.
- **FR-002**: a selection survives a case-only rename by another program (refresh).
- **FR-003**: NFC and NFD forms of a name stay two names (feature 004, FR-009).
- **FR-004**: a selected twin in a case-sensitive folder stays selected after a refresh; its twin
  never inherits it.
