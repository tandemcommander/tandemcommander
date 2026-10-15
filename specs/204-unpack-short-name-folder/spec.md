# Feature Specification: An archive's folder is never unpacked into another folder by its short name

**Feature Branch**: `204-unpack-short-name-folder`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: an archive member whose folder is only the short (8.3) name of another folder in the
  target ("LONGDI~1/a.txt" next to "longdirname") is unpacked into a folder of its own; the other
  folder and its files are never written to, nor offered for overwriting.
- **FR-002**: when that folder cannot be made (the other one cannot be moved aside), an error;
  nothing is unpacked into the other folder.
- **FR-003**: a target the user typed with a short name ("tgt\LONGDI~1\") keeps resolving through it.
