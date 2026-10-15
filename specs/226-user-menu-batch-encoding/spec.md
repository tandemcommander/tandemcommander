# Feature Specification: the User Menu's batch file keeps accented and CJK names

**Feature Branch**: `226-user-menu-batch-encoding`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a User Menu item run through a batch file gets the names, folders and arguments it
  was given, whatever letters they hold.
- **FR-002**: an ASCII batch text is written byte for byte as before; a text the OEM code page
  holds exactly is written in it after a line switching the console to it; otherwise in UTF-8
  with the console switched to UTF-8 for it and back afterwards. The switch runs chcp.com by its
  absolute path, never a file of the current folder.
- **FR-003**: a name no batch file can hold (an unpaired surrogate) is refused; the batch file is
  not run.
- **FR-004**: an Initial Directory that cannot be entered ends the batch file; the command never
  runs in another folder.
- **FR-005**: a command without an Initial Directory runs in the panel's folder, also when its path
  holds letters outside ASCII.
