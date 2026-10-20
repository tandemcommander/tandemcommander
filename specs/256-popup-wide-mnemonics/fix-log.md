# Fix log: 256 - popup menu hot keys and the Find window's hidden hot keys compare whole characters

Backlog item `menu-popup-loop-wide-mnemonics` (leftover of 236 / 237).

## Measured before (main at 084744e0)

- Build: `.\build.cmd` -> BUILD SUCCEEDED (HEAD, Debug x64).
- `probe/peek_mechanism.ps1` (standalone, no product; ACP 1250): a `WM_CHAR` posted with
  `PostMessageW` and taken with `PeekMessageA` (what `CMenuPopup::TrackInternal` does) arrives as
  `3F` for U+0416 and U+4E2D, `63` ('c') for U+010D, `71` for 'q' - for ANSI and Unicode windows
  alike; with `PeekMessageW` as `0416`, `4E2D`, `010D`, `0071`. The code-page conversion goes through
  the keyboard layout's code page (U+010D is 0xE8 in cp1250, yet came as 'c').
- Consequence by reading: `OnChar((char)wParam)` -> `SalACPCharToW('?')` = '?' -> an item "&?"
  matches a typed U+0416 (the wrong item runs); a DBCS character arrives as lead + trail bytes.
- `probe/pm256_probe.ps1` (User Menu "&Ж", "&Č", "&Q", "&?"; posts the character to the popup):
  **could not run before** - the maintainer's installed instance (`C:\Program Files\Tandem
  Commander`) was running; the probe refuses then (exit 99), and the run does not touch that instance.
- (b) by reading: `SendMessage(HParent, WM_MENUCHAR, MF_POPUP, hMenu)` - LOWORD 0x10, HIWORD 0;
  only `MNC_SELECT` honoured.
- (c) by reading: `GetControlHotKey` (`GetDlgItemTextA`, `UpperCase[byte]`) vs the `WM_SYSKEYDOWN`
  VK in `CFindDialog::ManageHiddenShortcuts`; "&&" not skipped. Shipped languages: ASCII hot keys on
  the five controls (2513-2516, 2520) - cs O e R C g, de E X K z g, fr C x b s l, nl I X K C R, es u X
  D P g, hu z X t l b, ro C X b i p, sk O e R C g; ru / uk (off): Cyrillic.

## Decisions

- The menu bar's own loop (`menubar.cpp`, F10 then a letter) is not named by the item: unchanged, a
  new Inbox item.

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH. Accepted: E1 (MEDIUM) - SC-001 rests on a probe that refuses
while another instance runs; NOT DRIVEN rows are recorded as such, the rules' saltests and the
mechanism scripts carry the claim. E2 / E3 (LOW): other keys unchanged - checked by reading and the
review; the closing documents are the run's step 8.
