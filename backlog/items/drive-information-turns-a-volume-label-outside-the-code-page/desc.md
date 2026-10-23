---
title: Drive Information turns a volume label outside the code page into question marks
type: bug
status: blocked
severity: 5
area: encoding
source: review:300
who: both
created: 2026-10-22
updated: 2026-10-23
verified: 2026-10-23 ae49a67d
effort: ?
feature: -
related: []
depends-on: []
reason: not reproduced at ae49a67d: the premise is wrong - IDE_VOLNAME is a comctl32 6 edit (manifest since the initial commit), a Unicode window inside the code-page dialog, and the modal loop is wide; no fix to name. The 069 / 300 comments in CDriveInfo say otherwise. Write of a real non-code-page label owed to a person (USB stick). Maintainer: close or keep. Evidence in evidence/
---

# Drive Information turns a volume label outside the code page into question marks

## Problem

Drive Information (Alt+F1 / the drive's information in the panel) shows the volume label in an
edit field of a code-page dialog. A label with letters outside the system code page (Cyrillic,
Greek, CJK on code page 1250) is shown as `?` in the field; when the user edits the label (e.g.
`Диск1` shown as `????1`, changed to `????2`) and presses OK, the question marks are written to
the drive - the label's letters are lost. Typing such letters into the field is not possible
either. Feature 069 made the merely-opened dialog safe (the "unchanged" reference is read back
from the field), feature 300 made the write wide; the field itself still drops the letters.

## Evidence

By reading at 124e1da5 (branch `300-volume-label-wide`, review 1 of feature 300, NOTE 4):
- `src/dialogs3.cpp` `CDriveInfo::CDriveInfo` - `CCommonDialog(HLanguage, IDD_DRIVEINFO, ...)`
  without `unicodeWnd` (default FALSE, `src/salamand.h` `CCommonDialog`, feature 015 comment):
  `CDialog::Execute` (`src/common/winlib.cpp`) then uses `DialogBoxParam` (A), so `IDE_VOLNAME`
  (`src/lang/lang.rc`, `EDITTEXT IDE_VOLNAME`) is a code-page edit.
- `src/dialogs3.cpp` `CDriveInfo::Transfer` - the feature 069 note: "IDE_VOLNAME is in an ANSI
  dialog (cluster B-1), so a label with characters the code page cannot express reads back as
  '?'"; `SetWindowTextW` of the true label into that edit is converted to the code page.
- Not measured: the end-to-end loss needs a label outside the code page on a drive whose label
  may be written (a USB stick, or a VHD with admin rights).

## Expected

The label field holds every Unicode letter (the dialog a Unicode window, `unicodeWnd` TRUE, or the
field made wide by the project's rules - `AttachToWindowKeepKind`, no code-page subclass on an
edit, features 093 / 102 / 104 / 116); a label `Диск1` is shown as `Диск1`, editing it to
`Диск2` writes `Диск2`; typed CJK letters are written as typed.

## Notes

Severity 5: a wrong result (the label) with a workaround (Explorer), in a narrow scenario (a label
outside the code page). The whole dialog becoming a Unicode window touches its other texts (the
title, the mount point, the GUID path - already set wide) and 069's "unchanged" seed, which
could then compare the true label; check `CCommonDialog` users that did the same (feature 015).
`who: both`: writing a real label needs a USB stick or an elevated program with a VHD - a
person's check. Related to the closed item `volume-label-written-through-ansi-api` (feature 300).

## Log

- 2026-10-22 — created (source review:300)
- 2026-10-22 — moved to Next position 10
- 2026-10-23 — verified at ae49a67d: not reproduced: probe evidence/vol_label_field_probe.ps1 on the Debug build at ae49a67d, ACP 1250 - the label field is a Unicode window (comctl32 6 edit in the code-page dialog); Cyrillic set by WM_SETTEXT and CJK posted as WM_CHAR read back whole; negative controls (code-page subclassed control 565, code-page loop) show the loss as ????1 / ??2
- 2026-10-23 — blocked: not reproduced at ae49a67d: the premise is wrong - IDE_VOLNAME is a comctl32 6 edit (manifest since the initial commit), a Unicode window inside the code-page dialog, and the modal loop is wide; no fix to name. The 069 / 300 comments in CDriveInfo say otherwise. Write of a real non-code-page label owed to a person (USB stick). Maintainer: close or keep. Evidence in evidence/
