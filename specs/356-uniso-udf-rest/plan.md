# Implementation Plan: A UDF-only disc image is kept when it holds more than its listing shows

**Branch**: `356-uniso-udf-rest` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/356-uniso-udf-rest/spec.md`

## Summary

Feature 354's block in `CISOImage::Open` (`src/plugins/uniso/isoimage.cpp`, the plain branch's
`cookedIso`) gets a second arm for a cooked image whose sector 16 is not an ISO 9660 primary descriptor
(`CheckForISO` accepted `BEA01`): a new member `CISOImage::UdfRestMarks` reads the anchor at sector 256,
the main volume descriptor sequence it names (at most 64 sectors: partition and logical volume
descriptors, up to the terminating descriptor), the file's last whole sector and the one 256 before it,
and fills a `SalIsoUdfVolume` (`src/common/salisotrack.h`). The pure rule `SalIsoUdfRestDecision` turns it
into the volume's size - the file's whole sectors when the file closes with this volume's own anchor or
(VAT) its own file entry, else the descriptors' end - and hands it to 354's `SalIsoCookedRestDecision`
(16 sectors kept, more than 512 marked, else checked). The check reads the rest sector by sector and
marks unless every sector is zero bytes only or an anchor of this volume (`SalIsoUdfRestSectorEmpty`).
A marked listing makes a whole unpack fail, so "Delete archive after unpacking" keeps the image.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; `salisotrack.h` (header-only, used by uniso and saltests)  
**Storage**: N/A (no registry, no files written)  
**Testing**: `saltests` (`TestIsoUdfRest_356`, synthetic descriptor sectors), hidden-desktop probe
`probe/iso356_probe.ps1` (IMAPI2FS seeds by `probe/imapiudf356.ps1`, composed by `probe/img356.py`,
mkudffs seeds by `probe/mkudf356.sh`); regressions: the probes of 354 and 355  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: per open of a UDF-only cooked image at most 1 + 64 + 2 sector reads of 2048 bytes,
plus the rest (17..512 sectors, only when the file does not close with the volume)  
**Constraints**: no UI string, no plug-in ABI change; images with an ISO 9660 descriptor at sector 16,
raw images and every other format unchanged  
**Scale/Scope**: `isoimage.cpp` / `isoimage.h`, one common header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project change. PASS
- II. Backward compatibility: plain UDF-only images (IMAPI2FS, mkudffs incl. VAT, Blu-ray-style with a
  closing anchor) behave as in 0.2.0; the only change is a kept image where data would be lost or where
  the volume's end cannot be read. PASS
- III. Incremental modernization: pure rule in `src/common/` with tests; minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: no new message. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/356-uniso-udf-rest/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso356_probe.ps1, imapiudf356.ps1, img356.py, mkudf356.sh, udfmeasure.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisotrack.h          # + SalIsoUdf* tag / anchor / partition / LVD / file-entry parsers,
                                  #   SalIsoUdfVolume, SalIsoUdfRestDecision, SalIsoUdfRestSectorEmpty
src/saltests/saltests.cpp         # + TestIsoUdfRest_356
src/plugins/uniso/isoimage.h      # + CISOImage::UdfRestMarks
src/plugins/uniso/isoimage.cpp    # Open's cookedIso block: the UDF arm; UdfRestMarks
```

**Structure Decision**: the existing plug-in and common-header layout (as features 334 - 355).

## Complexity Tracking

None.
