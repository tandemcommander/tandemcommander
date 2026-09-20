# Closing Report — Feature 080 (upgrading over a running instance)

**Date**: 2026-09-20 · **Branch**: `080-restart-manager-upgrade` (from `main`
at `e6466db`) · **Version**: unchanged, 0.1.8 / build 192 — *unreleased*; the
feature ships inside it (`## [0.1.8] — unreleased` in `CHANGELOG.md`)
· **Plug-in interface**: 106, untouched · **Flow**: specify → plan → tasks →
implement, run autonomously.

## What was asked, and what turned out to be true

The backlog item said: *with the program open, `winget upgrade` ends in
Abort/Retry/Ignore → Abort → exit 5, because the program does not end when the
installer asks it to; fix the `ENDSESSION_CLOSEAPP` handling.*

The reproduction — the first step the item itself demanded — **refuted the
cause**. The update over a running 0.1.7 failed because of `salmon.exe`: the
crash-reporting helper has no window, the Restart Manager cannot close a
process without one, and it then fails the *whole* request within
milliseconds without asking the main program anything. Asked on its own, the
main program closes in about a second — in 0.1.7 too. Feature 079 removed the
helper for unrelated reasons and with it the failure: at the starting point of
this feature a silent update over an idle program already succeeded.

What was really wrong, all measured before any code was written:

1. The request ran the **complete interactive exit inside the question**. With
   a copy running, or a plug-in viewer window open (the default F3 viewer —
   the everyday state), the installer gave up after 5 s, **a question stayed on
   the screen of a machine nobody sits at, and when it was answered later the
   program exited by itself**, with no installer left to bring it back.
2. After a successful update the program was **gone**.
3. Upgraded installations **keep `salmon.exe`** — the file antivirus engines
   flag — and the obvious remedy, `[InstallDelete]`, **re-creates the original
   exit 5** for anyone upgrading a running 0.1.7 (measured).

## What was delivered

| Commit | Content |
|---|---|
| `3ad8551` | `src/common/salcloseapp.*`: what counts as an installer's request, the close decision (D1–D8), the restart command line — pure, under `saltests` |
| `f4b1836` | Two-stage handling in `mainwnd3.cpp` (decide at the question, act at the instruction, synchronously), `UnattendedClose` guards at every prompt site on the exit path, the `WM_CLOSE` swallow |
| `8151f9c` | `RegisterApplicationRestart`, update case only; identity (`-t`, `-i`) on the command line, state through the stored configuration |
| `a1a8982` | Installer: stale helper removed from `[Code]` at `ssPostInstall`, never via `[InstallDelete]` |
| records | spec (revised after the baseline), research R1–R9 + P1–P9, plan, data model, three contracts, quickstart V1–V20, six probes, this report, `REMAINING-WORK.md` |

Behaviour now: an idle program closes without asking anything (not even
*Confirm on program exit*), saves its configuration exactly as a normal exit
does, and is started again after the update with the same directories, tabs
and title prefix / icon. In every state where closing would need a decision —
file operation, search, modal dialog, archive edits pending, plug-in file
system, **any plug-in window** — it declines within milliseconds, shows
nothing, and keeps running; the update then fails cleanly, as it always did.

## Evidence

| Criterion | Result |
|---|---|
| SC-001 silent update over a running idle instance | **5/5 exit 0** over this build, exit 0 over the published 0.1.7 (which failed 100 % with its own installer) |
| SC-002 process ends within 10 s | 1.2–1.4 s in every run |
| SC-003 back within 15 s, same state | restarted within the installer's 3 s total; stored panels/tabs identical (SC-006) |
| SC-004 / SC-010 busy states | modal dialog, copy in progress, Code Viewer open, Find searching: **351 after 0.0 s** (before: 5.0 s + prompt + later exit), nothing on screen, no later exit |
| SC-005 zero prompts | none in any scenario, including a **forced** close of a declining program |
| SC-006 configuration equivalence | 2103 of 2104 values identical; the one differing byte differs between any two runs (File Comparator, pre-existing). With *save on exit* off: 0 differences, stored tabs untouched |
| SC-007 nothing else changed | ordinary `WM_CLOSE`: confirmation, *Exiting* dialog and the plug-in question all still appear; ordinary sign-out query takes the old path; `saltests` **1427 → 1527 / 0** |
| SC-008 machine as found | configuration export identical to the backup (same SHA-256), `setup\output` hashes unchanged, machine-wide 0.1.7 untouched, no process, shortcut or crash report left |
| SC-009 no helper after upgrade | upgraded file list **identical** to a fresh installation (360 files); a locked file never fails the installation |
| Gates | full Debug + Release builds 0 errors; runtime closure OK; `check_encoding.py` strict 0; no diff under `src/plugins/shared/` |

## Process notes worth keeping

- **Reproduce first.** The backlog's diagnosis was wrong in its cause and half
  wrong in its scope; an implementation written from the description would
  have "fixed" a handler that was never reached in the failing case and missed
  the stale file entirely.
- **Measure the protocol.** The documentation mentions neither the `WM_CLOSE`
  the Restart Manager sends after the instruction, nor that a *forced*
  request delivers the instruction to a program that declined — both decided
  the design. A 60-line logging dummy settled each question in seconds.
- **The independent review earned its place again**: no blocker, but it found
  that an instruction without an agreement still reached the old *forced
  shutdown* message box (contradicting the contract and the log), asked for
  the restart to be tried from a path with spaces, and caught a fail-open
  `EnumWindows`. Following its first finding exposed a further hole it had
  not listed (the `WM_CLOSE` after a forced instruction).
- **Tooling traps recorded in the fix-log**: `Start-Process -Wait` waits for
  the process tree (614 s lost — and the 072 recipe had the same trap), Git
  Bash rewrites `/SWITCH` arguments into paths, Bash heredocs collapse doubled
  backslashes, Setup ignores `/DIR` while an installation with the same AppId
  exists.

## Not done here

`REMAINING-WORK.md`: five human steps (elevated machine-wide update, a real
`winget upgrade`, the interactive installer, real sign-out / shutdown, a
servicing restart); the plug-in-visible unattended signal that would let viewer
windows close silently; accepted limitations; restart after reboot.

## Ship gate

None of its own. The feature is part of the unreleased 0.1.8; publishing is
`specs/NEXT-WORK.md`, section R. The branch has not been merged into `main`.
