# Implementation Plan: Registry Editor - Copy / Move through a registry link in the target tree

**Branch**: `296-regedt-link-target-tree` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/296-regedt-link-target-tree/spec.md`

## Summary

The recursive copy `CopyOrMoveKey` (`src/plugins/regedt/fs5.cpp`) creates or opens every target
subkey by name (`RegCreateKeyExW`), which follows a registry link standing at that name - into the
source when the link points there (measured: Move lost z=9 / w=7 without a box; a dangling link made
the copy create keys inside the source). Features 292 / 294 checked only the top target key.

Before each target key is created or opened, a new check opens that name as a link
(`REG_OPTION_OPEN_LINK`) and reads its link value. Not a link (or no key) = exactly as before. A link:
its target's identity is read with links followed (292's `GetRegKeyIds`) and compared with the
identities of the operation's source (read once, lazily, the first time a link is met): inside or
equal to the source = refused; holding the source = 294's rule (the key being copied holds the path
from the link's target down to the source) - the 294 pair loop moves into a shared helper used by both
places; otherwise followed as before. A refusal shows the existing "Can't move/copy a key to itself."
box naming the full source key of that level (OK = skip that key, Cancel = stop). A dangling link and
any other error go through the existing open-error box (Retry / Skip / Skip All / Cancel; fails closed).
`CopyOrMoveKey` keeps its signature (a wrapper around the recursion), so Quick Rename gets the same
check. No UI text, no plug-in interface change.

## Technical Context

**Language/Version**: C++20 (MSVC v143), WinAPI
**Primary Dependencies**: advapi32 (registry: `REG_OPTION_OPEN_LINK`, `REG_LINK`); feature 292 / 294
identity helpers in `fs5.cpp` and `src/common/salregkeyid.h` (unchanged)
**Storage**: the Windows registry (what the user copies / moves); nothing of the product's own
**Testing**: hidden-desktop probe `probe/link296_probe.ps1` (creates real links under HKCU); the
probes of 292 (`alias292_probe.ps1`) and 294 (`above294_probe.ps1`) as regression; `saltests` (no
rule changes - the decision reuses `SalRegKeyIdsAnyWithin` / `SalRegKeyIdBelow`, already checked)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt.spl`
**Performance Goals**: one extra key open per target key (plus one value query when it exists);
identity reads only where a link stands
**Constraints**: decide before anything of that key is written; never a cut path (heap copies);
no new UI strings (a run cannot refresh `.slt`); fails closed on errors
**Scale/Scope**: `src/plugins/regedt/fs5.cpp` only

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build change; no new library |
| II Backward compatibility | only copies through a link reaching the source (and dangling links) are refused; a link elsewhere and every key that is no link behave as before (probe controls LINKOTHER, LINKUPOK, MOVE; 292's and 294's probes) |
| III Incremental modernization | one check in the recursion, 294's loop shared instead of copied |
| IV Windows commitment | WinAPI only |
| V Plug-in architecture | no `spl_*.h` change, no interface version change; `CopyOrMoveKey`'s signature unchanged |
| VI UI consistency | existing message boxes only |

Gate: PASS (also after Phase 1).

## Project Structure

### Documentation (this feature)

```text
specs/296-regedt-link-target-tree/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/target-link-check.md
├── probe/link296_probe.ps1 (+ results)
├── fix-log.md
└── tasks.md
```

### Source Code

```text
src/plugins/regedt/fs5.cpp   + SafeRegKeyIdsReachSource (294's pair loop, shared)
                             + SafeCheckTargetLink (is a link there? does it reach the source?)
                             CopyOrMoveKey -> wrapper + static recursion carrying the operation's source
```

**Structure Decision**: existing layout; extends features 292 / 294 in the same file.

## Complexity Tracking

None.
