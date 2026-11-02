---
title: Unpack of a tar file member whose name ends in a folder mark shows a WriteFile error
type: bug
status: new
severity: 3
area: archives
source: review:396
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Unpack of a tar file member whose name ends in a folder mark shows a WriteFile error

## Problem

A tar member of type "regular file" whose stored name normalizes to a name with a trailing separator (for example `x/y/..`, which the name rule makes `x\`, the caller's "folder" mark) is treated as a folder by name but carries file data. A whole Unpack (Alt+F9) then fails with the misleading message "Error writing to output file: The WriteFile function refused to write all the data requested". The archive is kept (nothing is lost), but the text does not tell the user which member is wrong or why.

## Evidence

- Found by the refute-first review of feature 396 (branch `396-tar-dotdot-name`, review 1, NOTE 3): a scratch row `UNP-DIRFILE-DEL` added to `specs/396-tar-dotdot-name/probe/dotdot_probe.ps1` (a regular file member named `x/y/..`) showed the WriteFile box; the archive was kept.
- Pre-existing: the legacy name rule gave the same `x\` for `x/y/..` (feature 396 changed only names whose dropped component was the first one).
- `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`): "skip the trailing slash but remember it was there" sets `header.IsDir = TRUE` from the normalized name, independent of the member's type.

## Expected

Such a member is reported by its raw name with a text that says what is wrong (like feature 395's "(123)" report of a regular file whose name normalizes to nothing), the operation fails after the rest is extracted and the archive is kept - or the data is written under the folder's name only if that is safe. No misleading WriteFile text.

## Notes

Not measured outside the reviewer's scratch probe row; the exact path from `IsDir` to the WriteFile message was not traced. Writers rarely store such names.

## Log

- 2026-11-02 — created (source review:396)
