# Feature Specification: The Renamer's search, whole words and cut work on letters of UTF-8 names

**Feature Branch**: `210-renamer-utf8-search`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a case-insensitive search (plain or a regular expression) never matches another
  letter, nor a piece of one; it matches one letter's two cases (Z-caron / z-caron).
- **FR-002**: "whole words" and the cut arguments count letters, not bytes.
- **FR-003**: a move is reported done without moving only when source and target are the very
  same path.
