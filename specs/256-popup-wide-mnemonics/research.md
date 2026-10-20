# Research: 256

## R1 - what the popup loop receives

- Decision: `PeekMessageW` + `DispatchMessageW` in `CMenuPopup::TrackInternal` / `DoDispatchMessage`.
- Rationale: measured (`probe/peek_mechanism.ps1`, ACP 1250): a posted UTF-16 `WM_CHAR` comes through
  `PeekMessageA` as `3F` (U+0416, U+4E2D) and `63` (U+010D - through the keyboard layout's code page),
  through `PeekMessageW` exact, for ANSI and Unicode windows alike. `DispatchMessageW` to a code-page
  window converts the character for it (the main loop and the Find loop do this since 093).
- Alternatives: keep the A loop and convert with the keyboard layout's code page
  (`GetKeyboardLayout` -> `LOCALE_IDEFAULTANSICODEPAGE`) - still loses characters outside it and DBCS
  pairs; rejected.
- The thread hook (`WH_CALLWNDPROC`) sees sent messages only - unaffected. The delayed message of
  `Track` is a mouse button message - no character, `PostMessage` unchanged.

## R2 - WM_MENUCHAR

- Decision: `SendMessageW` (review 1: `SendMessageW` to a Unicode owner, `SendMessageA` to a code-page one -
  wParam verbatim) `(HParent, WM_MENUCHAR, MAKEWPARAM(key, MF_POPUP), (LPARAM)hMenu)`; answer
  `MNC_SELECT` -> select, `MNC_EXECUTE` -> select and `OnKeyReturn`, only for an index of an existing
  item that is not a separator and is visible at the skill level; anything else ignored.
- Rationale: the message's contract (LOWORD character, HIWORD MF_POPUP / MF_SYSMENU; answers
  MNC_IGNORE 0, MNC_CLOSE 1, MNC_EXECUTE 2, MNC_SELECT 3). The template HMENU's item positions are the
  popup's item indexes (`LoadFromHandle` copies 1:1). Measured (`probe/menuchar_def.ps1`):
  `DefWindowProcW` / `DefWindowProcA` answer 0 (MNC_IGNORE) to every form - an owner that does not
  handle the message cannot make the popup run an item. The old code trusted the index of
  `MNC_SELECT` without a bounds check; the rule checks it now.
- Owners (superseded by review 1, S1 - the popup now sends in the owner's kind, wParam verbatim): the panel's list (`CFilesBox`, Unicode class since 004) gets the UTF-16 character; the main
  window and the Find window are code-page windows - Windows converts the character to their code page
  and they forward it to `IContextMenu3::HandleMenuMsg2` unchanged (a limit for non-ASCII hot keys of
  shell extensions in the drive menu, the New menu and the Find window's context menu; ASCII is exact).
- Alternatives: converting back in the code-page owners - changes their forwarding of Windows' own
  menus too; rejected (conservative, clarification 3).

## R3 - the Find window's hidden hot keys

- Decision: `SalDlgHotKeyW(text)` (the UTF-16 unit after a single '&', "&&" skipped; 0 when none or a
  surrogate); on `WM_SYSKEYDOWN` `SalDlgHotKeyVkMatch` (an ASCII letter or digit hot key, upper case,
  equals the virtual key - the old behaviour for every shipped language); on `WM_SYSCHAR`
  `SalDlgHotKeyCharMatch` (`CharUpperW` of both). Same modifier test (Alt, no Ctrl, no Shift) for both.
  Text through `GetDlgItemTextW` (500 units, as before 500 bytes).
- Rationale: `WM_SYSCHAR` carries the character the dialog manager matches mnemonics with; the Find
  loop is wide (093), so `wParam` is UTF-16; `ManageHiddenShortcuts` runs before `IsDialogMessageW`,
  so the controls are shown before the dialog manager looks for the mnemonic.
- Alternatives: `MapVirtualKeyW(vk, MAPVK_VK_TO_CHAR)` on key-down - the unshifted character of the
  layout, not what the dialog manager uses; rejected.
