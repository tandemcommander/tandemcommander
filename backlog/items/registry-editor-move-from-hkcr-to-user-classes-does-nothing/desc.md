---
title: Registry Editor: Move from HKCR into the user's Classes key does nothing
type: bug
status: open
severity: 4
area: other-plugins
source: review:292
who: agent
created: 2026-10-21
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: Move from HKCR into the user's Classes key does nothing

## Problem

Move (F6) of a key that exists under `HKEY_CLASSES_ROOT` only in the machine's half (from
`HKLM\Software\Classes`) into `\HKEY_CURRENT_USER\Software\Classes\` copies the key into the user's
half and then deletes the source through `HKEY_CLASSES_ROOT` - which by then reaches the new user
copy, not the machine key. The Move ends without an error, the user's copy is gone again and the
machine key is unchanged: the operation did nothing although it reported success. Nothing is lost.

## Evidence

Independent review of feature 292 (`specs/292-regedt-alias-move-self/fix-log.md`, *Review*,
second review, NOTE 4) - by reasoning from the measured merged-view behaviour (a key held by both
halves opens as the user's half; deleting through HKCR reaches the user's half first), not driven.

`src/plugins/regedt/fs5.cpp` at 424d9438: `CopyOrMoveKey` deletes the source with
`SafeDeleteKey(sourceRoot, source, ...)` = `RegDeleteKeyW(HKEY_CLASSES_ROOT, ...)` after the copy;
predates 292 (main behaves the same).

## Expected

A Move from the merged view deletes the key it copied (the machine's half here), or such a Move is
refused with a message; never a silent no-op reported as success.

## Notes

Not verified: needs a key held only by the machine's half, i.e. one written elevated, or an
existing machine-only key (a real file association - a probe must not delete it). Severity 4: a
function that silently does not work, nothing lost.

## Log

- 2026-10-21 — created (source review:292)
- 2026-10-21 — severity: a function that silently does not work (band 4-6)
- 2026-10-22 — related item registry-editor-move-of-a-key-onto-itself-through-hkey-users done in feature 292
- 2026-10-22 — moved to Next position 25
