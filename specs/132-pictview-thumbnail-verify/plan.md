# Implementation Plan: PictView's Update Thumbnail keeps the picture

**Branch**: `132-pictview-thumbnail-verify` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

Three layers, each able to stand without the others:

1. **The rule** (`src/common/saljpegkeep.h`, header-only, `saltests`): the new file may differ
   from the original only in its Exif APP1 / JFXX APP0 blocks; everything from the SOS marker
   to the end of the file is the same; a file that had Exif still has it. Not understood = no.
2. **The plug-in** (`src/plugins/pictview/thumbs.cpp`): after EXIF.DLL reports success, both
   files are read and the rule decides; a refusal deletes the temporary file and shows the
   existing message. The JFXX question is asked by the file's own blocks (`SalJpegHasExif`).
   `wicengine.cpp`: `WicSaveImage` accepts the second subset - a JPEG picture scaled to a given
   size into the caller's memory (`WicSaveJpegThumbnail`: `CWicDibSource` -> scaler -> format
   converter -> JPEG encoder on a memory stream -> one `WriteFunc` call).
3. **The library** (`src/plugins/pictview/exif/libjpeg/jpeg-data.c`, `.h`): an APP1 that is not
   Exif is kept as generic data (`JPEGSection::exif`); the loader marks data it left early as
   incomplete and the writer refuses them; a block over 64 KB, an Exif block that cannot be
   written and low memory fail the save; the end marker is recognised by both its bytes.

## Technical Context

- C++20 / C (the library), MSVC v143; the plug-in loads `exif.dll` beside it (ANSI interface).
- `jpeg-data.c` is ISO-8859-1 text with CRLF - edited by a script that keeps the bytes.
- Tests: `saltests` (the rule); `probe/exifdll_measure.py` (the library called directly through
  `ctypes`, 13 shapes of file made with Pillow, before / after); `probe/thumb132_probe.ps1` on
  the hidden desktop (the command in the program; modes fixed / before / oldlib);
  `probe/check_outputs.py` (the resulting files decode, hold a 160 x 120 thumbnail).
- No new strings; no interface change; `PRIVACY.md` untouched (no network, nothing stored).

## Constitution Check

- Never lose the user's data: the check fails closed; the original is replaced through
  `SalReplaceWithTempW` as before (105) and only after the check.
- Backward compatibility: no stored format changes.
- Plugin architecture: `exif.dll` keeps its exported interface.
- UI consistency: existing dialogs and texts.

## Structure

1. Measure: the library directly (0.1.9), the command in the program (finding: dead).
2. Rule + unit checks; plug-in check; library changes; the thumbnail encoder; the question.
3. Build, `saltests`, library measurement, probe in three modes, output check.
4. Independent review (refute-first), fixes, Release build, regressions, records.
