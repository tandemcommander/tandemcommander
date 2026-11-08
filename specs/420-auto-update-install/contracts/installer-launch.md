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
`IDS_UPDATE_INSTALL_FAILED` (code). The arm from before the click comes back with the new count
(`SalUpdArmAfterFailedNow`, round 4; an arm a click confirmed meanwhile - here or in another
instance - stays, round 6); nothing armed before = nothing armed after. An honoured arm with launches
left gets the question `IDS_UPDATE_INSTALL_LATER`: Yes confirms it (`Install Confirmed` = launches;
an arm another instance marked offered meanwhile becomes the user's again, round 8), No drops it.

An installer that **ran** since the user's last confirmation (`Install Launches` > `Install
Confirmed`) is never started again without the user's word: the exit refuses it and the next start
marks it offered (round 3, 6). A start that **failed before anything ran** (`CreateProcessW` - an
antivirus, a policy) counts the launch and moves `Install Confirmed` with it: the plan stays, the
next start completes it (rounds 6, 7: Install Now, the start-up completion, the exit). At most
`SALUPD_MAX_LAUNCHES` launches outside Install Now. An installer file that only cannot be read at
that moment (held by a scan) keeps the arm (round 8); a missing one, or one that is not ours, drops it.

*exit* is started by `UpdInstall_RunAtExit()` at the end of `WinMainBody` (after `OleUninitialize`;
only the closing trace follows), after `UpdInstall_PrepareExit()` decided right after the message
loop (`data-model.md`, exit decision).

Debug-only: `TC_UPDATE_PROBE_RUNLOG` appends `<kind>|<command line>` and does not start anything;
`TC_UPDATE_PROBE_LAUNCHFAIL` makes every start fail with error 5 (round 4);
`TC_UPDATE_PROBE_NORESTART` turns `/RESTARTAPPLICATIONS` into `/NORESTARTAPPLICATIONS`.
