---
title: A Documents folder of 260 or more characters opens the Desktop instead
type: bug
status: open
severity: 1
area: long-paths
source: review:386
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: [rescue-path-goes-to-the-windows-drive-root-when-documents]
depends-on: []
reason: -
---

# A Documents folder of 260 or more characters opens the Desktop instead

## Problem

`GetMyDocumentsOrDesktopPath` reads the Documents folder with `SHGetPathFromIDListW`, which
holds at most 259 UTF-16 units. A Documents folder with a longer path makes it fail; the helper
then treats Documents as "no file-system path" and returns the Desktop - the Documents drive,
Ctrl+; and the other callers open the Desktop silently, another folder than the one asked for.
Feature 386 refuses a Documents path that does not fit the caller's buffer instead of using the
Desktop, but this case still takes the Desktop.

## Evidence

Review 1 of feature 386 (`specs/386-mydocs-path-whole/fix-log.md`, *Review*, NOTE 1), by code
reading on branch `386-mydocs-path-whole`: `src/shellib.cpp` `GetSpecialFolderPathW`
(`SHGetPathFromIDListW(pidl, pathW)` into `WCHAR pathW[MAX_PATH]`) and
`GetMyDocumentsOrDesktopPath` (`if (!haveDocs) GetSpecialFolderPathW(CSIDL_DESKTOP, ...)`). Not
reproduced: whether Windows lets Documents be moved to a path of 260+ units (Explorer's Location
tab, the registry `User Shell Folders` value) is not measured; the 386 probe seam bypasses the
shell.

## Expected

A Documents folder whose path is longer than 259 units is read whole (for example
`SHGetPathFromIDListEx` with a long buffer, or `SHGetKnownFolderPath(FOLDERID_Documents)`) and
handed to `SalDocumentsOrDesktopToU8` - opened whole by the long-path callers, refused by the
others; never the Desktop instead.

## Notes

Measure first: can Documents be redirected to such a path at all? If not, close it as not
reachable. Severity 1: only reachable with an unusual redirection.

## Log

- 2026-11-02 — created (source review:386)
- 2026-11-02 — moved to Next
