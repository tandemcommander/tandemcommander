---
title: Encoding: the sites feature 069 deliberately did not convert
type: tech-debt
status: parked
severity: 2
area: encoding
source: leftover:069
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [copy-hook-for-drag-out-of-archives]
depends-on: []
reason: deliberately not on the list (069 §2): each site waits for its own condition for re-opening, stated in the item (a facade migration, the copy-hook change, a shell-boundary pass, a viewer-title pass, a new string); not a rejection
---

# Encoding: the sites feature 069 deliberately did not convert

## Problem

Sites left on ANSI / code page by 069, each with the condition under which 069 says to convert it: (1) `icncache.cpp:796` - the icon location read through the old ANSI `SalRegQueryValueEx`; only together with that read and every consumer of `iconLocation` (the remaining-facade migration); (2) the DROPFAKE / CLIPFAKE pair `shellsup.cpp:1025` / `:1440` - only together with the ANSI shell extension `src/shellext/copyhook.c` (a cross-binary change, 32- and 64-bit; see `copy-hook-for-drag-out-of-archives`); (3) six `IShellFolder` / `STRRET` sites in `shellib.cpp` - each needs its own consumer analysis; (5) `execute.cpp:1213` (`$(DOSPath)` of a user-menu item, the same expansion as the fixed `editwnd.cpp` site) - with any future shell-boundary pass; (6) reporting a failed archive-edit copy - needs a new translated string (the silent-failure cause is fixed); (7) the nine `IDS_VIEWERTITLE` call sites (`viewer2.cpp` x8, `viewer3.cpp:1670`; render correctly) - a future viewer-title pass; (8, 9) dead code `worker.cpp:7058` (inside a comment) and `mainwnd3.cpp` FMExt `szName` (inside `#if (_MSC_VER < 1700)`) - not to be changed while uncompiled. Site 4 of 069 §2 (`fileswn0.cpp` / `fileswn2.cpp`, ANSI `IShellLink`) was done by feature 128 (both use `IShellLinkW` at 7993914c).

## Evidence

`specs/069-finish-encoding-fixes/REMAINING-WORK.md` §2 (items 1-9). Migrated from specs/NEXT-WORK.md *Recorded, deliberately not on the list* (L2211-2216, at 7993914c). Site 4 done: `IShellLinkW` in `fileswn0.cpp:334` and `fileswn2.cpp:168` at 7993914c (ledger row RW069 §2.4; confirmed by the migration review, `specs/242-backlog-system/ledger/review.md` S4).

## Expected

Each site is converted only when its condition above is met (or found to apply no more); until then the site stays as 069 left it. Parked, not rejected: 069 itself defers several sites to a later pass.

## Notes

NEXT-WORK's summary names "three pieces of dead code"; 069 §2 lists two dead-code sites. Later features (e.g. 100's window titles) may have touched some of these sites - a `verify` settles which still apply before one is re-opened.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
- 2026-10-17 — moved to Parked: deliberately not on the list (069 §2): each site waits for its own condition for re-opening, stated in the item (a facade migration, the copy-hook change, a shell-boundary pass, a viewer-title pass, a new string); not a rejection
- 2026-10-17 — migration review S4: site 4 (IShellLink, done by 128) dropped; each site with its condition for re-opening; Expected written
