---
title: Frozen code-page plug-in services: add wide/UTF-8 variants or keep them (B-5)?
type: decision
status: open
severity: 3
area: plugin-api
source: review:068
who: person
created: 2026-08-24
updated: 2026-10-17
verified: -
effort: -
feature: -
related: [geterrortext-utf8-contract]
depends-on: []
reason: -
---

# Frozen code-page plug-in services: add wide/UTF-8 variants or keep them (B-5)?

## Problem

B-5: plug-in-facing services are code page (ANSI) and frozen by the plug-in interface (068 findings F-P5-03, F-P5-07, F-P5-01, F-P5-10, F-P5-11). Also here: the `CCodeTablesData::Name` invariant (names handed out by `EnumConversionTables`, accepted back by `GetConversionTable`, persisted by `dbviewer` / `filecomp`), and `EnumInstalledModules` - a plug-in service with a `MAX_PATH` buffer, left by 170 / 171 as an interface question of the install-path chain (an install folder outside the code page).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 19 (L401, L409) (at 7993914c). specs/069-finish-encoding-fixes/REMAINING-WORK.md §1 B-5; specs/068-encoding-regression-review/REMAINING-WORK.md; specs/170-install-path-unicode/fix-log.md ("Left on purpose: `EnumInstalledModules` ... an interface question, B-5"); specs/171-install-path-rest/fix-log.md *Left*. Plug-in API: architecture/06, the append-only ABI rule.

## Expected

A recorded decision per service: frozen with a reason, or a new variant appended to the interface (a contract in specs/NNN-*/contracts/, `spl_vers.h` history).

## Notes

RW069 §1 B-5 is the same entry. The SDK statement for `GetErrorText` (B-3) is `geterrortext-utf8-contract`. The options and recommendation below are the migration's summary, not the maintainer's.

## Question

Should the frozen code-page plug-in services (B-5, including `EnumInstalledModules` and the conversion-table names) get UTF-8 / wide variants appended to the interface, or stay as they are?

## Options

A - keep them frozen; record per service why the code-page form is harmless or accepted. B - append UTF-8 / wide variants (append-only ABI; older plug-ins keep the old ones) and move the shipped plug-ins over, service by service. C - only `EnumInstalledModules` (install-path chain) now, the rest later.

## Recommendation

None recorded in the source. C is the smallest step that closes the install-path chain; B is the full answer and an interface change per service.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-17 — migration review N8: a decision is answered by a person
- 2026-10-17 — migration review N3: migration remark replaced by a cross-reference
