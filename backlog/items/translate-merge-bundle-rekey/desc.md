---
title: Translation merge keys by bundle ordinal; removing a bundle needs a re-key
type: tech-debt
status: open
severity: 2
area: translations
source: leftover:084
who: agent
created: 2026-10-01
updated: 2026-10-23
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Translation merge keys by bundle ordinal; removing a bundle needs a re-key

## Problem

The translation merge tool keys string tables by bundle ordinal (`tools/translate/match.py` `entry_key` includes it). When a removal empties a 16-id bundle, every later bundle changes its ordinal and the merge sees their strings as new: 079 paid DeepL for the displaced rows; 084's first dry run reported 456 gaps per language until `probe/rekey_stringtables.py` re-keyed the committed input (then 15 - exactly the new strings).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 16 (L369) (at 7993914c). specs/084-archiver-cleanup/fix-log.md, *Bundle-ordinal hazard* (~line 244); specs/084-archiver-cleanup/probe/rekey_stringtables.py; specs/166-translation-layout/fix-log.md *Left* ("The bundle re-key of the merge tool ... not touched"). CLAUDE.md rule (084): removing whole bundles needs a re-key first.

## Expected

The merge identifies a string by its bundle's base id (id // 16) or by the id itself, so removing a bundle needs no manual re-key; a dry run after such a removal reports only the new strings.

## Approach

Fold 084's `rekey_stringtables.py` logic into `tools/translate` (`match.py`), with a test on a fixture that removes a bundle.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-23 — related item translations-clipped-labels closed: split into: translations-clipped-labels-cs, -de, -fr, -nl, -hu, -ro, -sk, -es and translate-merge-bundle-rekey - the parts replace it; maintainer 2026-10-23
