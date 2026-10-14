# Feature Specification: message texts with long paths composed on the heap

**Feature Branch**: `183-message-overruns`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: no message or dialog setup writes a name or path into a fixed buffer without a bound.
