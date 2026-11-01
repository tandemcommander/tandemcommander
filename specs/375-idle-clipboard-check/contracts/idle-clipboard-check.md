# Contract - the idle clipboard check (feature 375)

Internal to the core (no plug-in interface).

## `CFilesWindow::IsTextOnClipboard(BOOL noWait = FALSE, BOOL* busy = NULL)`

- `noWait == FALSE` (default, `RestoreGlobalSelection`): unchanged - up to 10 retries with
  `Sleep(10)`.
- `noWait == TRUE` (the idle check): one `OpenClipboard` attempt, no `Sleep`. If it fails,
  returns FALSE (today's result after the retries gave up) and sets `*busy = TRUE`.
- `busy` (optional) is set to TRUE only when the clipboard could not be opened; it is never
  cleared by the function (the caller initialises it).

## `SalClipCheckNextLook(BOOL busy, BOOL wasRetry, int* retries)` (`src/common/salclipcheck.h`)

Returns the delay of the next look in ms, 0 = none.

| wasRetry | busy | *retries before | result | *retries after |
|---|---|---|---|---|
| any | FALSE | any | 0 | 0 |
| FALSE | TRUE | any | 500 | 1 |
| TRUE | TRUE | n < 10 | 500 | n + 1 |
| TRUE | TRUE | n >= 10 | 0 | n |

## The idle check (`CMainWindow_RefreshCommandStates`)

When `IdleCheckClipboard`: runs the four queries as today, the text query in the no-wait form;
then `delay = SalClipCheckNextLook(busy, IdleClipCheckIsRetry, &IdleClipCheckRetries)`,
`IdleClipCheckIsRetry = FALSE`; `delay > 0` -> `SetTimer(main, IDT_CLIPCHECKRETRY, delay)`,
pending = TRUE; `delay == 0` and pending -> `KillTimer`, pending = FALSE.

## Timer `IDT_CLIPCHECKRETRY` (main window)

`KillTimer`, pending = FALSE, `IdleClipCheckIsRetry = TRUE`, `IdleRefreshStates = TRUE`,
`IdleCheckClipboard = TRUE` (the idle after the timer message runs the check).

## Menus (`RequestIdleClipCheckIfBusy`, review 1)

`IdleClipCheckLastBusy` = the `busy` of the last idle check. Before a menu reads the paste
enablers - `WM_USER_ENTERMENULOOP` (main menu), the archive item and archive panel context menus
(`shellsup.cpp`, before their `OnEnterIdle`), the disk panel background menu (before its Paste
items; then `RefreshCommandStates`) - `RequestIdleClipCheckIfBusy()`: if `IdleClipCheckLastBusy`
-> `IdleRefreshStates = IdleCheckClipboard = TRUE` (not a retry: the series restarts).
