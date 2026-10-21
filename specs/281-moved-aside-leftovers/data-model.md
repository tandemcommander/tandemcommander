# Data model: 281

## CMovedAsideLeft (core, `src/consts.h`)

| Field | Meaning |
|---|---|
| `Path` | malloc'd UTF-8 full path of the `salNNN` entry that could not get its name back; `NULL` = nothing left |
| `Err` | the Windows error of the last failed move back |

- Filled by `SalCreateFileEx`, `SalCreateDirectoryEx`, `MakeUnpackFoldersOwn` (from the inner
  `SalCreateDirectoryEx`) when both move backs failed; never when the entry got its name back.
- Consumed by `ReportMovedAsideLeft(parent, &left)`: shows it once and clears it (frees `Path`).
- The destructor frees `Path` (a record dropped without a report would be a defect - every caller
  reports; with no record the function reports itself).

## Seam state (Debug only, `src/common/salmoveback.h`)

| State | Meaning |
|---|---|
| remaining failures (per module) | read once from `TC_PROBE_MOVE_BACK_FAIL`; decremented on every move-back attempt it fails; 0 = off |
