---
title: Registry Editor 390: elevated check of Move from HKCR into the user Classes key
type: person-step
status: new
severity: 6
area: data-safety
source: leftover:390
who: person
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor 390: elevated check of Move from HKCR into the user Classes key

## Problem

Feature 390 makes the Registry Editor's Move (F6) of a key that `HKEY_CLASSES_ROOT` shows only from
the machine's half (`HKLM\Software\Classes`) into `\HKEY_CURRENT_USER\Software\Classes\` delete the
machine's key by its real path after the copy (before, the delete through HKCR removed the new
user copy again - a silent no-op). Without elevation the delete is refused by Windows (the probe
drove that: the box "Unable to remove the original registry key. (5)"); the real Move, which deletes
a machine key, needs an elevated Tandem Commander and was not driven.

## Evidence

`specs/390-regedt-hkcr-move-user/fix-log.md` (*NOT DRIVEN*, review SHOULD 1); probe rows MACHUSER /
MACHUSERU of `specs/390-regedt-hkcr-move-user/probe/hkcr390_probe.ps1` (non-elevated, real key
`.386` only read).

## Expected

Every step below gives the stated result; a different result is a new Inbox item (`measure:390`).

## Steps

- [ ] Elevated command prompt: `reg add HKLM\Software\Classes\TcCheck390\M /v m /d KEEP` and
      `reg add HKLM\Software\Classes\TcCheck390 /v t /d TOP` (TcCheck390 is held only by the
      machine's half; `reg query HKCU\Software\Classes\TcCheck390` must say it does not exist).
- [ ] Start Tandem Commander elevated (a build with feature 390). Registry Editor panel at
      `HKEY_CLASSES_ROOT`, focus `TcCheck390`, F6, target `\HKEY_CURRENT_USER\Software\Classes\`,
      OK. Expected: no box.
- [ ] `reg query HKCU\Software\Classes\TcCheck390 /s` shows `t = TOP` and the subkey `M` with
      `m = KEEP`; `reg query HKLM\Software\Classes\TcCheck390` says it does not exist; the panel at
      `HKEY_CLASSES_ROOT` still lists `TcCheck390`.
- [ ] Clean up: `reg delete HKCU\Software\Classes\TcCheck390 /f` (and
      `reg delete HKLM\Software\Classes\TcCheck390 /f` if a step failed).

## Log

- 2026-11-02 — created (source leftover:390)
