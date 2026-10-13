# Implementation Plan: plug-in messages with names and error texts

**Branch**: `130-plugin-mixed-templates` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

A plug-in's `LoadStr()` text is code page; file names (interface 104) and `GetErrorText()` are
UTF-8. A sentence composed from both is neither, and the core shows a text that is not valid
UTF-8 through the code page: the name is garbled in every language whose sentence has an
accented letter. The fix is the one of feature 127, carried into the plug-ins: the template is
loaded as UTF-8, and - the reverse rule - every other piece and the sink are UTF-8 too.

## Technical Context

- C++20, MSVC v143, WinAPI; 20 enabled plug-ins (`plugins.cfg`), each its own DLL with its own
  `LoadStr`; some are compiled for an older Windows version (no slim locks in the headers).
- Shared, header-only: `src/plugins/shared/splloadstru8.h` - `SplLoadStrU8(gen, module, id)`
  (a per-module cache, each text converted once, the pointer valid until unload, any thread) and
  `SplLegacyToU8Alloc` / `SplLegacyToU8` (a piece that is UTF-8 or code page -> UTF-8).
- Core: `src/zip.cpp` - the plug-in progress dialog set its title with `SetWindowText` (A); it
  is set wide from UTF-8-or-code-page text now, and a progress line cut at 299 bytes ends at a
  whole character.
- Tests: `saltests` (`TestPluginLoadStr130`), GUI probe `probe/plugmix_probe.ps1` on the hidden
  desktop, 0.1.9 as the control.
- No new strings, no interface change, no registry change, no network change (`PRIVACY.md`
  untouched).

## Constitution Check

- Build reproducibility: no new dependency. Backward compatibility: older plug-ins that pass
  code-page titles / texts are shown as before (a text that is not valid UTF-8 is code page).
- Plug-in architecture: the ABI is unchanged; the helper is header-only in `plugins/shared`.
- UI consistency: the sentences are the translations' own, only whole.

## Structure of the work

1. Shared helper + unit checks.
2. Triage of every `LoadStr(` use per plug-in, with a record per plug-in (`triage/*.md`):
   fixed / right as it is / recorded. Four groups in parallel (archivers; ZIP; SFTP, Renamer,
   File Comparator, Database Viewer; the viewers and the rest). FTP: facts and a plan only
   (`triage/ftp.md`) - its own feature.
3. Measure on 0.1.9 (probe), build, probe on the new build, English control.
4. Independent refute-first review (two reviewers), fixes, final runs, records.
