# Implementation Plan: An ISO 9660 folder whose length cannot be a directory of the image is a folder that cannot be read

**Branch**: `403-uniso-dir-length` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/403-uniso-dir-length/spec.md`

## Summary

`CISO9660::ListDirectoryRe` (`src/plugins/uniso/iso9660.cpp`) held the folder record's 32-bit unsigned
data length in an `int` and allocated `new char[size]`: a length of 2 GiB or more asked for ~2^64 bytes,
the core's memory box appeared, and both Abort and Ignore ended the program. The fix decides before the
buffer is allocated, by two pure rules in `src/common/salisowalk.h` (the walk header of 400 / 401,
`saltests`-checked):

- `SalIsoDirLengthReadable(length)` - 1 .. `SAL_ISO_DIR_MAX_LENGTH` (256 MiB);
- `SalIsoDirLastBlock(block, length, sectorSize, &last)` - the directory's last sector in 64-bit, false
  when it lies past sector 0xFFFFFFFF.

A refused length, or a folder of more than one sector whose last sector cannot be read (1 byte read
through `CISOImage::ReadBlock`), takes the existing failed-read path: the box once per walk (400),
ERR_TERMINATE (ERR_CONTINUE for the root), the listing marked by `ListDirectory` (330). The length is
then held as `DWORD`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; the plug-in includes `src/common` headers by `../../common/`  
**Storage**: N/A  
**Testing**: `saltests` (new `TestIsoDirLength403`), the hidden-desktop probe `iso403_probe.ps1`
(`img403.py`), regression probes 328 / 400 / 401 / 402  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, archiver plug-in `uniso`  
**Performance Goals**: one extra sector read only for folders of more than one sector  
**Constraints**: plug-in ABI unchanged; no UI string; header-only rule (plug-ins cannot compile a
`src/common` .cpp)  
**Scale/Scope**: one function in one plug-in, one header, one test function

## Constitution Check

- I Build reproducibility: no new dependency, header-only. PASS
- II Backward compatibility: valid images (lengths 1 .. 256 MiB, readable) read as before; plug-in
  interface untouched. PASS
- III Incremental modernization: one site, a pure rule with tests. PASS
- IV Windows commitment: N/A. PASS
- V Plugin architecture: no ABI change. PASS
- VI UI consistency: the existing box and string. PASS

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/403-uniso-dir-length/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/  img403.py, iso403_probe.ps1, result_*.txt
```

(no `contracts/` - nothing other code relies on changes)

### Source Code

```text
src/common/salisowalk.h          + SAL_ISO_DIR_MAX_LENGTH, SalIsoDirLengthReadable, SalIsoDirLastBlock
src/plugins/uniso/isoimage.h     + GetSectorUserSize() (inline accessor; the plug-in's own class)
src/plugins/uniso/iso9660.cpp    CISO9660::ListDirectoryRe - the checks before the allocation
src/saltests/saltests.cpp        + TestIsoDirLength403
```

**Structure Decision**: the existing walk header and its test file, as 400 / 401.

## Complexity Tracking

None.
