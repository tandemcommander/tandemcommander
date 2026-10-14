# Feature Specification: plug-in windows close cleanly while a worker box could appear

**Feature Branch**: `147-plugin-close-boxes`
**Created**: 2026-10-14
**Status**: Implemented - the reachable rows measured (7 / 0 before and after); the races by reading
**Input**: `specs/NEXT-WORK.md`, *Open items at a glance*, A.3 (queue 104 entry 6, feature 118):
"a worker's error box (File Comparator hex view, Checksum read errors) can appear while its window
closes, also on a normal exit; the File Comparator ends its fcremote receiver thread before a window
close that may time out."

## Clarifications

### Session 2026-10-14

- Q: What is reachable? -> A: Measured first (`probe/result_pre147.txt`): with the comparator's box
  or Checksum's read-error box OPEN, a normal exit closes cleanly and an installer's close declines -
  both plug-ins already defer their close while a box is open. What is left are races, by reading:
  a Checksum worker that meets a read error after its window began to close (the window waited for
  it without handling sent messages - the worker's box needs this thread: a deadlock), and the
  comparator's fcremote receiver, ended at the start of `Release` and not restarted when the close
  then failed.
- Q: Change? -> A: Checksum: no worker error box once the end was asked (the read / open fails as
  cancelled); `WM_DESTROY` waits handling sent messages and closes a box that still slipped through.
  File Comparator: the receiver is started again when `Release` returns FALSE without force.
  No string, interface, registry value.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Closing with a box open stays clean (Priority: P1)

**Independent Test**: probe `probe/plugin_close_box_probe.ps1` rows K1 (comparator's "identical"
box, normal exit), K2 (Checksum's read-error box, normal exit), K3 (the same, installer: decline).

### User Story 2 - No deadlock and no box during the close (Priority: P2)

By reading (the race cannot be driven on the hidden desktop: it needs a read that blocks and then
fails after the close began).

### User Story 3 - fcremote keeps working after a declined close (Priority: P3)

By reading.

## Requirements *(mandatory)*

- **FR-001**: A Checksum worker MUST NOT show an error box after its window asked it to end.
- **FR-002**: A Checksum window's `WM_DESTROY` MUST NOT deadlock with its worker; a box the worker
  opened anyway MUST be closed as Cancel.
- **FR-003**: When the File Comparator's `Release` returns FALSE without force, the fcremote
  receiver MUST run again.
- **FR-004**: No new string, interface or registry value.

## Success Criteria *(mandatory)*

- **SC-001**: K1-K3 PASS on this build (they pass on the build before too - regression rows).
- **SC-002**: The 118 probe unchanged (58 / 0).
