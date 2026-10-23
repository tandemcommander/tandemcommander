# Closing report - 313-quick-search-diacritics
Backlog item: quick-search-ignores-diacritics - Quick search ignores diacritics: typing zlut finds a name with žluťoučký
Outcome: closed

## What changed

- `src/common/salquickfilter.h` (pure rules of the quick search, feature 244): the key of a
  character drops, after NFD + invariant lower case, the nonspacing marks of the Latin, Greek and
  Cyrillic diacritic blocks (U+0300-036F except U+0338, U+1AB0-1AFF except U+1ABE, U+1DC0-1DFF,
  U+20D0-20FF except the enclosing marks, U+FE20-FE2F) and folds `ł Ł ø Ø đ Đ ß ẞ æ Æ œ Œ ı` to
  `l o d ss ae oe i` - in names and typed text alike (the maintainer's "symmetric" decision).
  - A character of marks only has an empty key (`CharKey` returns 0, -1 = no room; cache marker
    `SALQF_KEY_EMPTY`); a mask segment of marks only is not stored (a text of marks only = only
    wildcards).
  - `Starts` = 2 for a later unit of a folded letter: a match may end inside one (`stras` matches
    `Straße`, so the letters can be typed one by one) and then covers the whole letter
    (`KeyEndOffset`); a match never starts inside one.
  - `SalQFCutLastLetter` / `SalQFOnlyIgnoredMarks`: Left and Backspace remove a letter with its
    ignored marks, and a text of ignored marks only ends the search.
- `src/fileswn0.cpp`: Left and Backspace of the new mode use those helpers; Right, when the text +
  the name's next character is refused (a text ending inside a folded letter), goes on with the
  matched part of the name.
- `src/saltests/saltests.cpp`: M3 exact for pairs the folding does not touch, a superset check
  for the 229 it touches (`Fold313Touches`, an independent classifier); 244 cases adjusted; a 313
  block of 55 cases + per-code-point, cache, room, `SalQFCutLastLetter`, `SalQFOnlyIgnoredMarks`
  checks.
- `help/src/hh/salamand/basicwork_qsearch.htm`: accents ignored, the letter table, the option-off
  rule keeps accents. `CHANGELOG.md`: entry under 0.1.11 — unreleased. The 244 contract points to
  the 313 contract.
- With the option off (the 0.1.10 rule) nothing changed.

## Measurements (before / after, commands)

- Probe `specs/313-quick-search-diacritics/probe/qs313_probe.ps1` through
  `tools\run_on_hidden_desktop.ps1`:
  - before (9b79bd82, `-Expect before`, `probe/result_before.txt`): `zlut` -> {zlutý.txt} only,
    `cesky` -> {Übersicht.doc} (only `c` accepted), `ubersicht`, `lodz`, `reka` (NFD) do not find
    their names;
  - after (`-Expect after`, `probe/result_after.txt`): 32 rows, 0 FAIL - D01-D08, D11 Right on an
    NFD name, D12 `strasse` beside `Strand.txt` (baseline: {Strand, Straße} ->
    {Straße}), D13 `coeur`, D14/D15 Left and Backspace on an NFD name, D16 Right after `stras`.
  - option off (`-Expect off -FilterOption 0`): D09/D10 identical before and after.
- 244 probe: `-Expect new` 45 / 0 and `-Expect old -FilterOption 0` 45 / 0, case rows identical
  to 244's own records.
- Release timing (244 probe `-Perf`, scratch Release builds of the branch and of 9b79bd82,
  alternated, `probe/result_perf_ab*.txt`): no measurable difference - 100,000 Czech names
  15-30 ms per keystroke after the first in both, the first keystroke 283-338 ms in both (the
  panel layout, run-to-run noise).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED. `build.cmd release` (scratch folders): BUILD SUCCEEDED.
- `saltests: 27401 checks, 0 failed` (244 M1 0 differ; M3 0 differ, 229 folded; "feature 313
  folding - 55 cases, 0 differ").
- Negative controls: marks not dropped -> 24 checks fail; fold-end and empty-segment rules off ->
  7 fail; Right fallback off -> probe D16 FAIL. Each restored byte-identical (hash checked).
- Probes: 313 after 32 / 0; option off 32 / 0; 244 new 45 / 0 (after review 2); 244 off 45 / 0
  (after review 1 - the review-2 changes lie inside the new-mode branches only); registry restored
  identical on every run.

## Reviews (findings and what was done)

- Round 1: MUST - `strasse` / `coeur` typed letter by letter stuck (a partial text could not end
  inside a folded letter); SHOULD - Left stuck on NFD names; SHOULD - probes could not tell the
  builds apart for the table; NOTEs - an empty-segment negative control that did not fail, M3
  weaker for folded pairs (accepted), enclosing marks dropped. All fixed except the accepted NOTE.
- Round 2 (fresh agent): no MUST; SHOULD - Right stuck after a text ending inside a folded letter
  (fixed, D16 + negative control); NOTEs - a later segment starting inside a folded letter (case
  added), Left on a name starting with a lone mark (fixed), U+0338 negation (kept now), the dot
  tolerance after a typed mark (recorded, not changed - not reachable from a keyboard).
- Details: `fix-log.md`, section *Review*.

## Owed to a person (with the new person-step items)

- `quick-search-ignoring-accents-check-with-a-real-keyboard` - six steps with a real keyboard
  (Czech/German layout, Right/Left by hand, option off).

## New Inbox items (slug - title)

- quick-search-ignoring-accents-check-with-a-real-keyboard - Quick search ignoring accents: check with a real keyboard
