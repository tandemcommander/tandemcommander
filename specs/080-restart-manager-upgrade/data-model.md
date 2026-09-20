# Data Model — Feature 080

Nothing here is persisted. The feature introduces no stored value; these are
the in-memory shapes the pure module (`src/common/salcloseapp.*`) and the core
exchange.

## 1. Request class — `SalIsCloseAppRequest`

How a session message is classified. Input: the message's `lParam` and whether
the session is shutting down (`GetSystemMetrics(SM_SHUTTINGDOWN)`). Output:
TRUE = an installer's close request, FALSE = everything else — the existing
sign-out / shutdown / critical path handles it, untouched.

| `ENDSESSION_CLOSEAPP` | `ENDSESSION_CRITICAL` | session shutting down | Result |
|---|---|---|---|
| not set | any | any | FALSE |
| set | set | any | FALSE (forced: the critical path knows how to survive being killed) |
| set | not set | yes | FALSE (Windows is closing programs for servicing — a real shutdown) |
| set | not set | no | **TRUE** |

`ENDSESSION_LOGOFF` does not influence the result.

The **stage** is not encoded in the message: the question stage is
`WM_QUERYENDSESSION` arriving from outside; the execute stage is the same
message re-dispatched by the program to itself from its `WM_ENDSESSION`
branch, marked by the core's own flag `CloseAppExecuting` set around that
call. Nothing another process sends can select the execute stage.

## 2. State snapshot — `CSalCloseAppSnapshot`

Plain data, filled by `CMainWindow` on the main thread, read-only collection.

| Field | Type | Source in the core |
|---|---|---|
| `StartupFinished` | bool | `CanClose \|\| CanCloseButInEndSuspendMode` |
| `CloseInProgress` | bool | `CannotCloseSalMainWnd`, or the main window already marked closed |
| `Busy` | bool | `SalamanderBusy`, or the main window is disabled |
| `InsidePlugin` | bool | `AlreadyInPlugin > 0` |
| `FileOperations` | int | `ProgressDlgArray.RemoveFinishedDlgs()` |
| `FindSearching` | int | Find windows of `FindDialogQueue` with `IsSearchInProgress()` (under `WindowsManager.CS`) |
| `ArchiveEditsPending` | bool | `AssocUsed` of the left or the right panel |
| `PluginFSOpen` | bool | either panel `Is(ptPluginFS)`, or `DetachedFSList->Count > 0` |
| `Windows` | array of `CSalCloseAppWindow` | every top-level window of the process (`EnumWindows` + pid) |

### Window descriptor — `CSalCloseAppWindow`

| Field | Type | Meaning |
|---|---|---|
| `Visible` | bool | `IsWindowVisible` |
| `Style`, `ExStyle` | DWORD | `GWL_STYLE`, `GWL_EXSTYLE` |
| `Kind` | enum | `scawMain`, `scawInternalViewer`, `scawFind`, `scawHelp`, `scawOther` — assigned by the collector from the window class / the Find queue |

The pure module decides whether a descriptor **counts as foreign** (D8):

```
foreign = Visible
          && Kind == scawOther
          && !( no WS_CAPTION && (WS_EX_TOOLWINDOW || WS_EX_NOACTIVATE) )
```

i.e. tooltips, save-bits and IME windows never count; a captionless window
that is *not* a tool window (a full-screen picture viewer) does.

## 3. Decision — `CSalCloseAppDecision`

| Value | Reason (research R5) |
|---|---|
| `scadAgree` | the instance can close now without asking anyone |
| `scadStartupOrClosing` | D1 |
| `scadBusy` | D2 |
| `scadInsidePlugin` | D3 |
| `scadFileOperations` | D4 |
| `scadFindSearching` | D5 |
| `scadArchiveEdits` | D6 |
| `scadPluginFS` | D7 |
| `scadForeignWindow` | D8 |

Rules: the first matching reason in the order D1…D8 wins (so the trace names
the most fundamental obstacle); `SalCloseAppDecisionName()` returns a constant
ASCII name for the trace. The function is total and has no side effects.

## 4. Request state (core, main thread only)

| Item | Type | Life cycle |
|---|---|---|
| `CloseAppAgreed` | BOOL | set TRUE by an agreeing query stage; cleared by the following `WM_ENDSESSION` (either wParam) and by a new query |
| `CloseAppExecuteTime` | DWORD (tick) | set when the execute stage starts; arms the `WM_CLOSE` swallow |
| `CloseAppSwallowClose` | BOOL | one-shot: the first `WM_CLOSE` within 35 s of `CloseAppExecuteTime` is ignored and clears it |
| `CloseAppExecuting` | BOOL | TRUE around the re-dispatch from `WM_ENDSESSION`; selects the execute stage |
| `UnattendedClose` | BOOL, global (`consts.h`) | TRUE only while the execute stage runs; read by the prompt sites; never visible to plug-ins |

State transitions:

```
idle ──query, agree──▶ agreed ──WM_ENDSESSION(1)──▶ executing ──▶ (window destroyed, process ends)
  ▲                      │                              │
  │                      └──WM_ENDSESSION(0)──▶ idle    └──abandoned──▶ idle (swallow armed for 35 s)
  └──query, decline (nothing changes)
```

## 5. Restart command line

Input: title prefix given on the command line? (+ text), icon index given on
the command line? (+ 0–3). Output: a wide string, at most
`RESTART_MAX_CMD_LINE` (1024) characters, that the program's own tokenizer
(`GetCmdLine`) parses back to the same values:

| Input | Output |
|---|---|
| nothing | *(empty)* |
| prefix `Work` | `-t "Work"` |
| prefix `My "big" disk` | `-t "My ""big"" disk"` |
| icon 2 | `-i 2` |
| both | `-t "Work" -i 2` |

A prefix that would not fit is dropped rather than truncated (a truncated
quoted argument would not parse); in practice a prefix is at most
`TITLE_PREFIX_MAX` characters.
