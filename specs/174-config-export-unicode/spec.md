# Feature Specification: the configuration export keeps every letter and never deletes a backup

**Feature Branch**: `174-config-export-unicode`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: NEXT-WORK items 5d and 5e.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user whose configuration holds paths or texts in any script (Cyrillic folders, hot paths,
commands) exports it and later imports it (`-C`, `config.reg`): every letter comes back.

### User Story 2 (Priority: P1)

A user exports over an older backup; if the export cannot be written, the older backup stays as
it was.

### User Story 3 (Priority: P2)

Configuration files exported by older versions (REGEDIT4, code page) keep importing.

## Requirements *(mandatory)*

- **FR-001**: the export writes a UTF-16 "Windows Registry Editor Version 5.00" file.
- **FR-002**: values and key / value names round-trip whatever their letters.
- **FR-003**: the file is replaced only by a complete new one (rule 105); nothing deletes it after
  a failure.
- **FR-004**: REGEDIT4 files keep importing; no plug-in interface change, no new string.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/cfg_content_probe.ps1` - every row PASS after, the measured failures before.
