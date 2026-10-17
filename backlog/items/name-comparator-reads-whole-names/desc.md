---
title: The 092 name comparator reads both names to their ends (2x-16x slower sorts)
type: tech-debt
status: open
severity: 2
area: encoding
source: leftover:092
who: agent
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# The 092 name comparator reads both names to their ends (2x-16x slower sorts)

## Problem

The file system's name comparison of feature 092 (`SalNameCompareOrdinalCI`) costs 2x (ASCII) to 16x (every name accented) the old byte fold in a sort, because text that is not WTF-8 orders by a property of the whole string, so both names are read to their ends. It costs the sorted name lists 092 converted (stored selections, hidden names) a few tenths of a second at 100,000 accented names.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 15 (L359) and §5 *The comparator's cost* (L1519) (at 7993914c). specs/092-name-identity-unicode/fix-log.md (~lines 287-293, the comparator's cost); `src/common/salnameorder.h`.

## Expected

A comparator that stops at the first difference, with the order of text that is not WTF-8 redefined in the contract; saltests prove the order unchanged for WTF-8 text; the sorted lists measured faster.

## Approach

A contract change of 092's order: change the contract first (specs/092-name-identity-unicode/contracts/), then the code; every stored sorted list must be re-sorted or the order kept identical for valid text.

## Notes

Low. NW §5 *The comparator's cost* (L1519) is the same entry.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-17 — migration review N3: migration remark removed
