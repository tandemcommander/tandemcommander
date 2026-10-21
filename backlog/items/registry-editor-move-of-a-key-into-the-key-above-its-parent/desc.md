---
title: Registry Editor: Move of a key into the key above its parent loses a same-name subkey
type: bug
status: open
severity: 7
area: data-safety
source: review:292
who: agent
created: 2026-10-21
updated: 2026-10-22
verified: 2026-10-22 e752f9b9
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: Move of a key into the key above its parent loses a same-name subkey

## Problem

Move (F6) of a registry key into the key that holds its own parent - the target key of the same
name is then the source's parent - loses data without any question when the moved key has a subkey
of its own name. Example: `A\K` (a=1) holds `K` (b=2), which holds `K` (x=3). In the panel at
`A\K`, Move of `K` into `\HKEY_CURRENT_USER\...\A\`: the contents of `A\K\K` are merged into `A\K`,
and its subkey `A\K\K\K` is copied onto `A\K\K` - the source itself - which is then deleted. Left
over: `A\K` with a=1 and b=2; x=3 is gone and there is no other copy. Under one root name and
through another root name alike.

## Evidence

Independent review of feature 292 (`specs/292-regedt-alias-move-self/fix-log.md`, *Review*,
SHOULD 1), reproduced on the hidden desktop with the build of branch 292 (a scratch copy of
`specs/292-regedt-alias-move-self/probe/alias292_probe.ps1`, fixture `HKCU\Software\TcReview292\A\K\K\K`,
registry restored identical): no box, x=3 removed; the same with the target written as
`\HKEY_USERS\<SID>\...\A\`.

`src/plugins/regedt/fs5.cpp` at 80c44acd: `CPluginFSInterface::CopyOrMoveFromFS` refuses a target
that is the source or lies inside it (text test and, since 292, identity test), never a target
whose recursion reaches the source; `CopyOrMoveKey` enumerates the subkeys, copies each into the
target (here: onto the source) and deletes the source at the end (`SafeDeleteKey`). Predates 292
(upstream).

## Expected

A Copy or Move whose recursion would write into the source key itself (a target key that is an
ancestor of the source, reached again by a same-name subkey chain) is refused, or the copy never
writes into a key it later deletes; nothing is lost. Decided by identity (the rule of feature 292,
`src/common/salregkeyid.h`).

## Approach

Measure first with a hidden-desktop row (fixture of the review). One possible rule: before
copying, refuse when the source lies within the target key (`SalRegKeyIdsAnyWithin(source,
target)`) and the source path below the target repeats the moved key's name - or more simply,
inside `CopyOrMoveKey`, never copy a subkey onto a key whose identity is the source's or lies
within it. Check Copy too (no deletion, but the copied tree may be read while it is written).

## Notes

Not verified by this item's author beyond the review's reproduction (taken from the review's
report). Narrow scenario (a key containing a subkey of its own name), hence severity 7.

## Log

- 2026-10-21 — created (source review:292)
- 2026-10-22 — related item registry-editor-move-of-a-key-onto-itself-through-hkey-users done in feature 292
- 2026-10-22 — moved to Next position 2
- 2026-10-22 — verified at e752f9b9: reproduced at e752f9b9: hidden-desktop probe above294 -Expect before 14 PASS / 10 FAIL; Move into the key above the parent loses x=3 without a box (HKCU, HKEY_USERS alias, two-element chain), Copy writes into the source
