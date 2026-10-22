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
