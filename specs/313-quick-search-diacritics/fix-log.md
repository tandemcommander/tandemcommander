# Fix log - 313-quick-search-diacritics

Backlog item `quick-search-ignores-diacritics`: quick search (new mode of feature 244) ignores
diacritics.

## 2026-10-22 - measured at 9b79bd82 (main, before the feature)

- `build.cmd` (Debug x64): BUILD SUCCEEDED.
- Sites read: `src/common/salquickfilter.h` `SalQFDetail::CharKeySystem` (NFD + invariant
  lower case; marks stay in the key), `CharKey` (per-BMP-character cache, `Count == 0` = not
  computed, return 0 = "does not fit"), `SalQFBuildKey` (treats 0 units as overflow),
  `SalQFBuildMaskKeys`, `SalQFMatchKeys`, `SalQFMatchName`.
- Consumers enumerated (Grep): `src/fileswn0.cpp` `QFKeyOf` (cached name keys), `QFApply`
  (mask keys, `SalQFMatchName` per item), `CFilesWindow::QSMatch` (`QuickSearch`,
  `QFMatchStart`/`QFMatchEnd`), the caret code `SetQuickSearchCaretPos` (`SalQFMatchName` for the
  focused item), VK_RIGHT (appends the name's character at `QFMatchEnd`); `src/saltests/saltests.cpp`
  (feature 244 cases). Nothing else calls the key functions.
- Reachability: typing a printable character in a panel -> `QFApply` -> `SalQFMatchName(...,
  TRUE, ...)` -> keys for every non-ASCII name or mask (default configuration: option on).
- Probe written: `probe/qs313_probe.ps1` (style of `qs244_probe.ps1`; rows D01-D10).
  First run aborted in `Judge` (PowerShell variable names ignore case: `$exp` was the `[hashtable]`
  parameter `$Exp`); renamed, rerun:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\313-quick-search-diacritics\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\313-quick-search-diacritics\probe\qs313_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -Label before"`
  -> 20 rows, 0 FAIL against the "before" expectations; registry restored, identical:
  - D01 `zlut` -> {zlutý.txt} (not the folder žluťoučký) - **defect**
  - D02 `ž`+`lut` -> {žluťoučký} (the `t` refused)
  - D03 `cesky` -> {Übersicht.doc} (only `c` accepted) - **defect**
  - D04 `ubersicht` -> {zlutý.txt}; D05 `lodz` -> {alpha, zlutý.txt, žluťoučký}; D07 `reka` ->
    {Straße.txt} (INFO rows: the target names are not found)
  - D06 `strasse` -> {Straße.txt} (the prefix `stra`); D08 `か`+`kko` -> {かkko.txt}
- Option off (`-Expect off -FilterOption 0`, `probe/result_off_before.txt`): D09 `zlut` focuses
  zlutý.txt (PASS); D10 `cesky` focuses Straße.txt (INFO, compared later).
- Release timing: `build.cmd release` with `OPENSAL_BUILD_DIR=%TEMP%\tc313rel` (no trailing
  backslash, so the output went to `%TEMP%\tc313reltandemcommander\Release_x64` - a scratch folder;
  BUILD SUCCEEDED), then the 244 probe `-Perf -Only P` (`probe/result_perf_before.txt`), 8 rows PASS:
  - 10,000 ASCII: 3-14 ms per character; 100,000 ASCII: 9-14 ms, all-matching first 23 ms
  - 10,000 Czech: 3-35 ms; 100,000 Czech: 291 ms first, then 16-29 ms; Backspace 17-18 ms,
    257 ms the one that ends the search; all-matching 288 ms first, then 12-15 ms.
- `BL verify` recorded.

## Decisions (spec Clarifications)

- Marks dropped only from the generic diacritical-mark blocks (U+0300-036F, 1AB0-1AFF, 1DC0-1DFF,
  20D0-20FF, FE20-FE2F); marks of other scripts kept (conservative).
- Folding table: the item's list + `ẞ` U+1E9E.
- A text of marks only = a text of only wildcards.

## 2026-10-22 - speckit-analyze

- 0 CRITICAL, 0 HIGH. C1 (MEDIUM): Right on a decomposed name was not driven by a probe -> row
  D11 added to T013 and SC-001. A1 (LOW, accepted): SC-003's 10 % bound on the first keystroke is
  close to the run-to-run noise of the panel layout (244: 291-335 ms); if exceeded, re-run before
  judging.

## 2026-10-22 - implementation

- `src/common/salquickfilter.h`:
  - `SalQFDetail::CharKeySystem`: NFD -> invariant lower case (into a local buffer) -> drop the
    units of `IsFoldedMark` (U+0300-036F, 1AB0-1AFF, 1DC0-1DFF, 20D0-20FF, FE20-FE2F) -> replace
    `FoldLetter` letters (`ł Ł ø Ø đ Đ ß ẞ æ Æ œ Œ ı`). Returns the count (0 = empty key), -1 = no room.
  - `CharKey`: -1 for "does not fit" (was 0); the cache marks an empty key `SALQF_KEY_EMPTY` (0xFE).
  - `SalQFBuildKey`: `n < 0` grows the buffer; `n == 0` adds no unit.
  - `SalQFBuildMaskKeys`: a segment with an empty key is not stored; a wildcard before the first
    stored segment sets `LeadingWild` (so mark + `/` + text behaves as `/` + text).
  - Header comment updated.
- `src/saltests/saltests.cpp`:
  - `Fold313Touches` (independent classifier: whole-text NFD, plain code-point lists); M3 exact
    for the 672 pairs it does not touch, the superset property for the 229 it touches.
  - Changed 244 cases: `x`+`ú`/`u` now SUBSTRING 1..3; `xu`+U+0301/`u` end 2 -> 4; the `strasse`
    exception removed (the new mode now matches like the 0.1.10 rule); the long-key test uses
    `が` (2 kept units) instead of `á` (now 1 unit).
  - New 313 block: 43 cases (F1-F6), F7 option off = 0.1.10 matcher for each, negative control
    (option off does not find `žluťoučký` by `zlut`), F8 cache = uncached for every BMP code point
    (two passes), `CharKey` room results, a 3000-mark text.
- Build attempt 1: saltests 27,333 checks, **1 failed** - the 244 long-key test assumed `á` gives
  two units. Fixed (above). Attempt 2: `saltests: 27333 checks, 0 failed`; lines
  "901 prefix cases ..., 0 differ; 901 substring cases (229 touched by the 313 folding), 0 differ",
  "feature 313 folding - 43 cases, 0 differ; 320 BMP code points with an empty key".
- **Negative control**: `IsFoldedMark` disabled for U+0300-036F -> 20 of 43 cases differ, 24 checks
  fail (the table cases still pass, as they should); restored from a copy, rebuilt.
- Probes (Debug, hidden desktop, registry restored identical every time):
  - `qs313_probe.ps1 -Expect after` (`probe/result_after.txt`): 22 rows, 0 FAIL - D01 `zlut` ->
    {zlutý.txt, žluťoučký}; D02 `ž`+`lut` -> both; D03 `cesky` -> {Český.txt}; D04 -> {Übersicht.doc};
    D05 -> {Łódź.txt}; D06 -> {Straße.txt}; D07 -> {řeka (NFD)}; D08 `か`+`kko` -> {かkko.txt} (the
    voiced mark kept); D11 `r` + Right -> {řeka (NFD)} (Right appended `e`, not the mark).
  - `-Expect off -FilterOption 0` (`probe/result_off_after.txt`): D09 PASS; D09/D10 lines identical
    to `result_off_before.txt`.
  - 244 probe `-Expect new` (`probe/result_244_new.txt`): 45 rows, 0 FAIL; case rows identical to
    244's `result_after.txt`. `-Expect old -FilterOption 0` (`probe/result_244_off.txt`): 45 rows,
    0 FAIL; identical to 244's `result_option_off.txt`.
- `help/src/hh/salamand/basicwork_qsearch.htm`: a paragraph on accents and the table; the option
  remark says the earlier search does not ignore accents. `CHANGELOG.md`: entry under 0.1.11.
  244 contract: a pointer to the 313 contract.
- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).

## 2026-10-22 - timing (Release, scratch trees, 244 probe -Perf)

- New build (`build.cmd release`, `OPENSAL_BUILD_DIR=%TEMP%\tc313rel`, BUILD SUCCEEDED),
  `probe/result_perf_after.txt`: 10,000 ASCII 3-13 ms; 100,000 ASCII 9-14 ms, all-matching first
  23 ms; 10,000 Czech 3-34 ms; 100,000 Czech typing 286 ms first, then 15-27 ms; all-matching
  312 ms first, then 14-20 ms. The row is FAIL against the 244 probe's own 300 ms limit (the known
  layout cost, `quick-search-first-keystroke-over-100-000-non-ascii-names`); rerun
  (`result_perf_after_rerun.txt`): 338 ms first, then 15-28 ms.
- To separate noise from a change: the baseline commit 9b79bd82 exported (`git archive`) and built
  in `%TEMP%\tc313base` (BUILD SUCCEEDED), then base/new alternated, 100,000 Czech names
  (`result_perf_ab1-base.txt` .. `ab4-new.txt`):

| run | first char | next chars | Backspace | all-matching first / next |
|---|---|---|---|---|
| ab1 base | 329 | 17-29 | 19-38, 296 | 328 / 13-15 |
| ab2 new | 292 | 16-27 | 18-38, 258 | 288 / 13-15 |
| ab3 base | 293 | 17-28 | 18-38, 260 | 286 / 14 |
| ab4 new | 292 | 16-28 | 17-38, 262 | 283 / 13-15 |

- Result: no measurable change. Typing after the first keystroke 15-29 ms in both (<= 32 ms,
  SC-003); the first keystroke varies 283-338 ms run to run in **both** builds (the panel layout);
  the 38 ms second Backspace is present in the baseline as well. SC-003's 10 % bound holds against
  the alternated baseline (292 vs 293-329).

## Review

### Round 1 (refute-first agent on cd8e1a96) - not ready: 1 MUST, 2 SHOULD, 3 NOTE

The reviewer re-ran the measurement (baseline Release from 9b79bd82 and the branch Debug build):
the defect reproduces before and is gone after; saltests 27,333 / 0; encoding 0; no data-safety
issue (the off path never reaches keys; callers `QFApply`, `QFResume`, `QSMatch`,
`SetQuickSearchCaretPos`; offsets on character boundaries; nothing cut).

- **MUST 1 - `strasse` typed letter by letter did not find `Straße`** (nor `coeur` `cœur`): the
  new mode refuses a keystroke that leaves no match, and a match had to end on a character
  boundary, so `stras` (inside `ss` of `ß`) never matched and the text stuck at `stra`. Probe D06
  could not tell the builds apart (before and after both {Straße.txt}); the saltests case fed the
  whole text at once. **Fixed**: `Starts` = 2 for a later ASCII unit (only the fold table makes
  those), `KeySegAt` lets a match end before such a unit, `KeyEndOffset` moves the reported end
  behind the whole letter. Spec edge case / FR-004 / contract F4 / research R4 updated.
  Tests: 5 fold-end cases (`as`/`aß`, `stras`/`Straße.txt` prefix and inside a name, `co`/`cœur`,
  `xa`/`xÆble`) and `sb`/`aßb` (never starts inside). Probe rows D12 (`strasse` with `Strand.txt`
  beside: before {Strand, Straße} - measured on the baseline Release build,
  `probe/result_before_review1_rows.txt`; after {Straße}) and D13 (`coeur` with `cat.txt`: after
  {cœur.txt}; baseline {cat.txt, cœur.txt, Übersicht.doc}). D06 kept as a recorded row with a note.
- **SHOULD 2 - Left stuck on a decomposed name** (regression of the first 313 build): the match
  of NFD `řeka` ends behind the mark, and Left removed one code point - only the ignored mark - so
  the match came back the same. Backspace after a copied NFD fragment needed an extra press.
  **Fixed**: `SalQFCutLastLetter` (pure, header) removes trailing marks of the folded blocks and
  then the letter; used by Left and Backspace of the new mode in `src/fileswn0.cpp`. Tests: 11
  texts. Probe rows D14 (`r`, Left -> the search ends, all names; same on the baseline) and D15
  (`rek`, Left, Backspace, Backspace -> the search ends). On the baseline build D15 is INFO: there
  `rek` keeps only `r`, so the later Backspaces have no search and go up a folder - the copy stayed
  inside the fixture root (`%TEMP%\tc313`).
- **SHOULD 3 - probes did not prove the table claims**: covered by D12/D13 above.
- **NOTE 4 - a negative control that did not fail** (the empty-segment block of
  `SalQFBuildMaskKeys` disabled, saltests still green): the only differing case is an empty last
  segment at the end of the name (`KeySegAt` reads `Starts[Count]`). Added `b/`+mark against `ab`
  and a mark against a name of marks.
- **NOTE 5 - weaker M3 for 229 pairs**: accepted; exact answers are in the 313 table (now 51 cases).
- **NOTE 6 - U+20D0-20FF also held enclosing marks** (keycap U+20E3): `IsFoldedMark` now drops
  nonspacing marks only (U+1ABE, U+20DD-20E0, U+20E2-20E4 stay); a keycap case and per-code-point
  checks added. Cyrillic `й`->`и` etc. follow the maintainer's symmetric decision (changelog
  limitation). The FEATURE-HISTORY entry is written at closing.

After the fixes:
- `build.cmd`: BUILD SUCCEEDED; `saltests: 27383 checks, 0 failed` ("feature 313 folding - 51
  cases, 0 differ; 312 BMP code points with an empty key"; M1 0 differ; M3 0 differ, 229 folded).
- **Negative control** (the fold-end `Starts` = 2 and the empty-segment block disabled together,
  `saltests.cpp` touched so the test project relinks - a plain build does not rebuild saltests
  after a header-only change, as the reviewer noted): 7 cases differ, 7 checks fail (the five
  fold-end cases and the two empty-segment cases). Header restored from a copy, SHA-256
  `1f5ed444...f139` identical, rebuilt.
- Probes (Debug): `qs313_probe -Expect after` 30 rows, 0 FAIL (D01-D08, D11-D15 PASS);
  `-Expect off -FilterOption 0` 30 rows, 0 FAIL, D09/D10 identical to before; 244 probe new 45/0,
  old+off 45/0, both identical to 244's records. Registry restored identical every run.
- `check_encoding --strict`: TOTAL: 0.
- Timing after the review fixes (scratch Release rebuilt, BUILD SUCCEEDED; 244 probe `-Perf -Only
  P100000`, alternated, all PASS, registry identical; `probe/result_perf_ab5-new.txt` .. `ab7-new.txt`):

| run | 100,000 ASCII: chars / all-matching first | 100,000 Czech: first, next chars | Czech all-matching first / next |
|---|---|---|---|
| ab5 new | 9-21 / 24 | 286, 15-27 | 286 / 12-15 |
| ab6 base | 9-20 / 24 | 287, 17-28 | 286 / 12-14 |
| ab7 new | 9-21 / 24 | 287, 15-30 | 287 / 12-16 |

  No measurable difference from the baseline (SC-003 holds).
- Header comment wording: "nonspacing marks" (was "combining marks").
