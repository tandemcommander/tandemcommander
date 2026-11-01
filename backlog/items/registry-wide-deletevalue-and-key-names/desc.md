---
title: Registry facade: deleting a value and opening keys use the ANSI API with UTF-8 names
type: bug
status: new
severity: 2
area: plugin-api
source: review:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Registry facade: deleting a value and opening keys use the ANSI API with UTF-8 names

## Problem

The core's registry facade (also the plug-ins' `CSalamanderRegistryAbstract`) reads and writes values through wide helpers (`SalRegSetValueExW8` / `SalRegQueryValueExW8`) with UTF-8 names, but `DeleteValueAux` calls `RegDeleteValue` - the A function - with the same UTF-8 name, and `CreateKeyAux`, `OpenKeyAux` and `DeleteKeyAux` take key names through `RegCreateKeyEx` / `RegOpenKeyEx` / `RegDeleteKey` (A as well). A value whose name has non-ASCII letters can be written but never deleted: it comes back at the next load; a non-ASCII key name is created and opened under a code-page reading of its UTF-8 bytes (another name).

## Evidence

Found by the independent review of feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Review*, SHOULD 1), at 3e0da39c: `src/regwork.cpp` `DeleteValueAux` (`RegDeleteValue(hKey, name)`), `CreateKeyAux` (`RegCreateKeyEx`), `OpenKeyAux` (`RegOpenKeyEx`), `DeleteKeyAux` (`RegDeleteKey`). Measured by the reviewer on a cp1250 machine with a scratch key `HKCU/Software/tc379review-scratch` (created and deleted again): a value `číslo` set with the W API, then `RegDeleteValueA` with its UTF-8 bytes → error 2, the value stays. The only caller known to pass non-ASCII names is the Automation plug-in's persistence (`src/plugins/automation/persistence.cpp`, plug-in off); not searched exhaustively across all plug-ins. `check_encoding.py --strict` does not see it (the un-suffixed A calls with a `const char*` name are not a rule).

## Expected

The facade deletes values and creates, opens and deletes keys by their exact names (WTF-8 → UTF-16, the W functions), like its value read and write; ASCII names behave as today; a `saltests` or probe check deletes a non-ASCII value.

## Approach

Convert with `SalU8ToW` (heap buffer, refuse on failure) and call `RegDeleteValueW`, `RegCreateKeyExW`, `RegOpenKeyExW`, `RegDeleteKeyW`; check every caller in the core and the plug-ins for code-page key names (they would change meaning). Consider a guard rule for un-suffixed `Reg*` calls on a UTF-8 name.

## Notes

Severity 2: latent for the shipped configuration as far as known (core keys are ASCII; the known non-ASCII caller is an off plug-in). A plug-in that stores user-named values (a bookmark title as a value name) would raise it - not verified.

## Log

- 2026-11-01 — created (source review:379)
