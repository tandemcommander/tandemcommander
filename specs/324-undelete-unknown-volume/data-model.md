# Data model - 324 undelete-unknown-volume

## Core answer (input)

| Field | Values |
|---|---|
| `coreSame` | TRUE / FALSE - `PathsAreOnTheSameVolume` |
| `coreIsEstimate` | TRUE / FALSE - its `resIsOnlyEstimation` |

## Volume identity (input)

`CSalFileIdentity` (103) of the nearest existing folder: `Has64` + `Vsn32`, `Has128` + `Vsn64`.

`SalVolumeSerialMatch(a, b)`: `simUnknown` when either side lacks `Has64` or has a zero serial;
both `Has128` -> compare `Vsn64`, else `Vsn32`; `simEqual` / `simDifferent`.

## Decision (output) - `SalVolumeGuardSame(coreSame, coreIsEstimate, match)`

| coreSame | coreIsEstimate | match | treated as same volume |
|---|---|---|---|
| TRUE | any | any | TRUE (unchanged) |
| FALSE | FALSE | any | FALSE (unchanged - both volume names read) |
| FALSE | TRUE | simEqual | TRUE |
| FALSE | TRUE | simUnknown | TRUE (fail closed) |
| FALSE | TRUE | simDifferent | FALSE |

## Nearest existing folder walk

`SalWPathRootLength(w)`: `\\?\X:\` 7; `\\?\UNC\srv\share\` up to and with the backslash after
the share (whole length when it has none); `\\?\<name>\` (Volume GUID, GLOBALROOT...) up to and
with the first backslash after the prefix; `X:\` 3; anything else 0 (no step up).
`SalWPathCutLast(w)`: drops trailing backslashes and the last component; FALSE at the root.
