---
title: Unpack dialog offers a long target panel path cut and unpacks into the cut folder
type: bug
status: open
severity: 5
area: long-paths
source: review:299
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Unpack dialog offers a long target panel path cut and unpacks into the cut folder

## Problem

Unpack (Alt+F9) fills the Unpack dialog's target combo box with the other panel's path copied
into a `char[MAX_PATH]` with `lstrcpyn` - a byte copy that cuts a panel path longer than 259 bytes
(panel paths reach `SAL_MAX_PATH_UTF8`), possibly inside a UTF-8 character. The cut text fits, so
feature 299's `Validate` accepts it: choosing that entry and pressing OK unpacks into another
folder (a prefix of the panel path), nothing asked. With "Use the other panel for unpacking"
(`UseAnotherPanelForUnpack`) the cut path is the preselected first entry - one Enter does it. A
cut inside a CJK character makes invalid UTF-8, which `SalComboAddStringU8` shows through the
code-page fallback (garbage text).

## Evidence

Review 1 of feature 299 (branch `299-unpack-dialog-text-fits`, at b209d9e3), measured on the
fixed build with a scratch hidden-desktop probe (`%TEMP%\rv299\rv299_alt.ps1`, not kept): left panel
`src` holding a.zip, right panel a folder L; Alt+F9, combo item 1 (the other panel's path), OK.
- `alt-ascii`: L 297 bytes, item 1 259 bytes (a prefix of L): a.k unpacked into a new folder named
  after a 206-character prefix, nothing asked. FAIL.
- `alt-cjk`: L 355 bytes, item 1 259 bytes: unpacked into the cut folder. FAIL.
Sites, `src/fileswn7.cpp` `CFilesWindow::Unpack`:
- line 2137 `lstrcpyn(path, target->GetPath(), MAX_PATH);` (`UseAnotherPanelForUnpack`), line 2140
  `lstrcpyn(pathAlt, target->GetPath(), MAX_PATH);`.
- line 2163 `lstrcpyn(mask, unpackMask, MAX_PATH);` - a plug-in's unpack mask
  (`data->UnpackDlgUnpackMask`, `src/salamdr1.cpp`) cut the same way (by reading only).
- line 2151-2159: the archive's subfolder name is dropped silently when it would exceed MAX_PATH
  (`TRACE_E` only) - visible in the dialog, by reading.

## Expected

A default that does not fit the dialog's buffers is never offered cut: either the entry is left
out (an empty / the other default) or the dialog's buffers become large enough and the later steps
refuse with "The path specified is too long." - never a cut path or mask. The plug-in mask the
same. A hidden-desktop probe row for the other panel's long path (ASCII and CJK), both settings of
`UseAnotherPanelForUnpack`, before FAIL / after PASS, and a control that fits.

## Notes

Not part of feature 299 (that item named only the typed text). Severity 5: files land in another
folder (overwrite questions still asked), no loss found. Whether to leave the entry out or grow
the buffers is a design choice of the fix; leaving it out changes least.

## Log

- 2026-10-22 — created (source review:299)
- 2026-10-22 — moved to Next position 10
