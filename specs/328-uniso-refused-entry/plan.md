# Implementation Plan: An ISO entry the panel listing refuses is left out and reported

**Branch**: `328-uniso-refused-entry` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/328-uniso-refused-entry/spec.md`

## Summary

`CISO9660::AddFileDir` clears the whole listing and shows "Error" when the panel listing refuses an
entry; the walk then stops descending into later folders, and a whole-image unpack extracts the
remains and lets "Delete archive" delete the image. Now the ISO 9660 walk asks the listing's rule
(`sallistingname.h`) before adding: a refused entry is left out alone (not descended), recorded on
the image (`CISOImage`), reported once per listing by `ListArchive` (system text 206 + up to 10
whole paths) and makes `UnpackWholeArchive` fail. Rock Ridge names: 326's whole-volume fit check
stays the fast path (every name fits → listed as today); when it fails the walk decides per entry -
a file takes its Rock Ridge name, else its ISO 9660 name, else is left out; a folder keeps its Rock
Ridge name when its subtree fits with Rock Ridge names, or when that lists no fewer entries than its
ISO 9660 name (both counted with ISO 9660 names below), else takes the ISO 9660 name. The pure
decisions and the report text are a header `src/common/salisonamefit.h` with saltests.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: plug-in API (unchanged), `src/common/sallistingname.h` (321), `salsusp.h` (326)  
**Storage**: N/A  
**Testing**: `saltests` (new `TestIsoNameFit328`), hidden-desktop probe `probe/iso328_probe.ps1`; regression probes 322 / 326 / 327  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, archiver plug-in `uniso`  
**Performance Goals**: an image whose Rock Ridge names all fit - one extra directory walk (as 326 for SP volumes, now for every non-Joliet volume); the decision walks only on volumes whose names do not all fit  
**Constraints**: plug-in ABI unchanged; no UI string added (system text); never a cut name or path  
**Scale/Scope**: `iso9660.cpp/.h`, `isoimage.cpp/.h`, `uniso.cpp/.h`, new `src/common/salisonamefit.h`, `saltests.cpp`

## Constitution Check

- I Build reproducibility: no new dependency; header-only rule. PASS
- II Backward compatibility: listings of images that fit are unchanged; plug-in interface untouched. PASS
- III Incremental modernization: a local change of one reader, pure rule extracted and tested. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no ABI change; header-only shared rule as CLAUDE.md asks. PASS
- VI UI consistency: the report reuses TAR's (321) form - an error box with the system text. PASS

## Project Structure

```text
specs/328-uniso-refused-entry/
  spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
  probe/iso328_probe.ps1, probe/mkimg328.sh, probe/result_*.txt
src/common/salisonamefit.h          new: SalIsoFolderKeepsRockRidge, SalIsoPickFileName, CSalListingLeftOut
src/plugins/uniso/iso9660.cpp/.h    AddFileDir tri-state, decision mode, count walks, no Clear
src/plugins/uniso/isoimage.cpp/.h   the image's left-out record
src/plugins/uniso/uniso.cpp/.h      report after ListImage; pluginData flag; UnpackWholeArchive fails
src/saltests/saltests.cpp           TestIsoNameFit328
```

**Structure Decision**: in-place change of the existing walk (`ListDirectoryRe`) with mode members,
as 326's fit check did - the read-error behaviour of the walk is kept as it is.

## Complexity Tracking

| Item | Why | Simpler alternative rejected because |
|---|---|---|
| count walks per Rock Ridge folder (decision mode only) | keep Rock Ridge names where they fit and never list fewer entries than 326's whole-ISO listing | per-entry fallback alone loses `deep.txt` of a deep xorriso tree (31-letter ISO names still too deep under the Rock Ridge parents) - a regression of 326's DEEP row |
