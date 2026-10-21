# Contract: the move-back probe seam (feature 281)

Debug builds only (`#ifdef _DEBUG`); a Release build contains no reference to the variable.

- Variable: `TC_PROBE_MOVE_BACK_FAIL`, a decimal count `n` (1 to 1,000,000; anything else = off).
- Read once per module (the core and each plug-in that includes `src/common/salmoveback.h`) at the
  first move back.
- Effect: the first `n` move-back attempts of that module (each attempt of `SalMoveBackRetry`,
  not each call) fail without touching the disk, with `ERROR_SHARING_VIOLATION`.
- Nothing else is affected: the move aside, the operation and the undo of a rename are ordinary
  moves.
- Use: `n` = 3 - a hold shorter than the retry window (the first call succeeds at its 4th
  attempt); `n` = 1000 - every move back fails (each call gives up after 11 attempts, about 1 s).
