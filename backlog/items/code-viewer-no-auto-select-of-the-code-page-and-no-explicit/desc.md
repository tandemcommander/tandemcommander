---
title: Code Viewer: no Auto-Select of the code page and no explicit Set as default
type: improvement
status: new
severity: 3
area: other-plugins
source: leftover:262
who: both
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Code Viewer: no Auto-Select of the code page and no explicit Set as default

## Problem

Feature 262 gave the Code Viewer the product's conversion tables (View > Encoding lists them, a table chosen from the menu is applied and remembered for later single-byte files). Two parts of the built-in viewer's Convert menu were deliberately left out: **Auto-Select** (the built-in viewer recognizes the code page of every single-byte file - `CodePageAutoSelect`, on by default - so a CP852 batch file on a CP1250 machine opens readable without a choice) and an explicit **Set as default** command (the built-in viewer changes its remembered conversion only through it; the Code Viewer remembers the last table chosen from the menu instead). In the Code Viewer a DOS / ISO-8859-2 file therefore still opens with wrong letters until the user picks the table once, and a table picked for one file applies to every later single-byte file until *System code page* is chosen.

## Evidence

specs/262-codeview-code-tables/spec.md *Clarifications* (the Auto-Select / Set as default answer) and research.md R4; the built-in viewer: src/viewer2.cpp (`CodePageAutoSelect`, `RecognizeFileType`, `GetConversionToWinCodePage`), src/viewer3.cpp (`CM_RECOGNIZE_CODEPAGE`, `CM_SETDEFAULT_CODING`); the Code Viewer at 262: src/plugins/codeview/viewer.cpp `SelectEncoding` (remember from the menu), `OpenFile` (remembered table for a detected single-byte file). Plug-in services that exist: `RecognizeFileType`, `GetWindowsCodePage`, `GetConversionTable` (spl_gen.h).

## Expected

The Code Viewer offers the built-in viewer's Auto-Select (recognize the code page of a single-byte file and pick the matching table to the Windows code page) and an explicit *Set as default*, with the same defaults as the built-in viewer, and files that decode correctly today stay unchanged when recognition picks "none".

## Notes

Both need new UI strings (two menu items) - the two-stage `.slt` refresh (`translate.merge`, CLAUDE.md) is a maintainer step, so an autonomous run stops at it. Whether Auto-Select should be on by default in the Code Viewer (it may change how a CP1250 file with few accented letters is read) is a product choice. Two limits found by the 262 review belong here too: (1) table names are widened with the system code page in the menu and status bar, while the built-in viewer takes a name that is valid UTF-8 as UTF-8 (`SalInsertMenuItemU8`) - only a user-edited UTF-8 convert.cfg with non-ASCII names differs; (2) on a machine whose system code page is UTF-8 (65001) a converted file decodes to U+FFFD and a non-ASCII table name is not stored (the built-in viewer is limited the same way) - decoding with the table's `WINDOWS_CODE_PAGE_IDENTIFIER` would avoid it.

## Log

- 2026-10-20 — created (source leftover:262)
