# Feature Specification: SFTP leftovers

**Feature Branch**: `220-sftp-leftovers`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: F3 on a server file that cannot be read says why; a cancel says nothing.
- **FR-002**: closing a session whose server stopped answering frees it (no leak report at exit).
