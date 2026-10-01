# Implementation Plan: Unicode dialogs (encoding cluster B-1)

**Branch**: `093-unicode-dialogs` (from `092-name-identity-unicode`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary

Create the dialogs that take text as Unicode windows (`unicodeWnd = TRUE`,
the mechanism feature 015 used for Copy/Move), after fixing the three shared
things that would silently undo it: code-page subclasses on text fields, the
code-page fallback on buffer overflow, and the message loops. Then the
command line, and the 7-Zip password path.

## Technical Context

- C++ (MSVC v143), pure WinAPI; dialog library `src/common/winlib.*` (core)
  and `src/plugins/shared/winliblt.*` (compiled into each plug-in).
- No new dependency, no interface change (stays 107), no configuration
  version change, no translation change.
- Testing: saltests for pure helpers; a PowerShell GUI probe (own instance,
  registry key exported and restored) with three channels per field —
  `IsWindowUnicode`, prefill read back wide, characters posted one by one;
  the Win32 semantics probe `probe/B1Probe.cs` (from the research).

## Constitution Check

- Build reproducibility: unchanged.
- Backward compatibility: stored data untouched (FR-007); archives encrypted
  under the old password derivation stay openable (FR-008).
- Incremental modernization: per-dialog flag, in reviewed stages; each stage
  can be reverted alone.
- Plug-in architecture: no ABI change; winliblt gains an optional default-off
  parameter (source-level, every plug-in rebuilds as on any build).
- UI consistency: no visible change for code-page text.

Gate: passes.

## Stages (one commit each, each independently reviewed)

| Stage | Content | Evidence |
|---|---|---|
| **S0** prerequisites | (a) a `CWindow` attached to an existing control takes the control's kind (`IsWindowUnicode`) instead of forcing the code-page subclass — or an explicit parameter at the attach sites of text fields (`CComboboxEdit`, `CEditLBEdit`, key forwarders); (b) overflow in `CTransferInfo::EditLine` / `SalGetWindowTextU8` cuts UTF-8 at a whole character instead of the code-page re-read; (c) the main loop's `IsDialogMessage` becomes the wide one. No dialog converted yet. | saltests for the truncation helper; probe: existing W dialogs (Copy/Move) unchanged; B1Probe pins the Win32 semantics |
| **S1** modal path dialogs | `unicodeWnd TRUE` for Change Directory, Pack, Unpack, Select, filter, Convert, Make File List, compare arguments, Change Icon, Drive Information (label); the code-page reads on those dialogs (`BrowseCommand`, `BrowseDirCommand`, the `WM_GETTEXT` in Convert) move to the wide helpers | GUI probe per dialog (SC-001, SC-002), negative control on the previous build |
| **S2** Find | `CFindDialog` + its sub-dialogs W; the Find thread's loop and its secondary loops wide; combo edit helpers follow | typing test through the real loop; menu/shortcut regression |
| **S3** Configuration | `unicodeWnd` parameter for property pages; the holder's loop wide; pages: Hot Paths, User Menu, Viewers, Editors, Command Shell, Packers, Unpackers, Archiver Locations (+ the pages with masks if the audit is clean); in-place list editor created wide; list/tree notifications handled in both forms; `dialogsp.cpp` code-page reads/writes → UTF-8 helpers | probe: stored values after OK, unchanged-on-OK, label editing |
| **S4** command line | the control created wide; the typed-character switch, selection offsets, drop position and measuring move to UTF-16 units | probe: insert name, type, run; editing regression |
| **S5** 7-Zip password | measurement first; winliblt optional `unicodeWnd`; the prompts created wide; password handed to the engine as Unicode; one retry with the legacy form on wrong password | engine probe with archives made by 7-Zip; GUI probe of the prompt |
| **S6** gates & records | builds, saltests, guard, probes of 087–089/092, CHANGELOG, NEXT-WORK, CLAUDE.md, quickstart | — |

Order: S0 → S1 → S2 → S3 → S5 → S4 → S6 (the command line last; if its
review does not pass it is reverted and recorded).

## Risks (from research §5)

1. A code-page subclass on a text field undoes the fix silently → S0 (a),
   and the probe's `IsWindowUnicode` channel catches any that is missed.
2. Notification format in W dialogs → per-dialog audit in S1–S3.
3. Loops → S0 (c), S2, S3; neutrality for code-page windows was measured.
4. Buffer limits → S0 (b).
5. Passwords: master-password dialogs untouched; 7-Zip compatibility retry.
6. Dark theme subclassing keeps a Unicode control Unicode (measured).

## Project Structure

```
specs/093-unicode-dialogs/
  spec.md plan.md research.md tasks.md quickstart.md fix-log.md
  contracts/dialog-unicode.md
  checklists/requirements.md
  probe/   B1Probe.cs (Win32 semantics), dialogs_probe.ps1, pwd probes
src/common/winlib.*            S0
src/salamdr1.cpp               S0 (main loop)
src/dialogs*.cpp, execute.cpp  S1, S3
src/find*.cpp, finddlg*.cpp    S2
src/common/sheets.cpp          S3
src/edtlbwnd.cpp               S3
src/editwnd.cpp                S4
src/plugins/shared/winliblt.*  S5
src/plugins/7zip/*             S5
```
