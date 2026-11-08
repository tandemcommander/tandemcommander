# Contract - starting the installer (feature 420)

`CreateProcessW(<updates>\tandemcommander-<ver>-x64-setup.exe, <command line>)`, current directory
the updates folder, no inherited handles. The command line (`SalUpdBuildInstallerArgs`):

| Kind | Arguments after the quoted program path |
|---|---|
| *now* (Install Now, start-up completion) | `/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS <mode> /LOG="<log>"` |
| *exit* | `/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS <mode> /LOG="<log>"` |

`<mode>` = `/ALLUSERS` (uninstall entry in HKLM) or `/CURRENTUSER` (HKCU). `<log>` =
`<updates>\setup-<ver>.log`. A path containing `"` is refused (cannot happen for the fixed folder).

Before the start: `Install Launches` + 1 written (the arm is created with source user for *now*).
*now*: a thread waits for the process; exit code 0 -> nothing (the program has normally been closed
by then); non-zero while the program runs -> `WM_USER_UPDATEINSTALL_DONE` -> message
`IDS_UPDATE_INSTALL_FAILED` (code), the arm stays (source user) for the exit.

*exit* is started by `UpdInstall_RunAtExit()`, the last statement of `WinMainBody` before
`return 0`, after `UpdInstall_PrepareExit()` decided right after the message loop
(`data-model.md`, exit decision).

Debug-only: `TC_UPDATE_PROBE_RUNLOG` appends `<kind>|<path>|<arguments>` and does not start
anything; `TC_UPDATE_PROBE_NORESTART` turns `/RESTARTAPPLICATIONS` into `/NORESTARTAPPLICATIONS`.
