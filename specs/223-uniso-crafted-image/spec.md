# Feature Specification: the ISO plug-in checks an image's lengths; Rock Ridge names whole

**Feature Branch**: `223-uniso-crafted-image`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a length read from a disk image never makes the plug-in write or read past its
  buffers (HFS+ names, Rock Ridge entries, directory records).
- **FR-002**: a Rock Ridge name continued in a continuation area is read whole; a name that cannot
  be read whole is never used cut.
