---
title: Registry Editor View: confirm F3 shows a whole non-ASCII text value on UTF-8
type: person-step
status: new
severity: 3
area: other-plugins
source: leftover:387
who: person
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: [registry-editor-find-confirm-a-regexp-finds-the-end-of-a-non, regedit-find-hex-utf8-code-page-check-257]
depends-on: []
reason: -
---

# Registry Editor View: confirm F3 shows a whole non-ASCII text value on UTF-8

## Problem

Feature 387 makes the Registry Editor's View (F3) of a text value (REG_SZ / REG_EXPAND_SZ /
REG_MULTI_SZ) write the whole code-page form of the text to the viewer's file (the space and the
written length were the UTF-16 unit count, so on a UTF-8 or DBCS ANSI code page the text was cut
and padded with stale bytes and a NUL). The rule `SalRegViewExportBytes` is proven by `saltests`
with code pages 65001 / 932 / 1250 (and a mutation run); the measuring machine has code page
1250, where the old and new code write the same bytes - the plug-in's behaviour under a
multi-byte code page rests on reading the call site and the reviewer's harness. A person
confirms it in the GUI.

## Evidence

`specs/387-regedt-view-text-cp/fix-log.md`, sections *Checks* (GUI probe NOT DRIVEN) and
*Review* (SHOULD 1); `specs/387-regedt-view-text-cp/quickstart.md` step 4. Can be done in the
same restart as `registry-editor-find-confirm-a-regexp-finds-the-end-of-a-non` and
`regedit-find-hex-utf8-code-page-check-257`.

## Expected

On a machine with the UTF-8 ANSI code page, F3 on a REG_SZ `a€ čččč bar` shows the whole text
(before 387: `a`, a garbage character, and nothing more); a REG_MULTI_SZ with the lines `a€` and
`čččč bar` shows both lines whole.

## Notes

Do it on a test machine or VM: the setting changes the whole system. Turn it back off afterwards.
An automatable alternative (from review 1 of 387, not tried): a copy of `tandemcommander.exe`
with an `activeCodePage=UTF-8` application manifest (`mt.exe -updateresource`) runs with
`GetACP()` = 65001 for itself and its plug-ins, so a hidden-desktop probe could drive F3 without
changing the system - whether the product runs correctly under that manifest is unproven.

## Steps

- [ ] Settings → Time & language → Language & region → Administrative language settings → Change
      system locale → check "Beta: Use Unicode UTF-8 for worldwide language support", restart →
      `Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage` shows ACP 65001.
- [ ] In Registry Editor (a build of 387 or later) create `HKCU\Software\tc387` with a REG_SZ `v`
      = `a€ čččč bar` and a REG_MULTI_SZ `m` with the lines `a€` and `čččč bar`.
- [ ] F3 on `v` → the viewer shows `a€ čččč bar` whole, no garbage character at the end.
- [ ] F3 on `m` → the viewer shows both lines whole.
- [ ] Delete `HKCU\Software\tc387`, uncheck the UTF-8 option again and restart.

## Log

- 2026-11-02 — created (source leftover:387)
