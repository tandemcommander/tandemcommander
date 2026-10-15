# Fix log: 218 - a thread ended by force leaves no call-stack entry behind

Backlog (left by 193's review, `specs/NEXT-WORK.md`): every thread the core ends with
`TerminateThread` leaves its `CCallStack` in `CCallStack::CallStacks` pointing into its freed stack
(Vista+); a bug report written afterwards walks that list and can fault inside the crash handler.
"Fix needs the entry taken out while the thread still exists (suspend, then remove by the stack
range, not by reading other entries)."

## Read (not driven)

The call-stack object of a thread is a local of the thread (on its stack); `TerminateThread` runs
no destructor and frees the stack; the entry stays. `PrintBugReport` (`bugreprt.cpp`) reads every
entry inside `__try` - a fault there loses the rest of the report's call stacks. Not driven: it
needs a forced termination (an icon reader or a path check that does not answer within a second)
followed by a crash report - not reachable on the hidden desktop.

## Work

- `src/callstk.cpp` / `.h`: `CallStk_TerminateThread(thread, code)` - the thread is suspended,
  `GetThreadContext` makes the suspension take effect and gives its stack pointer,
  `CCallStack::ForgetThread(id, sp)` sets to NULL every slot whose object lies in that stack's
  reservation (`VirtualQuery` - `AllocationBase`) or in memory no longer committed (an entry left by
  a thread ended elsewhere), then `TerminateThread`. Entries are never read; nothing is allocated
  while the thread is suspended (no `Delete` - it may reallocate; raw `TryEnterCriticalSection` -
  the Debug `HANDLES` wrapper allocates); the section is not waited for when the suspended thread
  owns it, or after 200 tries - then the entry stays (as before). The constructor drops the NULL
  slots before adding its own (a normal thread, under the section).
- `src/bugreprt.cpp`: the call-stack walks skip a NULL slot (each slot read once).
- The five core sites: `cache.cpp`, `fileswn1.cpp` (icon reader), `salamdr3.cpp` (aux threads at the
  exit), `salamdr5.cpp` (CheckPath), `snooper.cpp` (SafeFindClose).

Build: BUILD SUCCEEDED; saltests 22,428 / 0. Smoke (starts and exits of the program, the aux
threads ended at each exit): 213's probe 8 / 0, 204's probe 22 / 0 (`probe/regress_*.txt`).

## Review

First refute-first review: rejected - `ForgetThread` read `ThreadID` of every entry, also those of
PLUG-IN threads killed by `plugins/shared/auxtools.cpp` (they do register in the core's list,
`plugins1.cpp` `CallWithCallStack`): a read of freed memory outside any `__try`, at an exit or a
panel's close - worse than before. Reworked to match by the memory region (above, as the backlog
said). Second review: accept - a stack is one reservation (one `AllocationBase`, guard page
included); `MainThreadStack` lies in the image, no `CCallStack` is on the heap; `VirtualQuery`,
`TryEnterCriticalSection`, `Sleep` neither allocate nor lock; `CONTEXT_CONTROL` gives `Rsp` / `Esp`;
the `CreateThread` handles have the rights. Taken: the report reads each slot once; the header says
the plug-ins' kills are not covered. NITs kept: a suspension caught while the thread takes the
section costs up to 200 ms; empty slots can leave an extra "----" in a report; the duplicated
thread handle of a forgotten entry stays open (as before, a Debug note). Recorded in NEXT-WORK:
`plugins/shared/auxtools.cpp` 173 / 222 end plug-in threads with a raw `TerminateThread` (their
entries are swept only when the core ends a thread) - a plug-in service, an interface addition.
