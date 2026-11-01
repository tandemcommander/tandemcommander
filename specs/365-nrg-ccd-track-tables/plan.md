# Implementation Plan: The ISO plug-in reads NRG ETNF / ETN2 and CloneCD track tables with the right sector sizes, sessions and ends

**Branch**: `365-nrg-ccd-track-tables` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/365-nrg-ccd-track-tables/spec.md`

## Summary

Three track-table readers of the ISO plug-in (`src/plugins/uniso`) give tracks a wrong geometry:
`readETNF` takes the stored sector size from bit 0 of Nero's mode byte, `readETN2` reads one entry per
chunk with a fixed Mode 1 / 2048, extent 0 and `End` = the entry's length, and `ReadSessionCCD` splits
CloneCD tracks into sessions at `INDEX 1 = 0` with unsigned sector counts. Fix:

1. Pure rules, header-only, with `saltests` checks:
   - `src/common/salnrgcdtext.h` (the NRG header of 331 / 350): `SalNrgEtnSectorSize(mode, v2)` - Nero's
     verified modes (0x00 / 0x02 -> 2048, 0x03 -> 2336, 0x05 / 0x06 / 0x07 -> 2352), any other mode
     the size 41f18c08 gave (ETNF: bit 0 -> 2336 else 2048; ETN2: 2048); `SalNrgModeVerified(mode)`;
     `SalNrgEtnDecode(p, v2, entry)` - an ETNF (20-byte) or ETN2 (32-byte) entry, big-endian;
     `SalNrgEtnEnd(start, length)` - start + length, saturated at the largest signed 64-bit value;
     `SalNrgEtnEntryCount(size, v2)`; `SalNrgEtn2ChunkPlausible(size)` - at most 99 whole entries.
   - `src/common/salisotrack.h` (the track header of 334-364): `SalIsoCcdSectorCount(start, end,
     inconsistent)` - end - start, 0 and `inconsistent` when negative; `SalIsoCcdTocLayout(entries, n,
     trackCount, out)` - the CloneCD layout from the table of contents (FR-004 / FR-005 / FR-006):
     `SAL_ISO_CCD_TOC_NONE` (cannot be followed), `..._OK`, `..._INCONSISTENT`; per track its session,
     extent (PLBA), first sector in the `.img` and sector count.
2. `nrg.cpp`: `readETNF` takes the sector size from `SalNrgEtnSectorSize(mode, false)`; `readETN2` is
   rewritten as ETNF's loop over whole 32-byte entries (start, end = `SalNrgEtnEnd`, mode / type by
   `SetTrackTypeMode` for a verified mode else Mode 1 / ISO 9660 as before, sector size, header size,
   extent = the first-sector field), reading the chunk only when `SalNrgChunkFits` and
   `SalNrgEtn2ChunkPlausible` hold (else skipped as readCUEX skips), continuing right after the chunk.
3. `img.cpp` `ReadSessionCCD`: after the tracks are built, `SalIsoCcdTocLayout`; when it can be
   followed the sessions are its runs (`AddSessionTracks`) and every track gets `SectorSize` 0x930,
   its header size, `ExtentOffset` = PLBA, `Start` / `End` from first sector and count; INCONSISTENT
   marks `ListingLeftOut` incomplete. Otherwise the 41f18c08 path, unchanged except its sector counts
   go through `SalIsoCcdSectorCount` (a negative count: 0 and the mark). 352's
   `SalIsoCcdLayoutTrusted` check stays after both paths.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new  
**Storage**: N/A  
**Testing**: `saltests` (`TestNrgEtn365`, `TestIsoCcdToc365`); hidden-desktop probe `probe/iso365_probe.ps1`
(seeds `probe/mkimg365.sh`, images `probe/img365.py`), Debug; regressions: the probes of 352 (R-ABS
expected to change), 351, 335, 334, 353  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (uniso)  
**Performance Goals**: N/A  
**Constraints**: plug-in ABI unchanged; header-only rules without CRT dependencies beyond what the
headers already include; no UI string  
**Scale/Scope**: two reader files, two rule headers, two test functions

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency. PASS |
| II. Backward compatibility | Images 41f18c08 reads correctly keep their track records (FR-008; controls C-ETNF00, C-ETN2ONE, C-CCDREL; 351 / 352 / 334 / 335 / 353 probes). PASS |
| III. Incremental modernization | Format rules as pure headers with tests. PASS |
| IV. Windows commitment | Unchanged. PASS |
| V. Plugin architecture | No change to `spl_*.h`, no ABI change. PASS |
| VI. UI consistency | No new text, dialog or menu - no `.slt` refresh. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/365-nrg-ccd-track-tables/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── checklists/requirements.md
└── probe/ (iso365_probe.ps1, mkimg365.sh, img365.py, result_*.txt)
```

No `contracts/`: the change is internal to the plug-in (no plug-in interface, file format written or
command line).

### Source Code (repository root)

```text
src/common/salnrgcdtext.h      # + SalNrgModeVerified, SalNrgEtnSectorSize, SalNrgEtnDecode, SalNrgEtnEnd,
                               #   SalNrgEtnEntryCount, SalNrgEtn2ChunkPlausible
src/common/salisotrack.h       # + SalIsoCcdSectorCount, SalIsoCcdTocLayout
src/plugins/uniso/nrg.cpp      # readETNF sector size, readETN2 rewritten
src/plugins/uniso/img.cpp      # ReadSessionCCD: TOC layout, guarded counts in the INDEX-1 path
src/saltests/saltests.cpp      # TestNrgEtn365, TestIsoCcdToc365
```

**Structure Decision**: the existing uniso plug-in and its two existing rule headers.

## Complexity Tracking

None.
