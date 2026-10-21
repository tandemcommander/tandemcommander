---
title: Registry Editor 292: elevated checks of Move through HKEY_CLASSES_ROOT
type: person-step
status: new
severity: 6
area: data-safety
source: leftover:292
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor 292: elevated checks of Move through HKEY_CLASSES_ROOT

## Problem

Feature 292 refuses a Copy / Move of a registry key onto or into itself under another root name,
including the merged view `HKEY_CLASSES_ROOT` (a key held by both `HKLM\Software\Classes` and
`HKCU\Software\Classes` counts as both). The case that deletes data on a build without the fix -
a Move onto the machine's half - needs an elevated Tandem Commander, which the hidden-desktop
probe does not have; the probe drove it non-elevated only (the unfixed build got "access denied"
at its first write, the fixed build refuses). One assumption of the rule (where a key created
through `HKEY_CLASSES_ROOT` lands) can only be measured elevated too.

## Evidence

`specs/292-regedt-alias-move-self/fix-log.md`, *Review*: second review MUST 1 (the reproduction
these steps follow), third review NOTE 3 (the creation assumption); probe row HKCRBOTH of
`specs/292-regedt-alias-move-self/probe/alias292_probe.ps1` (non-elevated).

## Expected

Every step below gives the stated result; a different result is a new Inbox item (`measure:292`).

## Steps

- [ ] Elevated command prompt: `reg add HKLM\Software\Classes\TcCheck292\M /v m /d KEEP` and
      `reg add HKCU\Software\Classes\TcCheck292 /v u /d U` (TcCheck292 is now held by both halves,
      `M` only by the machine's half).
- [ ] Start Tandem Commander elevated (a build with feature 292). Registry Editor panel at
      `HKEY_CLASSES_ROOT`, focus `TcCheck292`, F6, target `\HKEY_LOCAL_MACHINE\Software\Classes\`,
      OK. Expected: the box "Name: TcCheck292 / Error: Can't move a key to itself." (OK / Cancel);
      Cancel. Then `reg query HKLM\Software\Classes\TcCheck292 /s` still shows `M` with `m = KEEP`
      and `reg query HKCU\Software\Classes\TcCheck292` still shows `u = U`.
- [ ] Same panel, F6 of `TcCheck292` into `\HKEY_LOCAL_MACHINE\Software\Classes\TcCheck292\M\`.
      Expected: the same "Can't move a key to itself." box; Cancel; nothing changed (`reg query` as
      above).
- [ ] Where a new key goes (the assumption of the rule): elevated command prompt,
      `reg add HKCR\TcCheck292\M\N`; then `reg query HKLM\Software\Classes\TcCheck292\M\N` and
      `reg query HKCU\Software\Classes\TcCheck292\M\N`. Expected: only the HKLM one exists (the half
      of the deepest existing key, `M`). Record which one exists.
- [ ] Clean up: `reg delete HKLM\Software\Classes\TcCheck292 /f` and
      `reg delete HKCU\Software\Classes\TcCheck292 /f`.

## Log

- 2026-10-22 — created (source leftover:292)
