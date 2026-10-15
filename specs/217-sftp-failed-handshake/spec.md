# Feature Specification: SFTP - a failed key exchange leaks nothing

**Feature Branch**: `217-sftp-failed-handshake`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: an SSH key exchange that fails at any point frees everything it made; the program
  exits cleanly afterwards.
- **FR-002**: a valid server never fails the key exchange because of the encoding of the shared
  secret (a leading zero byte).
