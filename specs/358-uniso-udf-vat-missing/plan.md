# Implementation Plan: A UDF image with a VAT that is not found no longer crashes

**Branch**: `358-uniso-udf-vat-missing` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/358-uniso-udf-vat-missing/spec.md`

## Summary

`CUDF::ReadSupportingTables` (`src/plugins/uniso/udf.cpp`) returns TRUE when a virtual partition's VAT is not
found (or its search ends with `ERR_TERMINATE`), leaving no translation table; `CUDF::LogSector` then reads
`Translation[lbNum]` through a NULL pointer (and with `<=` one entry past a found table). The fix:

1. `ReadSupportingTables` returns FALSE (after the existing "Missing virtual allocation table." message) when
   the search ends without a VAT - `ERR_CONTINUE` or `ERR_TERMINATE` - so `CUDF::Open` fails like the existing
   "Error reading virtual allocation table" path: the track / UDF part does not open and the existing rules
   (334's `MarkTrack(NOT_OPENED)`, 330's `PartMissing`) mark the listing.
2. `LogSector` (case `mapVirtual`) translates only through a new pure rule
   `SalIsoUdfVatTranslates(lbNum, entries, hasTable)` = table present and `lbNum < entries`.
3. `CheckForVAT` (VAT 2.00) computes the entry count through `SalIsoUdfVat200Entries(infoLen, headerLen,
   tableLen, entries)`, which refuses a header longer than the table (or a table shorter than its header) -
   the sector is then not a VAT (`ERR_CONTINUE`); the count is bounded by the bytes read.
4. The constructor sets `Entries = 0`, `Length = 0`.

Both rules live in the new header-only `src/common/salisoudfvat.h` (uniso and saltests include it), checked by
`TestIsoUdfVat_358` in `saltests`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfvat.h` (header-only)
**Storage**: N/A
**Testing**: `saltests` (`TestIsoUdfVat_358`), hidden-desktop probe `probe/iso358_probe.ps1` (mkudffs images by
356's `mkudf356.sh` in WSL, `probe/vatimg.py`); regression: probe 356 (`iso356_probe.ps1`, 56 rows)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: unchanged (no extra reads)
**Constraints**: no UI string, no dialog, no plug-in ABI change
**Scale/Scope**: one plug-in source file, one new common header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change (a header). PASS
- II. Backward compatibility: VAT images whose VAT is found list as in 0.2.0; images that crashed now do not
  open (as an unreadable VAT already does). PASS
- III. Incremental modernization: pure rules in `src/common/` with tests, a minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: the existing message, no new string. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/358-uniso-udf-vat-missing/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso358_probe.ps1, vatimg.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoudfvat.h         # new: SalIsoUdfVatTranslates, SalIsoUdfVat200Entries
src/saltests/saltests.cpp         # + TestIsoUdfVat_358
src/plugins/uniso/udf.cpp         # constructor, LogSector, CheckForVAT, ReadSupportingTables
```

**Structure Decision**: the existing plug-in and common-header layout (as features 334-357).

## Complexity Tracking

None.
