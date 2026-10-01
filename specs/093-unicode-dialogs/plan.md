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

**Revised after the measurement in the product** (`probe/baseline_result.txt`;
spec *Clarifications*): the modal dialogs are not lossy, so no dialog is
re-created as a Unicode window. The stages are:

| Stage | Content | Evidence |
|---|---|---|
| **S1** loops and attached helpers | (a) the Find thread's message loop and its secondary loops, and the Configuration window's loop, take and dispatch messages wide (`GetMessageW`/`PeekMessageW`, `IsDialogMessageW`, `TranslateAcceleratorW`, `DispatchMessageW`); the main loop's `IsDialogMessage` becomes the wide one; (b) a helper attached to a text field (`CComboboxEdit` on Find's *Look in* / *Containing* and on the other history combos, the in-place list editor) keeps the field a Unicode control - `AttachToWindow` follows the control's kind; (c) overflow in `EditLine` / `SalGetWindowTextU8` cuts UTF-8 at a whole character instead of re-reading through the code page | `dialogs_probe.ps1`: the 25 lossy rows of the baseline become PASS except the command line; the 56 PASS rows stay; menu, shortcuts, label editing regression |
| **S2** 7-Zip password | password handed to the engine as Unicode at the four sites; one retry with the legacy form for existing 7z archives (contract P1); buffers wiped | engine probe with archives made by the 7-Zip program; GUI probe of the prompt |
| **S3** command line | the control created as a Unicode control; the typed-character switch, selection offsets, drop position and measuring move to UTF-16 units | probe: set, type, insert name, run; editing regression |
| **S4** gates & records | builds, saltests, guard, probes of 087-089/092, CHANGELOG, NEXT-WORK, CLAUDE.md, quickstart | - |

The command line is last; if its review does not pass it is reverted and
recorded. Not part of the feature (found by the probe, recorded): the main
window's title shows `?` for such a folder (the main window is a code-page
window).

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
