# Data Model: Remove the salmon.exe Crash Reporter

**Feature**: 079 | **Date**: 2026-09-19

## 1. Crash report (file)

| Attribute | Value |
|-----------|-------|
| Location | `%LOCALAPPDATA%\Tandem Commander\` (`SHGetFolderPathW(CSIDL_LOCAL_APPDATA)` + `\Tandem Commander`), created on demand |
| Name | `TC<shortver>-YYYYMMDD-HHMMSS[-n].TXT`, upper-case; `<shortver>` = `VERSINFO_SAL_SHORT_VERSION`; `n` = 1…99 collision suffix |
| Encoding of the path | UTF-16 (`WCHAR`) end to end inside the crash code |
| Content | unchanged: header `Tandem Commander Bug Report File`, exception information (code, faulting/execution address), registers, call stacks of all threads, loaded modules — produced by `CCallStack::PrintBugReport` |
| Producer | the application itself (bug-report thread, or the crashing thread as fallback) |
| Lifetime | never read, renamed, offered or deleted by the application |
| Privacy | never transmitted |

**Validation rules** (unit-tested in `TestBugReport079`): name contains only
`A-Z`, `0-9`, `-`, `.`; fixed layout with 8-digit date and 6-digit time;
suffix appears only when `n > 0`; the formatter refuses (returns FALSE) when
the buffer is too small; a name never exceeds 64 characters.

**State transitions of one crash** (see `contracts/crash-report.md`):

```text
fault → [guard: re-entry on handling thread → terminate]
      → folder resolved/created → name chosen
      → report written (thread, ≤6 s) ─┐        → message shown (thread) → MessageDone → terminate(1)
      → report written inline (fallback)┘        → message shown inline           → terminate(1)
      → report NOT writable → message "could not be saved" (either path)      → terminate(1)
```

## 2. Bug-report thread handshake (`CTBRData`, in-process only)

| Field | Type | Meaning |
|-------|------|---------|
| `TerminateEvent` | HANDLE | existing: ends the thread at shutdown |
| `Event` | HANDLE | existing: "a crash is waiting for you" |
| `EventProcessed` | HANDLE | existing: "the report has been written (or failed)" |
| `EventProcessedRet` | BOOL | existing: result of writing the report |
| `MessageDone` | HANDLE | **new**: "the closing message was dismissed" |
| `Exception`, `CurrentThreadID`, `ShellExtCrashID`, `IconOvrlsHanName` | | existing |
| `BugReportPath` | `const WCHAR*` | **changed**: full path of the report file (was `const char*`) |
| `ExitProcess` | BOOL | existing (unused output) |

The crashing thread owns the static buffers the pointers refer to; the
thread only reads them. `HandlingThreadID` (static, `DWORD`) records which
thread is inside `HandleException` for the re-entry guard.

## 3. Process-list record (`CProcessListItem`, shared between instances)

See `contracts/process-list-record.md`. Only one field changes name:

| Offset order | Field | Change |
|--------------|-------|--------|
| 1–6 | `PID`, `StartTime`, `IntegrityLevel`, `SID_MD5`, `ProcessState`, `HMainWindow` | unchanged |
| 7 | `SalmonPID` → `Reserved1` | same type (`DWORD`), same offset, always 0 |

## 4. Language resources

| Removed | Added |
|---------|-------|
| dialog `IDD_SALMON_MAIN` (6130) and controls `IDC_SALMON_*` (6131–6140) | — |
| strings `IDS_SALMON_*` (14010–14075) and `IDS_SALMON_NOT_RUNNING` (14100) | `IDS_BUGREPORT_SAVED`, `IDS_BUGREPORT_NOTSAVED` (ids chosen in the freed 14010 range) |

Both new strings carry exactly one `%s` (the report path). The English
texts are duplicated as fallback literals in `callstk.cpp` for a crash
before the language module is loaded.

## 5. Registry

| Key | Before | After |
|-----|--------|-------|
| `HKCU\Software\Tandem Commander\Bug Reporter` (`ID` REG_QWORD, helper settings) | read/created at every start | never touched; left on users' machines |
| `HKCU\Software\Tandem Commander\0.1\…` | — | unchanged, no version bump |
