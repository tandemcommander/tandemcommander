# Contract: a map window asked to close while its thread is inside a loop

Scope: the Disk Map plug-in's main window (`Zar.DM.MainWin.WC`) and its `CPluginInterface::Release`.
No plug-in interface change; this is the behaviour contract the probe checks.

## Loops

| Kind | Where | Ended by a close request |
|---|---|---|
| menu | `CShellMenu::ShowFileMenu` / `ShowDirMenu` around `TrackPopupMenuEx` | yes - `EndMenu`, no command |
| own box | `CMainWindow::OnCommand(IDM_HELP_ABOUT)`, `CMainWindow::OnKey(VK_ESCAPE)` close confirmation | yes - `IDCANCEL` to the thread's enabled dialogs owned by the map, only while no shell command is open |
| shell | `IContextMenu::InvokeCommand` in `ShowFileMenu`, `ShowDirMenu`, `InvokeDefaultCommand` | no - the shell's windows are never touched |

## Rules (pure part: `src/common/salloopclose.h`)

1. `WM_CLOSE` with no loop open: destroyed as before.
2. `WM_CLOSE` with a loop open: not destroyed; the close is pending; the actions of the table
   for the open kinds.
3. Leaving the last loop with a close pending: `WM_CLOSE` is posted to the window (rule 1 then
   applies). Several requests inside one loop: one close.
4. Entering the first loop: the window's unattended-close declaration is withdrawn (107 core);
   leaving the last loop without a pending close: declared again. The process-wide counter of
   map threads inside a loop goes up / down with them.
5. `Release` during an unattended close with the counter > 0: returns FALSE before posting
   anything (nothing closed, nothing shown).
6. `Release` otherwise: unchanged (posts `WM_CLOSE`, `KillAll` waits as before).
