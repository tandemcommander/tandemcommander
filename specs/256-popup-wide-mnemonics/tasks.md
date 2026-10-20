# Tasks: popup menu hot keys and the Find window's hidden hot keys compare whole characters

**Input**: `specs/256-popup-wide-mnemonics/` (spec.md, plan.md, research.md, quickstart.md)
**Tests**: saltests for the pure rules (project rule: pure decisions in `src/common/` with saltests);
the hidden-desktop probe for US1.

## Phase 1: Setup

- [X] T001 Record the measurements before (done in step 3) and the decisions in specs/256-popup-wide-mnemonics/fix-log.md

## Phase 2: Foundational (pure rules)

- [X] T002 Add `SalMenuCharAnswer`, `SalDlgHotKeyW`, `SalDlgHotKeyVkMatch`, `SalDlgHotKeyCharMatch` to src/common/salmenuhotkey.h (header comment: feature 256)
- [X] T003 Add saltests checks of the four rules (valid / out-of-range / negative index, MNC_IGNORE / MNC_CLOSE / garbage answers; "&&", trailing '&', no '&', surrogate, ASCII letter / digit vs VK, Cyrillic / Czech case-insensitive characters) in src/saltests/saltests.cpp

## Phase 3: User Story 1 - a popup item is chosen by the character typed (P1)

**Independent test**: `probe/pm256_probe.ps1` rows ZH, CC, AS.

- [X] T004 [US1] `CMenuPopup::TrackInternal`: `PeekMessageW`; `DoDispatchMessage`: `WM_CHAR` / `WM_SYSCHAR` -> `OnChar((WCHAR)wParam, ...)`, the final dispatch `DispatchMessageW` in src/menu2.cpp
- [X] T005 [US1] `OnChar(WCHAR key, ...)` without `SalACPCharToW` in src/menu2.cpp and its declaration in src/menu.h

## Phase 4: User Story 2 - owner-drawn items answer the typed character (P2)

- [X] T006 [US2] `OnChar`: `SendMessageW(HParent, WM_MENUCHAR, MAKEWPARAM(key, MF_POPUP), hMenu)`; carry out the answer through `SalMenuCharAnswer` - select, or select + `OnKeyReturn` - only for a non-separator item visible at the skill level, in src/menu2.cpp

## Phase 5: User Story 3 - the Find window's hidden hot keys compare characters (P3)

- [X] T007 [US3] `GetControlHotKey` -> wide text (`GetDlgItemTextW`) and `SalDlgHotKeyW`; `ManageHiddenShortcuts`: `WM_SYSKEYDOWN` by `SalDlgHotKeyVkMatch`, `WM_SYSCHAR` by `SalDlgHotKeyCharMatch`, same modifier test, in src/finddlg1.cpp (the commented-out copy in src/dialogs3.cpp stays as it is)

## Phase 6: Polish & verification

- [X] T008 `python tools/check_encoding.py --strict` -> TOTAL 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [X] T009 Probe `pm256_probe.ps1` after (and before on the main build, when no other instance runs); results into specs/256-popup-wide-mnemonics/probe/ and fix-log.md
- [X] T010 New Inbox item for the menu bar's own code-page loop (`menubar.cpp`), source measure:256
- [X] T011 Record what is owed to a person (real keyboard, IME / DBCS / UTF-8 systems, TortoiseSVN, Find with a Cyrillic language) in fix-log.md

## Dependencies

T002 -> T003, T006, T007; T004 -> T005 -> T006; T008 after T003-T007; T009 after T008.
Parallel: T003 and T004/T005 (different files); T007 with T004-T006 (different files).

## Implementation strategy

MVP = US1 (T004-T005); US2 and US3 are independent increments on the same rules header.
