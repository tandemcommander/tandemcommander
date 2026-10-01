# Contract: External Archiver Launch (feature 084)

Covers FR-001, FR-005, FR-006, and the encoding edge cases. It replaces the
`salspawn.exe` indirection. It binds every caller of the two launch sites:
the listing run (today `PackList`, `src/pack1.cpp`) and the execute run (today
`PackExecute`, `src/pack3.cpp`).

## C1 — No intermediary

The archiver executable is the process that is created. There is no helper,
no `-c<base>` argument, and no exit-code multiplexing. A command line that
expands to an empty program name is an error before any process is created.

## C2 — Process creation

- The command line is UTF-8 (WTF-8) and passed to `SalCreateProcess`.
- Creation flags are `CREATE_NEW_PROCESS_GROUP | CREATE_DEFAULT_ERROR_MODE |
  NORMAL_PRIORITY_CLASS | CREATE_SUSPENDED`. *Listing* adds `CREATE_NEW_CONSOLE`
  and `SW_HIDE`; *execute* keeps today's minimized-then-restored console
  (restore after `PackWinTimeout` = 15 s).
- The process is assigned to a fresh job object with
  `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` **before** it is resumed, so no child
  can escape the job.
- In listing mode stdin is `NUL`, not an absent handle, so an archiver that
  prompts gets EOF and fails instead of waiting forever. stdout and stderr go
  to the pipe.
- If creation fails, the result is `LaunchFailed(err)`. The message is
  `IDS_PACKERR_PROCESS` (new wording, new ID), naming **the archiver's
  executable path** and the system error text. It never suggests
  Autoconfiguration unless the path is empty or does not exist.

## C3 — Waiting and Cancel

- The UI thread shows the modal wait window (`CExecuteWindow`, extended with a
  **Cancel** button) and keeps pumping messages. The pipe is read on a worker
  thread.
- **Cancel** calls `TerminateJobObject`, waits for the process, and reports
  `Cancelled`: no error box, the panel is refreshed, and in an *unpack*
  operation the target is reported as incomplete.
- **Closing the main window** while a run is active behaves exactly like
  Cancel. The job handle is closed on every exit path, so kill-on-close ends
  the archiver even if the product crashes.
- **Line limits.** A listing line longer than the existing 990-byte buffer
  stops the run with `IDS_PACKERR_PARSE`. The listing is never partial.

## C4 — Exit codes

- 0 means success.
- Any other code goes through the row's error table: a known code shows its
  message; an unknown one shows `IDS_PACKERR_RETURN` with the program name and
  the number.
- Codes ≥ 10000 have no special meaning anymore.
- For custom entries with no error table, behaviour is unchanged: non-zero
  means "returned an error" with the code.

### C3 amendment (implementation, 2026-10-01)

- The main window is disabled for the whole run, as `PackExecute` always did,
  so "closing the main window during a run" cannot happen through the UI.
  Kill-on-close covers the program ending or crashing.
- A cancelled **unpack** writes nothing to the target: extraction goes to a
  temporary directory that is removed. So a cancel is silent there.
- A cancelled **pack** or **delete** shows `IDS_PACKERR_CANCELLED_ARC`: the
  archive may be incomplete.
- A **listing** run shows **no** window of its own. Its callers already show
  "Reading list of files … please wait" (`CreateSafeWaitWindow`, after 2 s,
  without a Close button), and a second window would cover it. **Esc** cancels
  (`UserWantsToCancelSafeWaitWindow`). The pipe is drained every 50 ms inside
  the message loop; there is no worker thread. This was revised after review
  #1; an earlier draft showed a window after 500 ms.
- An **execute** run shows the wait window with **Cancel**; **Esc** cancels it
  too. The loop wakes every 100 ms to notice Esc.
- A command that quotes the archiver variable itself (`"$(Rar32bitExecutable)"`)
  would expand to `""path""`. The doubled quotes around the program are
  reduced to single ones (`PackNormalizeProgramQuotes`, re-review finding 1),
  so such user entries keep working (FR-008).

### What was built where it differs from C2–C4 (final review #3, 2026-10-01)

The original bullets above are kept as written; these points supersede them.

- **C2, error message**: there is no `IDS_PACKERR_PROCESS`. A failed launch
  shows `IDS_PACKERR_EXEMISSING` when the program's path is empty or the file
  does not exist (it points to *External Archivers Locations* and
  *Archivers Autoconfiguration*), otherwise `IDS_PACKERR_STARTFAIL` with the
  program and the system error text.
- **C3, waiting**: there is no worker thread; the pipe is drained inside the
  UI thread's message loop (see the amendment above).
- **C3, line limits**: there is no 990-byte line buffer any more. The whole
  output is collected (`CPackOutput`) and handed to the parser; output beyond
  `PACK_OUTPUT_MAXLEN` (512 MB) stops the run with `IDS_PACKERR_NOMEM`. A
  malformed listing is rejected as a whole (`IDS_PACKERR_PARSE`), so the
  listing is still never partial.
- **C4, unknown exit code**: a code that is not in the row's table shows
  `IDS_PACKERR_RETURN` with the program name and the text *Unknown error*
  (`IDS_PACKRET_UNKNOWN`), not the number. Only entries without a table show
  the number (`IDS_PACKRET_GENERAL`). This is the behaviour 0.1.8 had and was
  left unchanged.

## C5 — Encoding

**Amended during implementation (research R7a).** The list-file encoding is
chosen by the command template: a command that uses `$(ListUnicodeFullName)`
gets **UTF-16LE with a BOM**. 7-Zip 22.01 rejects 4-byte UTF-8 in a list file.

| Path | List file | Pipe output → panel |
|---|---|---|
| Commands using `$(ListUnicodeFullName)` (the 7-Zip and RAR rows and the new default entries) | UTF-16LE with BOM; 7-Zip reads it with `-scsUTF-16LE`, RAR with `-scul` | 7-Zip listing `-sccUTF-8`: names stay UTF-8 end to end |
| Every other command (custom entries) | unchanged: OEM, or ANSI when *Need ANSI list* is set, including the feature-069 legacy fallback | not applicable (custom entries do not list) |

A custom entry keeps its old behaviour for a name its code page cannot hold.
That is the feature-069 fallback, and changing it would change entries users
built (FR-008).

## C6 — Not changed

- The variable-expansion syntax `$(…)`, including the DOS variables, for custom
  entries.
- The initial-directory rules.
- The 15 s console restore.
- The plug-in interface: no `src/plugins/shared/` change.
