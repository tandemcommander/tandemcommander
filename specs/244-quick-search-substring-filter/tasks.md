---
description: "Task list for feature 244 — quick search that finds text anywhere in a name and filters the panel"
---

# Tasks: Quick search that finds text anywhere in a name and filters the panel

**Input**: `specs/244-quick-search-substring-filter/` — plan.md, spec.md, research.md (R1–R9), data-model.md, contracts/, quickstart.md (V1–V10)
**Tests**: requested by the plan and quickstart — `saltests` tables (contract M/F/T) and the GUI probe on the hidden desktop.
**Rules for every task**: names are UTF-8/WTF-8 (never an `A` API, never `CP_ACP`); no character cut; sources UTF-8-BOM + clang-format; new comments in English; keep `fix-log.md` running; the option-off path must keep 0.1.10 behaviour.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup (measure first)

- [ ] T001 Build Debug x64 (`build.cmd`) and run `saltests` on the unchanged tree; record the check count and the build state in specs/244-quick-search-substring-filter/fix-log.md
- [ ] T002 Write the GUI probe skeleton specs/244-quick-search-substring-filter/probe/qs244_probe.ps1. It must:
  - build the fixture of quickstart *Prerequisites* under `%TEMP%\tc244\` and assert every typed target starts with the fixture root;
  - back up `HKCU\Software\Tandem Commander\0.1` with a hash and restore it on every exit path;
  - start the build's `tandemcommander.exe` with the left panel on `left\` and the right panel on `right\`;
  - drive it with `WM_CHAR`/`WM_KEYDOWN`/`WM_COMMAND` posted to the panel list box and main window;
  - observe through the disk (select all + F5 copy into `right\`), focus and directory-line text, and `PrintWindow` captures;
  - run through `tools/run_on_hidden_desktop.ps1`.
- [ ] T003 Run quickstart V1 (baseline) with the probe on the unchanged build. Write specs/244-quick-search-substring-filter/probe/result_before.txt with:
  - the focus after `c`/`ch`/`cha`/`chat` and after `/chat`;
  - that `chat` is refused when nothing starts with `c`;
  - that F5 with a hidden-by-search selection copies the whole selection.
  
  Compare with the spec's *Current behaviour* and record every difference in fix-log.md.

---

## Phase 2: Foundational (blocking prerequisites)

- [ ] T004 [P] Create src/common/salquickfilter.h (header-only, UTF-8-BOM, GPL SPDX header like salmaskname.h). It provides `SALQF_*`, `CSalQFMatch`, `SalQFMatchName`, `SalQFChooseFocus`, `SalQFTint` and `SalQFContrast` per contracts/salquickfilter-rules.md:
  - prefix = the exact 0.1.10 `AgreeQSMaskU8`/`AgreeQSMask` algorithm, with the ASCII byte path and the trailing-dot tolerance;
  - substring = the leftmost UTF-8 boundary with the same algorithm, i.e. an implicit leading wildcard;
  - the result reports `MatchStart`/`MatchEnd`.
- [ ] T005 [P] Add the saltests tables M1–M7, F1–F4 and T1–T4 to src/saltests/saltests.cpp:
  - M1 compares against a local copy of the 0.1.10 matcher (copied from fileswn0.cpp:42-114 and masks.cpp AgreeQSMask, labelled);
  - T fixtures copy the four built-in schemes' `ITEM_*` colours from salamdr1.cpp and Dark from themes_palette.h, naming the source lines.
- [ ] T006 Make `AgreeQSMaskU8` in src/fileswn0.cpp a wrapper of `SalQFMatchName(..., substring = FALSE, ...)`. Rebuild, rerun saltests and the V1 probe; the result must equal result_before.txt (depends on T003, T004).
- [ ] T007 Add `BOOL QuickSearchFilter` to `CConfiguration` with default `TRUE`. Store it as registry value `Quick Search Filter` (absent = TRUE) next to `Quick Search Enter Alt`. Files: src/cfgdlg.h, src/dialogs4.cpp, src/mainwnd2.cpp.
- [ ] T008 Add the Configuration checkbox for the option:
  - a free `IDC_` id in src/lang/lang.rh;
  - the control under `IDC_QUICKSEARCH_ALT` in `IDD_CFGPAGE_PANELS` in src/lang/lang.rc, with the following controls moved 12 units down and the template grown 231 → 243;
  - `ti.CheckBox` in `CCfgPagePanels::Transfer` in src/dialogs5.cpp;
  - label *Quick search finds text &anywhere in the name and shows only the matching items* (choose a free mnemonic on the page).
- [ ] T009 Add the new UI strings to free slots of an existing bundle in src/lang/lang.rc2 and src/lang/lang.rh:
  - the directory-line format `Search: %s (%d of %d)`;
  - the information-line variant, if it differs.
  
  Record in fix-log.md that the two-stage `.slt` refresh is owed.
- [ ] T010 Add the filtered-view state of data-model.md to src/fileswnd.h:
  - fields `QFActive`, `QFFullDirs`, `QFFullFiles`, `QFDirMap`, `QFFileMap`, `QFKinds`, `QFTotalCount`, `QFTintBk`, `QFTintBrush`;
  - declarations `IsQuickFilterOn()`, `ApplyQuickFilter(BOOL narrowOnly)`, `SuspendQuickFilter()`, `ResumeQuickFilter()`, `EndQuickFilter()`;
  - initialise them in the constructor (src/fileswn1.cpp or wherever `QuickSearchMode` is initialised).
  
  Build green.

**Checkpoint**: saltests green, V1 unchanged, option visible in Configuration, nothing behaves differently yet.

---

## Phase 3: User Story 1 — find an item by a word inside its name (P1) 🎯 MVP

**Goal**: with the option on, typing matches names containing the text; prefix matches decide the focus; the caret stands after the match.
**Independent test**: quickstart V3.

- [ ] T011 [US1] Rework `QSFindNext` in src/fileswn0.cpp:
  - with `Configuration.QuickSearchFilter` on, match through `SalQFMatchName(substring = TRUE)`;
  - keep the matched part `name[MatchStart..MatchEnd)` in `QuickSearch`;
  - the search for a typed character applies the focus rule `SalQFChooseFocus`: a prefix match anywhere wins over a substring match at the caret;
  - with the option off, the code path is unchanged.
- [ ] T012 [US1] Generalise `SetQuickSearchCaretPos` in src/fileswn0.cpp to measure `name[0..MatchEnd)` instead of `strlen(QuickSearch)` in all view modes. Keep the Brief/Detailed extension-column case and the clamps; with the option off, MatchEnd equals the old length.
- [ ] T013 [US1] Adapt the Left and Right keys in the quick-search block of `OnSysKeyDown` in src/fileswn0.cpp:
  - Left: text = matched part minus its last character, wildcards dropped as today;
  - Right: append the focused name's character at `MatchEnd`.
- [ ] T014 [US1] Run quickstart V3 with the probe and record it in probe/result_after.txt and fix-log.md.

**Checkpoint**: US1 complete without hiding — a viable increment.

---

## Phase 4: User Story 2 — the panel shows only what matches (P1)

**Goal**: filtered view over full arrays; commands and selection act on visible items; the search lives until the R2 end points.
**Independent test**: quickstart V4, V5, V6, V9, V10.

- [ ] T015 [US2] Implement `ApplyQuickFilter` in src/fileswn0.cpp (research R1, R4; data-model invariants I1–I6).
  - On first use, move `Dirs`/`Files` into `QFFullDirs`/`QFFullFiles` keeping ownership.
  - Build non-owning visible arrays (`SetDeleteData(FALSE)`) of whole-struct copies of the matches in full order, without `..`, plus the maps and kinds.
  - `narrowOnly` re-tests only the current visible items.
  - Do the whole-struct write-back before every rebuild.
  - Run the swap sequence: icon-reader sleep/wake, `InvalidateArr`, focus mapping, reset of `DropTargetIndex`/`SingleClickIndex`/`SingleClickAnchorIndex`, `SelectedCount` recount, list-box items count + repaint, `WM_USER_SELCHANGED`.
- [ ] T016 [US2] Implement `EndQuickFilter` in src/fileswn0.cpp:
  - write back, restore the full arrays, map the focus to its full index, recount `SelectedCount`;
  - destroy the caret and the tint brush, end `QuickSearchMode`, repaint the list box and directory line, post `WM_USER_SELCHANGED`.
  
  Make `EndQuickSearch` call it when `QFActive`.
- [ ] T017 [US2] Wire typing in `OnChar` and the quick-search block of `OnSysKeyDown` in src/fileswn0.cpp:
  - a printable character → narrow (refused if no match, FR-005);
  - Backspace/Left → widen from the full arrays; Backspace of the last character → `EndQuickFilter` (FR-017);
  - Esc → `EndQuickFilter`;
  - Up/Down/PgUp/PgDn/Home/End move over visible items, which now are all matches; check Shift/Alt behaviour stays;
  - Insert selects and moves to the next visible item without ending the search (FR-020).
- [ ] T018 [US2] Change `CFilesWindow::CancelUI` (src/fileswn5.cpp) and every direct `EndQuickSearch` caller so that in the new mode they keep the search running and only end quick rename. Callers: `OnSetFocus`/`OnKillFocus` in src/fileswn0.cpp, `ShellAction` in src/shellsup.cpp, Insert. Focus loss destroys only the caret; focus gain recreates it while the search runs (R2).
- [ ] T019 [US2] Add the R2 end points that call `EndQuickFilter` explicitly:
  - `ChangePathToDisk`/`ChangePathToArchive`/`ChangePathToPluginFS`/`ChangePathToDetachedFS` with `!isRefresh`, **before** `RefreshPathHistoryData()` (src/fileswn2.cpp:1772, 2244, 3015, 3515);
  - `ChangeDir` (src/fileswn3.cpp:1991);
  - `SwitchToTab` before `CaptureActiveTab` (src/paneltabs.cpp:241);
  - `ChangePanel` and `FocusPanel` of a panel other than the searching one (src/mainwnd4.cpp:1355, 1422);
  - panel `WM_DESTROY` (src/fileswnb.cpp:1126);
  - the option switched off on Configuration OK (src/dialogs5.cpp or the apply path in src/mainwnd*.cpp).
- [ ] T020 [US2] Implement refresh suspend/resume in `RefreshDirectory` (src/fileswn0.cpp:2438-3298, research R3).
  - Call `SuspendQuickFilter` at the start (write back, full arrays back, text kept).
  - Call `ResumeQuickFilter` before `RefreshListBox` (~3286): keep the same focused item if it matches, else the nearest match.
  - In the new mode, replace the `CancelPanelsUI` calls at ~3132 (`NextFocusName`) and ~3272 (focus lost). A `NextFocusName` item that does not match → `EndQuickFilter`, then focus it. No match left → `EndQuickFilter`. A failed refresh (~2809) → `EndQuickFilter`.
  - Measure whether an unfiltered frame is painted, and hold list-box painting if it is.
- [ ] T021 [US2] Keep the search, and rebuild the filtered view instead of ending it, in:
  - `ChangeSortType` (src/fileswn2.cpp:565-689): sort the full arrays, then rebuild;
  - `CFilesBox::OnHScroll`/`OnVScroll`/`LayoutChilds` and the header-line click (src/filesbx1.cpp, src/filesbx2.cpp);
  - the mouse handlers `OnLButtonDown`/`OnLButtonDblclk`/`OnRButtonDown` (src/fileswn9.cpp:866, 1021, 1069);
  - the menu loop and `WM_ACTIVATEAPP`, plus the central `WM_COMMAND` cancel (src/mainwnd3.cpp:1944, 2525, 6493).
  
  Most of these already end the search only through `CancelUI`, so verify each site by reading after T018.
- [ ] T022 [US2] Check the viewer's next/previous enumeration (`WM_USER_ENUMFILENAMES`, src/fileswnb.cpp:1154) and the drag box (`CFilesMap`) against array swaps. Signal an enumeration-source change on every swap, the same way a refresh does; never swap while a drag box is active. Record the outcome in fix-log.md.
- [ ] T023 [US2] Run quickstart V4 (visible set via select all + F5) and V5 (hidden selection untouched with F5, F6, F8 to the Recycle Bin, Pack). Record in probe/result_after.txt.
- [ ] T024 [US2] Run quickstart V6 (lifetime: every end and keep case, refresh from outside, history Back position, F7 non-matching folder). Record the results.
- [ ] T025 [US2] Run quickstart V9 (inside a ZIP archive; SFTP Docker `tandem-sftp` if running, else record a person step) and V10 (10k/100k fixtures, per-keystroke time via Debug TRACE). Optimise if SC-003 is missed. Record the results.

**Checkpoint**: filtering, commands on visible items and the lifetime work in all panel types.

---

## Phase 5: User Story 3 — the user can see that a search is running (P2)

**Goal**: tint, directory-line text with count, repaint at start/end.
**Independent test**: quickstart V7.

- [ ] T026 [US3] Spike (research R7): draw the panel's normal background with a test tint in Brief/Detailed/Icons/Thumbnails/Tiles, with icons drawn by the leave-background path. Files: src/fileswn4.cpp, src/filesbx1.cpp, src/iconlist.cpp. `PrintWindow` captures go to probe/; decide per icon kind (alpha, masked, thumbnails, overlays) and record the decision in fix-log.md.
- [ ] T027 [US3] Implement the tint for the searching panel:
  - compute `QFTintBk = SalQFTint(ITEM_BK_NORMAL, ITEM_BK_FOCUSED, ITEM_FG_NORMAL)` from `CurrentColors` when the search starts and on `ColorsChanged`;
  - a per-panel `QFTintBrush` replaces `HNormalBkBrush` in `PaintAllItems` (src/filesbx1.cpp) and `FillIntersectionRegion` (src/fileswn4.cpp);
  - `SetFontAndColors` (src/fileswn4.cpp) uses the tint for the normal background and the Detailed other-column background, but not for per-file-type explicit backgrounds;
  - icons are drawn with the spike's path while tinted;
  - the global brushes and the shared icon lists stay untouched.
- [ ] T028 [US3] Show the search text and the count in the directory line:
  - append `Search: <text> (<visible> of <QFTotalCount>)` after the path the same way the filter mask is appended (src/fileswn1.cpp:1894-1932), keeping `PathLen`;
  - make `CStatusWindow` drawing (src/stswnd.cpp) shorten the path first and never split a character or a surrogate pair;
  - with the directory line hidden, show the text in the information line instead (`WM_USER_SELCHANGED` path in src/fileswnb.cpp);
  - update the text after every narrow/widen/refresh.
- [ ] T029 [US3] Repaint the list box and the directory line when the search starts and ends (src/fileswn0.cpp), and only the searching panel.
- [ ] T030 [US3] Run quickstart V7: captures of idle vs searching in five view modes × four schemes + Dark, with the other panel unchanged. Store them in probe/captures/ and record the person step owed (colour judgement).

---

## Phase 6: User Story 4 — existing habits keep working (P2)

**Goal**: option off = 0.1.10; Alt+letter start, wildcards and Shift/Alt keys with the new mode.
**Independent test**: quickstart V8 and the US4 acceptance scenarios.

- [ ] T031 [US4] Run quickstart V8: clear the option through the registry value in the probe's backed-up key, rerun V1, and diff against result_before.txt (must be identical).
- [ ] T032 [US4] Probe the US4 scenarios with the option on and record the results:
  - `Quick Search Enter Alt` on: Alt+c, Alt+h … start and continue the filtered search;
  - mask `a/b`;
  - Shift+Down selects matches;
  - Right extends `chat` → `chatb` on `2024_chatbot`.

---

## Phase 7: Polish & cross-cutting

- [ ] T033 [P] Update help/src/hh/salamand/basicwork_qsearch.htm and help/src/hh/salamand/configuration_panels.htm: substring matching, filtering, the indication, commands on visible items, the end points, the option.
- [ ] T034 [P] Add the CHANGELOG.md entry under the unreleased heading in the user's terms, including how to return to the previous behaviour and the remaining limitations (feature 244).
- [ ] T035 Run the two-stage translation refresh for the new strings (`translate.merge` with `--templates`, per CLAUDE.md and memory). Pin de/fr/nl/es register in translations/ui-overrides.json if DeepL is informal, then run `build.cmd full` green.
- [ ] T036 Run `python tools/check_encoding.py` (strict, `TOTAL: 0`) and clang-format on the changed sources; rerun saltests and record the new check count.
- [ ] T037 Run independent refute-first reviews (separate agents):
  - (a) data safety: hidden items untouched, write-back complete, every R2 end point incl. history/tab-capture order;
  - (b) the option-off path equals 0.1.10;
  - (c) painting/encoding: tint contrast, no cut character, wide sinks.
  
  Fix confirmed findings and record them in fix-log.md.
- [ ] T038 Add serious defects found on the way to the backlog *Inbox* with `/tandem-backlog add` (source `measure:244` / `review:244`), e.g. the ANSI byte measuring in `SplitText`/`TruncateSringToFitWidth`, if confirmed on the build.
- [ ] T039 Write specs/244-quick-search-substring-filter/closing-report.md:
  - results V1–V10 and SC-001…SC-008;
  - limitations;
  - owed person steps (colours per scheme; SFTP if not driven).
  
  Add the feature entry at the end of specs/FEATURE-HISTORY.md and the area to its index; add a `CLAUDE.md` standing-rule line only if a rule for future work follows.

---

## Dependencies & execution order

- Phase 1 → Phase 2 (T006 needs T003 and T004; T005 needs T004).
- Phase 2 → US1 (T011–T014) → US2 (T015–T025, needs the match results of T011).
- US3 depends on US2 for the filtered state (T026 can start right after Phase 2 as a spike).
- US4 needs US1–US3.
- Polish follows.

## Parallel opportunities

- T004 ∥ T007/T008/T009 (different files); T005 after T004.
- T026 (spike) ∥ T015–T022 (different files: fileswn4/filesbx1/iconlist vs fileswn0/2/5/9).
- T033 ∥ T034.
- The T037 reviews (a)(b)(c) run as parallel agents.

## Implementation strategy

MVP is US1: substring matching and the focus rule, no hiding (T001–T014).

Then US2 (filtering and the lifetime, the core of the request), US3 (the
indication) and US4 (compatibility proof). Each checkpoint is built,
`saltests` green, and the probe re-run; every step is logged in `fix-log.md`.
