---
title: User Menu errors name the command, not the file or folder at fault
type: bug
status: open
severity: 3
area: panels-ui
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: [user-menu-messages-and-folder-leftovers, user-menu-unc-folder-pushd]
depends-on: []
reason: -
---

# User Menu errors name the command, not the file or folder at fault

## Problem

A User Menu item that is refused or cannot start tells the user about the wrong thing, and one case may run the command in the wrong folder:

1. A value the batch file cannot hold unchanged (a `^` in a file name, an unquoted `&`, a `%` the line would change - features 229 / 238) is refused with "Error executing <the command>: The filename, directory name, or volume label syntax is incorrect" - the user is not told which file's name is the reason.
2. A missing item folder (the panel or a Find result shows a folder that was renamed or removed meanwhile; feature 234 passes it as `lpDirectory` / cmd's start folder) fails with "Error executing <the command>" (direct route) or "Error executing <COMSPEC> /C <the batch file>" (batch route) - the folder is not named.
3. A panel folder that cannot be made the current folder falls back to the system folder (System32): `SetCurrentDirectoryToSystem()`. A command with a relative name, or a document opened through an association that ignores `lpDirectory`, could then resolve in System32. Refuse instead (naming the folder) when the command would run relative to that folder.

## Evidence

At 50cf9e7d (by reading; not reproduced in the run that split the parent item):

- `src/mainwnd4.cpp` `ShowUserMenuBatchRefusal(parent, command)` (~564) is called from `ExpandCommand2` (~670, ~704) with the expanded command also when `batchRefused` was set by `ExpandUserMenuArguments` for an inserted file name.
- `src/mainwnd4.cpp` `CMainWindow::UserMenu` direct route: `sei.lpDirectory = initDir or path` (~1081); on failure `IDS_EXECERROR` with `cmdLine` (~1090). Batch route: `SalCreateProcess(..., firstItemDir, ...)` (~1155-1169), failure message with `cmdLine` = COMSPEC + `/C` + the batch file name.
- `src/mainwnd3.cpp` ~2829: `if (!SalSetCurrentDirectoryU8(activePanel->GetPath())) SetCurrentDirectoryToSystem();` before `UserMenu(...)` (feature 226's comment: "when it cannot be set, that system folder - never another panel's").
- Origin: features 226 (`specs/226-user-menu-batch-encoding/fix-log.md`), 229, 234 (`specs/234-user-menu-item-folder/fix-log.md`, *Review* 1: "a missing folder's message names the command, not the folder"), 238; split from `user-menu-messages-and-folder-leftovers`.

## Expected

- A refused inserted value names the file (the full name) whose name is the reason; a refused command text still names the command.
- A missing or unenterable item folder / Initial Directory (without a `%VAR%` left for cmd to expand) is refused before anything runs, with a message naming the folder (an existing string such as `IDS_EXECERROR` with the folder and `GetErrorText(ERROR_PATH_NOT_FOUND)`, or another existing one - no new UI string unless the `.slt` refresh is planned).
- No User Menu command runs with System32 as its folder because the panel's folder could not be set.
- A probe in the style of `specs/226-user-menu-batch-encoding/probe/um226_probe.ps1` shows each case before / after; 226 / 229 / 234 probes stay green.

## Approach

Measure first: is the System32 fallback still reachable after 234 (both routes now pass the item's folder explicitly)? Check what ShellExecuteEx does with an `lpDirectory` that is not there (an .exe vs a document with an association). For item 1, `ExpandUserMenuArguments` / `DoExpandVarString` would have to tell which inserted value was refused - the refusal flag carries no name today.

## Notes

Severity: wording plus a suspected wrong-folder case; the lower value taken until the System32 case is measured. The UNC case of the batch route is its own item (`user-menu-unc-folder-pushd`); a missing Initial Directory in a hidden batch with a `%VAR%` cmd must expand is `user-menu-hidden-batch-silent-early-end`.

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 52
