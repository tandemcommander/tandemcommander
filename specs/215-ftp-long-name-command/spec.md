# Feature Specification: FTP never acts on a cut name

**Feature Branch**: `215-ftp-long-name-command`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a name of an FTP listing of up to 3 * 255 bytes of UTF-8 is shown, compared and sent
  whole; every command for it (delete, rename, download, view, change attributes, create folder)
  carries the whole name or is not sent.
- **FR-002**: no command is sent cut or empty; a work on a local file whose path or name does not
  fit is refused ("too long") or goes through the user's "cannot create" action - never done on a
  cut name.
