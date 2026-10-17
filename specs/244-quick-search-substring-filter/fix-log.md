# Fix log — 244 quick search substring filter

## 2026-10-17 — specify, plan

- Spec written from the maintainer's request (Czech). Two clarifications answered: commands act only on visible items and keep the search; on by default + an option back to 0.1.10 (documented exception to Constitution II).
- Code read by three read-only agents (listing/filter pipeline, painting/colours, lifecycle/commands); findings in `research.md` R1–R8.
- Key facts that shaped the design:
  - disk panels have no full listing, because hidden items are dropped while reading;
  - everything acts on `Dirs`/`Files` directly;
  - almost every route ends quick search today (central `WM_COMMAND` cancel, focus, menus, scroll, clicks);
  - icons have the normal background baked into icon lists shared by both panels.
- Spec adjusted after research:
  - FR-026: the text goes in the directory line, with the information line as fallback;
  - FR-027: the caret after the match end, no colour highlight;
  - FR-015: the mouse and dialogs do not end the search;
  - new edge case: an operation focusing a non-matching item ends the search.
- Not yet measured on the build: the *Current behaviour* section and every R-finding are from source reading. Quickstart V1 is the first implementation step.

## 2026-10-17/18 — implementation

### Baseline (T001-T003)

- Debug x64 build green; `saltests` 22,737 checks, 0 failed (at HEAD `3cd56a11`).
- GUI probe `probe/qs244_probe.ps1` (hidden desktop; observes through the disk: F5 with nothing selected copies the focused item, select all + F5 copies the visible set). Baseline `probe/result_before.txt`: 45 rows PASS against the 0.1.10 expectations.
- **Premise measured, not assumed:** with no name starting with `c`, typing `chat` focuses `alpha`: `c` and `h` are refused, `a` matches. A substring item cannot be found by typing.
- **Data-loss risk of the old model measured:** F6 with `old.log` selected and `rep` typed moved *both* files. In the old mode, Select all ends the search and selects everything.

### Pure rules (T004-T006)

- `src/common/salquickfilter.h`: `SalQFMatchName`, `SalQFChooseFocus`, `SalQFTint`, `SalQFContrast`, `SalQFDistance`.
- `saltests` +271 checks (23,008):
  - 901 prefix cases equal the 0.1.10 matcher (a copy of `AgreeQSMaskAux`/`AgreeQSMaskU8Aux` in the test);
  - 901 substring cases equal an independent reference;
  - focus rule F1-F4;
  - tint on the four schemes (caption colour as the scheme value and as Windows 11 shows it), Dark and two custom schemes.
- **Design change while measuring:** the tint accent is the panel caption colour, not the cursor colour. The Salamander scheme's cursor is light grey (232,232,232), so a tint toward it is indistinguishable from the cursor bar. The rule picks the smallest share (10-40 %) that keeps an RGB distance of 18 from the normal, focused, selected and full-row backgrounds and the normal text's contrast.
- **Design change:** no incremental narrowing (research R5 planned it). `SalNameEqualCI` compares non-ASCII names through a locale-aware compare, so appending a character is not provably monotone (canonical composition, possible expansions). Every keystroke scans the full listing; the measured cost is below.
- `QSFindNext` matches through `QSMatch` → `SalQFMatchName(substring = QFMode)`; the old matcher remains only for the unused whole-string search.

### Option, strings (T007-T009)

- `Configuration.QuickSearchFilter`, default TRUE, registry `Quick Search Filter`; an absent value keeps TRUE (`GetValue` leaves the buffer on `ERROR_FILE_NOT_FOUND`, no message).
- Checkbox `IDC_QUICKSEARCH_FILTER` (307) on `IDD_CFGPAGE_PANELS`. All configuration pages are 231 units high, so the page was not grown: the section gaps were tightened instead (Keyboard -4, Mouse +8, Sorting +4/+5); the last control ends at 230.
- `IDS_QUICKSEARCH_STATUS` 14001 in the 14000 bundle ("Search: %s (%d of %d)").

### Filtered view, lifetime (T010, T015-T022)

- Full/visible arrays with whole-struct write-back, as designed (R1).
- `CancelUI`, focus loss and `ShellAction` keep a new-mode search. Explicit end points:
  - `ChangePathTo*` (not refresh), **before** `RefreshPathHistoryData`;
  - `ChangeDir`;
  - `SwitchToTab`, before `CaptureActiveTab`;
  - `ChangePanel` and `FocusPanel(other)`;
  - Configuration OK with the option off;
  - the main-window close path, before `PrepareCloseCurrentPath`;
  - panel `WM_DESTROY` (without a repaint).
- Safety nets in `ReadDirectory`, `ReleaseListing` and `~CFilesWindow` (`TRACE_E`).
- `RefreshDirectory` suspends at the start and resumes at both exits; a failed refresh ends the search. A `NextFocusName` item that does not match ends the search (F7 `zzz` is shown and focused).
- `ChangeSortType` sorts the full listing and filters again. Sorting the visible arrays in place would have broken the visible→full maps, and the write-back would then have put items into the wrong slots.
- The viewer's enumeration: `EnumFileNamesChangeSourceUID` on every swap.

### Indication (T026-T029)

- The tint is drawn through `QFPanelBk`/`QFPanelBrush`:
  - per-panel brush; `SetFontAndColors` and the Detailed column backgrounds;
  - `FillIntersectionRegion` (new brush argument), `PaintAllItems`;
  - icons through the new non-virtual `CIconList::DrawOnBk`: alpha and plain icons by `DrawALPHA` with the tint as background (plain icons keep alpha 0 on their transparent pixels), XOR icons by `DrawXOR`, the blend state by `AlphaBlend` with the tint.
- **Found by the capture probe** (`probe/qs244_capture.ps1`, `PrintWindow` per scheme × view mode): in Icons/Thumbnails/Tiles the item cells stayed untinted. `FillIntersectionRegion` took the brush argument, but its four `FillRect` calls still used `HNormalBkBrush`. Fixed; every search capture of the 25 now has no normal-background pixel in the left panel.
- The tint is created before the first repaint (`QFUpdateTint` in `QFApply`), so the first frame is already tinted.
- Directory line: `QFSetDirLineText` appends `Search: <text> (<n> of <total>)` after the path (`pathLen` keeps the path's hot-tracking); with the directory line hidden, the information line shows it (`QFStatusFallback` after `ItemFocused` and `WM_USER_SELCHANGED`).
- The caret follows a focus moved by the mouse (`SetCaretIndex`) and moves off-screen when the focused item is scrolled out.

### Crash found and fixed (perf probe)

- **Symptom:** closing the program while a search ran crashed (access violation in the icon reader, `GetIconOverlayIndex` on a freed name).
- **Cause:** the close path sleeps the icon reader and closes the panel's path; `ReleaseListing`'s safety net ended the search, and `QFRestoreArrays` **woke the reader** while the names were being freed.
- **Fix:**
  - `QFApply`/`QFRestoreArrays` wake the reader only when it was running (`ICStopWork` before sleeping);
  - the close path ends a search before `PrepareCloseCurrentPath`.
- Rerun: no reports, clean exits.

### Performance (T025, SC-003)

- 10,000 and 100,000 files; `needle` (1 % matches), Backspace, and `file` (every item matches).
- Debug: worst 308 ms for the first all-matching keystroke at 100,000 items. **Optimisation:** when the matching set is unchanged, the view is not rebuilt (only the focus, caret and text are updated).
- Release (scratch build in `%TEMP%\tc244rel`): 100,000 items → 20/11 ms per character, 40 ms for the first all-matching keystroke, 5 ms after it; 10,000 items → ≤ 15 ms. `probe/result_after_release.txt`.

### Probe results

- Debug, new mode: 49 rows PASS (`C01`-`C21` + `P10000`/`P100000`).
- Release, new mode: 49 rows PASS.
- **Option off (V8):** every observed row identical to `result_before.txt` (`probe/result_option_off.txt`).

### Not driven on the hidden desktop

- **Real keyboard keys:** Shift+arrows and Alt+letter need a real key state; posted messages cannot set it. Owed to a person.
- **Colour judgement:** "light but recognisable" on a real screen, per scheme (SC-006). Owed to the maintainer.
- **SFTP:** not driven; the ZIP archive was (C21).

### Translations (T035)

- `build_langs.cmd --export-templates --module salamand` + `translate.merge`: 2 new entries × 8 languages, 0 validation failures.
- The merge also rewrote the widths of about 40 unrelated controls in each language. It fits translations to the current English layouts, which changed since the last refresh (feature 173); this is the pipeline's normal output.
- **Pins** (`ui-overrides.json`, `_feature_244`):
  - the checkbox is one line of 285 units (~86 characters), and the engine's de/fr/hu/ro/sk/es texts were too long, so they are pinned shorter, each with an accelerator free on that page;
  - Hungarian status `(%d / %d)`.
