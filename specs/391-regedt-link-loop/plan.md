# Implementation Plan: Registry Editor - Copy and Find never loop through a registry link

**Branch**: `391-regedt-link-loop` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/391-regedt-link-loop/spec.md`

## Summary

Copy (F5) and Find of the Registry Editor plug-in open every subkey by name, which follows a registry
link; a link to the walked key, a key above it, or a cycle of links makes them walk the same tree again
until Windows refuses (error 87, ~28 levels). Each walk now keeps the identities (feature 292: the
internal name the registry reports for an opened key) of the keys it is inside; a subkey whose opened
identity is one of them or holds one of them is not followed - Copy refuses it with feature 296's
existing "Can't copy a key to itself." box, Find skips it silently. Links elsewhere stay followed.

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI
**Primary Dependencies**: the plug-in `regedt` (`src/plugins/regedt`), header-only rule `src/common/salregkeyid.h`
**Storage**: the Windows registry (read by Copy and Find; Copy writes the target)
**Testing**: `saltests` (pure rule), GUI probe `probe/loop391_probe.ps1` on the hidden desktop; regression probes of 292, 294, 296, 297, 390
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: one extra `NtQueryKey` (no extra open) per walked key; the chain test is a length comparison for every key reached without a link
**Constraints**: no new UI string; plug-in ABI untouched; never cut a name (identity too long = error, fails closed)
**Scale/Scope**: two walks (`CopyOrMoveKeyRec` in `fs5.cpp`, `CFindThread::ScanKeyAux` in `finddlg.cpp`)

## Constitution Check

- I Build reproducibility: no new dependency, no project file change (new code in existing files) - PASS
- II Backward compatibility: Copy / Find of trees without a looping link unchanged; a link elsewhere followed as before; no configuration change - PASS
- III Incremental modernization: a local fix with a pure rule under `src/common/` and `saltests` checks - PASS
- IV Windows commitment: registry identities through `NtQueryKey` (already used by 292) - PASS
- V Plug-in architecture: no change to `spl_*.h` or `LAST_VERSION_OF_SALAMANDER` - PASS
- VI UI consistency: reuses the existing message (feature 296), no new text, no translation refresh - PASS

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/391-regedt-link-loop/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/loop391_probe.ps1 (+ results)
```

No `contracts/`: nothing outside the plug-in relies on the change (no plug-in API, no file format).

### Source Code (repository root)

```text
src/common/salregkeyid.h          SalRegKeyIdLeadsBack (pure rule)
src/saltests/saltests.cpp         checks of the rule
src/plugins/regedt/regedt.h       CRegWalkChain + RegWalkEnterTop / RegWalkEnter declarations
src/plugins/regedt/fs5.cpp        the chain functions; CopyOrMoveKeyRec checks each opened source key;
                                  the refusal box of 296 moved into a helper shared by both checks
src/plugins/regedt/finddlg.h/.cpp ScanKey keeps a chain, ScanKeyAux skips a key that leads back
```

**Structure Decision**: existing files only; the chain type lives in the plug-in (it uses the plug-in's
`TIndirectArray`), the decision rule in the shared header (tested by `saltests`).

## Design

1. `SalRegKeyIdLeadsBack(chain, count, id)`: TRUE when some `chain[i]` lies within `id`
   (`SalRegKeyIdWithin(chain[i], id)`: `id` is that key or a key above it); empty / NULL `id` or entries
   never match.
2. `CRegWalkChain`: heap copies of identities (`TIndirectArray<WCHAR>`), `Count()`, `PopTo(n)`.
3. `RegWalkEnterTop(chain, hKey, root, key)`: the walk's starting key - `GetRegKeyIds(root, key)` (root
   identities for an empty key, both HKCR halves) and the opened handle's own identity; errors ignored
   (best effort: a missing top identity only moves the detection one level down, never refuses wrongly).
4. `RegWalkEnter(chain, hKey, leadsBack)`: a key below the start - its opened identity
   (`AddOpenedRegKeyId`); leads back = not pushed; otherwise pushed. Returns a Win32 error.
5. Copy: `CopyOrMoveKey` creates the chain for the operation; `CopyOrMoveKeyRec`, right after
   `SafeOpenKey` of the source and before 296's target check, enters the key (top or below); an error
   goes to `RegOperationError(err, IDS_OPEN, ...)` (Retry repeats; fails closed); leads back -> the
   source handle closed, 296's refusal box (`IDS_CANTCOPYTOITSELF2` / `IDS_CANTMOVETOITSELF2` naming the
   full source path), OK = skip, Cancel = stop; nothing written. The level is popped on every return
   (an RAII guard).
6. Find: `ScanKey` creates a chain; `ScanKeyAux` enters each opened key; leads back -> close, return TRUE
   (nothing searched, no box); an error -> `RegOperationError(err, IDS_OPEN, IDS_SEARCHERROR, ...)` like
   an open error.

## Complexity Tracking

None.
