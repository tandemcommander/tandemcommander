# Feature Specification: the Plugins dialog's Focus builds the plug-in's path whole, in UTF-8

**Feature Branch**: `151-plugins-dialog-focus-path`
**Created**: 2026-10-14
**Status**: Implemented - the regression row P1 PASS; the overflow by reading
**Input**: `specs/NEXT-WORK.md` 5b (150's review): "`dialogs5.cpp` takes `GetModuleFileName` (A, code
page) into `buf[MAX_PATH]` and appends `plugins\` + `DLLName` without a bound."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Focus on a plug-in reaches its folder (Priority: P1)

**Independent Test**: probe `probe/plugins_focus_probe.ps1` row P1 (the Plugins dialog, the first
plug-in, Focus: the panel opens its folder under `plugins`). The overflow needs an install folder
near 259 bytes (a copy of the whole build there) - by reading.

## Requirements *(mandatory)*

- **FR-001**: The path MUST be built whole (no fixed buffer, no unbounded append) and in UTF-8 (the
  panel's encoding).
- **FR-002**: No interface, string or registry change.
