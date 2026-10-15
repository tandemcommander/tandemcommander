# Feature Specification: FTP and SFTP downloads never write into another entry by its short name

**Feature Branch**: `205-download-short-name-clash`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md (FTP not driven)

## Requirements *(mandatory)*

- **FR-001**: a download whose local name is only the short (8.3) name of another local entry
  lands as an entry of its own; the other entry is never overwritten, resumed into, joined or
  offered for any of these (SFTP and FTP, copy and move).
- **FR-002**: when the other entry cannot be moved aside for that (held open), the download fails
  with the reason; a move keeps its source.
