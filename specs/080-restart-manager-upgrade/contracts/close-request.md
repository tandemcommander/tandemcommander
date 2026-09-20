# Contract — an installer's close request

**Feature**: 080 · **Binding for**: `src/mainwnd3.cpp` (`WM_QUERYENDSESSION`,
`WM_ENDSESSION`, `WM_CLOSE`), `src/common/salcloseapp.*`, and every prompt
site on the exit path. Measured protocol facts P1–P6: `research.md` R2.

## C1 — What counts as an installer's close request

A session message is an installer's close request **iff**
`lParam & ENDSESSION_CLOSEAPP`, **not** `lParam & ENDSESSION_CRITICAL`, and
`GetSystemMetrics(SM_SHUTTINGDOWN) == 0` (`SalIsCloseAppRequest`).

Everything else is **not** covered by this contract and MUST take the code
path it took before feature 080, unchanged: sign-out, shutdown, critical
shutdown, a servicing restart, `WM_USER_CLOSE_MAINWND`,
`WM_USER_FORCECLOSE_MAINWND`.

## C2 — The question stage (`WM_QUERYENDSESSION` from outside)

1. The program collects a snapshot (`data-model.md` §2) and evaluates
   `SalCloseAppDecide`.
2. It returns **TRUE** for `scadAgree`, **FALSE** otherwise.
3. It has **no side effects**: nothing is closed, stopped, saved, shown,
   disabled or marked busy. The only state it changes is `CloseAppAgreed`.
   In particular it MUST NOT set `SalamanderBusy`, `DisableIdleProcessing`,
   `SaveCfgInEndSession` or `WaitInEndSession`.
4. It answers within milliseconds (budget: 5 s, P4). It MUST NOT wait for
   anything — no `WaitForIdle`, no message pumping, no cross-thread
   `SendMessage`.
5. The decision and its reason are traced (`TRACE_I`).

## C3 — The instruction stage (`WM_ENDSESSION`)

| wParam | `CloseAppAgreed` | Behaviour |
|---|---|---|
| 0 | any | clear `CloseAppAgreed`; `return 0`. Nothing to undo (C2.3). |
| 1 | FALSE | not ours (we never agreed) → the pre-080 `WM_ENDSESSION` path |
| 1 | TRUE | clear `CloseAppAgreed`; arm the `WM_CLOSE` swallow (C5); evaluate the decision **again**; if it no longer agrees → trace, `return 0` (the program keeps running); else run the execute stage (C4); `return 0` |

The pre-080 *forced shutdown* message box (`IDS_FORCEDSHUTDOWN`) MUST NOT be
reachable for an installer's close request.

## C4 — The execute stage

The exit sequence that a non-critical session request has always run — Find
windows, viewers, plug-in unload, panels, configuration save, `DestroyWindow`
— **synchronously**, inside the `WM_ENDSESSION` handler, with
`UnattendedClose == TRUE` for its whole duration.

- It is entered by re-dispatching `WM_QUERYENDSESSION` to the handler with
  `CloseAppExecuting == TRUE`; no message from outside can select it.
- It saves the configuration exactly when and how a normal exit does
  (`Configuration.AutoSave`), under the same half-written-configuration
  protection (`SALAMANDER_SAVE_IN_PROGRESS`).
- A wait window that needs no answer is allowed. **No prompt is.**
- After `DestroyWindow` the handler touches no member of the window object.
- The process then ends by itself (`WM_DESTROY` → quit message → message loop
  → normal clean-up). Nobody kills it. Budget: 10 s target, 30 s limit (P3).
- `CriticalShutdown` stays FALSE and `IsCriticalShutdown()` keeps returning
  FALSE to plug-ins: the unattended close loses nothing, the critical one is
  allowed to.

## C5 — No prompt, ever (`UnattendedClose`)

While `UnattendedClose` is TRUE, every site on the exit path that would show
a question, a message box or a dialog that waits for the user MUST take its
**negative** branch — the one that leaves the program running — without
showing anything. The sites (research R6):

| Site | Negative branch |
|---|---|
| `CExitingOpenSal` (file operations running) | as if cancelled → refuse |
| Find close query | sent *quiet*; a refusing Find window → refuse |
| `CPluginData::Unload` → `IDS_PLUGINFORCEUNLOAD` | as if *No* → unload fails → refuse |
| `IDS_SHELLEXTBREAK3` | as if *Continue* → refuse |
| `PrepareCloseCurrentPath`: `IDS_ARCHIVECLOSEEDIT`, the pack-back dialog | return FALSE before either |
| `PrepareCloseCurrentPath`: `IDS_ARCHIVEFORCECLOSE`, `IDS_FSFORCECLOSE` | as if *No* → FALSE |
| `CloseDetachedFS`: `IDS_FSFORCECLOSE` | as if *No* → FALSE |
| `LockedUIReason` message box | not shown |
| exit confirmation `CnfrmOnSalClose` | never reached (it belongs to `WM_USER_CLOSE_MAINWND` only) |

A site added to the exit path later MUST follow the same rule. The guard is
spelled out at each site (`if (UnattendedClose) …`), not hidden inside the
message-box function.

**The `WM_CLOSE` that follows** (P2): the first `WM_CLOSE` delivered to the
main window within 35 s of the start of the execute stage is ignored, once.
Any later `WM_CLOSE` is an ordinary interactive exit.

## C6 — The decision table

`SalCloseAppDecide` returns the first matching row (`data-model.md` §3):

| # | Condition | Decision |
|---|---|---|
| D1 | start-up not finished, or a close already under way | decline |
| D2 | main thread busy (modal dialog, menu, command) or main window disabled | decline |
| D3 | inside a plug-in call | decline |
| D4 | at least one file operation running | decline |
| D5 | at least one Find window searching | decline |
| D6 | files opened from an archive not yet packed back (either panel) | decline |
| D7 | a panel on a plug-in file system, or a detached file system exists | decline |
| D8 | a visible top-level window of the process that is not the main window, an internal viewer, a Find window or the help window, and is not a captionless tool window | decline |
| — | none of the above | **agree** |

Closed silently by an agreed request: internal viewer windows, idle Find
windows, the help window, a panel inside an archive with nothing edited.

## C7 — Other windows of the process (spec FR-008)

Find windows, viewers and plug-in windows receive the same two messages from
the Restart Manager (P1). They keep their default handling: they answer TRUE
and do nothing on `WM_ENDSESSION`. Only the main window decides; when it
declines, D4/D5/D8 have already accounted for them, and they are not touched.

## C8 — What a refusal leaves behind

Nothing: no window, no disabled main window, no wait window, no pending exit.
In particular the program MUST NOT exit later as a consequence of a request it
declined or abandoned (the pre-080 defect measured in S2/S3).
