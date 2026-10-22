---
title: Registry Editor: Copy or Find through a link to an ancestor walks in a loop
type: bug
status: new
severity: 4
area: other-plugins
source: measure:297
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: Copy or Find through a link to an ancestor walks in a loop

## Problem

Copy (F5) of a registry key whose tree holds a registry link (a key made with
`REG_OPTION_CREATE_LINK`, possible without elevation under HKCU) pointing at the copied key itself or
at one of its ancestors walks through the link back into the same tree: `A` holding `A\L` -> `A` is
copied as `A`, `A\L` (= `A`), `A\L\L`, ... until the key-name length limit stops it with the
"too long name" box - a chain dozens of keys deep written into the target. Find in the Registry
Editor walks the same way (read-only, but slow and the results repeat). The source is not changed.

## Evidence

Reasoned from the code at 297's closing commit, not driven: `CopyOrMoveKeyRec`
(`src/plugins/regedt/fs5.cpp`) opens and enumerates every source subkey by name (`SafeOpenKey`,
`SafeEnumKey`), which follows a link; feature 297 refuses links only for a Move (Copy kept the old
behaviour on purpose - the item did not name it); 296's check looks at links in the **target** tree.
Find: the recursive search in `src/plugins/regedt/finddlg.cpp` (`SafeEnumKey` on each key, opened by
name). Probe 297's COPYTREE row (`specs/297-regedt-delete-link/probe/link297_probe.ps1`) drives a
Copy through a link to an unrelated key (copied as a plain key, as before) - not to an ancestor.
Export runs `reg.exe` / `regedit.exe` and has no own walk.

## Expected

Copy and Find never walk through a link back into the tree they walk (a link to the walked key or
an ancestor is not followed - skipped or refused with a message); a link elsewhere may stay followed.

## Notes

Not data loss of the source (Copy only reads it). Whether Copy should follow links at all, copy the
link as a link, or refuse it is a product choice; refusing only the looping case is the conservative
option. The identity helpers of 292 / 294 (`GetRegKeyIds`, `SalRegKeyIdsAnyWithin`) can decide "the
link points into the walked tree".

## Log

- 2026-10-22 — created (source measure:297)
