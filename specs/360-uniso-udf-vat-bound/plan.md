# Implementation Plan: ISO plug-in - a damaged UDF VAT file entry no longer writes past the table buffer

**Branch**: `360-uniso-udf-vat-bound` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/360-uniso-udf-vat-bound/spec.md`

## Summary

`CUDF::ReadVAT` (`src/plugins/uniso/udf.cpp`) allocates the VAT table with the file's information length cut
to 32 bits (`(int)fe.InformationLength`), takes the descriptor area `[176 (+40) + L_EA, + L_AD)` of the
2048-byte sector in 32-bit arithmetic without a bound, and `CUDF::ReadAllocDesc` copies each descriptor's
data into the table (`memcpy` of `L_AD` embedded bytes, `ReadBlock` of `ad.Length` bytes) without comparing
with the bytes left; a reserved descriptor type (4 - 7) leaves the descriptor uninitialised and returns 0 (no
progress). The fix:

1. Pure rules in `src/common/salisoudfvat.h` (64-bit, no wrap):
   - `SalIsoUdfVatTableLength(infoLen, len)` - false over 2^32 - 1;
   - `SalIsoUdfVatDescArea(sectorLen, efe, lEA, lAD, first, end)` - the area inside the sector, or false;
   - `SalIsoUdfVatDescSize(type)` - 8 / 16 / 20, 0 for embedded data, -1 for the reserved types;
   - `SalIsoUdfVatDescFits(pos, descLen, end)` - the descriptor inside the area;
   - `SalIsoUdfVatCopyFits(written, extentLen, tableLen)` - the copy inside the table.
2. `ReadVAT` refuses (`ERR_CONTINUE`, "not a VAT", after the existing strategy check) an over-long length, an
   area outside the sector and a reserved descriptor type before allocating; it passes the area's remaining
   bytes and the table's length to `ReadAllocDesc`, which refuses (`-1` → `ERR_CONTINUE`, table freed) a
   descriptor outside the area or a copy past the table.
3. `saltests`: `TestIsoUdfVat_360` - the measured cases and a grid that checks every accepted walk stays inside
   the sector and the table.
4. Probe `probe/iso360_probe.ps1` + `probe/vat360.py` (measured before: 9 rows fail); regressions: probes 358
   and 359.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfvat.h` (header-only, features 358 - 359)
**Storage**: N/A
**Testing**: `saltests` (`TestIsoUdfVat_360`); hidden-desktop probe `probe/iso360_probe.ps1` (mkudffs images by
356's `mkudf356.sh` and 358's `mkvat358.sh` in WSL, changed in place by `probe/vat360.py`); regression: probes
358 (`iso358_probe.ps1`, 52 rows) and 359 (`iso359_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: unchanged (a few comparisons per descriptor)
**Constraints**: no UI string, no dialog, no plug-in ABI change; ZIP-like plug-ins compile only headers from
`src/common` (header-only rule)
**Scale/Scope**: two plug-in functions and a declaration, five rules in an existing header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change. PASS
- II. Backward compatibility: well-formed VAT entries (descriptors within the sector, total not over the
  information length, known descriptor type, length under 4 GB) read exactly as before; only entries that wrote
  past the buffer or read past the sector are refused, through the existing "not a VAT" path. PASS
- III. Incremental modernization: the rules pure in `src/common/` with tests, a minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: existing messages only. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/360-uniso-udf-vat-bound/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso360_probe.ps1, vat360.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoudfvat.h         # + SalIsoUdfVatTableLength, DescArea, DescSize, DescFits, CopyFits
src/saltests/saltests.cpp         # + TestIsoUdfVat_360
src/plugins/uniso/udf.cpp         # ReadVAT, ReadAllocDesc through the rules
src/plugins/uniso/udf.h           # ReadAllocDesc's declaration (area bytes, table length)
```

**Structure Decision**: the existing plug-in and common-header layout (as features 356 - 359).

## Complexity Tracking

None.
