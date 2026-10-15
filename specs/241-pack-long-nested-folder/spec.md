# Feature Specification: packing a folder whose folder name is too long says why

**Feature Branch**: `241-pack-long-nested-folder`
**Created**: 2026-10-16
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: copying or moving into an archive a folder that is (or holds) a folder whose name the
  archive list cannot take shows "too long name" and packs nothing; a Move deletes nothing.
