---
title: Restore the product registry key changed by a killed probe of feature 320
type: person-step
status: new
severity: 2
area: tooling
source: leftover:320
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Restore the product registry key changed by a killed probe of feature 320

## Problem

The first independent review of feature 320 was killed while its hidden-desktop probe ran; the
probe's own restore never happened. The product key `HKCU\Software\Tandem Commander` was left with
the probe's panel paths and focus and the Debug build's `Plugins.ver Version (x64)`. The run could not
restore it: the installed Tandem Commander was running on the same key (started 06:43) and writes its
state on exit.

## Evidence

`specs/320-zip-failed-replace/fix-log.md`, *Review*: backup `%TEMP%\tc320_backup.reg` (06:02,
SHA-256 CF69145A373CD3C5FA6D952F0F20D792817E208F4706F523B2C6005A9B9AEF01 - the state every probe
run of 320 restored to); the export at 08:00 differed only in the left/right panel `Path` values and
the drive `C` path (the `tc320_zipreplace\add-ctl` fixture), `Right Panel Focused` (1 -> 0) and
`Plugins.ver Version (x64)` (00d724bc -> 00d728f2).

## Expected

The key holds the maintainer's own settings again (or the maintainer decides the current state is
fine), and `%TEMP%\tc320_backup.reg` is gone.

## Steps

- [ ] Close every Tandem Commander window (installed and Debug builds).
- [ ] Decide: if the settings changed since 06:00 should stay, only check that `Plugins.ver Version
      (x64)` under the key is what the installed version expects (start it once: no plug-in
      re-registration question) and delete `%TEMP%\tc320_backup.reg`; otherwise go on.
- [ ] `reg delete "HKCU\Software\Tandem Commander" /f`, then `reg import %TEMP%\tc320_backup.reg`.
- [ ] `reg export "HKCU\Software\Tandem Commander" %TEMP%\check.reg /y` and compare its SHA-256 with
      CF69145A373CD3C5FA6D952F0F20D792817E208F4706F523B2C6005A9B9AEF01 - identical; then delete both
      `.reg` files.

## Log

- 2026-10-23 — created (source leftover:320)
