# Contract - background path check of a panel (feature 372, internal)

Internal to the core; no plug-in or configuration interface.

## Rule (`src/common/salbkgndcheck.h`, header-only, `saltests`)

- `SalBkgndCheckRoute(isDiskOrArchive, isNetwork)` - TRUE: `Activate` starts the background check
  instead of the synchronous `CheckPath`. Only disk or archive panels on a network folder.
- `SalNeedsAutoRefreshVerify(isRefresh, listed, monitorChanges, automaticRefresh)` - the old
  condition of the `Sleep(400)` branch; TRUE: start the 400 ms verification timer.
- `SalBkgndCheckAction(wanted, samePath, valid)`:

| wanted | samePath | valid | action |
|---|---|---|---|
| 0 | any | any | NONE |
| ACTIVATE (with or without VERIFY) | yes | yes | REFRESH_EX |
| VERIFY only | yes | yes | NONE |
| any non-zero | yes | no | REFRESH |
| any non-zero | no | any | RESTART |

## Guarantees

- C1: the UI thread never waits for the worker (no wait, no wait window, no cursor change).
- C2: a result is applied only to the folder it was taken for (same panel type and
  `SalPathEqualOrdinalCI` path); otherwise it is dropped and a still wanted check restarts on the
  current path.
- C3: at most one awaited worker per panel; the worker owns its data until `PostMessage`
  succeeds; a failed post frees it. `SalBkgndCheckAbandon(runningForMs, samePath)`: a request
  while a worker runs for another folder, or for `SAL_BKCHK_ABANDON_MS` (10 s) or longer, starts a
  new worker (generation number + 1); the abandoned worker's result is dropped (generation
  mismatch) and its wanted bits carry over to the new one.
- C4: an accessible folder after a verification is never re-listed (no refresh loop); an
  inaccessible one gets the program's normal refresh, which shows the existing messages and
  leaves the folder as before.
- C5: the accessibility test is the check-path thread's own (`SalTestPathAccessible`), so the
  background and the synchronous checks agree.
