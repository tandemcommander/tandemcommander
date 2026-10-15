# Feature Specification: The Renamer's case changes work on letters of UTF-8 names

**Feature Branch**: `208-renamer-case-utf8`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: lower, upper and mixed case and "strip diacritics" change the letters of any name
  (Czech, CJK ...) - in the new-name pattern and in the dialog's name / extension options; the
  result is a valid name, its length may differ from the original's.
- **FR-002**: a case change of a name is recognised as the file itself (no overwrite question).
