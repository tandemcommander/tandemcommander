---
title: Registry Editor View: a key that cannot be opened is still read with an unset handle
type: bug
status: new
severity: 3
area: other-plugins
source: measure:387
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor View: a key that cannot be opened is still read with an unset handle

## Problem

Registry Editor, View (F3) of a value whose key cannot be opened (deleted by another program since
the listing, or access denied): the export shows the "query value" error and then goes on with
the uninitialised key handle - it queries the value through it (a second error, or with a stack
value that happens to be a valid handle, another key's data in the viewer) and closes it with
`RegCloseKey`.

## Evidence

Found while measuring feature 387 (`specs/387-regedt-view-text-cp/fix-log.md`), by reading.
`src/plugins/regedt/fs3.cpp` at 7895880d, `ExportValueData` (start of the function):
`int ret = RegOpenKeyExW(PredefinedHKeys[root].HKey, key, 0, KEY_QUERY_VALUE, &hKey);`
`if (ret != ERROR_SUCCESS) ErrorL(ret, IDS_QUERYVAL);` - no `return`; `hKey` is not initialised.
Upstream code (not changed by 387). Not reproduced on the build.

## Expected

A key that cannot be opened ends the export after its one error message
(`return ErrorL(ret, IDS_QUERYVAL);`), no viewer is opened, nothing is read through an unset
handle.

## Notes

Reproduction idea: list a key, delete it with reg.exe from another process, press F3 on one of
its values in the stale listing (hidden-desktop probe). Not verified.

## Log

- 2026-11-02 — created (source measure:387)
- 2026-11-02 — related item registry-editor-view-of-a-text-value-cut-text-and-a-stray done in feature 387
