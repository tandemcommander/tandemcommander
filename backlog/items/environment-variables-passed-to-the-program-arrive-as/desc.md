---
title: Environment variables passed to the program arrive as question marks outside the code page
type: bug
status: open
severity: 4
area: encoding
source: measure:386
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Environment variables passed to the program arrive as question marks outside the code page

## Problem

At start the program copies its environment through the code page: `CEnvVariables`
(`src/salamdr7.cpp`) reads it with `GetEnvironmentStrings` (the code-page form), lets the shell
regenerate the user environment (`RegenerateUserEnvironment`) and then re-adds every variable the
regeneration dropped - the variables the launcher passed that are not in the user's registry
environment - with the code-page `SetEnvironmentVariable`. A value with letters outside the code
page (CJK on a Czech or English system, for example) becomes `?` in the program and in every
program it starts (Command Shell, external viewers and editors, user-menu commands, archivers):
another path, another value.

## Evidence

Measured by feature 386 (`specs/386-mydocs-path-whole/fix-log.md`, *T002-T004*) at 66a9dfcc on
branch `386-mydocs-path-whole`: a probe started `tandemcommander.exe` (Debug) with
`TC_PROBE_MYDOCS_PATH=C:\Users\...\Temp\tc386\` + 90 CJK letters (U+4E01..U+4E5A) through Windows
PowerShell `Start-Process`; the program read the variable with `GetEnvironmentVariableW` and got
90 literal `?` (the message the probe dumped: code units `003F` x 90, error 123). The same
`Start-Process` passed the value intact to another PowerShell (checked, UTF-8 bytes
`E4 B8 81 E4 B8 82`), so the value was intact up to the program's start. Code at HEAD:
`src/salamdr7.cpp` `CEnvVariables::LoadFromProcess` (`char* vars = GetEnvironmentStrings();`),
`CEnvVariables::ApplyDifferencesToCurrentProcess` (`SetEnvironmentVariable(var->Name, ...)`),
`InitEnvironmentVariablesDifferences`.

## Expected

A variable the launcher passed keeps its exact value (wide: `GetEnvironmentStringsW` /
`SetEnvironmentVariableW`, names compared by the system's rule); the regeneration still drops or
refreshes what it did before.

## Notes

Not checked: whether variables refreshed later (`EnvVariablesDiff` re-applied after a settings
change) are affected the same way, and whether a user-registry variable with CJK letters keeps
its value (the regeneration itself is wide). Feature 386 worked around it in its probe seam (a
file named by an ASCII variable).

## Log

- 2026-11-02 — created (source measure:386)
- 2026-11-02 — moved to Next position 29
