# Feature Specification: Checksum Verify takes a list line of any length

**Feature Branch**: `149-checksum-long-lines`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (probe L1 PASS, control FAIL; 117 probe 82 / 0)
**Input**: `specs/NEXT-WORK.md`, *Open items at a glance*, A.5 (queue 104 entry 4, found by 117):
"a list line whose path does not fit 780 bytes aborts the whole Verify ("name too long",
`FILEINFO::fileName`)."

## Clarifications

### Session 2026-10-14

- Q: What should happen to such a line? -> A: It is verified like any other (the file system
  takes paths far longer than 780 bytes; the plug-in opens files through the extended-length form).
  No line is cut and the Verify is never stopped for a length.
- Q: The Focus button for such a row? -> A: Refused with the existing "too long name" text when the
  path does not fit the focus buffer (a cut path would name another file).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long line is verified with the rest (Priority: P1)

**Independent Test**: probe `probe/checksum_long_line_probe.ps1` row L1 - a list with an ordinary
line and a line whose relative path has 817 bytes, both files matching: two rows, "All files OK",
no box.

## Requirements *(mandatory)*

- **FR-001**: A list line MUST NOT stop the Verify because of its length.
- **FR-002**: A name or path MUST NOT be cut; the Focus of a path longer than its buffer is refused.
- **FR-003**: No new string, interface or registry value.

## Success Criteria *(mandatory)*

- **SC-001**: L1 FAIL before (measured: "Cannot finish operation because of too long name.", no
  Verify window), PASS after.
- **SC-002**: The 117 and 147 probes unchanged.
