---
title: Command line: a COMSPEC path outside ASCII is read through the code page
type: bug
status: open
severity: 2
area: encoding
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Command line: a COMSPEC path outside ASCII is read through the code page

## Problem

A command typed into the command line under the panels is run through `%COMSPEC%` (cmd /C or /K). The program reads COMSPEC with the code-page (A) call and hands the result to `SalCreateProcess`, which takes UTF-8: a COMSPEC with letters outside ASCII (e.g. a shell in a folder with accented or CJK letters) becomes another name or `?` and the command does not start. The length limit of the command line (`GetCmdLineLimit`) is also computed from the A read. Narrow: COMSPEC almost always is `C:\Windows\system32\cmd.exe`.

## Evidence

At 50cf9e7d (by reading):

- `src/editwnd.cpp` `GetCmdLineLimit` (~355): `GetEnvironmentVariable("COMSPEC", cmd, MAX_PATH)`.
- `src/editwnd.cpp` `CEditLine::WindowProc` (~482): `GetEnvironmentVariable("COMSPEC", cmd, SALCMDLINE_MAXLEN + MAX_PATH)`, then `AddDoubleQuotesIfNeeded`, the `/C` / `/K` and the user's command appended, `SalCreateProcess(NULL, cmd, ...)` (~552).
- The User Menu's batch route already reads it with `SalGetEnvVarU8` (`src/mainwnd4.cpp` ~1140, feature 226).
- Recorded with feature 226's leftovers ("`editwnd.cpp:355/482` read COMSPEC with the A call"); split from `user-menu-messages-and-folder-leftovers`.

## Expected

Both sites read COMSPEC with `SalGetEnvVarU8` (UTF-8); an unset or too long COMSPEC behaves as today (empty -> the user's command alone; check what that does and keep it, or refuse aloud); `tools/check_encoding.py --strict` stays `TOTAL: 0`. A probe or a by-reading note shows a non-ASCII COMSPEC (a copy of cmd.exe in a folder with Czech letters, set for the probe's process only) runs the typed command.

## Notes

The policy check `SystemPolicies.GetMyCanRun(cmd)` gets the same buffer - check that it takes UTF-8.

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 57
- 2026-10-23 — related item user-menu-messages-and-folder-leftovers closed: split into: user-menu-errors-name-the-file-or-folder, user-menu-hidden-batch-silent-early-end, user-menu-shortcut-start-in-folder, user-menu-unc-folder-pushd, command-line-comspec-read-wide, user-menu-long-paths - the parts replace it; maintainer 2026-10-23
