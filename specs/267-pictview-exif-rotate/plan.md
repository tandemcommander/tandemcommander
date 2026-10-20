# Implementation Plan: PictView - the Exif dialog and Exif auto-rotation with the built-in engine

**Branch**: `267-pictview-exif-rotate` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/267-pictview-exif-rotate/spec.md`

## Summary

The WIC engine reports `PVFF_EXIF` the way the old engine did, so the three existing gates (the
Exif command's handler, its enabler for menu and toolbar, the auto-rotation in WM_PAINT) open
for JPEG files with an Exif block. Auto-rotation reads the orientation through the engine's
WIC metadata reader (`WicGetExifOrientation`, already used by panel thumbnails) instead of
EXIF.DLL's code-page export, and turns the picture by a pure rule (`src/common/salexiforient.h`,
all eight values per the standard, `saltests` checks). Update Thumbnail keeps 132's own file
check. No new text, no plug-in interface change, no EXIF.DLL change.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI, WIC (`IWICMetadataQueryReader`); EXIF.DLL (libexif) for the
Exif window, unchanged
**Storage**: N/A (the existing `AutoRotate` setting is only read)
**Testing**: `saltests` (new `TestExifOrient267`), hidden-desktop probe
`probe/pv267_probe.ps1` (42 fixture rows + 14 real-file rows), regressions: 120's probe
(`pv120_probe.ps1`), 132's Update Thumbnail probe (`thumb132_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in)
**Performance Goals**: no extra file access (FR-010): one metadata query on the decoder's frame
per opened JPEG
**Constraints**: no new UI strings; EXIF.DLL exports untouched; `PVImageInfo` layout untouched
**Scale/Scope**: 5 source files + 1 new header + saltests, ~120 lines

## Constitution Check

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - one header added to `saltests.vcxproj` (ClInclude); no dependency |
| II Backward compatibility | PASS - registry, files, plug-in interface unchanged; `AutoRotate` default (on) unchanged; files that had no turn and no Exif command now get them as the setting always promised |
| III Incremental modernization | PASS - reuses the engine's existing reader, small edits at the three gates |
| IV Windows commitment | PASS - WIC |
| V Plugin architecture preservation | PASS - `spl_*.h`, `LAST_VERSION_OF_SALAMANDER`, EXIF.DLL `.def` untouched |
| VI UI consistency | PASS - the viewer now turns pictures as its panel thumbnails do (064) |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/267-pictview-exif-rotate/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── tasks.md
├── fix-log.md
├── checklists/requirements.md
└── probe/            pv267_probe.ps1, mkfix267.py, quad267.py, real267.py, real267_wic.ps1, results
```

No `data-model.md` (no stored data) and no `contracts/` (no interface exposed or changed; the
new engine query and the header are plug-in-internal).

### Source Code (repository root)

```text
src/common/salexiforient.h                  NEW: SalExifOrientTurn(orient) -> quarter turn + mirrors
src/saltests/saltests.cpp                    TestExifOrient267 (all values, invalid, composition check)
src/vcxproj/saltests/saltests.vcxproj        ClInclude of the header
src/plugins/pictview/wicengine.cpp           CWicImage::HasExif, set at open for a JPEG (/app1/ifd);
                                             FillInfo: Flags = PVFF_EXIF when set
src/plugins/pictview/render1.cpp             WM_PAINT auto-rotation: JPEG + PVFF_EXIF + AutoRotate,
                                             WicGetExifOrientation + SalExifOrientTurn, post the
                                             commands (turn first, then mirrors); no EXIF.DLL
src/plugins/pictview/thumbs.cpp              Update Thumbnail: `!ThumbFileHasExif(path)` alone (132)
```

`render1.cpp` CMD_IMG_EXIF and `pictview.cpp` enabler: unchanged - they open with the flag.

**Structure Decision**: edits in place in PictView plus one header-only rule in `src/common/`
(standing rule: pure decisions in a header with `saltests` checks).

## Complexity Tracking

None.
