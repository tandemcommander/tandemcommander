# Feature Specification: a thread ended by force leaves no call-stack entry behind

**Feature Branch**: `218-callstack-terminated-threads`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a thread the core ends by force is taken out of the call-stack list first; a crash
  report written afterwards never reads its freed stack.
- **FR-002**: taking it out never allocates, never reads another entry and never waits for a lock
  the suspended thread holds.
