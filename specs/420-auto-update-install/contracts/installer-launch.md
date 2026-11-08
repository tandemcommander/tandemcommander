# Contract - starting the installer (feature 420)

`CreateProcessW(<updates>\tandemcommander-<ver>-x64-setup.exe, <command line>)`, current directory
the updates folder; the only handle the installer inherits is the read handle that denies writing
and deleting its own file (`PROC_THREAD_ATTRIBUTE_HANDLE_LIST`, inheritable only for that call - review 1 /
review 2), so the file stays the verified one while the installer runs. Never while an installer
of the product runs (`SalUpdIsInstallerProcessName`, review 1 M1). The command line (`SalUpdBuildInstallerArgs`):

| Kind | Arguments after the quoted program path |
|---|---|
| *now* (Install Now, start-up completion) | `/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS <mode> /LOG="<log>"` |
| *exit* | `/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS <mode> /LOG="<log>"` |

`<mode>` = `/ALLUSERS` (uninstall entry in HKLM) or `/CURRENTUSER` (HKCU). `<log>` =
`<updates>\setup-<ver>.log`. A path containing `"` is refused (cannot happen for the fixed folder).

Before the start: `Install Launches` + 1 written (the arm is created with source user for *now*).
*now*: a thread waits for the process; exit code 0 -> nothing (the program has normally been closed
by then); non-zero while the program runs -> `WM_USER_UPDATEINSTALL_DONE` -> message
`IDS_UPDATE_INSTALL_FAILED` (code); an arm the click itself created is dropped; an arm that existed
before stays only when the user answers Yes to `IDS_UPDATE_INSTALL_LATER` (UX test 1). At the next
start an arm whose installer was launched and did not install it is OFFERED (notification), never
started again at the start (review 2); the exit tries again within `SALUPD_MAX_LAUNCHES`.

*exit* is started by `UpdInstall_RunAtExit()`, the last statement of `WinMainBody` before
`return 0`, after `UpdInstall_PrepareExit()` decided right after the message loop
(`data-model.md`, exit decision).

Debug-only: `TC_UPDATE_PROBE_RUNLOG` appends `<kind>|<path>|<arguments>` and does not start
anything; `TC_UPDATE_PROBE_NORESTART` turns `/RESTARTAPPLICATIONS` into `/NORESTARTAPPLICATIONS`.
