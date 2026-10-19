---
title: Plug-in interface does not say that column names are code-page text
type: tech-debt
status: new
severity: 1
area: plugin-api
source: review:248
who: agent
created: 2026-10-19
updated: 2026-10-19
verified: -
effort: S
feature: -
related: [desktop-view-folders-plug-in-repeats-its-shell-columns-after]
depends-on: []
reason: -
---

# Plug-in interface does not say that column names are code-page text

## Problem

`CColumn::Name` and `CColumn::Description` do not state their encoding, while the cell texts
of a plug-in column are UTF-8 since interface 104 and `architecture/06` says that "all `char*`
names/paths crossing the interface are UTF-8". Feature 004 read it that way and converted the
Folders plug-in's column names to UTF-8 - the cause of GitHub issue #13 (fixed by feature 248
in the plug-in). A plug-in author can repeat the mistake.

## Evidence

Review 1 of feature 248 (`specs/248-folders-column-names/fix-log.md`, *Review*, NOTE 7). At
93e777eb:

- `src/plugins/shared/spl_com.h:475-487`, `struct CColumn`: the comments of `Name` and
  `Description` say nothing about the encoding (only "must not be empty").
- `architecture/06-plugin-architecture.md`, section *Plugin Interface 104*: "all `char*`
  names/paths crossing the interface are UTF-8" - no exception for column names.
- The core reads both as code page: `src/filesbx2.cpp` `CHeaderLine::PaintItem` / width
  (`TextOut`, `GetTextExtentPoint32` - MBCS build), tooltip `filesbx2.cpp:511`
  (`Description`); every plug-in that inserts a column fills it from `LoadStr` (code page).

## Expected

`spl_com.h` (`CColumn::Name`, `Description`, `SetColumnName`) and `architecture/06` state that
column names and descriptions are code-page text (Windows ANSI code page), unlike the cell
texts (UTF-8), and point to `src/common/salcpfit.h` (`SalWToCodePageWhole`) for a plug-in that
has the name as wide text.

## Notes

A comment-only change, no ABI change - but `src/plugins/shared/spl_*.h` belongs to the
maintainer in autonomous runs (stop-rules §1), so an autonomous run would stop on it; the
maintainer may do it or allow it.

## Log

- 2026-10-19 — created (source review:248)
