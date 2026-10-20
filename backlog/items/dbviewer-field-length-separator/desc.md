---
title: DB Viewer: a field length of 1000 or more shows a broken thousands separator
type: bug
status: new
severity: 2
area: other-plugins
source: measure:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# DB Viewer: a field length of 1000 or more shows a broken thousands separator

## Problem

DB Viewer's *Columns* dialog shows each column's length with `PrintDiskSize(..., 2)` ("1 024
bytes"). The number carries the locale's thousands separator as UTF-8 (feature 041), the word
"bytes" is code-page text, and the result is put into the list with `ListView_SetItemText` (the A
message, code page). With a separator outside ASCII - the no-break space of Czech, French,
Russian and other locales - a length of 1000 or more reads "1Â 024 bytes". Shorter lengths, and
locales with ',' or '.', are not affected.

## Evidence

By reading, at e849e68c: `src/plugins/dbviewer/dialogs.cpp` `CColumnsDialog::SetLVTexts` (the
"len" column). `PrintDiskSize` encoding: `src/plugins/shared/spl_gen.h` (feature 067 note).
Reported by `python tools/check_encoding.py --plugins` (`utf8-to-legacy-sink`); verdict in
`specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`).

## Expected

With a Czech locale, a column of length 1024 reads "1 024 bytes" (a real no-break space) in the
*Columns* dialog; `check_encoding.py --plugins` no longer reports `dialogs.cpp`.

## Approach

Compose the text as UTF-8 (number + `LoadStrU8` word, or ask for an ASCII number) and hand it to
the list as UTF-16 (`ListView_SetItemTextW` + `SplU8ToWAlloc`), as the same function already does
for Unicode column names.

## Notes

Field lengths of 1000 or more are rare in DBF files; more common in CSV columns.

## Log

- 2026-10-20 — created (source measure:255)
- 2026-10-20 — moved to Inbox
