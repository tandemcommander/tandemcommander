---
title: Registry Editor: Move into a key holding a registry link to the source writes into the source
type: bug
status: open
severity: 7
area: data-safety
source: review:294
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: 2026-10-22 4420aae1
effort: ?
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: Move into a key holding a registry link to the source writes into the source

## Problem

Copy / Move (F5 / F6) of a registry key into a target whose tree holds a registry symbolic link
(`REG_LINK`, a key created with `REG_OPTION_CREATE_LINK`) that points into the source: the
recursive copy creates / opens `target\P` by name, follows the link and writes into the source
tree; a Move then deletes the source - what was written there is lost. Features 292 and 294 compare
the identities of the source and the target key and the source's own subkey chain by name, never
the links below the target.

## Evidence

Independent review of feature 294 (`specs/294-regedt-move-above-parent/fix-log.md`, *Review*,
NOTE 1) - reasoned, not driven. `src/plugins/regedt/fs5.cpp` at the closing commit of 294:
`CopyOrMoveKey` (`SafeCreateKey` for `target\<subkey>`, follows links), the checks in
`CPluginFSInterface::CopyOrMoveFromFS` (292 identity test, 294 `SafeRegKeyHoldsPath`). Predates 294
(upstream); applies to unrelated targets too.

## Expected

A Copy / Move never writes into a key it reads from or later deletes, also through a registry link
in the target tree; or such a link is not followed by the copy (refused or skipped with a message).

## Notes

Exotic: a link must have been created by hand (possible without elevation under HKCU). Not
reproduced by the item's author. Severity 3 for the rarity; the loss itself would be silent.

## Log

- 2026-10-22 — created (source review:294)
- 2026-10-22 — auto-triage: severity 3 -> 7: a Move can silently lose the moved key in a narrow scenario (a registry link in the target tree), band 7-8; rarity picks the low end
- 2026-10-22 — moved to Next position 2
- 2026-10-22 — verified at 4420aae1: reproduced at 4420aae1: new hidden-desktop probe link296_probe 14 PASS / 15 FAIL - F6 into a target holding a link to the source loses the subkey value without a box; F5 writes into the source
