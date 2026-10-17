# Implementation Plan: Quick search that finds text anywhere in a name and filters the panel

**Branch**: `244-quick-search-substring-filter` | **Date**: 2026-10-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/244-quick-search-substring-filter/spec.md`

## Summary

Typing in a panel matches names that contain the typed text anywhere. A name
that starts with the text still decides where the focus lands. While text is
typed, the panel shows only the matches: it keeps its listing as *full
arrays* and installs non-owning *visible arrays* as `Dirs`/`Files`. Commands,
selection commands and plug-ins therefore act only on what is visible, with
no change of their own. Hidden items keep their selection and every other
per-item state through a whole-struct write-back (research R1).

In the new mode the search no longer ends at every `CancelUI`. It ends at a
short list of points (R2): Esc, empty text, a path change (before the history
records it), a tab switch, the other panel, a failed or emptied refresh, and
an operation focusing a non-matching item. A refresh suspends and resumes the
filter around the unchanged refresh and merge (R3).

The searching panel is lightly tinted from its own colour scheme (R7);
icons are drawn over the tint by the leave-background path. The directory
line shows `Search: <text> (<n> of <total>)`, and the caret stands after the
match.

Pure rules (matching, focus choice, tint) live in a header-only
`src/common/salquickfilter.h` with `saltests` checks. One Configuration
option, default on, restores the 0.1.10 quick search exactly. That is the
maintainer's documented exception to Constitution II.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS2022)
**Primary Dependencies**: WinAPI (GDI drawing, carets); the core's `CFilesWindow`/`CFilesBox`/`CStatusWindow`/`CIconList`; `src/common/salunicode.*` (`SalNameEqualCI`)
**Storage**: one DWORD `Quick Search Filter` under the existing `Configuration` key; nothing else stored
**Testing**: `saltests` (pure rules, new tables M/F/T); GUI probe `specs/244-*/probe/` on the hidden desktop (quickstart V1–V10); `PrintWindow` captures; refute-first review
**Target Platform**: Windows 11+ x64
**Project Type**: desktop application (core change; no plug-in change)
**Performance Goals**: per keystroke < 0.1 s at 10,000 items, < 0.3 s at 100,000 (SC-003); incremental narrowing, full re-test only when the text gets shorter
**Constraints**:
- names UTF-8/WTF-8, never through an `A` API or `CP_ACP`;
- no character cut in shown text;
- no ABI change;
- no change of the global brushes or the shared icon lists' baked background;
- the option-off path byte-identical in behaviour to 0.1.10.

**Scale/Scope**:
- about 12 core files: `fileswn0/1/2/3/4/5/9/b.cpp`, `filesbx1.cpp`, `mainwnd2/3/4.cpp`, `paneltabs.cpp`, `stswnd.cpp`, `iconlist.cpp`, `dialogs4/5.cpp`, `cfgdlg.h`, `fileswnd.h`, `lang.rc`/`lang.rh`;
- one new header;
- 2–3 new strings;
- 2 help pages;
- 1 changelog entry.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / rule | Assessment |
|------------------|------------|
| I. Build reproducibility | Pass. No new dependency or build step; the new header is in `src/common/`, and `saltests` already compiles `salunicode.cpp`. |
| II. Backward compatibility | **Justified deviation.** The new behaviour is on by default (maintainer's decision 2026-10-17). It is bounded by one option restoring 0.1.10 exactly (FR-029, SC-008, quickstart V8) and stated in `CHANGELOG.md` (FR-031). See *Complexity Tracking*. No plug-in ABI change (`LAST_VERSION_OF_SALAMANDER` stays 107); plug-ins see visible items, as with the panel filter. |
| III. Incremental modernization | Pass. The changes are limited to the quick-search paths and the listed end points; no refactor of adjacent code. The pure rules are extracted into a tested header, and the core's `AgreeQSMaskU8` becomes a wrapper. New comments in English. |
| IV. Windows commitment | Pass. Pure WinAPI/GDI. |
| V. Plug-in architecture | Pass. No interface change; plug-in-listed panels (archives, FS) filter the same way (FR-011). |
| VI. UI consistency | Pass. The checkbox is added to the existing `IDD_CFGPAGE_PANELS` `DIALOGEX` (house style kept, controls moved down 12 units). The tint is per panel and derived from the active scheme/theme; no process-wide visual change, no new control class. |
| Standing rules: UTF-8 names, no cut, `LoadStrU8`/`LoadStrW` | Pass by design. The shown text is formatted from `LoadStrU8` into the wide-drawing directory line; the ellipsis never splits a character (R7). |
| Standing rules: never lose the user's data | Pass by design. Hidden items are unreachable for commands (R1); the write-back keeps every per-item state; an operation focusing a non-match ends the search instead of hiding the result. |
| Standing rules: new strings / translations | Owed. Free slots in an existing bundle; the two-stage `.slt` refresh before `build.cmd full` (084). |
| `PRIVACY.md` | No update. No network change. A new boolean setting under the existing key does not change the "settings are stored in the registry" claim, and the search text is not stored (it never joins a history). |
| `CHANGELOG.md` | Entry under the unreleased heading, including how to return to the previous behaviour. |

**Post-design re-check (after Phase 1)**: unchanged. The data model keeps the
full listing untouched (I6), the contracts add no ABI, and the only stored
value is the option.

## Project Structure

### Documentation (this feature)

```text
specs/244-quick-search-substring-filter/
├── spec.md
├── plan.md                      # this file
├── research.md                  # R1–R9
├── data-model.md                # state, invariants, transitions
├── quickstart.md                # V1–V10
├── contracts/
│   ├── salquickfilter-rules.md          # M1–M7, F1–F4, T1–T4
│   └── panel-quick-filter-behaviour.md  # keys, commands, display, never
├── checklists/requirements.md
├── fix-log.md                   # running log (from the first build on)
├── probe/                       # GUI probe + result_before/after
└── tasks.md                     # /speckit-tasks
```

### Source Code (repository root)

```text
src/common/salquickfilter.h      # NEW: SalQFMatchName, SalQFChooseFocus, SalQFTint, SalQFContrast
src/saltests/saltests.cpp        # + M/F/T tables
src/masks.cpp                    # AgreeQSMask unchanged (ASCII legacy), referenced by M1
src/fileswnd.h                   # + QF* fields, EndQuickFilter/ApplyQuickFilter/SuspendQuickFilter/ResumeQuickFilter
src/fileswn0.cpp                 # QSFindNext → SalQFMatchName; OnChar/OnSysKeyDown search block; Insert;
                                 #   EndQuickSearch vs. EndQuickFilter; RefreshDirectory suspend/resume (2441, 3132, 3272, 3286);
                                 #   OnSetFocus/OnKillFocus caret; SetQuickSearchCaretPos(matchEnd)
src/fileswn1.cpp                 # directory-line text (next to the filter mask, 1894-1932)
src/fileswn2.cpp                 # ChangePathTo* (!isRefresh): EndQuickFilter before RefreshPathHistoryData; ChangeSortType rebuild
src/fileswn3.cpp                 # ChangeDir end point
src/fileswn4.cpp                 # SetFontAndColors / FillIntersectionRegion: tint brush; icon draw flag
src/fileswn5.cpp                 # CancelUI: new-mode branch (quick rename only)
src/fileswn9.cpp                 # mouse handlers keep the search inside the panel
src/fileswnb.cpp                 # WM_DESTROY end; WM_USER_SELCHANGED fallback text when the directory line is hidden
src/filesbx1.cpp                 # PaintAllItems empty area with the tint; OnH/VScroll and LayoutChilds keep the search
src/iconlist.cpp                 # leave-background draw for a tinted panel
src/mainwnd2.cpp                 # registry value Quick Search Filter
src/mainwnd3.cpp                 # central WM_COMMAND cancel, menu loop, WM_ACTIVATEAPP: new-mode no end
src/mainwnd4.cpp                 # ChangePanel / FocusPanel(other) end points
src/paneltabs.cpp                # SwitchToTab end point before CaptureActiveTab
src/stswnd.cpp                   # directory line: path shortened first, no character cut
src/cfgdlg.h, src/dialogs4.cpp, src/dialogs5.cpp   # option field, default, checkbox transfer
src/lang/lang.rc, src/lang/lang.rh, src/lang/lang.rc2  # checkbox control, id, strings
help/src/hh/salamand/basicwork_qsearch.htm, configuration_panels.htm
CHANGELOG.md                     # unreleased entry
specs/FEATURE-HISTORY.md         # entry at the end (closing)
```

**Structure Decision**: this is a core change in the existing panel sources plus
one header-only rule file under `src/common/`, following the project's pattern
for pure decisions (`salmaskname.h`, `salsamefile.h`). Tests go into the
existing `saltests`, probes into the feature folder.

## Implementation order (for `/speckit-tasks`)

1. **Measure**: baseline probe V1 on the unchanged build → `result_before.txt`, `fix-log.md`.
2. **Pure rules**: `salquickfilter.h` + `saltests` (M, F, T). `AgreeQSMaskU8` wraps `SalQFMatchName(substring = FALSE)`; V1 must be unchanged.
3. **Option**: field, registry, checkbox, strings (option-off = today); `.slt` refresh owed.
4. **Matching without hiding**: substring + focus rule + caret at `MatchEnd` (US1 alone is a viable increment).
5. **Spike, icons over a tint**: one panel in five view modes; captures; decide the per-icon-kind outcome before step 7.
6. **Filtered view**: full/visible arrays, write-back, swap sequence (R4), incremental narrowing, Backspace/Left/Right, focus mapping; `SelectedCount`; viewer enumeration source.
7. **Lifetime**: new-mode `CancelUI`, the R2 end points (incl. history order and tab capture order), mouse, refresh suspend/resume, `NextFocusName` rule, sort and view changes.
8. **Indication**: tint brush and painting, directory-line text and fallback, repaint at start and end, `ColorsChanged`.
9. **Commands on visible items**: V4/V5 probes (copy, move, delete, pack, select all, Insert).
10. **Archives and FS** (V9), **performance** (V10), **option off** (V8).
11. **Docs**: help pages, `CHANGELOG.md`, `FEATURE-HISTORY.md`; refute-first review; findings on the way go to the backlog *Inbox* (`measure:244` / `review:244`). The pre-existing ANSI byte measuring in `SplitText`/`TruncateSringToFitWidth` (R7) is checked on the build and filed if confirmed.

## Risks

| Risk | Mitigation |
|------|------------|
| A missed end point leaves a filtered list where the full list is expected (history, tab capture, a plug-in path change) | R2 list in one function; `ChangePathTo*` order fixed in code; V6 probes each; refute-first review targets it |
| A missed `CancelUI` caller still ends the search in the new mode | The new-mode switch is inside `CancelUI`/`EndQuickSearch` itself, not at call sites; `ShellAction`'s direct `EndQuickSearch` and the focus handlers are routed through the same check |
| Selection or size state lost on hidden items | Whole-struct write-back (I2) before every swap; V5 |
| Icon reader or drag box sees arrays mid-swap | Swap sequence R4 (sleep/wake, invalidate, no swap during a drag box) |
| One frame of the unfiltered list during refresh | Measured in V6; hold list-box painting during the refresh if visible |
| Icons show untinted squares | Spike step 5 before the painting work; limitation recorded if a kind cannot be drawn over the tint |
| Performance with 100k items and non-ASCII names | Incremental narrowing; ASCII fast path; V10 measured; Backspace worst case reported |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution II: a user-facing behaviour change on by default, not opt-in | The maintainer's decision (Clarifications 2026-10-17): the feature exists so that users can find items they cannot find today. An opt-in hidden in Configuration would leave most users without it. | Opt-in (default off) complies with the letter of II but defeats the feature's purpose. The deviation is bounded: one option restores 0.1.10 exactly (SC-008, V8), and the changelog says how. |
| The search's lifetime inverted: an end-point list instead of "everything cancels" | Commands must act on the filtered view without ending it (Clarifications Q1) | A keep-list of commands is about 60 call sites and makes every future command end the search by default (R2) |
