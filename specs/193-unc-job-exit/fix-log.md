# Fix log: 193 - an abandoned share-list worker leaves nothing behind at exit

Backlog: NEXT-WORK D, "Found by the second verification of 124-128", item 6 (125): "the job of a
worker that is still in the network call at exit is not freed (ended by `TerminateAuxThreads`; a
Debug leak report after Esc on a dead server and an immediate exit)".

## Measured (before)

Esc / Close of the wait window read the real keyboard and mouse - not drivable on the hidden
desktop (125's W1). A Debug-only seam was added first: `TC_PROBE_UNC_CANCEL` (milliseconds after
the wait window opens, the wait is given up as if Esc was pressed; `fileswnb.cpp`, documented in
`specs/125-unc-server-shares/contracts/probe-seam.md`). Probe `probe/unc_abandon_probe.ps1`
(`TC_PROBE_UNC_SHARES` answers without the network, `TC_PROBE_UNC_DELAY` holds the worker):
- ABANDON (delay 60 s, given up after 0.8 s, exit 2.5 s later): **"Detected memory leaks!"** at
  exit (`probe/result_before.txt`, the build at 192 + the seam);
- DONE (the control: delay 1.5 s, given up after 0.3 s, exit 4 s later - the worker answered and
  freed the job itself): clean.

What leaked, read with an OutputDebugString listener (`probe/dbwin_lib.ps1`, the DBWIN protocol):
the job (`shares.cpp`, 64 bytes) and its server name (28 bytes) - and, once those were freed, the
worker's call-stack monitor buffer (`callstk.cpp(990)`, 1,200 bytes, Debug builds only): the
thread's `CCallStack` destructor never runs when the thread is terminated.

## Work

- `src/shares.cpp`, `src/salamand.h`: every `CUncSharesJob` is in a list (a static `SRWLOCK` -
  nothing to construct or destroy at exit); `CUncSharesJob::FreeAbandoned()`, called in
  `salamdr1.cpp` right after `TerminateAuxThreads()`, frees what is left (only jobs of ended
  workers: the main thread holds a job only inside `PickServerShare`); a lock still held (a worker
  ended inside its job's destructor) leaves the jobs as before - the exit never waits.
- `src/shares.cpp`: a job whose worker was ended inside `Add`'s `realloc` (`Changing`, also around the two `qsort` calls - second review) is left
  as it was - `Shares` may name the freed old block (review S2).
- `src/callstk.cpp`: the call-stack monitor queue (Debug builds and `CALLSTK_MEASURETIMES` only)
  is a CRT block in a Debug build (`_malloc_dbg` / `_free_dbg` with `_CRT_BLOCK`), which the
  leak report leaves out: it is the call-stack's own instrumentation, and a thread ended by
  `TerminateThread` cannot have it freed from outside - its `CCallStack` lives on its stack, which
  `TerminateThread` frees (since Vista). The destructor paths set the pointer to NULL.
  **Rejected on the way:** releasing the ended thread's call-stack (queue, handle, list entry)
  from `TerminateAuxThreads` - after `TerminateThread` it crashed at exit (the freed stack); with
  the thread suspended first it worked here, but the review found it reads through every entry
  of `CallStacks`, and other threads ended by `TerminateThread` (the icon reader, CheckPath, cache
  handles, plug-in threads) leave entries pointing into freed stacks - a new crash at exit
  (CRITICAL). Removed.
- `src/fileswnb.cpp`: the seam (Debug only).

Build: BUILD SUCCEEDED; saltests 22,361 / 0; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 2 / 0, no leak dump for either row (left: the handles monitor's Debug
note "monitored handles remained opened" for ABANDON - the ended thread's call-stack keeps its
duplicated thread handle, as for every thread ended at exit). Negative control (with the
rejected call-stack release, `FreeAbandoned` switched off, built, run): the leak box again, the
dump names the job and its server name (`probe/result_negative_control_no_job_free.txt`) - the
job part is needed. 125's probe `-Expect fixed`: 26 / 0 (W1 / W2 not driven as recorded there).

## Review

First refute-first review: **CRITICAL** - the cross-thread call-stack release read through every
`CallStacks` entry, and entries of other threads ended by `TerminateThread` point into freed
stacks: a new crash at exit. Removed (above); the queue became a CRT block instead (its S1
proposal), the pointer set to NULL after the frees. SHOULD-FIX S2 taken (a job ended inside
`realloc`). NIT N2 taken (the seam parsed once). Checked and fine: no new hang (every lock the
suspended thread could hold would be left owned by a dead thread anyway), `FreeAbandoned`'s races,
`TerminateAuxThreads` called once, the seam Debug-only and in the contract. Recorded in
`specs/NEXT-WORK.md`: the stale `CallStacks` entries of every thread ended by `TerminateThread`.

Second review (of the rework): nothing critical; SHOULD-FIX taken - `qsort` swaps `Shares` in
place, the same kind of window as `realloc`: the flag (`Changing`) is set around both calls too;
NIT taken - the macros inside the measuring guard. Checked: every allocation and free of the queue
uses the matching macro, `_CRTDBG_MAP_ALLOC` does not conflict, the normal paths still free the
queue (the leak report hides it only where the destructor is skipped - instrumentation memory,
accepted), the flag's ordering on x64 (`/volatile:ms`), `FreeAbandoned`'s cases, the seam.

Final: BUILD SUCCEEDED; the probe 2 / 0 (no leak dump); 125's probe 26 / 0.
