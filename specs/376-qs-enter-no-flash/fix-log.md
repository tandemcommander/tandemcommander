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
