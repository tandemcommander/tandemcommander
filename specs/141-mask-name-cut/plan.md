# Implementation Plan: a name built from a mask is never cut

**Branch**: `141-mask-name-cut` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

## Summary

- **Core** (`src/masks.cpp/.h`, `src/fileswn5.cpp`, `src/fileswn6.cpp`): a checked form of the
  mask routine - `MaskNameChecked(buffer, bufSize, name, mask, BOOL* cut)` - reports whether
  the result was cut by the buffer (today `MaskName` stops silently at `bufSize - 1`, and with
  a NULL mask `lstrcpyn` cuts). The pure decision ("the length the mask needs for this name")
  lives in a header under `src/common/` (`salmaskname.h`: `SalMaskNameNeed(name, mask)` or the
  whole routine moved there) with `saltests` checks. Callers:
  - `RenameFileInternal` (`fileswn5.cpp`): buffer `SAL_FIND_NAME_U8 + ...`; cut -> the
    existing `IDS_TOOLONGNAME` message, `*tryAgain` as for other refusals;
  - the Copy / Move script builder (`fileswn6.cpp`, two sites, `2 * MAX_PATH + 200`): buffer
    large enough for 255 units of any script plus the mask; cut -> the existing "too long
    target name" route (`IDS_TOOLONGNAME2`, Skip / Skip all).
  - `MakeValidFileName` and what follows the buffers are re-read for the same limit.
- **Plug-ins** calling `SalamanderGeneral->MaskName` with `2 * MAX_PATH` buffers (FTP
  `fs4.cpp`, `fs5.cpp`; PictView `render1.cpp`): measured by reading; where a server or disk
  name over 519 bytes can reach them, the buffer grows and a result that fills the buffer is
  refused (the service has no cut flag - a full buffer is treated as cut, fail closed).
  `CSalamanderGeneral::MaskName` itself is unchanged (ABI).
- **FTP upload autorename** (`src/plugins/ftp/ftputils.cpp`, the generators of new names per
  server type): every cut goes through `SplU8WholePrefixLen` (137); nothing left -> the
  caller's existing "name too long" failure. `saltests` or the FTP harness checks per branch.

## Technical Context

- Probe: new `specs/141-mask-name-cut/probe/maskname_probe.ps1` on the hidden desktop (library
  of 098): rows CP250, MV250, QR250, QR256, with the 0.1.9 control build as "before". The
  in-place rename line cannot be typed into on the hidden desktop (no keyboard) - NOT DRIVEN
  unless the edit accepts `WM_SETTEXT` + Enter as in 137's row.
- FTP: the AUTOREN row of `ftp134_probe.ps1` covers download; an upload row if the stdlib test
  server can be made to report "file exists" (`If Target File Exists` = autorename).

## Constitution Check

"A path or name is never cut" (097, 098, 101). Plug-in ABI unchanged. No new strings.

## Structure

1. Spec, plan, tasks. 2. Probe + "before". 3. Code + tests. 4. Rows, review, records, commit.
