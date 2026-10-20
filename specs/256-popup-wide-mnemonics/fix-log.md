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

## Work

- `src/common/salmenuhotkey.h`: `SalMenuCharAnswer` (owner's answer -> MNC_SELECT / MNC_EXECUTE for an
  existing index, else 0), `SalDlgHotKeyW` (UTF-16 hot key, "&&" literal, surrogates never),
  `SalDlgHotKeyVkMatch` (ASCII letter / digit vs virtual key - the old comparison, for these only),
  `SalDlgHotKeyCharMatch` (characters, case ignored). saltests in `TestMenuHotKey236`.
- `src/menu2.cpp`: `CMenuPopup::TrackInternal` `PeekMessageW`; `DoDispatchMessage` passes
  `(WCHAR)wParam` of `WM_CHAR` / `WM_SYSCHAR` to `OnChar(WCHAR)` and ends with `DispatchMessageW`.
  `OnChar` sends `SendMessageW(HParent, WM_MENUCHAR, MAKEWPARAM(key, MF_POPUP), hMenu)` (review 1: in
  the owner's kind, W or A) and carries out
  select / execute for a non-separator item visible at the skill level (execute = `OnKeyReturn`).
- `src/menu.h`: `OnChar(WCHAR, ...)`.
- `src/finddlg1.cpp`: `GetControlHotKey` (now static) reads `GetDlgItemTextW` -> `SalDlgHotKeyW`;
  `ManageHiddenShortcuts` handles `WM_SYSKEYDOWN` (by virtual key, as before) and `WM_SYSCHAR` (by
  character; the Find loop is wide since 093 and runs this before `IsDialogMessageW`).
- `probe/menuchar_def.ps1`: `DefWindowProcW` / `DefWindowProcA` answer 0 (MNC_IGNORE) to WM_MENUCHAR in
  every form tried - an owner that does not handle it cannot make the popup execute an item.

## Checks

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED, no warnings in the changed files (recompiled on purpose).
- saltests: 24,474 checks, 0 failed (main: the 236 test without the 256 checks).
- clang-format: the changed lines conform (pre-existing differences elsewhere in the files untouched).

## Probe `pm256_probe.ps1` (hidden desktop)

| Row | before (main 084744e0 sources, rebuilt) | after |
|---|---|---|
| ZH typed U+0416 | FAIL - ran the "&?" item (QM) | PASS - ran ZH |
| CC typed U+010D | FAIL - no User Menu item ran; the popup took 'c' (the layout's code-page conversion) and opened the Configuration dialog (an item whose assigned hot key is C); END FAIL (that dialog stayed open) | PASS - ran CC |
| AS typed 'q' | PASS | PASS |
| registry | restored, identical | restored, identical |

Before: PASS 3, FAIL 3 (`probe/result_before.txt`; one 70,869-character END line shortened for the
record); after: PASS 6, FAIL 0 (`probe/result_after.txt`). The before run was made by checking out
main's five source files on the branch, building, running, and checking the branch's files out again.

## Not driven (owed to a person)

- WM_MENUCHAR with a real owner-drawn shell extension (TortoiseSVN context menu: type a hot key of
  one of its items) - no such extension on the hidden desktop.
- The Find window's hidden hot keys: the check reads the real Alt state (`GetKeyState`), which posted
  messages do not set; and every shipped language has ASCII hot keys there (the virtual-key route,
  unchanged). Pure rules in saltests.
- Real keyboard / IME: a DBCS system (Japanese, IME full-width hot key in a popup), a UTF-8 (beta)
  system, a Russian keyboard layout on a Czech Windows with a User Menu item "&Ж...".

## Review

### Review 1 (refute-first, independent agent)

- **MUST M1, taken**: `CFilesBox::WindowProc` (`src/filesbx1.cpp`, `case WM_MENUCHAR`) returned an
  uninitialized `LRESULT` from `HandleMenuMsg2` (the shell leaves it untouched: `S_OK` for a menu
  that is not its own - the background menu and the New submenu are asked through the file's
  `ContextMenu` - `E_FAIL` for none). With MNC_EXECUTE now carried out, Release stack garbage with a
  high word 2 could run an item. Now: all three results there start at 0 and a failed
  `HandleMenuMsg2` answers 0. In addition the popup carries out an answer only when it was built from
  a Windows menu (`hMenu != NULL`; a template-less popup has no item an owner could name).
- **SHOULD S1, taken**: `SendMessageW` to a code-page owner (the main window, the Find window) packs
  the low and high byte of wParam as two code-page characters - measured
  (`probe/menuchar_kinds.ps1`): `00100071` arrived as `00001071`, `0010010D` as `000010E8`,
  `00100416` as `0000103F`; a send of the owner's own kind arrives verbatim. Now the popup sends with
  `SendMessageW` to a Unicode owner and `SendMessageA` to a code-page one, so every owner forwards
  `MAKEWPARAM(<UTF-16 unit>, MF_POPUP)` to `IContextMenu3::HandleMenuMsg2` (the research's limit for
  code-page owners is gone). The comment that said otherwise is replaced.
- **SHOULD S2, recorded** (owner-side, outside the item): the panel asks `ContextMenu` also for the
  background / New menus, the Find window's `DialogProc` loses the answer (no `DWLP_MSGRESULT`) ->
  Inbox `menuchar-owner-routing` (review:256).
- **NOTE, taken**: `probe/menuchar_def.ps1` listed `0x00102000 + 0x20` (PowerShell: array + 0x20);
  explicit values now (`00100020`, `00102020`, `00100416` added): `DefWindowProcW` / `A` answer 0 to all.
- NOTE: the execute path and the Find window's `WM_SYSCHAR` route are not driven end to end (recorded
  above as owed to a person).
- Refuted by the reviewer: char / IME / DBCS messages through the wide loop, the re-posted delayed
  message (mouse only), plug-in owners (only codeview / mdview handle WM_MENUCHAR, without core
  popups), double expansion in Find, the `OnChar` signature (non-virtual, protected, one caller).

After the fixes: BUILD SUCCEEDED (no warnings), saltests 24,474 / 0 failed, encoding TOTAL 0,
clang-format clean on the changed lines, probe `result_after_review1.txt` PASS 6 / FAIL 0, registry
identical.

### Review 2 (fresh, with review 1's findings)

No MUST, no SHOULD. Verified review 1's fixes (every WM_MENUCHAR answerer starts its result at 0;
plug-in FS handlers write 0 or return FALSE; the execute path cannot run a separator, a hidden or a
grayed item); re-measured the scripts and saltests (24,474 / 0). NOTEs: N1 (a code-page owner now
gets a UTF-16 unit - stated in the spec's assumption), N2 (the Inbox item's "answers nothing" was
measured only with the shell's handler - softened there), N4 (stale "always SendMessageW" in
research / plan / fix-log - corrected), taken; N3 (four call sites ignore the HRESULT of
`HandleMenuMsg2`, safe as the result starts at 0) and N5 (the owner / execute path not driven end to
end; closing documents) recorded - N5's documents are written at closing.
