---
title: B-2: panel sort, archive listings and plug-in services keep the old comparison
type: tech-debt
status: rejected
severity: 2
area: encoding
source: leftover:092
who: agent
created: 2026-10-04
updated: 2026-10-17
verified: -
effort: L
feature: -
related: []
depends-on: []
reason: maintainer 2026-10-04: the remaining B-2 systemic work is not implemented - it changes what users see (panel order, archive and plug-in listings) or what plug-ins get, with the highest regression risk for a mostly theoretical gain; every identity decision that could lose data was converted (092) and the losses found since were fixed one by one (103, 107-110, 112, 113, 115, 117, 119). Re-open only with a concrete wrong-file or lost-data scenario.
---

# B-2: panel sort, archive listings and plug-in services keep the old comparison

## Problem

The remainder of encoding cluster B-2 would move the last name comparisons to the file system's rule: (1) the panel sort comparator, which is intransitive with "Use locale" off for names mixing ASCII and other characters (found by the 092 research); (2) `CSalamanderDirectory` (archive and plug-in listings), which compares names by the byte fold with a case-sensitive mode chosen by the plug-in; (3) the comparison services exported to plug-ins (`StrICmp`, `IsTheSamePath`, `SalParsePath`, `PathsAreOnTheSameVolume`, ...), which keep the byte fold; (4) a guard rule for the old comparison functions. The merged `Dir`/`DIR` folders of ZIP/TAR listings (queue 108, entry 4: tar extracts case-sensitively under a case-insensitive listing, so a Linux tarball with `Dir/a.txt` and `DIR/b.txt` shows one merged `Dir`) follow the `CSalamanderDirectory` listing and would move with it - no loss known.

## Evidence

Decision: specs/NEXT-WORK.md item 5, *Decision (maintainer, 2026-10-04): the remaining B-2 systemic work is NOT implemented* (L1317 at 7993914c) and the four entries below it (L1328-1340); queue 108 entry 4 at L1495 (`plugins/tar/untar.cpp:330`, `strcmp`). Core identity done by feature 092 (`specs/092-name-identity-unicode/fix-log.md`); disk-cache keys done by 109. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L470, at 7993914c).

## Expected

(not stated in the source)

## Notes

The comparator's cost (NEXT-WORK item 5, *The comparator's cost*, still open, low) is the item `name-comparator-reads-whole-names`.

## Log

- 2026-10-04 — maintainer: the remaining B-2 systemic work (panel sort comparator, CSalamanderDirectory comparison, plug-in comparison services, guard rule) is not implemented
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
- 2026-10-17 — migration review N3: cross-reference to the final slug
