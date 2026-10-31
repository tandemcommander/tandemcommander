# Research - 346 Shift+F6 in-place rename

## R1 Where the key is recognised

- **Decision**: in `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp`), directly after
  `Plugins.HandleKeyDown`, posting `WM_COMMAND CM_QUICKRENAMEINPLACE` to the main window.
- **Rationale**: plug-in hot keys are dispatched in that handler; the main-window accelerators
  (`IDA_MAINACCELS1/2`) run in the message loop *before* it. An accelerator row would silently take
  Shift+F6 from a user who had bound a plug-in command to it (Shift+F6 was free until now and
  `IsSalHotKey` accepted it). After the plug-in call, such a binding would keep its place; otherwise
  the panel opens the editor. **Measured during implementation**: an F-key plug-in binding never
  runs from the key - `CPlugins::QueryHotKey` upper-cases `wParam` through `UpperCase[]` (a
  character table), so VK_F6 = 0x75 = 'u' is looked up as 'U' (Shift+U is reserved, so Shift+F6
  reaches the panel's code; Ctrl+Shift+F6 sent past the accelerator ran Undelete's Ctrl+Shift+U in
  the probe). Pre-existing, outside this item: Inbox. The placement after the plug-ins stays: it is
  what a fix of that defect needs to keep a stored binding's precedence. Posting the command (as Shift+F10 posts `CM_CONTEXTMENU`) runs the same
  path as the menu, including the WM_COMMAND preamble that ends quick search / a running editor.
- **Alternatives**: accelerator row `VK_F6, CM_QUICKRENAMEINPLACE, VIRTKEY, SHIFT` - rejected
  (overrides existing user bindings); handling before the plug-ins - rejected for the same reason.

## R2 Plug-in hot key reservation

- **Decision**: `IsSalHotKey` returns TRUE for Shift+F6 (Plugins Manager and the settings import
  refuse it as a new binding, as all program keys); `IsSalHotKeyKeptAtLoad` returns TRUE for it
  so a binding stored before this feature is not cleared at load.
- **Rationale**: precedent of feature 312 (Ctrl+Shift+G). No plug-in declares a default Shift+F6
  panel hot key (grep of `src/plugins`: only CodeView's viewer-window accelerators use Shift+F6).

## R3 The label rectangle for a keyboard start

- **Decision**: `QuickRenameOnIndex(index)`: `SetCaretIndex(index, FALSE)` + `EnsureItemVisible`,
  then `ListBox->GetItemRect(index, &r)`; `ListBox->GetIndex(r.left + 1, r.top + 1, FALSE,
  &labelRect)` computes the label rectangle for every view mode (detailed, brief, icons,
  thumbnails, tiles - `GetIndex` fills `labelRect` from the cell even when the point misses the
  text); store `QuickRenameIndex`/`QuickRenameRect` (`AdjustQuickRenameRect` uses
  `QuickRenameRect` as the minimum size) and call `QuickRenameBegin`. The point is clamped into
  `FilesRect`.
- **Rationale**: identical geometry to the mouse start, which passes the `GetIndex` label
  rectangle of the clicked cell. The upstream comment ("sorting issue: Vista keeps items in place")
  concerns Tab-to-next-item, which stays out.

## R4 Menu string and id

- **Decision**: `IDS_MENU_FILES_RENAMEINPLACE` = 13019, a free slot in the string bundle of
  `IDS_MENU_FILES_RENAME` (13021) - no bundle renumbering (rule 084). Text
  `Rename in Place\tShift+F6`, no `&`: every letter of the words is already an access key in the
  Files menu (Q V L H E N C M I D R S A G T U P K W X F); precedent *Edit With\tCtrl+Shift+F4*.
  Command id `CM_QUICKRENAMEINPLACE` = 2954 (2954-2969 unused in `resource.rh2`).

## R5 Bottom toolbar

- **Decision**: unchanged. Its Shift row (`IDS_BTBTEXTS_S`) has no F6 button; the item asks for
  the menu and the keyboard help only. Changing that string would change an existing translated
  text in every language.

## R6 Pure rule

- **Decision**: `src/common/salrenamekey.h`: `SalIsRenameInPlaceKey(vk, ctrl, shift, alt)` and
  `SalIsRenameInPlaceHotKey(WORD hotKey)` (the `HOTKEYF_*` form used by `IsSalHotKey`), checked in
  `saltests` (Shift+F6 yes; F6, Ctrl+F6, Alt+F6, Ctrl+Shift+F6, Alt+Shift+F6, Shift+F5 no).
