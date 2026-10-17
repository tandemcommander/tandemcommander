# Research: Quick search that finds text anywhere in a name and filters the panel

Feature 244 · 2026-10-17 · read from the 0.1.10 tree (`main` at `6fc5e5d1`).
Line numbers are those of that tree; they are pointers for the
implementation, not a contract.

## R1. Where the visible list lives — and why the filter swaps arrays

**Finding.** The panel shows `Dirs->Count + Files->Count` items; index
`i < Dirs->Count` is a directory, the rest are `Files[i - Dirs->Count]`
(`fileswnd.h:576-577`). There is no view-index layer. Everything that acts on
items reads these two arrays directly:

- `GetSelItems` (`fileswn0.cpp:734`), `GetSelCount`/`SelectedCount` (`933`).
- "The focused item if nothing is selected" (`SelectFocusedItemAndGetName`, `fileswn0.cpp:830`).
- `FilesAction` (`fileswn8.cpp:181`), `MakeFileList` (`fileswn6.cpp:341`), Pack/Unpack (`fileswn7.cpp`), `ChangeAttr` (`fileswn5.cpp:188`).
- The drag source (`shellsup.cpp:1365-1393`) and the user-menu name lists (`mainwnd3.cpp:2629-2809`).
- The plug-in interface: `GetPanelItem`, `GetPanelSelection`, `SelectPanelItem` (`zip.cpp:1160-1316`).
- Every selection command (`fileswn1.cpp:1948-2279`).

The panel filter and *Hide names* already work this way: an item they hide is
never put into `Dirs`/`Files` (`fileswn3.cpp:468-507`, `1065-1138`,
`1332-1379`).

There is **no full listing to filter from** on disk. `Dirs`/`Files` own their
data (`SetDeleteData(TRUE)`, `fileswn3.cpp:138-139`) and are filled straight
from the FindFirst/FindNext loop. Archives and plug-in file systems do keep
the full listing (`ArchiveDir`, `PluginFSDir`), and their `Dirs`/`Files` are
shallow copies. No function re-filters in memory: `ChangeFilter`,
`ShowHideNames` and Ctrl+H all post `WM_USER_REFRESH_DIR` and read the
directory again (`fileswn9.cpp:825`, `fileswn1.cpp:2354`, `mainwnd3.cpp:4852`).

**Decision.** While the filter is on, the panel keeps the listing it had as
the *full arrays* (`QFFullDirs`/`QFFullFiles`, the original arrays with their
ownership) and installs *visible arrays* as `Dirs`/`Files`. The visible
arrays are non-owning (`SetDeleteData(FALSE)`) copies of the matching
`CFileData` items in the full order, plus one index map per array
(visible → full).

Every gatherer, selection command and plug-in call then sees only visible
items with no change of its own. FR-019, FR-020 and FR-021 follow from the
data layout instead of from per-command code.

**Write-back.** `CFileData` holds per-copy state by value: `Selected`,
`SizeValid`/`Size` (directory size from Space), `CutToClip`, `Dirty`,
`IconOverlayIndex`/`IconOverlayDone` (`spl_com.h:230-238`). Before any
rebuild of the visible arrays and before the full arrays are put back, every
visible item is copied back **whole** to its full slot through the map. A
field list could miss a bit; the whole-struct copy-back cannot. The pointers
(`Name`, `Ext`, `DosName`, `PluginData`) are shared, so the copy is shallow
and safe.

**Alternatives rejected.**
- *A view-index layer under the list box.* Every gatherer and the plug-in API would act on the full arrays, so hidden selected items would be copied or deleted. FR-019 would need a change at about 40 call sites.
- *A test inside `ReadDirectory` like `HiddenNames`.* It re-reads the disk on every keystroke (seconds on a network share, a reconnect on FTP). It also drops the selection of hidden items, because the refresh merge only keeps the selection of items that are in the new list (`fileswn0.cpp:2937-3093`).
- *Clearing the selection of hidden items.* It loses user state, against the spec (edge case; FR-023).

## R2. Lifetime: the search ends only at listed points

**Finding.** Today almost every route ends quick search:

- The central `CancelPanelsUI()` at the start of `WM_COMMAND` (`mainwnd3.cpp:2519-2526`, everything except the three refresh commands).
- `OnKillFocus`/`OnSetFocus` (`fileswn0.cpp:2242`, `2211`), so every dialog and viewer ends it.
- Menu loops (`mainwnd3.cpp:1944`), scrolling (`filesbx1.cpp:1020-1247`), every mouse click (`fileswn9.cpp:866`, `1021`, `1069`).
- App deactivation (`mainwnd3.cpp:6493`), `FocusPanel` even for the same panel (`mainwnd4.cpp:1422`).
- `ShellAction` (`shellsup.cpp:1329`), `Execute` (`fileswn2.cpp:59`).
- The refresh after an operation that names a focus or loses the focused item (`fileswn0.cpp:3132`, `3272`).

If items stay hidden, F5 would end the search before the copy reads the
selection. That breaks the maintainer's decision (Clarifications Q1).

**Decision.** With the new option on, a running search is **not** ended by
`CancelUI`/`CancelPanelsUI`, focus loss, menus, scrolling, mouse clicks
inside the panel or app deactivation. Those keep ending quick rename as
today. Quick search is ended, through one function `EndQuickFilter()`, only
at these points (FR-016–FR-018):

1. **Keys.** Esc in the panel; Backspace deleting the last character.
2. **A real path change, before the history is recorded.** `ChangePathToDisk`/`Archive`/`PluginFS`/`DetachedFS` when `!isRefresh`, and `ChangeDir`. These call `RefreshPathHistoryData()` *before* they cancel today (`fileswn2.cpp:1772`, `2244`, `3015`, `3515`). The filter must end first, so that history records the full list's top index and focus, not the filtered ones.
3. **Panel tabs.** `SwitchToTab` (`paneltabs.cpp:241`), before `CaptureActiveTab`, which saves the selection by walking `Dirs`/`Files` (`paneltabs.cpp:202-213`).
4. **The other panel.** `ChangePanel` (`mainwnd4.cpp:1355`), and `FocusPanel(other)` when `other` is not the searching panel (`mainwnd4.cpp:1422`).
5. **The refresh itself.** A failed refresh (`fileswn0.cpp:2809`); a refresh after which no item matches; a refresh with `NextFocusName` naming an item that does not match (a new folder from F7 or a renamed item) — the search ends so that the item is shown and focused (new edge case in the spec).
6. **Configuration.** The option switched off while a search runs; the panel destroyed (`fileswnb.cpp:1126`).

The caret belongs to the focused window: it is destroyed on kill focus and
recreated on set focus while a search runs.

**Alternatives rejected.**
- *A list of commands that do not end the search.* About 60 call sites across mainwnd3/4, fileswn9, shellsup and filesbx1; every future command would end the search by default.
- *Ending on any focus loss, as today.* Every operation dialog takes focus, so F5 would end the search.

## R3. Refresh while filtered

**Finding.** `RefreshDirectory` (`fileswn0.cpp:2438-3298`) keeps the old
`Dirs`/`Files`, re-lists, merges the selection and per-item state by name
(`2937-3093`) and restores the focus by name (`3128-3275`). It already
tries to keep quick search alive (`2441`).

**Decision.** At the start of `RefreshDirectory`, with the filter on:

1. Write back and put the full arrays back as `Dirs`/`Files` (*suspend*); the search text is kept.
2. Let the refresh run unchanged on the full listing, so the merge sees the full selection.
3. Just before `RefreshListBox` (`3286`), apply the filter to the new listing again (*resume*): focus the same item if it still matches, else the nearest match in sort order. If nothing matches, end the search (spec edge case).

The `CancelPanelsUI()` calls at `3132`/`3272` are replaced, in the new mode,
by the R2 rule 5 decision. `CommonRefresh` → `RefreshListBox` inside the
re-list may paint the unfiltered list for one frame. Measure it on the build;
if it is visible, hold painting of the list box during the refresh.

## R4. Icon reader and other index holders

**Finding.** The icon reader walks `Dirs`/`Files` by index inside
`ICSleepSection` and posts indices (`fileswn1.cpp:679-853`). `CFilesMap`
(drag box) holds pointers (`filesmap.cpp:171`). `CVisibleItemsArray` holds
name pointers and indices (`fileswna.cpp:988-1119`). `QuickRenameIndex`,
`DropTargetIndex` and `SingleClickIndex` are indices. `ChangeSortType` is the
precedent for changing the arrays in place (`fileswn2.cpp:597-601`).

**Decision.** Every array swap (start, each rebuild, suspend, end) runs this
sequence:

1. `SleepIconCacheThread()` (when icons or thumbnails are used).
2. Write back; swap.
3. `InvalidateArr()` on both visible-items arrays.
4. Map `FocusedIndex`; reset `DropTargetIndex`, `SingleClickIndex` and `SingleClickAnchorIndex`; end quick rename.
5. Recount `SelectedCount` over the visible arrays — the debug check at `fileswn0.cpp:933` compares it with them.
6. `WakeupIconCacheThread()`.
7. `RefreshListBox`-equivalent repaint; post `WM_USER_SELCHANGED`.

Icons are found again by name, so cached icons of hidden items are harmless.
No swap happens while a drag box is active: a drag box ends on any key.

**To verify during implementation.** The viewer's next/previous file
(`WM_USER_ENUMFILENAMES`, `fileswnb.cpp:1154`) enumerates `Files`. Check how
a refresh signals a changed enumeration source, and signal it the same way
on every swap.

## R5. Matching rule (FR-002–FR-005)

**Finding.** `QSFindNext` → `AgreeQSMaskU8` (`fileswn0.cpp:42-114`) matches
`PrepareQSMask`'s mask (`masks.cpp:188`): literal segments separated by `/`
(`/`, `\` and `<` are wildcards, `masks.cpp:183`), anchored at the start of
the name.

- Non-ASCII text goes through `SalNameEqualCI`: case and canonical equivalence (`salunicode.h:336`, tried over windows up to `3 * segChars + 3` characters).
- ASCII mask with an ASCII name keeps the legacy byte-wise `AgreeQSMask`.
- A dot at the end of the mask is tolerated for a name without an extension.
- It returns only where the match **ends**.

**Decision.** A header-only rule `src/common/salquickfilter.h` with
`saltests` checks:

- `SalQFMatch(name, hasExtension, mask, &result)`: the prefix match exactly as today. When it fails, the leftmost substring match is the same algorithm with an implicit leading `/`.
- The result holds: matched, prefix or not, and the match's start and end bytes (the end is where today's offset was).
- The ASCII fast path is kept byte-for-byte: ASCII case folding only, as `AgreeQSMask` does for ASCII; a `saltests` equivalence table pins it.
- The core's `AgreeQSMaskU8` becomes a wrapper, so the option-off path returns the same results (SC-005, SC-008).
- Matching is incremental: appending a character only narrows (every substring of a match is a match), so a longer text is tested only against the current matches; a shorter text is tested against the full arrays.

**Alternatives rejected.**
- *Regular expressions or fuzzy matching.* Out of scope.
- *Base name without the extension.* The spec matches the whole name (Assumptions).

## R6. Focus rule (FR-004)

**Decision.** Pure function `SalQFChooseFocus(kinds[], count, current)`,
where `kinds` holds none/substring/prefix per visible-candidate index:

- If the current item is a prefix match, it stays.
- Otherwise: the first prefix match downwards from `current`, then upwards — the same order `QSFindNext` uses today (`fileswn0.cpp:1050-1051`).
- If there is no prefix match: the current item if it is a substring match, otherwise the first substring match downwards, then upwards.

In `saltests`.

## R7. Indication (FR-024–FR-028)

**Finding (colours).**
- Panel colours are `CurrentColors[...]` (`consts.h:1314-1398`). The built-in schemes are in `salamdr1.cpp:519-729`, Dark in `themes_palette.h:58-92` (feature 028).
- Items choose their background in `SetFontAndColors` (`fileswn4.cpp:29-122`).
- The empty area is painted with the **global** `HNormalBkBrush` (`filesbx1.cpp:178-452`, `fileswn4.cpp:401-430`).
- Icons have the normal background **baked in**: `CIconList::SetBkColor` (`iconlist.cpp:1097`). The lists are the panel's `IconCache`, the global `SimpleIconLists` and the association and plug-in lists. A plain `BitBlt` draws them (`iconlist.cpp:698`).
- `DrawALPHALeaveBackground` (`iconlist.cpp:855-914`) draws over the existing pixels.
- No colour-blend helper exists. `GetFullRowHighlight` (`salamdr1.cpp:1685`) is the closest.

**Decision (tint).** The searching panel paints its normal item background and
its empty area with a **tint**:

- `SalQFTint(normalBk, accentBk)` mixes 12 % of the scheme's cursor colour (`ITEM_BK_FOCUSED`) into `ITEM_BK_NORMAL`.
- If the result is too close to the normal background (a custom scheme with equal colours), it raises the share to 25 %. If it is still too close, it shifts the luminance by 6 % away from the text colour.
- Pure; in `saltests`, with contrast checks on all four built-in schemes and Dark (fixture values copied from `salamdr1.cpp`/`themes_palette.h`):
  - normal text on the tint keeps at least 4.5:1, or the scheme's own contrast if that is lower;
  - the tint is visibly different from the normal background, the full-row highlight and the selected background;
  - focused, selected and focused+selected keep their own colours (FR-025).
- The tint is computed when the search starts and again on `ColorsChanged`. It is a per-panel brush, not a change of the global `HNormalBkBrush`.

**Decision (icons).** While the panel is tinted, icons are drawn with the
leave-background path: `DrawALPHALeaveBackground` for alpha icons and the
list's mask for the others. Normal panels keep the `BitBlt` path.

- Measure first: a spike task draws one panel in every view mode over the tint and captures screenshots before the rest is built.
- If some icon kind cannot be drawn this way, its cell keeps the untinted background. That is recorded as a limitation in the closing report.
- Thumbnails keep their baked frame.
- Per-file-type colours with an explicit background stay untinted: an explicit choice of the user.

**Decision (text and count).** The directory line shows the search after the
path, the same way the panel filter mask is shown today (`fileswn1.cpp:1894-1932`,
`SetText(buf, pathLen)` keeps the clickable path part).

- The text is `Search: chat (3 of 120)`, from a new string formatted with `LoadStrU8`; no plural forms are needed.
- The count of all is the full arrays' count without `..`.
- With the directory line hidden, the same text replaces the information line's content while searching; it is restored by `WM_USER_SELCHANGED` when the search ends.
- The directory line is wide-text (`stswnd.cpp:157-166`, `ExtTextOutW`). The ellipsis must cut the path first and never split a character, including a surrogate pair (FR-026). To be checked in `DrawEllipsis`.
- *Alternative rejected:* the information line as the primary place. It is the selection summary (FR-021) and the focused item's details; showing the search there would hide what a command will act on.

**Decision (matched part, FR-027).** The caret is placed after the **end** of
the match inside the name (`SetQuickSearchCaretPos`, `fileswn0.cpp:3318`,
which already measures a prefix; it now measures `name[0..matchEnd)`). Where
the match starts can be read from the search text shown in the directory
line.

- *Alternative rejected:* drawing the matched part in another colour in every view. It needs a split draw in three item painters, and `SplitText` and `TruncateSringToFitWidth` measure UTF-8 bytes with the ANSI API (`fileswn4.cpp:1097`, `1673`), which would mis-place it for non-ASCII names. Out of scope (spec Assumptions).

**Repaint.** Today the search starts and ends without a repaint
(`fileswn0.cpp:27-37`, `1054-1069`). The new mode invalidates the list box
and the directory line at both points.

## R8. Setting (FR-029) and compatibility

**Decision.** `CConfiguration::QuickSearchFilter`:

- `BOOL`, default `TRUE` (`dialogs4.cpp:376`).
- Registry value `Quick Search Filter` under `Configuration` (`mainwnd2.cpp:299`, `1695`, `3308`); an absent value means `TRUE`.
- A checkbox on *Configuration › Panels › Keyboard* under `IDC_QUICKSEARCH_ALT` (`lang.rc:1956`): *Quick search finds text &anywhere in the name and shows only the matching items*. The id is a free number in `lang.rh` next to 305/306. The page's controls below move 12 units down; the template grows 231 → 243.
- It takes effect at the next search (FR-029). Switching it off during a search ends that search.

With the option off, every changed path takes its 0.1.10 branch: prefix
matching, nothing hidden, no tint, `CancelUI` ends the search (SC-008).

**Constitution II.** The default-on is the maintainer's documented exception
(spec *Constitution note*), justified in the plan's Complexity Tracking.

**New strings.** Three: the checkbox, the directory-line format, and its
information-line variant if it differs. Use free slots of an existing bundle;
the two-stage `.slt` refresh is owed before `build.cmd full` (Standing rule
084). The help pages `help/src/hh/salamand/basicwork_qsearch.htm` and
`configuration_panels.htm` are updated.

## R9. Measurement plan (measure first)

Before the fix, on the Debug build, the GUI probe records the 0.1.10
baseline on the fixture (quickstart V1). This is also SC-005 and SC-008's
reference:

- focus after each `WM_CHAR`;
- that `chat` is refused when nothing starts with `c`;
- that `/chat` finds `2024_chatbot`;
- that F5 after a search copies the whole selection.

**Observable for "what is visible".** Run select-all, then copy to the other
panel's fixture folder: the copied set **is** the visible set. Copying a
selection that includes hidden items checks FR-019 and SC-007 on disk.

Screenshots (`PrintWindow`, as in `specs/081-*/probe/render_diff.ps1`) cover
the tint per scheme and view mode. The person check of SC-006 is owed to the
maintainer: colours on a real screen.

**Performance.** Fixtures of 10,000 and 100,000 files on a local disk; the
time from posting `WM_CHAR` to the list box's next paint, measured with a
probe-only timestamp in `TRACE` (Debug).
