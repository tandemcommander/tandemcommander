---
title: Automation: non-ASCII texts and captions garbled, persistent value names may collide
type: bug
status: parked
severity: 1
area: other-plugins
source: review:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: [automation-script-folder-list-code-page, registry-wide-deletevalue-and-key-names]
depends-on: []
reason: plug-in automation not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-11-01
---

# Automation: non-ASCII texts and captions garbled, persistent value names may collide

## Problem

Automation (not shipped: `plugins.cfg` automation=off) is built without `_UNICODE`, so `OLE2T(s)` is `OLE2A(s)` - a lenient UTF-16 to UTF-8 conversion (`WideCharToMultiByte(CP_UTF8, 0, …)`). Its results go where UTF-8 does not belong or where a lossy name hurts: (1) window captions of script GUI controls - `CreateWindowEx` here is the A function, so any non-ASCII caption a script sets before the window exists shows as mojibake (button, label, check box, text box, form title); the `InputBox` prompt goes through `OLE2A` as well; (2) persistent value names - `registry->DeleteValue` and the `REG_DWORD` `registry->SetValue` take `OLE2T(name)`, so two names that differ only in an unpaired surrogate both become U+FFFD and collide, while the `REG_SZ` path writes the exact name.

A second narrowing layer does the same through `_bstr_t`: its `operator const char*` converts with `CP_ACP` and best-fit, and the plug-in hands the result to text sinks that expect UTF-8 or show code page - the message box prompt and caption (`salamanderaut.cpp`, `MsgBox`), the error and question dialog titles and an error text from a variant (`salamanderaut.cpp`), `ProgressDialogAddText` (`progressaut.cpp`), and the script error source / description (`aututils.cpp`). Letters outside the code page become `?` or best-fit look-alikes there.

## Evidence

Found by the independent review of feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Review*, MUST 1), confirmed by reading at the branch's base 3e0da39c: `src/plugins/automation/strconv.h` (`#define OLE2T(s) OLE2A(s)` without `_UNICODE`), `src/plugins/automation/strconv.cpp` `OLE2A::operator const char*` (three lenient conversions - reported by `python tools/check_encoding.py --plugins`, `lossy-lenient-at-intake`), callers `guibutton.cpp`, `guilabel.cpp`, `guichkbox.cpp`, `guitxtbox.cpp`, `guiform.cpp` (`CreateWindowEx` captions), `guicomponent.cpp` (text set before creation), `inputbox.h` (prompt), `persistence.cpp` (`DeleteValue`, `SetValue` `REG_DWORD`). Feature 255 had marked these lines "a question text and a trace only", which is wrong.

## Expected

A script's GUI controls and the input box show non-ASCII captions and prompts correctly (wide window creation or `SetWindowTextW` with the UTF-16 text); persistent values are found, written and deleted by their exact names (WTF-8, `SplWToU8`); `check_encoding.py --plugins` no longer reports `automation/strconv.cpp`.

## Approach

Make `OLE2A` total and exact (`SplWToU8`, WTF-8) for names; create the GUI windows with `CreateWindowExW` from the BSTR directly; replace every `_bstr_t` → `const char*` narrowing that reaches a text sink by an exact UTF-8 conversion (`SplWToU8Alloc`) or a wide call (`grep -n _bstr_t src/plugins/automation`). The value-name part also needs `registry-wide-deletevalue-and-key-names` (the core facade's `DeleteValue` uses the A API).

## Notes

The plug-in is not shipped, hence severity 1; fix before enabling it. Same plug-in: `automation-script-folder-list-code-page`.

## Log

- 2026-11-01 — created (source review:379)
- 2026-11-01 — extended after review 2 of feature 379: the _bstr_t narrowing layer
- 2026-11-01 — approach extended after review 2 of feature 379
- 2026-11-01 — title after review 2 of feature 379
- 2026-11-01 — moved to Parked: plug-in automation not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-11-01
