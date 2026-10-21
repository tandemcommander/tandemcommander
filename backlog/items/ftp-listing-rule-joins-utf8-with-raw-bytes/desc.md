---
title: FTP: a name a listing rule extends (z/VM, AS/400, VxWorks) mixes UTF-8 with raw server bytes
type: bug
status: open
severity: 4
area: ftp
source: review:288
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: a name a listing rule extends (z/VM, AS/400, VxWorks) mixes UTF-8 with raw server bytes

## Problem

Some FTP server types build a file name from several parts of a listing line with the parser rule `add_string_to_column` - z/VM CMS joins the file name, `.` and the file type (`NAME` + `.` + `EXT`). The rule takes the column's value, which is already decoded to UTF-8, appends the next part as the server's raw bytes, and decodes the whole joined text again. On a legacy (code-page) server with letters outside ASCII the joined name is no longer valid UTF-8, so it is read in the code page twice for the first part: `NAMEč.EXTč` becomes `NAMEÄŤ.EXTč` - the panel shows another name and every command for that file names a file the server does not have (delete, download, rename fail). On a UTF-8 server the join is right only when the raw part is UTF-8 too.

## Evidence

By reading at 92b9926e (independent review 2 of feature 288, `specs/288-ftp-per-server-encoding/fix-log.md` *Review 2*, NOTE 1): `src/plugins/ftp/parser2.cpp` `CFTPParserFunction::UseFunction`, case `fpfAdd_string_to_column`: `GetStringOperand` of the column (the decoded UTF-8 value from `file->Name`, `parser1.cpp` `GetStringOperand`) and of the next listing part (raw bytes), `memcpy` of both into one buffer, then `AssignStringToColumn(..)`, which decodes it with `FTPListingFieldToU8`. The rules that use it on the name: `src/plugins/ftp/ftp3.cpp:1441-1442`, `:1471-1472`, `:1501-1502` (z/VM CMS 1/2/3), and AS/400 / VxWorks rules use it on other text columns. Pre-existing (interface 104, before 288); 288 only stopped such re-assigned values from counting as evidence of the server's encoding.

## Expected

A joined column is decoded part by part (the raw part decoded with the same rule as a listing field, then appended to the UTF-8 value), so `NAMEč.EXTč` from a cp1250 z/VM listing shows and is addressed as `NAMEč.EXTč`; a parser self-test or a probe row with a z/VM-style listing from `ftpmini.py` (a listing-format option would be needed) or the server-type test dialog's parse.

## Notes

Severity 4: only legacy z/VM (and the other listed types) servers with non-ASCII names; the file cannot be worked with by its name, nothing else is touched (no other file has the garbled name). Not driven - no such server or listing fixture.

## Log

- 2026-10-21 — created (source review:288)
- 2026-10-21 — moved to Next position 14
