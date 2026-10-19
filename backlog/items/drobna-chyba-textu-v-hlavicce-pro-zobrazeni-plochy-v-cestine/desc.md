---
title: Desktop view (Folders plug-in) column headers show mojibake for accented names
type: bug
status: in-progress
severity: 3
area: plugin-api
source: github#13
who: agent
created: 2026-10-19
updated: 2026-10-19
verified: 2026-10-19 7f37ec00
effort: -
feature: 248
related: []
depends-on: []
reason: -
---

# Desktop view (Folders plug-in) column headers show mojibake for accented names

## Problem

In the Desktop view (`fld:`, the Folders plug-in) on Czech Windows, the
column headers that come from the shell are garbled: "Typ položky" shows as
"Typ poloĹľky" and "Datum změny" as "Datum zmÄ›ny". The core's own headers
("Název", "Velikost") and the cell texts ("Složka souborů") are correct.
UTF-8 bytes are drawn as code page 1250 text - every language whose shell
column names contain non-ASCII letters is affected.

## Evidence

GitHub issue #13: https://github.com/tandemcommander/tandemcommander/issues/13 -
reported on Tandem Commander 0.1.10 (x64), with a screenshot of the panel header
(original text in `issue.md`).

At aa9581d4:

- `src/plugins/folders/fs1.cpp:456-458`, `CPluginDataInterface::GetShellColumns`:
  the shell column name is read with `StrRetToBufW` and stored as UTF-8
  (`SplWToU8`) in `CShellColumn::Name`; `SetupView` (`fs1.cpp:412`) copies it
  into `CColumn::Name`. This conversion came with feature 004 (d855eec6); the
  upstream code used `StrRetToBuf` (code page).
- `src/filesbx2.cpp` ~229-249, `CHeaderLine::PaintItem`: the header draws
  `column->Name` with `TextOut` / `GetTextExtentPoint32` (the `A` API, code
  page).
- `CColumn::Name` in `src/plugins/shared/spl_com.h:477` states no encoding;
  `specs/004-long-paths-unicode/contracts/plugin-interface-vnext.md` does not
  mention column names. Cell texts do cross the interface as UTF-8 (comment
  at `fs1.cpp:368`, "plugin interface 104"), which is why the cells are right.

## Expected

The Desktop view's column headers show the shell's column names correctly
in every language (here "Typ položky", "Datum změny"), in the header and
wherever else a plug-in column name is shown (column menus, sorting, width
measurement).

## Approach

Maintainer decision 2026-10-19: fix it in the Folders plug-in only. The
plug-in passes the shell column name to `CColumn::Name` as code-page text,
as upstream and every other plug-in that inserts columns do; the plug-in
interface (`spl_com.h`, `LAST_VERSION_OF_SALAMANDER`) does not change. A
character outside the code page is not shown in the header, as with any
other column name. Cell texts stay UTF-8 (interface 104). Before changing,
enumerate every core reader of `CColumn::Name` (header line, column menu,
view configuration) and confirm each one treats it as code page.

## Notes

Severity 3: cosmetic - a garbled but still readable header label - in a
plug-in enabled in the default build, seen by every user of a non-English
Windows in the Desktop view; one reporter. GitHub labels: bug, ai backlog.
No earlier feature found for #13 in `specs/FEATURE-HISTORY.md`.

## Log

- 2026-10-19 — created (source github#13)
- 2026-10-19 — fields set from the issue text and labels
- 2026-10-19 — maintainer decision 2026-10-19: fix in the Folders plug-in only - column names passed as code-page text, plug-in interface unchanged
- 2026-10-19 — moved to Next position 1
- 2026-10-19 — verified at 7f37ec00: present at 7f37ec00: GetShellColumns stores UTF-8 (SplWToU8), header draws with TextOutA (MBCS core); UTF-8 of the cs-CZ shell names read as cp1250 = the reported text; GUI probe not run (installed instance running)
- 2026-10-19 — run started, feature 248
