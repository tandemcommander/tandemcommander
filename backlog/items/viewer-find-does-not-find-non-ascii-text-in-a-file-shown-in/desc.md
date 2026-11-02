---
title: Viewer Find does not find non-ASCII text in a file shown in a code page
type: bug
status: new
severity: 3
area: encoding
source: leftover:398
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Viewer Find does not find non-ASCII text in a file shown in a code page

## Problem

The internal viewer's Find searches the field's UTF-8 bytes in the file's bytes. For a file the viewer
shows in a code page (no BOM, not valid UTF-8 - e.g. a Windows-1250 text), a typed or pre-filled
`café` is searched as `63 61 66 C3 A9` while the file holds `63 61 66 E9`: "Cannot find the string
'café'" although the viewer shows that word. Every non-ASCII letter in a code-page file is unfindable
by plain (non-hex) Find; only hex mode finds it.

## Evidence

At the branch `398-viewer-find-seed` (feature 398), measured:
- `specs/398-viewer-find-seed/probe/seed398_probe.ps1`, row `legacy` (code-page 1250 file
  `café au lait`, Alt+F3, Select All, Find, OK): the field pre-filled `café au lait` (right), the
  search answered "Cannot find the string 'café au lait'." - before and after 398
  (`probe/result_before.txt`, `probe/result_after.txt`).
- By reading: `src/viewer.cpp` `HistoryComboBox` reads the field with `SalGetWindowTextU8`;
  `src/viewer.h` `CViewerWindow::InitFindDialog` gives those bytes to `SearchData.Set` (and
  `RegExp.Set` for regular expressions); `src/viewer3.cpp` `CM_FINDNEXT` compares them with
  `Buffer` (the file's bytes after the viewer's conversion table, `CodeCharacters`).

## Expected

For content the viewer shows in a code page, plain and regular-expression Find look for the text in
the code page the viewer shows it in (after the conversion table), so a word the viewer shows is
found; a character the code page cannot hold is refused or reported as not findable instead of being
searched as other bytes. UTF-8 content keeps searching UTF-8 bytes; hex mode is unchanged.

## Notes

Not part of 398 (that item fixed only the pre-fill; its *Expected* "a selected non-ASCII word is
found" holds for UTF-8 content). The conversion table (`CodeTable`, Coding menu) maps file bytes to
the shown code page, so the search text needs the reverse mapping (or the search must compare
through the table). Case-insensitive search uses `LowerCase[]` on bytes - check it for the code page.
UTF-16 content is not detected into a wide mode yet (`ContentEncoding` is only `VCE_LEGACY` or
`VCE_UTF8`); when it is, the same gap applies to it.

## Log

- 2026-11-02 — created (source leftover:398)
