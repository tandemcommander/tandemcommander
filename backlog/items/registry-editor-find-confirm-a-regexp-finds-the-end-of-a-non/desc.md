---
title: Registry Editor Find: confirm a regexp finds the end of a non-ASCII text on UTF-8
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:278
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [regedit-find-hex-utf8-code-page-check-257]
depends-on: []
reason: -
---

# Registry Editor Find: confirm a regexp finds the end of a non-ASCII text on UTF-8

## Problem

Feature 278 makes the Registry Editor's Find with **Regular expression** search the whole
code-page form of a key name, value name or text value (the space and the searched length were
the UTF-16 unit count, so on a UTF-8 or DBCS ANSI code page the end of a non-ASCII text was never
searched). The rule is proven by `saltests` with code pages 65001 / 932 / 1250; the measuring
machine has code page 1250, where the old and new code search the same bytes - the plug-in's
behaviour under a multi-byte code page rests on reading the call site. Switching the system's
ANSI code page to UTF-8 needs a restart, so a person confirms it in the GUI.

## Evidence

`specs/278-regedt-find-regexp-cp/fix-log.md`, sections *Owed to a person* and *Review*
(SHOULD 2); `specs/278-regedt-find-regexp-cp/quickstart.md` step 4. Can be done in the same
restart as `regedit-find-hex-utf8-code-page-check-257`.

## Expected

On a machine with the UTF-8 ANSI code page, a regexp `bar` finds the value data, the value name
and the key name `čččč bar`, with and without Whole words (before 278: none of them found).

## Notes

Do it on a test machine or VM: the setting changes the whole system. Turn it back off afterwards.

## Steps

- [ ] Settings → Time & language → Language & region → Administrative language settings → Change
      system locale → check "Beta: Use Unicode UTF-8 for worldwide language support", restart →
      `Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage` shows ACP 65001.
- [ ] In Registry Editor (a build of 278 or later) create `HKCU\Software\tc278` with a REG_SZ `v`
      = `čččč bar`, a REG_SZ named `čččč bar` with the data `x`, and a subkey `čččč bar`.
- [ ] Find in `tc278`, Regular expression `bar`, only Look at data → `v` is found; with Whole
      words → `v` is found.
- [ ] The same with only Look at values → the value `čččč bar` is found (also with Whole words).
- [ ] The same with only Look at keys → the key `čččč bar` is found (also with Whole words).
- [ ] Delete `HKCU\Software\tc278`, uncheck the UTF-8 option again and restart.

## Log

- 2026-10-21 — created (source leftover:278)
- 2026-10-21 — moved to Person steps position 23
