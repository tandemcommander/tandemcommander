---
title: Registry Editor: Move of an HKCR key held by both halves leaves its machine half
type: bug
status: open
severity: 4
area: other-plugins
source: leftover:390
who: agent
created: 2026-11-02
updated: 2026-11-06
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: Move of an HKCR key held by both halves leaves its machine half

## Problem

A Move (F6) of a key that `HKEY_CLASSES_ROOT` shows from both halves (it exists in
`HKLM\Software\Classes` and in `HKCU\Software\Classes`) to another place copies the merged
contents and then deletes the source through HKCR, which removes only the user's half. With
elevation (or a machine key the user may delete) the key's own machine half survives a Move that
reported success and is still shown under `HKEY_CLASSES_ROOT`; since feature 390 the machine-only
subkeys below it are deleted by their real paths, so the leftover is the machine half of the key
itself with its values. Nothing is lost (the copy holds everything), but the Move is incomplete
without a word.

## Evidence

Review of feature 390 (`specs/390-regedt-hkcr-move-user/fix-log.md`, *Review*, NOTE 2), by reading,
not measured (needs elevation or a machine key with a permissive ACL). `src/plugins/regedt/fs5.cpp`
`CopyOrMoveKeyRec`: `SalRegHkcrDeleteHalf` returns `SAL_HKCR_DELETE_VIEW` for two halves, which
keeps the old `SafeDeleteKey(sourceRoot = HKCR, ...)` (spec FR-002 of 390 kept it on purpose: the
item did not name the case). Predates 390.

## Expected

A Move of an HKCR key held by both halves removes both halves of the source (each by its real path,
errors in the existing "Unable to remove the original registry key." box), or is refused with a
message - never a partial Move reported as success. Measure first (elevated, or with a scratch
machine key whose ACL lets the user delete it).

## Log

- 2026-11-02 — created (source leftover:390)
- 2026-11-02 — auto-triage: left in Inbox - who agent contradicts its own text: measuring the defect needs elevation or a machine key created by an admin (a person); who both may fit
- 2026-11-06 — moved to Next position 2
