# Implementation Plan: A shortcut opens its target, whatever letters the path has

**Branch**: `128-shortcut-target-unicode` (from `127-mixed-template-texts`) | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)
**Input**: GitHub issue #8 (`issues/issue_8.md`)

## Summary

Enter on a `.lnk` (`CFilesWindow::Execute`) and *Go to Shortcut Target*
(`CFilesWindow::FocusShortcutTarget`) read the target with `IShellLinkA::GetPath` - code-page
bytes - while the core's paths are UTF-8; the path check then answers `ERROR_INVALID_NAME`
(123) for every target with a non-ASCII letter. Both use the wide interface now, through one
header-only rule `SalShellLinkGetPathU8` (wide `GetPath`, UTF-8 result, whole or refused).
Feature 069 had done the same for the drop-target code only.

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: `IShellLinkW`, `IPersistFile` (shell32 / ole32, already used), `SalWToU8`
**Storage**: none
**Testing**: `saltests` `TestShellLink128` (real `.lnk` files in the temporary folder: Czech, Greek, Chinese + emoji targets; exact fit / one byte short; a shortcut without a path); GUI probe `probe/lnk_probe.ps1` on the hidden desktop (7 shortcuts, Enter and Go to Shortcut Target, exact locations), before and after
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Constraints**: a path is never cut; ASCII, pathless and broken shortcuts unchanged; no new string
**Scale/Scope**: 1 new header (about 40 lines), 2 core files (about 12 changed lines), about 40 saltests checks

## Constitution Check

All six principles: PASS (no build, format, interface or UI change; the code moves from an `A`
shell interface to the `W` one, the direction of every encoding feature since 004).

## Stages

| Stage | Content |
|---|---|
| S0 measure | done: `probe/lnk_result_before_v019.txt` - 7 of 18 rows fail, the report's box reproduced exactly |
| S1 rule | `src/common/salshelllink.h`: `SalShellLinkGetPathU8`; saltests |
| S2 call sites | `src/fileswn2.cpp` `Execute` (3 `GetPath` calls), `src/fileswn0.cpp` `FocusShortcutTarget` (2): `IShellLinkW`, the helper with the real buffer sizes |
| S3 tests, gates, records | probe on the fixed build (18 / 18); Debug + Release builds; guard; independent review; records |

## Project Structure

```text
src/common/salshelllink.h      # new, header-only
src/fileswn2.cpp, src/fileswn0.cpp
src/saltests/saltests.cpp      # TestShellLink128
specs/128-shortcut-target-unicode/probe/   # lnk_probe.ps1, results
```

## Complexity Tracking

No violations.
