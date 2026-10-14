# Implementation Plan: a pending edit is never packed into the archive a re-pointed name leads to

**Branch**: `145-pending-edits-repointed` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

## Summary

Each panel records where its archive's name led at the open (final path). Packing pending edits
is refused like a failed pack when the name leads elsewhere now, and the refresh reopens such an
archive. An archive replaced at the same place keeps taking the edit.

## Technical Context

C++20, MSVC v143; core only (`tandemcommander.exe`); tests: 109 probe (cases `resubst-pending`,
`replace-pending`, op `replace`), 108/112 regressions, `saltests`. No string, interface, registry.

## Constitution Check

I-VI PASS (core-only, existing message reused). Re-checked after design: unchanged.

## Project Structure

```text
src/common/salfileio.h/.cpp  # SalGetFinalPathOfHandleU8Alloc (split from SalGetFinalPathU8Alloc)
src/fileswnd.h, fileswn1.cpp # ZIPArchiveFinalPath, TakeZIPArchiveFinalPath, ArchiveNameLeadsElsewhere
src/fileswn2.cpp             # the open stores it; the refresh's change test uses it
src/salamdr3.cpp             # CheckAndPackAndClear refuses the pack when the name leads elsewhere
specs/109-.../probe/diskcache_probe.ps1   # op 'replace', cases resubst-pending, replace-pending
```

The comparison is one call of the tested `SalPathEqualOrdinalCI`; no new pure rule.

## Complexity Tracking

None.
