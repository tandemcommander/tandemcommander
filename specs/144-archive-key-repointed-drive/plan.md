# Implementation Plan: an archive's copies are never another archive's across a re-pointed letter

**Branch**: `144-archive-key-repointed-drive` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

## Summary

The key choice of 109 reads both archives' identities by name at the second open; a re-pointed
drive letter makes the first panel's name name the second file, so two archives share copies
(measured loss, `research.md` R1). Each panel stores its archive's identity at its open and the
choice compares with that; a key that could not be built is never rebuilt from the name.

## Technical Context

**Language/Version**: C++20, MSVC v143 · **Dependencies**: `src/common/salsamefile.h`,
`salfileio` (existing) · **Testing**: 109 probe (+ case `resubst-both`), 108/112 regressions,
`saltests` · **Target**: Windows 11 x64 core (`tandemcommander.exe`) · **Constraints**: no new
string / interface / registry value.

## Constitution Check

I-VI: PASS (core-only change; no ABI, no UI). Re-checked after design: unchanged.

## Project Structure

```text
src/fileswnd.h    # CFilesWindowAncestor: ZIPArchiveIdentity, ZIPArchiveCacheKeyFailed, accessors
src/fileswn1.cpp  # SetZIPArchive forgets both; GetArchiveCacheKey refuses after a failure; ctor init
src/fileswn2.cpp  # SetArchiveCacheKey109: read and store the own identity; compare with the other's stored one
specs/109-disk-cache-archive-key/probe/diskcache_probe.ps1   # case resubst-both
```

The pure choice (`SalArchiveCacheKeyChoice`) is unchanged - only what it is fed changes.

## Complexity Tracking

None.
