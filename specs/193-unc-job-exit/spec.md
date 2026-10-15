# Feature Specification: an abandoned share-list worker leaves nothing behind at exit

**Feature Branch**: `193-unc-job-exit`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: leaving the program while a share-list worker the user gave up waiting for is still
  asking the server frees everything that worker held; a Debug build reports no leak.
- **FR-002**: the exit never waits for a thread it ended.
