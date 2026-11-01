# Research - 376-qs-enter-no-flash

## R1 - What draws the parent folder

- **Finding**: `CFilesWindow::RefreshListBox` (`src/fileswn2.cpp`) lays the listing out and then
  draws it itself: `ListBox->SetItemsCount(..., FALSE)` (scroll bars via `SetupScrollBars`,
  boundary correction via `CheckAndCorrectBoundaries`, which scrolls and draws when it corrects),
  `PaintHeaderLine()`, `UpdateWindow()` of the scroll bars and `ListBox->PaintAllItems(NULL, 0)`.
  `QFEndView(TRUE)` calls it for the whole listing; `Execute` calls `EndQuickSearch()` before
  `ChangePathToDisk`. So the parent is drawn every time, synchronously - the item's suspicion of
  a paint message processed during the read is not the mechanism.
- **Consequence**: holding back paint messages (validating, `WM_SETREDRAW`) would not help or
  would be fragile (`WM_SETREDRAW` hides the window for a private DC; the scroll bars and the
  header are separate windows). The drawing has to be skipped where it is made.

## R2 - What the path change needs from the ended search

- `Execute` remembers `ListBox->GetTopIndex()` (pushed to `TopIndexMem` for the return through
  `..`) and `GetCaretIndex()` (restored when the folder is access-denied) after the search ended.
  `ChangePathToDisk` records the Back history (`RefreshPathHistoryData`) from the panel's top
  index and focus. Standing rule 244: `Dirs`/`Files` must be the full listing before a path change
  (`ReleaseListing`, `ReadDirectory` treat a filtered view as an error).
- **Decision**: keep the order (search ends, full listing back, layout computed for the whole
  listing with the opened folder visible) and drop only the drawing: `RefreshListBox` gets a
  trailing `BOOL paint = TRUE`; with `FALSE` it computes the column widths, the item size, the
  focus and the top index exactly as before and sets the list box's item count, top index and
  x offset (`SetItemsCount(..., disableSBUpdate = TRUE)`), but does not update the scroll bars,
  does not run the boundary correction (it draws) and draws neither the header nor the items.
- **Difference accepted**: the remembered top index is `PredictTopIndex`'s value without the
  boundary correction. The correction only pulls a top index that leaves empty rows at the end
  back to the last full page; the return through `..` passes it to `RefreshListBox` again, whose
  `SetItemsCount` runs the same correction - the user lands on the same page.

## R3 - Drawing the parent when the folder is not opened

- Paths of `Execute` after the search ended that do not lay out a new listing: the index check
  after the mapping, an over-long name (`IDS_TOOLONGNAME`), `ChangePathToDisk` failing with
  `noChange` (path unchanged, nothing re-listed), the archive and plug-in-FS branches when their
  change fails without a refresh. Each must still draw the whole parent once.
- **Decision**: a flag `QFPaintDeferred` on the panel, set by the layout-only end, cleared by
  every drawing `RefreshListBox` (any later full drawing replaces the owed one). `Execute` arms a
  scope guard right where it ends the search; on every return the guard calls
  `QFFinishDeferredPaint()`: when the flag is still set it draws the whole listing as laid out
  (`RefreshListBox(-1, current top index, FocusedIndex, TRUE, FALSE)`), and in every case it
  calls `QFUpdateIndication()` (tint and the search text in the directory line / information
  line follow the ended search; when the path change already rewrote the directory line it does
  nothing).
- **Alternative rejected**: calling the repaint explicitly at each return - eight returns in three
  branches, easy to miss in later edits.

## R4 - Scope

- Enter, double click and Ctrl+PageDown on a folder all reach `CFilesWindow::Execute`; one site.
- Other ends of a search at a path change (`QFEndAtPathChange`: history, drive menu, Change
  Directory, hot paths, `ChangePathToDisk` itself) still end with a drawing `EndQuickSearch()`
  and may draw the parent the same way. Outside the item (it names Enter on a folder) - an Inbox
  item (`measure:376`).

## R5 - Measurement method

- Hidden-desktop probe sampling the list box with `BitBlt` from its window DC from the probe
  process while the program is busy reading a 30,000-file folder (~300 ms). Works on the hidden
  desktop (controls pass: references classify correctly). Before: 38-39 PARENT samples per round.
- Failure rows added for R3: a folder whose listing is denied to the user (access denied; the
  panel stays and re-lists) and a folder deleted just before Enter (the path change fails); both
  must end with the whole parent folder drawn, untinted.
