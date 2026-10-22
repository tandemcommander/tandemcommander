---
title: tar plug-in ignores PAX extended headers: long or non-ASCII names listed under the ustar fallback name
type: bug
status: in-progress
severity: 5
area: archives
source: measure:275
who: agent
created: 2026-10-21
updated: 2026-10-22
verified: 2026-10-22 8c6f4d68
effort: M
feature: 306
related: []
depends-on: []
reason: -
---

# tar plug-in ignores PAX extended headers: long or non-ASCII names listed under the ustar fallback name

## Problem

The tar plug-in treats PAX extended headers (type `x` for the next member, `g` global) as entries it cannot handle and ignores them, so the `path` (and `linkpath`, `size`, `mtime`) records they carry are never applied. Tools that write PAX for exactly the names that do not fit the ustar header - Python's `tarfile` (default PAX format), GNU tar `--format=posix`, bsdtar / Windows `tar.exe` for non-ASCII or long names - leave in the ustar header only a fallback: a name cut at 100 (+155 prefix) bytes or a substitute spelling. Such a member would be listed, viewed and extracted under the fallback name instead of its real one (a long name cut, a non-ASCII name garbled), and two members whose fallback names coincide would collide.

## Evidence

At 97384331: `src/plugins/tar/untar.cpp` (the header reader, `switch (tarHeader->Header.typeflag)`): `case XHDTYPE: case XGLTYPE:` fall into "types we cannot handle" -> `header.Ignored = TRUE`; `XHDTYPE` / `XGLTYPE` defined in `src/plugins/tar/tar.h`. GNU long names (`GNUTYPE_LONGNAME`) are handled in the same reader. By reading (audit of feature 275, `specs/275-arcmember-long-path/fix-log.md`); not measured - the probe of 275 builds a GNU tar, not a PAX one.

## Expected

A member preceded by a PAX `x` header is listed and extracted under the header's `path` (UTF-8 by the PAX standard), with the header's size and time where given; a `g` header applies to the following members; a PAX path that no file system takes is refused with a message, never cut. Measured first with a PAX tar (e.g. Python `tarfile` with a 200-letter CJK name and a 300-byte path).

## Notes

Not verified on the build: the severity assumes the fallback names really differ from the PAX path (true for names over 100 bytes in ustar); the size field of a PAX header matters only for members over 8 GiB.

## Log

- 2026-10-21 — created (source measure:275)
- 2026-10-21 — moved to Next position 12
- 2026-10-22 — verified at 8c6f4d68: reproduced at 8c6f4d68: hidden-desktop probe with Python PAX tars - 302-byte path extracted under its 100-byte cut, CJK names as ? (error 123), PAX size/mtime and g mtime ignored; 9 FAIL / 13 PASS
- 2026-10-22 — run started, feature 306
