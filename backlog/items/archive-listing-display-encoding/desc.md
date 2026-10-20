---
title: Archive listings show names in one encoding only as a whole (F-P1-05)
type: tech-debt
status: blocked
severity: 4
area: encoding
source: review:069
who: agent
created: 2026-08-24
updated: 2026-10-20
verified: 2026-10-20 49cb4b8f
effort: L
feature: -
related: [mask-matcher-code-page-fold]
depends-on: []
reason: not reproduced at 49cb4b8f: feature 084 deleted the OEM listing parser; 7-Zip listing is UTF-8 end to end, no per-item fallback, so no split tree
---

# Archive listings show names in one encoding only as a whole (F-P1-05)

## Problem

F-P1-05, the archive listing display encoding (`pack1.cpp`, both sites) is still open. Three attempts in 069 produced three defects - a fatal listing abort (an archive with a long non-ASCII path stopped opening), then a tree split (one folder shown twice with the files divided), then a narrower split - because the decision can only be made per item while `CSalamanderDirectory::FindDir` matches directory components by bytes. The listing must move as a whole: every name and path of one archive in one encoding, with `AddFile` / `AddDir`'s `MAX_PATH - 5` limit raised or measured in the target encoding first.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 19 (L399) (at 7993914c). specs/069-finish-encoding-fixes/REMAINING-WORK.md §0b; specs/068-encoding-regression-review/ (finding F-P1-05). The list-file and unpack halves of F-P1-05 are fixed and do not depend on this.

## Expected

One archive's listing is in one encoding end to end; a non-ASCII and a long non-ASCII archive list, open and unpack without a split tree or an abort (measured with 069's fixtures).

## Approach

Not a contained fix - its own feature; follow 069's fix protocol (`specs/069-finish-encoding-fixes/contracts/fix-protocol.md`): check the site at HEAD first, enumerate the consumers.

## Notes

RW069 §0b is the same entry (also 068 F-P1-05). Related decision (NW §C, 2026-10-04): the `CSalamanderDirectory` listing's byte comparison is left as it is (B-2 systemic) - check that it does not settle this item.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-17 — migration review N3: migration remark removed
- 2026-10-20 — verified at 49cb4b8f: not reproduced: the OEM column parser (OemToCharBuff into CFileData::Name) was deleted by 084; the only external listing is 7-Zip -sccUTF-8 (Pack7zList), UTF-8 end to end with no per-item fallback; 7z output of unicode.7z and sample.arj measured valid UTF-8; names to 255 UTF-16 units (222), inner path 259 bytes refused whole (decided, item 259-byte-limits-kept)
- 2026-10-20 — blocked: not reproduced at 49cb4b8f: feature 084 deleted the OEM listing parser; 7-Zip listing is UTF-8 end to end, no per-item fallback, so no split tree
