# Implementation Plan: PictView - Update Thumbnail and Exif information for any file name

**Branch**: `142-pictview-thumb-unicode` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

## Summary

- **EXIF.DLL** (`src/plugins/pictview/exif/exif.c`, `exif.def`, `exif.h`,
  `libjpeg/jpeg-data.c/.h`, and the libexif loader used by the information call): wide entry
  points appended - `EXIFReplaceThumbnailW(const wchar_t* fileName, const wchar_t* newFile,
  unsigned char* data, int size)` and `EXIFGetInfoW(...)` (the wide twin of the call
  `dialogs.cpp` uses). Files are opened with `_wfopen` on the path given (the caller passes a
  `\\?\` path for long ones); the ANSI entry points stay and convert to the wide ones.
- **Plug-in** (`thumbs.cpp`, `dialogs.cpp`): `GetProcAddress` the wide export first and pass
  the path through `SalU8ToW`-style conversion + the long-path form the plug-in already uses
  for its own file access; when the export is missing (an older DLL) the existing
  `U8ToDLLPathAlloc` route is used.
- **Failure box** (`thumbs.cpp`): the OK-only `ShowMessageBox` becomes the command's
  `DialogError(hProgress, BUTTONS_SKIPCANCEL, name, reason, title)` with `FL_SKIP_ALL`
  honoured; the reason: the existing text when nothing better is known, the Windows error when
  the temporary file could not be written, and the existing "not understood" reasons of 132 /
  135 stay as they are.
- **Read-only**: after a replace done with `clearRO`, the attribute is set again on the new
  file (the 105 code restores it only on failure).
- **`PRIVACY.md`**: the sentence about `pv????.tmp` names Update Thumbnail too.

## Technical Context

- Probe: `specs/132-pictview-thumbnail-verify/probe/thumb132_probe.ps1` gets cases with names
  outside the code page; the fixture strips the short name (`fsutil file setshortname <f> ""`
  needs administrator rights - if not available, a volume without 8.3 names is looked for
  (`fsutil 8dot3name query`), else the row is NOT DRIVEN and the wide route is checked by the
  DLL harness `exifdll_measure.py`-style direct call of the new export.
- `exif_real_measure.py` of 135 (82 files) run through the wide export.

## Constitution Check

Never lose the user's data: the checks of 132 / 135 stay in front of the replace. Public claim
updated in the same change. No new strings. The DLL's exports are append-only.

## Structure

1. Spec, plan, tasks. 2. "Before" row. 3. Code. 4. Rows, review, records, commit.
