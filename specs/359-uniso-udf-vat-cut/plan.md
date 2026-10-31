# Implementation Plan: ISO plug-in - a cut UDF VAT image no longer hangs the listing

**Branch**: `359-uniso-udf-vat-cut` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/359-uniso-udf-vat-cut/spec.md`

## Summary

`CUDF::ReadSupportingTables` (`src/plugins/uniso/udf.cpp`, case `mapVirtual`) searches a window of partition
sectors for the VAT's file entry. When a read fails it computes the file's partition sectors in 32 bits
(`nSectors = size / 2048 - PD.Start`) and, if `nSectors < vatLoc - 7`, restarts at `nSectors - 7 .. nSectors`.
Nothing limits how often: a failed read at a sector below 7 wraps `vatLoc - 7`, the same window is set again,
and the loop never ends (measured: raw Mode 1 dumps, whose sectors are counted in 2048 bytes). The fix:

1. A pure rule `SalIsoUdfVatFallback(fileSectors, partStart, failed, taken, first, last)` in
   `src/common/salisoudfvat.h` (64-bit, no wrap): false when the fallback was taken already, when the file ends
   at or before the partition start, or when `n + 7 >= failed` (`n` = the file's partition sectors - today's
   `nSectors < vatLoc - 7` without the wrap); otherwise the window `[max(n - 7, 0), n)`.
2. `ReadSupportingTables` asks the rule (with a local `fallbackTaken` flag) instead of the inline arithmetic;
   `false` goes to the existing `VatMissing = TRUE; return Error(IDS_UDF_ERROR_READING_VAT, ...)` path.
3. `saltests`: `TestIsoUdfVat_359` - the cases of the spec, plus a simulation of the search loop over a grid of
   file sizes, partition starts, claimed lengths and readable-sector limits that must end within a bound.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfvat.h` (header-only, feature 358)
**Storage**: N/A
**Testing**: `saltests` (`TestIsoUdfVat_359`); hidden-desktop probe `probe/iso359_probe.ps1` (mkudffs images by
356's `mkudf356.sh` in WSL, `probe/rawimg359.py`); regression: probe 358 (`iso358_probe.ps1`, 40 rows)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: the search reads at most 14 + 7 sectors
**Constraints**: no UI string, no dialog, no plug-in ABI change
**Scale/Scope**: one plug-in function, one rule in an existing header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change. PASS
- II. Backward compatibility: images whose VAT is found list as in 0.2.0; where the old fallback did not wrap
  its decision is unchanged; images that hung now show the existing read-error message. PASS
- III. Incremental modernization: the rule pure in `src/common/` with tests, a minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: existing messages only. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/359-uniso-udf-vat-cut/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso359_probe.ps1, rawimg359.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoudfvat.h         # + SalIsoUdfVatFallback
src/saltests/saltests.cpp         # + TestIsoUdfVat_359
src/plugins/uniso/udf.cpp         # ReadSupportingTables (mapVirtual) through the rule
```

**Structure Decision**: the existing plug-in and common-header layout (as features 356-358).

## Complexity Tracking

None.
