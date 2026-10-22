---
title: Quick search ignores diacritics: typing zlut finds a name with žluťoučký
type: improvement
status: open
severity: 5
area: panels-ui
source: manual
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: [quick-search-keys-skip-canonical-reordering-of-combining]
depends-on: []
reason: -
---

# Quick search ignores diacritics: typing zlut finds a name with žluťoučký

## Problem

Quick search in the new mode (feature 244, *Configuration > Panels > Quick search finds text
anywhere in names and shows only the matches*) ignores case but not diacritics. A user who types
without accents - the usual way to type quickly, and the only way on a keyboard without the
language's letters - does not find a folder named `žluťoučký` by typing `zlut`; the panel shows no
match. Czech, Slovak, Polish, German, French and other users meet this every day.

## Evidence

At 3aafc2c6, by reading:

- `src/common/salquickfilter.h:29-41` (header comment) and `SalQFDetail::CharKeySystem` :135-152:
  the key of a character is `NormalizeString(NormalizationD)` followed by
  `LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_LOWERCASE)`; the combining marks of the
  decomposition stay in the key, so `ž` (`z` + U+030C) never equals `z`.
- `SalQFBuildKey` :315 builds the keys of the name and of each mask segment (:478, :486);
  `SalQFMatchName` :618 compares them. An ASCII mask against an ASCII name takes the byte-wise
  rule (`AsciiAux`), which is not affected - a name with an accented letter is not ASCII, so `zlut`
  against `žluťoučký` goes through the keys.
- The per-character key cache `CCharKeyCache` (:85-130) uses `Count == 0` for "not computed yet";
  a character whose key becomes empty after dropping its marks (a lone combining mark) needs another
  marker.
- Tests: `src/saltests/saltests.cpp` (the 244 cases of `salquickfilter.h`); probes
  `specs/244-quick-search-substring-filter/probe/qs244_probe.ps1`; record
  `specs/FEATURE-HISTORY.md` entry 244.

## Expected

- In the new mode the comparison ignores diacritics **in both directions**: the keys of the name and
  of the typed text drop the combining marks (Unicode category Mn) of their canonical decomposition.
  `zlut` and `žlut` both find `žluťoučký` and `zlutý`; `Cesky` finds `Český`; `ubersicht` finds
  `Übersicht`.
- Letters without a canonical decomposition fold through a small table: at least `ł`/`Ł` -> `l`,
  `ø`/`Ø` -> `o`, `đ`/`Đ` -> `d`, `ß` -> `ss`, `æ`/`Æ` -> `ae`, `œ`/`Œ` -> `oe`, `ı` -> `i`
  (the spec fixes the list; the match still starts and ends on character boundaries of the name).
- The focused item's match (`QFMatchStart` / `QFMatchEnd`, the caret) still covers whole
  characters of the original name.
- With the option off the quick search is the 0.1.10 rule, unchanged (prefix, `SalNameEqualCI`).
- The 244 timing stays: typing over 100,000 names is not slower than measured in 244 (<= 32 ms per
  keystroke in Release; the first keystroke over non-ASCII names as filed).
- `saltests` cases for the folding (each table letter, NFC and NFD names, mask with and without
  marks, a lone combining mark, WTF-8 lone surrogates); the 244 probe rows pass; the manual's quick
  search page says that accents are ignored.

## Approach

Drop the marks inside `CharKeySystem` (after the NFD step, before or after lower-casing) and apply
the table there, so the cache and `SalQFBuildKey` stay as they are; check that the offsets
(`Offsets`, `Starts`) still point at the name's characters when a character yields fewer units.
Measure the timing probe before and after.

## Notes

- Decided with the maintainer on 2026-10-22: diacritics are ignored symmetrically (also when the
  typed text has them), not "smart" (accented text matching exactly). Highlighting the matched
  letters in the names was discussed and deliberately left out ("not now").
- Dropping all marks also removes the case of
  `quick-search-keys-skip-canonical-reordering-of-combining` for the new mode (no marks left to
  order); that item stays open for the record until this one is done - then verify it.
- Not verified: whether any script used in file names relies on marks to tell letters apart in a
  way the folding would make noisy (e.g. Vietnamese, Hebrew points, Devanagari vowel signs are Mc,
  not Mn) - the spec decides whether to restrict the folding to Latin, Greek and Cyrillic.

## Log

- 2026-10-22 — created (source manual)
- 2026-10-22 — moved to Next position 2
