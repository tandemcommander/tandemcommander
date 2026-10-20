# Implementation Plan: popup menu hot keys and the Find window's hidden hot keys compare whole characters

**Branch**: `256-popup-wide-mnemonics` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/256-popup-wide-mnemonics/spec.md`

## Summary

(a) `CMenuPopup::TrackInternal` takes messages with `PeekMessageW` and `DoDispatchMessage` ends with
`DispatchMessageW`; `WM_CHAR` / `WM_SYSCHAR` reach `OnChar(WCHAR)` whole (the `SalACPCharToW`
conversion goes). (b) `OnChar` asks the owner with `WM_MENUCHAR`, `MAKEWPARAM(key, MF_POPUP)`, `hMenu` (review 1:
`SendMessageW` / `SendMessageA` by the owner's kind, so wParam arrives verbatim) and carries out `MNC_SELECT` / `MNC_EXECUTE` for a valid item
(pure rule `SalMenuCharAnswer` in `salmenuhotkey.h`). (c) `CFindDialog::ManageHiddenShortcuts`
reads the watched controls' text as UTF-16 and matches the hot key by virtual key (ASCII letters /
digits, as before) on `WM_SYSKEYDOWN` and by character on `WM_SYSCHAR` (pure rules
`SalDlgHotKeyW`, `SalDlgHotKeyVkMatch`, `SalDlgHotKeyCharMatch`). saltests for every rule.

## Technical Context

**Language/Version**: C++20, MSVC v143, core built as MBCS (`PeekMessage` = `PeekMessageA`)
**Primary Dependencies**: Win32 user32 only
**Storage**: N/A (nothing stored)
**Testing**: saltests (pure rules); hidden-desktop probe `probe/pm256_probe.ps1` (posted characters);
mechanism scripts `probe/peek_mechanism.ps1`, `probe/menuchar_def.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: N/A
**Constraints**: plug-in ABI unchanged (CMenuPopup's `OnChar` is not part of `CGUIMenuPopupAbstract`);
no UI strings
**Scale/Scope**: `src/menu2.cpp`, `src/menu.h`, `src/finddlg1.cpp`, `src/common/salmenuhotkey.h`,
`src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no new dependency, no build change. PASS
- II Backward compatibility: ASCII hot keys, navigation keys and every other message behave as before;
  config untouched. PASS
- III Incremental modernization: one loop and one check, the same pattern as 093's main / Find loops. PASS
- IV Windows commitment: Win32 W APIs. PASS
- V Plug-in architecture: no ABI change; plug-ins that open a core popup with their window as owner
  now get `WM_MENUCHAR` with the documented wParam (before: 0x10, which no handler matched). PASS
- VI UI consistency: no UI change. PASS

## Project Structure

```text
specs/256-popup-wide-mnemonics/
  spec.md  plan.md  research.md  quickstart.md  tasks.md  fix-log.md
  probe/   pm256_probe.ps1  peek_mechanism.ps1  menuchar_def.ps1  result_*.txt
src/
  menu2.cpp, menu.h          popup loop, OnChar, WM_MENUCHAR
  finddlg1.cpp               GetControlHotKey -> wide, ManageHiddenShortcuts
  common/salmenuhotkey.h     SalMenuCharAnswer, SalDlgHotKeyW, SalDlgHotKeyVkMatch, SalDlgHotKeyCharMatch
  saltests/saltests.cpp      checks
```

**Structure Decision**: core only; the pure rules join 236/237's header (core-only, includes
`salunicode.h`).

## Complexity Tracking

None.
