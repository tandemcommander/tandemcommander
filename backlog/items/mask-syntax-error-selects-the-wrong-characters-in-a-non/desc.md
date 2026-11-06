---
title: Mask syntax error selects the wrong characters in a non-ASCII mask
type: bug
status: parked
severity: 2
area: encoding
source: review:392
who: agent
created: 2026-11-02
updated: 2026-11-06
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: minor finding (severity 2) parked in the one-time cleanup of Next; reopen when it bothers a user or the area is worked on; maintainer 2026-11-06
---

# Mask syntax error selects the wrong characters in a non-ASCII mask

## Problem

When a typed mask group has a syntax error, the dialog shows "File mask is syntactically
incorrect." and selects the character at the error. `CMaskGroup::PrepareMasks` reports the error
position as a byte index into the UTF-8 text, but the dialogs pass it to `EM_SETSEL`, which counts
UTF-16 characters. In a mask with accented or CJK letters before the error the selection lands
further right than the error (or past the end), so the user is pointed at the wrong place.

## Evidence

Review 1 of feature 392 (NOTE, `specs/392-filter-dialog-backup/fix-log.md` *Review*), by reading
at e81d6cfd: `src/dialogs3.cpp` `CFilterDialog::Validate` -
`SendMessage(GetDlgItem(HWindow, IDE_FILTER), EM_SETSEL, errorPos, errorPos + 1)` after
`check.PrepareMasks(errorPos)` on the text read as UTF-8 (`ti.EditLine`). The same pattern
(`EM_SETSEL, errorPos, errorPos + 1` after a mask check) at e81d6cfd: `src/dialogs3.cpp:865`
(`IDC_CM_NAMED_MASK`), `src/dialogs4.cpp:3465` (`IDE_RECYCLEMASKS`), `src/dialogs6.cpp:1492`.
Not reproduced.

## Expected

The selection after a mask syntax error covers the character at the error in every such dialog,
also when the mask holds non-ASCII letters before it (the byte index converted to a UTF-16 index
of the field's text, at a whole character).

## Notes

Not verified: which of the listed sites check a UTF-8 text (a site whose text is code page or
wide needs no conversion), and whether `src/dialogs4.cpp:1726` / `:1746` (viewer find, hex) and
the `errorPos1` / `errorPos2` sites (`src/dialogs.cpp:1959`, `src/dialogs4.cpp:4626`,
`src/dialogs5.cpp:2973`) have the same mismatch. Measure first: Change Filter, type a mask of
ten accented letters followed by `|`, OK, read the selection (`EM_GETSEL`).

## Log

- 2026-11-02 — created (source review:392)
- 2026-11-02 — moved to Next position 135
- 2026-11-06 — moved to Parked: minor finding (severity 2) parked in the one-time cleanup of Next; reopen when it bothers a user or the area is worked on; maintainer 2026-11-06
