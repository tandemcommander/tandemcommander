---
title: Drive Information writes the volume label through an ANSI API
type: bug
status: in-progress
severity: 5
area: encoding
source: review:270
who: both
created: 2026-10-20
updated: 2026-10-22
verified: 2026-10-22 82bf0dac
effort: S
feature: 300
related: []
depends-on: []
reason: -
---

# Drive Information writes the volume label through an ANSI API

## Problem

Drive Information (Alt+F1 / the drive's properties in the panel) reads the typed volume label as
UTF-8 (`SalGetWindowTextU8`) and passes it to `SetVolumeLabel`, which in the core (no `_UNICODE`)
is `SetVolumeLabelA` and reads the bytes in the code page. A label with any letter outside ASCII
is written as mojibake: `Zálohy` on code page 1250 becomes `ZĂˇlohy` on the drive. The same applies
to the volume path argument (UTF-8 in an `A` call; drive roots are ASCII, a mounted-folder path may
not be). The encoding checker does not catch it: `SetVolumeLabel` is missing from its
`ANSI_NAME_API` list, so `TOTAL: 0` does not cover this call.

## Evidence

At 7ae8d2a4 (branch `270-mask-filter-label-fits`), by reading (review 1 of feature 270):
- `src/dialogs3.cpp:1341` - `CDriveInfo::Validate`: `BOOL res = SetVolumeLabel(volumePathWithBackslash, newName);`
  after `SalGetWindowTextU8(edit, newName, MAX_PATH)`; no shim for `SetVolumeLabel` in `src/`
  (`grep -rn SetVolumeLabel src --include=*.h` finds nothing).
- `tools/check_encoding.py:270-284` - `ANSI_NAME_API` without `SetVolumeLabel`.
- Not driven: writing a label needs an elevated program for a fixed drive (feature 270's probe row
  `vol` runs only unelevated, where the call fails with access denied).

## Expected

The label and the path go to `SetVolumeLabelW` (`SalU8ToWAlloc`), never through the code page;
`SetVolumeLabel` is added to the checker's `ANSI_NAME_API` list (and any other site it then finds is
fixed or recorded). A non-ASCII label is written as typed.

## Notes

Severity 5: a function gives a wrong result (the label), with a workaround (Explorer); a label
change needs admin rights for fixed drives, not for removable ones. `who: both`: the code and the
checker are agent work; writing a real label must be confirmed by a person on a scratch drive
(VHD or USB stick, elevated) - or by an agent run that may create a VHD, which needs admin.

## Log

- 2026-10-20 — created (source review:270)
- 2026-10-21 — moved to Next position 6
- 2026-10-22 — verified at 82bf0dac: still present at 82bf0dac: CDriveInfo::Validate calls SetVolumeLabel (A, core has no UNICODE) with UTF-8 label and path; checker list lacks it; write itself not driven (needs admin)
- 2026-10-22 — run started, feature 300
