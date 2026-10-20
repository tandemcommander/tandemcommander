# Closing report - 256-popup-wide-mnemonics
Backlog item: menu-popup-loop-wide-mnemonics - Popup menu mnemonics fail on DBCS / UTF-8 code pages; dialog hot keys by byte
Outcome: closed

## What changed

- `src/menu2.cpp`, `src/menu.h`: the popup loop (`CMenuPopup::TrackInternal`) takes messages with
  `PeekMessageW` and dispatches with `DispatchMessageW`; `OnChar(WCHAR)` gets the UTF-16 unit (no
  `SalACPCharToW`). When no item matches, `WM_MENUCHAR` carries `MAKEWPARAM(key, MF_POPUP)`, sent in
  the owner's own kind (W to a Unicode window, A to a code-page one - wParam verbatim); the owner's
  MNC_SELECT selects, MNC_EXECUTE selects and chooses, only for an existing, non-separator item
  visible at the skill level of a popup built from a Windows menu.
- `src/filesbx1.cpp`: the panel's `WM_MENUCHAR` answers start at 0 and a failed `HandleMenuMsg2`
  answers 0 (review 1 MUST: an uninitialized result could now have run an item).
- `src/finddlg1.cpp`: the Find window's hidden option hot keys are read as UTF-16 ("&&" literal) and
  matched by virtual key on `WM_SYSKEYDOWN` (ASCII letters / digits, as before) and by character on
  `WM_SYSCHAR`.
- `src/common/salmenuhotkey.h`: `SalMenuCharAnswer`, `SalDlgHotKeyW`, `SalDlgHotKeyVkMatch`,
  `SalDlgHotKeyCharMatch`; saltests in `TestMenuHotKey236`.
- No plug-in interface, UI string, stored data or translation change.

## Measurements (before / after, commands)

- `probe/peek_mechanism.ps1` (ACP 1250): posted UTF-16 `WM_CHAR` through `PeekMessageA` -> `3F`
  (U+0416, U+4E2D), `63` (U+010D); through `PeekMessageW` exact.
- `probe/menuchar_def.ps1`: `DefWindowProcW` / `A` answer 0 to every `WM_MENUCHAR` form.
- `probe/menuchar_kinds.ps1`: a send of the owner's kind arrives verbatim; `SendMessageW` to a
  code-page window turns `00100071` into `00001071` (review 1, S1).
- `probe/pm256_probe.ps1` on the hidden desktop (User Menu "&Ж", "&Č", "&Q", "&?"; one wide
  `WM_CHAR` posted to the popup): before (main 084744e0 sources) PASS 3 / FAIL 3 - U+0416 ran the "&?"
  item, U+010D opened the Configuration item (arrived as 'c'); after PASS 6 / FAIL 0
  (`result_after.txt`, again after review 1 `result_after_review1.txt`); registry restored and
  identical every time.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED, no warnings in the changed files.
- saltests: 24,474 checks, 0 failed.
- Probe: 6 / 0 after (3 FAIL before).
- clang-format: the changed lines conform.

## Reviews (findings and what was done)

- Review 1: MUST M1 (uninitialized `LRESULT` in `CFilesBox` + new MNC_EXECUTE) - fixed, plus the
  answer is honoured only for a popup built from a Windows menu; SHOULD S1 (W send scrambles wParam
  for code-page owners) - fixed (send in the owner's kind, measured); SHOULD S2 (owner-side routing)
  - Inbox `menuchar-owner-routing`; NOTE (script list bug) - fixed.
- Review 2: no MUST / SHOULD; NOTEs N1, N2, N4 taken (spec assumption, Inbox wording, stale docs);
  N3, N5 recorded.

## Owed to a person (with the new person-step items)

- `popup-hot-keys-real-keyboard-256`: a Russian layout on a Czech Windows, a DBCS (Japanese) and a
  UTF-8 (beta) system with the IME, TortoiseSVN's owner-drawn items, the unchanged navigation keys,
  the Find window's hidden hot keys with a real Alt key.

## New Inbox items (slug - title)

- `menubar-loop-wide-mnemonics` - Menu bar hot keys typed after F10 arrive as code-page bytes
- `menuchar-owner-routing` - Shell extensions in the panel background menu and the Find window never answer typed hot keys
- `popup-hot-keys-real-keyboard-256` - Popup menu hot keys by hand: Russian layout, DBCS and UTF-8 systems, TortoiseSVN (person step)
