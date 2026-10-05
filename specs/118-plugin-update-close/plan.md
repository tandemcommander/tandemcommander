# Implementation Plan: plug-in windows and an installer's close request

**Branch**: `118-plugin-update-close` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

## Summary

Use plug-in interface 107 (feature 088) in the four non-viewer plug-ins: declare the windows that
hold nothing to lose (`SetWindowClosesUnattended`), keep undeclared the ones that hold work, and
make each plug-in's `Release(parent, FALSE)` during an unattended close (`IsUnattendedClose`)
close what it declared silently with the 088 viewers' 5 s - or refuse silently when a window with
work is open. Two defects on the path are fixed: the File Comparator lost a close request when its
worker finished at that moment (and showed a message box), and Disk Map wrote into freed memory
after a refused `Release()`.

## Technical Context

C++20, MSVC v143, WinAPI; plug-ins `filecomp`, `diskmap`, `checksum`, `renamer`. No core change,
no interface change (107), no strings, no registry. Probe: Windows PowerShell 5.1 on the hidden
desktop, reusing 080's `rm_probe.ps1`, 098's `fix_probe_lib.ps1` and the hot-key method of 117.

## Constitution Check

- Plugin architecture preservation: interface unchanged; only documented services used; Disk Map
  keeps loading in older cores (calls guarded).
- Backward compatibility: a person's normal exit is unchanged (none of the four asked anything);
  configuration unchanged.
- Incremental modernization: four contained changes, one per plug-in, plus two local fixes.

## Design

| Plug-in | Declared | Withdrawn / never | `Release` unattended |
|---|---|---|---|
| File Comparator | comparator window at `WM_CREATE` | Compare Files dialog, its boxes (undeclared) | refuse if a Compare Files dialog is open (`CompareDialogsOpen`); else `CloseAllWindows(FALSE, 5000)`, `KillAll(FALSE, 5000)` |
| Disk Map | map, Log, tooltip at creation (107 core only) | About, Esc confirmation (undeclared) | post `WM_CLOSE` as before, `KillAll(FALSE, 5000)`; thread records freed after |
| Checksum | Verify at `WM_INITDIALOG`; Calculate when it holds nothing unsaved | Calculate while reading / calculating / unsaved | refuse if `WindowsHoldingWork > 0`; else `CloseAllWindows(FALSE, 5000)`, `KillAll(FALSE, 5000)` |
| Batch Renamer | never | always | refuse while any window is open |

Checksum's Calculate state: `HoldsWork() = !WorkEnded || (SaveEnabled && (SavedTypes &
calculated) != calculated)`, `SavedTypes` a bit per hash type saved completely, each with the
identity (volume serial + file index) of its file; a save forgets the types whose file it has
just opened ("wb" truncates) and adds its own type only after `ferror` / `fclose` succeed;
`DeleteItem` forgets all. Recomputed (`UpdateClosesUnattended`, on the dialog's thread) at
`WM_INITDIALOG`, `OnThreadEnd`, at the open and the end of a save, after `DeleteItem`;
`WindowsHoldingWork` follows it with `Interlocked*` and is decremented at `WM_DESTROY`.

File Comparator's result race: in `WM_USER_WORKERNOTIFIES`, with `CancelWorker == CW_EXIT` (close
requested while comparing) any result posts `CM_EXIT` and shows no box; with `CW_SILENT` (the
result is being dropped) no box.

## Verification

Debug build, full Release build, `saltests` (unchanged 14,576 - no pure helper was added: the
decisions are plug-in-local state), encoding guard strict. GUI: `probe/update_close_probe.ps1`
(20 rows, `quickstart.md`) on this build and on `Debug_x64_pre118` - pending.
