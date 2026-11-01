# Research - 372-wsl-activation-freeze

## R1 - Where the activation waits (measured, fix-log)

- Decision: the WSL-specific wait is the `Sleep(400)` + second `CommonRefresh` in
  `ChangePathToDisk` (condition `isRefresh && !cannotList && GetMonitorChanges() &&
  !AutomaticRefresh`); the cold-distribution wait is the synchronous `CheckPath` in
  `CFilesWindow::Activate`.
- Rationale: QPC instrumentation: `REF end - REF begin` = 410-428 ms with "SLEEP400 branch",
  `CommonRefresh` itself 4-9 ms; `WM_USER_END_SUSPMODE` 5 ms in total; the 2 s first answer of a
  stopped distribution measured from PowerShell.
- Alternatives: setting `DrvSpecRemoteDoNotRefreshOnAct` by default (a configuration change, and
  the panel would no longer show WSL changes - rejected); treating WSL paths as local (wrong:
  no change notification, the panel would never refresh).

## R2 - What replaces the `Sleep(400)` + second listing

- Decision: a 400 ms one-shot panel timer after the successful refresh listing; it starts the
  background check; an inaccessible folder gets `WM_USER_REFRESH_DIR` (which fails to list and
  leaves the folder as the old second listing did), an accessible one gets nothing.
- Rationale: the code comment says the second listing exists to notice a folder that is being
  deleted (the second listing "should fail"). A folder that is deleted or delete-pending fails the
  accessibility test (`GetFileAttributesW` opens it). No re-listing means no refresh loop.
- Alternatives: a deferred full second refresh (a second UI-thread listing on every refresh, and
  it needs a flag against the loop); keeping the sleep only for local disks (the same wait for a
  local folder whose notification failed, no reason to keep it).

## R3 - The background check

- Decision: a worker thread per request (`CreateThread`, registered with `AddAuxThread` so a hung
  network call cannot hold the exit), at most one per panel; it calls the same test as the
  check-path thread (`SalTestPathAccessible`, extracted from `ThreadCheckPathFBody` without change
  of behaviour) on a heap copy of the panel path (never cut) and posts
  `WM_USER_BKGNDCHECK_DONE` with the result to the panel; a failed post frees the data.
- Rationale: the existing `SalCheckPath` machinery is synchronous by design (it waits, shows
  "ESC to cancel"), and is shared with every other check under a critical section; a separate
  worker keeps it untouched.
- Alternatives: `RegisterWaitForSingleObject` / thread pool (a hung 9P call would occupy a pool
  thread the program also uses elsewhere); reusing `ThreadCheckPath[]` slots (they are the
  synchronous checks' and would need its locking).

## R4 - Which panels take the route

- Decision: `ptDisk` or `ptZIPArchive` with `GetNetworkDrive()` (drive type remote: UNC paths,
  mapped drives, `\\wsl.localhost\...`, `\\wsl$\...`), inside the existing condition of `Activate`.
- Rationale: the item names WSL and "any slow network share"; local folders keep the synchronous
  check (it runs in the main thread for local drives already, < 1 ms).

## R5 - The common ~150 ms block

- Decision: out of scope; Inbox item (`measure:372`).
- Rationale: `IdleCheckClipboard` -> clipboard queries in `RefreshCommandStates` (154 ms on the
  hidden desktop, with local folders too); no panel folder's file system is involved. Whether it is
  that long on the user's own desktop is not measurable in the run.
