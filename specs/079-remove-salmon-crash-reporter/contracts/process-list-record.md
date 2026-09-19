# Contract: Inter-instance process-list record

**Feature**: 079 | **Scope**: `CProcessListItem` in `src/tasklist.h`
(mirrored in `tools/salbreak/tasklist.h`), shared memory
`TandemCommander01ProcessList`.

## Layout (unchanged size and offsets, `#pragma pack(4)`)

| # | Field | Type | 079 |
|---|-------|------|-----|
| 1 | `PID` | DWORD | unchanged |
| 2 | `StartTime` | SYSTEMTIME | unchanged |
| 3 | `IntegrityLevel` | DWORD | unchanged |
| 4 | `SID_MD5` | BYTE[16] | unchanged |
| 5 | `ProcessState` | DWORD | unchanged |
| 6 | `HMainWindow` | UINT64 | unchanged |
| 7 | `SalmonPID` → **`Reserved1`** | DWORD | always written as 0; never read |

## Rules

- The record is append-only across versions (header comment); this feature
  neither appends nor removes a field, so `TandemCommander01ProcessList`,
  its mutex and events keep their names and a 0.1.8 instance interoperates
  with a 079 instance in both directions.
- On `TASKLIST_TODO_BREAK` the requesting instance calls
  `AllowSetForegroundWindow(Items[i].PID)` only; the former second call with
  the helper's PID is removed. An older instance reading a 079 record calls
  `AllowSetForegroundWindow(0)`, which fails harmlessly.
- `extern HANDLE HSalmonProcess` is removed together with its only writer.

## Verification

- `saltests` cannot reach this struct (it links only `src/common/`); the
  contract is verified by a static check (`static_assert(sizeof
  (CProcessListItem) == <today's size>)` is **not** added, to avoid a new
  dependency on padding rules — instead the reviewer compares the field list
  before/after) and by the Task List scenario in the quickstart (Break from a
  second instance ends in the standard report and message).
