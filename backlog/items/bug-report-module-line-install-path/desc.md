---
title: Bug report's module line from an install folder outside the code page
type: bug
status: open
severity: 2
area: encoding
source: leftover:171
who: agent
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Bug report's module line from an install folder outside the code page

## Problem

The last core site of the install-path chain (170-172): the bug report's module line (`bugreprt.cpp`) still takes the program's path with the code-page `GetModuleFileName`, a code-page form of the path (A API into `buf`, up to 1000 bytes), so from an install folder outside the code page the line does not carry the real path.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 19 (L409) (at 7993914c). specs/171-install-path-rest/fix-log.md *Left (NEXT-WORK)*; specs/170-install-path-unicode/fix-log.md. At 7993914c: `src/bugreprt.cpp` ~1720 `GetModuleFileName(HInstance, buf + strlen(buf), 1000)`. Measure with `specs/170-install-path-unicode/probe/install_path_probe.ps1`.

## Expected

The bug report names the module path in UTF-8 from any install folder (`SalGetModuleDirU8` / `SAL_MODULE_PATH_U8` of 170).

## Notes

The effect is on a report text only; check first what the report does with the line (shown, saved, sent).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
