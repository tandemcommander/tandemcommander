# Implementation Plan: ISO plug-in - a video file in Form 2 sectors without an XA Form 2 attribute extracts whole

**Branch**: `367-uniso-form2-unmarked` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/367-uniso-form2-unmarked/spec.md`

## Summary

A listed ISO 9660 file that feature 366 does not read as Form 2 is examined at listing when its track stores
Form 2 user data and it starts in a Form 2 stream track, or its CD-XA attributes carry the Form 2 bit (also
mixed 0x3D55), or its first sector is a Form 2 sector. Examining reads the subheaders of all its sectors (in
blocks) and classifies each sector Form 2 / Form 1 / unknown (feature 335's subheader validity). All Form 2 ->
listed and read as a 366 Form 2 file; mixed -> listed with the per-sector sum (2324 a Form 2 sector, 2048 any
other, the record's remainder for a last non-Form-2 sector) and read sector by sector by both readers; none ->
as before. The coverage check counts an examined file's leading run of sectors read whole (Form 2, or Form 1 not
cut by the record's end) - it stops at the first unknown sector, so a damaged sector in a stream is left to
feature 337's gap check (fails closed). Rules in `src/common/salisotrack.h` with `saltests`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new
**Storage**: N/A
**Testing**: `saltests` (new `TestIsoSectorScan_367`); hidden-desktop probe `probe/iso367_probe.ps1` (366's
probe with 367's rows and expectations; images `probe/img367.py` from the real vcdimager output in
`%TEMP%\rev335c\data`); regressions: 366's probe (rows not touched by this feature), 337's (with 336 / 335
rows), 365's, 334's
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (uniso)
**Performance Goals**: one 24-byte read per listed file on a track that stores Form 2 data (FR-001's first
sector test); an examined file's subheaders read 64 sectors a read
**Constraints**: plug-in ABI unchanged (`CFilePos` is the plug-in's own data); header-only rules; no UI string
**Scale/Scope**: salisotrack.h, isoimage.h/.cpp, iso9660.h/.cpp, rawfs.cpp, saltests.cpp

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency. PASS |
| II. Backward compatibility | Files not examined (plain data discs, Mode 1, cooked, Video CD Form 1 files with a Form 1 first sector and no Form 2 bit) and 366's Form 2 files are listed, read and counted as before; probe control rows and regression probes. PASS |
| III. Incremental modernization | Pure rules with tests. PASS |
| IV. Windows commitment | Unchanged. PASS |
| V. Plugin architecture | No change to `spl_*.h`, no ABI change. PASS |
| VI. UI consistency | No text, dialog or menu - no `.slt` refresh. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/367-uniso-form2-unmarked/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── checklists/requirements.md
└── probe/ (iso367_probe.ps1, img367.py, result_*.txt)
```

No `contracts/`: the change is internal to the plug-in.

### Source Code (repository root)

```text
src/common/salisotrack.h       # SalIsoSectorForm (Form 2 / Form 1 / unknown; SalIsoSectorIsForm2 = Form 2),
                               # SalIsoFileNeedsSectorScan, SalIsoSectorScan + Add / Kind / Size / Whole
src/plugins/uniso/isoimage.h   # CFilePos: Form2 0 / 1 / 2 (mixed), Scanned, WholeSectors;
                               # CISOImage::ExamineFileSectors, ReadMixedBlock
src/plugins/uniso/isoimage.cpp # the scan at listing; the per-sector read; NoteListedFileStarts uses WholeSectors
src/plugins/uniso/iso9660.h/.cpp # AddFileDir gets the XA attributes; calls ExamineFileSectors; UnpackFile mixed
src/plugins/uniso/rawfs.cpp    # UnpackFile mixed
src/saltests/saltests.cpp      # TestIsoSectorScan_367
```

**Structure Decision**: the existing plug-in files; the rules beside 335's / 366's in `salisotrack.h`.

## Design

1. `SalIsoSectorForm(raw, len, sectorRawSize)`: the checks of `SalIsoSectorIsForm2` (sync + mode 2 for 2352+,
   subheader copies equal, channel < 32, at most one data/audio/video bit); valid -> Form 2 when the Form bit is
   set, else Form 1; anything else unknown. `SalIsoSectorIsForm2` returns `SalIsoSectorForm == Form 2` (335's and
   366's callers unchanged by construction; 335's tests keep passing).
2. `SalIsoFileNeedsSectorScan(readAsForm2, trackStoresForm2, dataLength, startsInStream, xaKnown, xaAttrs,
   firstSectorForm2)`: false when 366 reads it as Form 2, the track does not store Form 2 data or the length is
   0; else true when it starts in a stream, or its XA attributes have the Form 2 bit and not the directory bit,
   or its first sector is Form 2.
3. `SalIsoSectorScan` (sectors expected = ceil(length / 2048); counted Form 2; whole leading run; stopped at the
   first unknown / partial sector; last form): `Add(form)` per sector in order; `Kind` = none / all Form 2 /
   mixed; `Size` = Form 2 x 2324 + other non-last x 2048 + the last non-Form-2 sector's remainder (equals the
   record length for none, `SalIsoForm2FileSize` for all); `Whole` = the leading run of sectors read whole.
4. `CISOImage::ExamineFileSectors(extent, length, xaKnown, xaAttrs, &form, &size, &whole)`: the file's start track
   (`GetTrackFromExtent`, as 366's `FileIsForm2`), `SalIsoTrackStoresForm2`, the first sector's 24 bytes, the
   rule of 2; then 64 sectors a read from the stored sector's start, each through `SalIsoSectorForm` (a short read
   = unknown for the sectors not read whole); out of memory -> listing marked incomplete, the file unchanged.
5. `AddFileDir`: 366's branch first; else `ExamineFileSectors` - all Form 2 -> `Form2 = 1`, size = sectors x 2324;
   mixed -> `Form2 = 2`, the scan's size; `Scanned` + `WholeSectors` for any examined file.
6. `CISOImage::ReadMixedBlock(block, data)`: the open track's stored sector at `GetSectorOffset(block) -
   SectorHeaderSize`, 24 bytes, `SalIsoSectorForm` -> Form 2: `ReadForm2Block` (2324), else `ReadBlock(block, 2048)`
   (2048); 0 on a read error. Both readers: `Form2 == 2` -> a 2324-byte buffer, `nbytes = min(ReadMixedBlock, remain)`.
7. `NoteListedFileStarts`: a scanned file's span = `SalIsoFileSectorSpan(extent, WholeSectors x 2048, ..., 2048)`;
   others as before.

## Complexity Tracking

None.
