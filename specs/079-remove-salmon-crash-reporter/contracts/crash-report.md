# Contract: In-process crash handling without a helper

**Feature**: 079 | **Scope**: `tandemcommander.exe` top-level exception
filter (`CCallStack::HandleException`, `ThreadBugReportF`,
`CreateBugReportFile`) and the pure helper `SalFormatBugReportName`.

## C1. Trigger

Any unhandled exception reaching the top-level filter registered by
`CCallStack` (spontaneous fault in the application or in a plugin,
`RaiseBreakException` from a Task List *Break*, shell-extension or
icon-overlay-handler crash reported through the existing entry points).
Under a debugger in a Debug build the filter passes the exception on, as
today.

## C2. Report location and name

- Folder: `%LOCALAPPDATA%\Tandem Commander\` — resolved with
  `SHGetFolderPathW(CSIDL_LOCAL_APPDATA)`, created with `CreateDirectoryW`
  when missing. Failure to resolve or create the folder is not fatal for the
  message (C5).
- Name: `SalFormatBugReportName(out, outLen, VERSINFO_SAL_SHORT_VERSION,
  localTime, suffix)` → `TC<shortver>-YYYYMMDD-HHMMSS[-suffix].TXT`,
  upper-case ASCII, `suffix` 0 (omitted) … 99. The caller probes with
  `GetFileAttributesW` and takes the first suffix that does not exist; after
  99 collisions the last name is used and `CREATE_NEW` decides.
- The full path is a `WCHAR` string of at most `MAX_PATH` characters.

## C3. Report content

Unchanged from 0.1.8: `CreateBugReportFile` opens the file with
`CreateFileW(…, CREATE_NEW, …)` and `CCallStack::PrintBugReport` writes the
header, the exception information (`Information About Exception` with
`execution address = 0x…`), registers, call stacks and modules. Consumers
(users, the 077/079 probes) may rely on the `.TXT` extension and on the
`execution address = 0x<hex>` line.

## C4. Threading and timing

1. The crashing thread records itself as the handling thread. A second
   entry on the **same** thread (nested fault) terminates the process
   immediately with exit code 1 (no report, no message). A second entry on
   **another** thread waits, as today, until the first is done (which ends
   in termination).
2. If the bug-report thread exists and the crashing thread is not that
   thread: signal `Event`, wait `EventProcessed` up to **6 000 ms**. On
   success, wait `MessageDone` **without a time limit** (user-driven).
3. Otherwise (no thread, timeout, failure reported, or the crashing thread
   *is* the bug-report thread): write the report on the crashing thread
   (suspending the bug-report thread first, as today, unless it is the
   current thread), then show the message on the crashing thread.
4. `TerminateProcess(GetCurrentProcess(), 1)` — the exit code stays 1.

## C5. Closing message

- Shown once per crash, after the report was written (or failed).
- API: `MessageBoxW(NULL, text, caption, MB_OK | MB_ICONERROR |
  MB_SETFOREGROUND | MB_TOPMOST)`.
- Caption: `SALAMANDER_TEXT_VERSION` widened (`Tandem Commander 0.1.8
  (x64)`).
- Text: `IDS_BUGREPORT_SAVED` with the full report path when the report was
  written; `IDS_BUGREPORT_NOTSAVED` with the intended path otherwise. When
  `HLanguage` is NULL (crash before the language module is loaded) the
  English fallback literals are used; they are byte-identical to the English
  resource texts.
- The existing special notices (`IDS_SHELLEXTCRASH`,
  `InformAboutIconOvrlsHanCrash`) are shown **before** the closing message,
  from the same thread, as today.

## C6. What no longer happens

- No process is started; no shared memory, events or mutex named
  `TandemCommanderBugReporterRegistryMutex` are created.
- No wait on anything outside the process.
- `HKCU\Software\Tandem Commander\Bug Reporter` is never opened.
- The report folder is never scanned; earlier reports are never offered,
  renamed or deleted.
- The strings `IDS_SALMON_*` and the dialog `IDD_SALMON_MAIN` do not exist.

## C7. Test hooks

- `TestBugReport079` (saltests): name format, upper-case, suffix, illegal
  characters, buffer bound.
- `probe/crash_inject.ps1`: end-to-end for targets `app` and `plugin`
  (report path in the message text, `WM_COMMAND IDOK` dismisses it, exit
  code 1).
