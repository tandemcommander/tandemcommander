# Feature Specification: typed text survives the core's drain loops

**Feature Branch**: `154-drain-loops-wide`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 9 (093's leftovers): "the loops that only drain messages
during an operation and the menus' own modal loops are code-page loops; other plug-ins' dialogs
were not examined."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A character typed while the program catches up arrives as typed (Priority: P1)

A user types into the command line (or another Unicode field) right when the program works through
its queue - on switching back to the program, while an operation pumps messages, in the internal
viewer. Characters outside the keyboard layout's code page (another script typed through an
input method or a Unicode-only layout, the emoji panel) arrive as typed, not as `?`.

**Independent Test**: `probe/drain_loop_probe.ps1` (Cyrillic posted while the activation's drain
loop runs; controls).

## Requirements *(mandatory)*

- **FR-001**: Every core loop that dispatches messages to windows during an operation MUST use the
  wide forms (093's pattern).
- **FR-002**: Code-page windows MUST see what they saw before (the system converts for them).
- **FR-003**: The menus' own loops stay as they are (they match code-page mnemonics against
  code-page menu texts); no interface, string or registry change.

## Success Criteria *(mandatory)*

- **SC-001**: The drain-loop rows pass on the fix and fail on the build before; the control rows
  pass on both.
- **SC-002**: 093's command-line and dialogs probes unchanged.
