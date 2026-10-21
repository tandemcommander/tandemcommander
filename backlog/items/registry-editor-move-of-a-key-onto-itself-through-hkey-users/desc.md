---
title: Registry Editor: Move of a key onto itself through HKEY_USERS deletes the key
type: bug
status: in-progress
severity: 7
area: data-safety
source: review:287
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: 2026-10-21 9781daee
effort: M
feature: 292
related: []
depends-on: []
reason: -
---

# Registry Editor: Move of a key onto itself through HKEY_USERS deletes the key

## Problem

Move (F6) of a registry key onto itself through another name of the same key - for example
`HKEY_CURRENT_USER\Software\X\Key` moved into `\HKEY_USERS\<the user's own SID>\Software\X\` - is
not recognized as a move into itself. The overwrite question names two different paths; answering
*All* (or *Yes* for each value) "moves" the key onto itself and then deletes the source, which is
the same key: the key and its subkeys are gone, and there is no other copy.

## Evidence

Found and measured by the independent review of feature 287
(`specs/287-regedt-move-class-name/fix-log.md`, *Review*, S3), on the build of 287: F6 of
`HKCU\Software\TcProbe287\Zdroj\<K>` with the target `\HKEY_USERS\<own SID>\Software\TcProbe287\Zdroj\`,
overwrite answered *All* - `<K>` and its subkey were removed completely.

`src/plugins/regedt/fs5.cpp` at 243174e4, `CPluginFSInterface::CopyOrMoveFromFS`: the "onto itself"
checks compare only the root index and the key path text (`root == CurrentKeyRoot` and
`CompareStringW(... key, CurrentKeyName ...)`, and the prefix test before `CopyOrMoveKey`
"sourceKey is not a prefix of targetKey"). `CopyOrMoveKey` deletes the source at the end of a move
(`SafeDeleteKey`). Predates 287 (upstream).

## Expected

A Move or Copy whose target is the source key itself (or lies inside it) under another root name is
refused like the same path under the same root ("Can't move a key to itself"), and nothing is
deleted. The decision goes by the key's identity, not by its name (CLAUDE.md: same-file decisions
by identity).

## Approach

Measure first with a hidden-desktop row (the probe of 287 has the fixture and the helpers). Decide
identity without the text: e.g. open both keys and compare what the registry says about them
(`NtQueryKey` with `KeyNameInformation` gives the kernel path `\REGISTRY\USER\<SID>\...` for both
`HKCU` and `HKEY_USERS\<SID>`; `HKCR` is a merged view and needs its own rule). Put the pure
comparison of the two kernel paths into a header under `src/common/` with `saltests` checks.

## Notes

Other aliases are likely to behave the same and were not measured: `HKEY_CLASSES_ROOT` (a merged
view of `HKCU\Software\Classes` and `HKLM\Software\Classes`), `HKEY_CURRENT_CONFIG` (a link into
`HKLM\SYSTEM\CurrentControlSet\Hardware Profiles\Current`). Not re-measured by the run of 287
itself (taken from the review's report).

## Log

- 2026-10-21 — created (source review:287)
- 2026-10-21 — moved to Next position 3
- 2026-10-21 — verified at 9781daee: reproduced at 9781daee by probe alias292 (before): F6 via HKEY_USERS SID and via HKCR deletes key / value; into-itself nests copies
- 2026-10-21 — run started, feature 292
