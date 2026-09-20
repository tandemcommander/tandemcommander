# Contract — restart registration

**Feature**: 080 · **Binding for**: the start-up code in `src/salamdr1.cpp`
and `SalRestartCommandLine` in `src/common/salcloseapp.*`.

## R1 — When

Once per process, at the point where start-up is complete and the main window
may be closed (`MainWindow->CanClose = TRUE`). Not earlier: an instance that
exits during start-up (configuration import, *only one instance* hand-over,
language selection) must not be restartable.

A failure of `RegisterApplicationRestart` is traced and otherwise ignored; it
never affects start-up.

## R2 — Flags

`RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT`

| Flag | Why |
|---|---|
| `RESTART_NO_CRASH` | the program handles its crashes itself (report, message, exit code 1); an automatic restart on top is not part of this feature |
| `RESTART_NO_HANG` | same |
| `RESTART_NO_REBOOT` | keeps the program out of *"restart apps after signing in"*; unrelated to updates, not verifiable here, a separate decision |

Remaining case = the one wanted: a close requested through the Restart
Manager (an installer, a package manager).

## R3 — Command line

`SalRestartCommandLine(hasTitlePrefix, titlePrefix, hasIconIndex, iconIndex,
buffer, bufferSize)`:

- carries **identity**: `-t "<prefix>"` when the instance was started with
  `-t`, `-i <n>` when it was started with `-i`;
- carries **no location and no mode**: never `-l`, `-r`, `-a`, `-aj`, `-p`,
  `-c`, `-o`, `-run_notepad`;
- quotes the prefix the way the program's tokenizer (`GetCmdLine`) reads it:
  enclosed in `"`, a literal `"` doubled;
- never exceeds `RESTART_MAX_CMD_LINE` (1024): a part that does not fit is
  left out whole, never cut;
- is empty for an instance started without `-t` / `-i`.

The restarted process is an ordinary instance: it reads the stored
configuration like any other start and shows what that says (both panels'
directories, tabs, active tab — feature 078). With *Save configuration on
exit* disabled it shows the stored state, not the state at closing.

## R4 — Who decides

The installer. The program only declares itself restartable; Inno Setup
restarts what it closed unless run with `/NORESTARTAPPLICATIONS`. No program
option exists for this (spec *Assumptions*).

## R5 — What the registration must not change

- nothing about a normal exit, a crash, a hang, a sign-out or a reboot;
- nothing about *only one instance* handling;
- nothing stored anywhere.
