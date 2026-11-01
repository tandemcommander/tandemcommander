---
title: FTP: a listing rule assigning one column to another decodes the decoded text again
type: bug
status: new
severity: 2
area: ftp
source: review:384
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: a listing rule assigning one column to another decodes the decoded text again

## Problem

A user-defined FTP server type whose listing rule copies one text column into a name or text
column (`assign(<name>, <other column>)`) runs the copied value, which is already decoded to
UTF-8, through the listing-field decoder again as if it were the server's raw bytes, and with
name evidence. A decoded value is always valid UTF-8, so the text itself stays the same; but a
non-ASCII value that came from the code page then counts as evidence that the server speaks
UTF-8 (feature 288's per-server state can become "mixed" instead of "legacy"), and new names
(MKD, RNTO, STOR) may go out in UTF-8 to a legacy server. No built-in server type assigns a
column to a string column.

## Evidence

Review 2 of feature 384 (`specs/384-ftp-joined-column/fix-log.md`, *Review*, NOTE 1), by reading
at 4040cdf7: `src/plugins/ftp/parser2.cpp` `CFTPParserFunction::UseFunction`, case `fpfAssign`
(name / text column): `GetStringOperand` of a `pptColumnID` operand returns `file->Name` or
`GetStringFromColumn` (decoded UTF-8), then `AssignStringToColumn(..)` with the default
`evidence = TRUE` -> `FTPListingFieldToU8(.., nameField)` (`ftputils.cpp`). Feature 384 made the
target take over the source column's listing bytes (`FTPLineRaw.Copy`), but the evidence flag
is unchanged. Not driven (needs a custom server type).

## Expected

`assign(<col>, <other column>)` takes the other column's decoded value as it is (no second
decode, no evidence of the server's encoding); a literal or a listing operand keeps today's
handling. A parser self-test or a probe row with a custom server type proves it.

## Log

- 2026-11-01 — created (source review:384)
