# Feature Specification: FTP server paths over 300 bytes

**Feature Branch**: `233-ftp-long-server-paths`
**Created**: 2026-10-15
**Status**: Closed - measured: such paths are refused, not cut and acted on (see fix-log.md)

## Requirements *(mandatory)*

- **FR-001**: a server path the plug-in cannot hold is refused, never cut and acted on. Holds
  for typed / entered paths (the core) and the operation queue (`FTPPathAppend`).
