# Feature Specification: FTP sends names in the server's encoding

**Feature Branch**: `224-ftp-utf8-server-names`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: on a UTF-8 server a name with letters outside ASCII is sent in UTF-8 (delete, rename,
  download, change directory, ...).
- **FR-002**: on a legacy server the names its listing (or its PWD reply) gave in the code page go
  back in the code page, also inside a path.
