# Fix log - 376-qs-enter-no-flash

Backlog item `opening-a-folder-found-by-quick-search-briefly-shows-the`: opening a folder found
by quick search briefly shows the whole parent folder.

## Measurement at HEAD (d4fb03e7, before any change)

Code trace (user action -> site):

- Enter in the list box while searching -> `CFilesWindow::Execute(index)` (`src/fileswn2.cpp`);
  `CancelPanelsUI` does not end a 244 search (`CancelUI` ends only the 0.1.10 mode).
- `Execute`: `QuickSearchMode && QFMode && QFActive && index < Dirs->Count` -> map the index to
  the full listing -> `EndQuickSearch()` -> `QFEndView(TRUE)` -> `QFRestoreArrays()` +
  `RefreshListBox(-1, -1, FocusedIndex, TRUE, FALSE)` + `QFUpdateIndication()`.
- `RefreshListBox` ends with `ListBox->SetItemsCount(...)` (scroll bars), `PaintHeaderLine()`,
  `UpdateWindow(scroll bars)` and **`ListBox->PaintAllItems(NULL, 0)`**: it draws the whole
  parent listing synchronously into the window - it does not only invalidate (the item's
  Evidence suspected a stray paint message; that is not the mechanism).
- Only then `ChangePathToDisk(HWindow, fullName, -1, NULL, &noChange, FALSE)` reads the new
  folder and its own `RefreshListBox` draws the new listing. Everything between the two drawings
  (read, sort, layout of the new listing) keeps the parent picture on screen. The flash is
  therefore deterministic; a person sees it only when that takes longer than a screen refresh.

Probe `probe/qs376_probe.ps1` (written for this item; hidden desktop; registry backed up and
restored, identical hash): left panel on `%TEMP%\tc376\left` (folders aaa_one, big, ccc_three,
ddd_four, eee_five; `big` holds 30,000 empty files), Detailed view. References: type `big` + Esc
(the whole parent folder, cursor on `big` = the picture of the flash) and type `big` again (the
filtered view). Then Enter is posted to the list box and the list box pixels are sampled from the
probe process (BitBlt from the window DC) every ~6 ms for 4 s; each sample is classified FILT /
PARENT / NEW / OTHER.

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\376-qs-enter-no-flash\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

Result before (`probe/result_before.txt`, frame `probe/before_flash.png`): ROWS 15, FAIL 3 -
FLASH fails in 3 of 3 rounds: `FILT x1, PARENT x39 @7-303ms, NEW x573 @307-3996ms` (and 38 / 38
in rounds 2 and 3). CTRL (classifier sees FULL as PARENT, FILT as FILT, settled picture as NEW),
LOC (panel in `big`), BACK (Backspace -> parent, cursor on `big`) and END pass.

## Decisions

- Scope: the "open the item" action (`Execute`) only - Enter, double click and Ctrl+PageDown
  share it. Other path changes during a search (`QFEndAtPathChange` sites: Alt+Left history,
  drive menu, Change Directory, hot paths, ...) go through `EndQuickSearch` too and may draw the
  parent the same way; outside the item -> Inbox item.

## Analyze (speckit-analyze)

- Round 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (FR-004 check implicit) and C2 (SC-003 no task) fixed
  in T007; LOW U1 (a paint during the read is not driven - covered by design: the layout-only
  mode sets the list box's item count, top index and offset for the whole listing, so any paint
  draws a consistent whole listing) and U2 (double click / Ctrl+PageDown not driven - they reach
  the same `Execute`) accepted here.
- Round 2 (after the fix of C1/C2): 0 CRITICAL / HIGH / MEDIUM; coverage 8/8.

## Implementation

- `RefreshListBox(..., BOOL paint = TRUE)` (`src/fileswn2.cpp`): `paint == FALSE` lays out as
  before and ends with `ListBox->SetItemsCount(count, x, top, TRUE)` only - no scroll bars, no
  boundary correction (it scrolls and draws), no header, no items. `paint == TRUE` clears
  `QFPaintDeferred` and draws as before.
- `EndQuickSearch(BOOL deferPaint = FALSE)` -> `QFEndView(TRUE, deferPaint)`; with a filtered view
  and `deferPaint` the full listing is laid out without drawing, `QFPaintDeferred = TRUE`, and
  `QFUpdateIndication` is left to `QFFinishDeferredPaint()` (`src/fileswn0.cpp`), which draws the
  laid-out listing if nothing drew the panel since and always updates the indication.
- `CFilesWindow::Execute`: a scope guard (`CQFDeferredPaint`) armed where the filtered view ends;
  its destructor calls `QFFinishDeferredPaint()` on every return.
- `QFPaintDeferred` member (`src/fileswnd.h`), initialised in the constructor (`src/fileswn1.cpp`).
- Callers of `RefreshListBox` / `EndQuickSearch` unchanged (trailing defaults keep the old
  behaviour). clang-format on the four files reformatted unrelated, previously unformatted lines
  of `fileswnd.h` and one line of `fileswn2.cpp`; those hunks were reverted - only the feature's
  lines changed.
- Accepted difference (research R2): the remembered top index for the return through `..` is
  `PredictTopIndex`'s value without the boundary correction; the return's own `RefreshListBox`
  applies the same correction, so the user lands on the same page (BACK row).

## Measurements after (Debug x64, hidden desktop, registry restored identical every run)

| Run | Rows | FLASH (PARENT samples per round) | NEW starts (ms) |
|---|---|---|---|
| before (`result_before.txt`) | 15, FAIL 3 | 39 / 38 / 38 | 307 / 308 / 309 |
| before, extended probe 1 round (`result_before_ext.txt`) | 9, FAIL 1 | 36 | 306 |
| before, timing (`result_before_timing.txt`) | 19, FAIL 3 | 38 / 35 / 38 | 309 / 306 / 316 |
| after (`result_after.txt`) | 19, FAIL 0 | 0 / 0 / 0 | 358 / 324 / 324 |
| after, timing (`result_after_timing.txt`) | 19, FAIL 0 | 0 / 0 / 0 | 345 / 315 / 312 |
| after, timing 6 rounds (`result_after_timing2.txt`) | 34, FAIL 0 | 0 x 6 | 298 / 304 / 301 / 315 / 312 / 306 |

- FLASH after: `FILT x38-55 @0-~300ms, NEW ...` - the filtered view stays until the new listing
  is drawn (one OTHER sample = a picture taken in the middle of that drawing).
- SC-003: the first two after-runs started right after the maintainer closed their instances
  (machine busy); the 6-round run on a quiet machine gives mean 306 ms against 309 ms before -
  no slowdown.
- FR-004: the settled class is NEW in every round (CTRL row: >= 70 % normal background, < 5 %
  tint) - the search ended, the panel is untinted.
- DENY (listing denied by an ACE; access-denied path re-lists and draws) and GONE (folder deleted
  before Enter; `ChangePathToDisk` fails, the guard draws the parent): PASS before and after - the
  failure paths end with the whole parent folder drawn, untinted, panel in the parent.
- Feature 244 probe (`result_qs244.txt`, `-Expect new -FilterOption 1`): 45 rows, FAIL 0.
- saltests: 30,237 checks, 0 failed. Encoding guard: TOTAL 0.

## Interruption

- Between the baseline and the after-run the maintainer started the installed program and, from
  it, the Debug build: the link failed (LNK1168, exe in use) and probes were not started while
  their instances shared the registry key. Waited until both had exited; nothing was killed.

## Inbox

- `leaving-a-folder-by-other-ways-during-quick-search-briefly` (measure:376): the other path
  changes during a search (`QFEndAtPathChange`: drive menu, history, Change Directory, hot path,
  directory line) still draw the whole folder first - code reading, not measured.
