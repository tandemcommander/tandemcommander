# Feature Specification: the User Menu's batch file keeps %, ^, ! and & in names

**Feature Branch**: `229-user-menu-batch-special-chars`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a name, path or environment value a User Menu item inserts reaches its command
  unchanged through the batch file - never another file's name, never another command.
- **FR-002**: a value that cannot pass unchanged ('^'; '&', '|', '<', '>' outside quotes) is
  refused before anything runs.
- **FR-003**: what the user typed in the item (%VAR%, operators, redirections) keeps its meaning.
- **FR-004**: list variables quote a name holding a space or one of cmd's delimiters / operators.
