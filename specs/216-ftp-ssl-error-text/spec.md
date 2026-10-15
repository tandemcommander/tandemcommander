# Feature Specification: the FTP plug-in's SSL texts

**Feature Branch**: `216-ftp-ssl-error-text`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: OpenSSL's error text is written into a buffer of the size OpenSSL requires; no log
  line of the SSL connection is written unbounded.
- **FR-002**: the SSL lines of the FTP log are readable in every UI language.
