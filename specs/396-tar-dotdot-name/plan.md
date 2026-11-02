# Implementation Plan: A tar member whose name contains `..` goes to the folder its name points to

**Branch**: `396-tar-dotdot-name` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/396-tar-dotdot-name/spec.md`

## Summary

`SalTarNormalizeNameU8` (`src/common/saltarlink.h`, header-only, feature 309) resolves `..` by
`dst -= 2`, a walk back to a `\` or the start, then `dst++` "when it moved" - right after a
previous separator, but at the start it keeps the first byte of the dropped component. Replace the
`..` branch with: when the output is not empty, drop its trailing separator and walk back to just
after the previous separator (or to the start); when it is empty, drop the `..` (never above the
root). Nothing else in the loop changes. The single caller (`CArchive::ReadArchiveHeader`,
`src/plugins/tar/untar.cpp`) needs no change: an empty result already takes the "skip invalid
names" branch (395). Fix the saltests pin and add checks; update the comments that call the rule
wrong (`saltarlink.h` header, `untar.cpp` link-name comment) without changing 309's link rule.

## Technical Context

**Language/Version**: C++20 (MSVC v143); header `src/common/saltarlink.h`, used by plug-in `tar` and `saltests`
**Primary Dependencies**: none new
**Storage**: N/A
**Testing**: `saltests` (`TestTarLink309`, `TestCpioKeepsGroupMember394`, a new `TestTarDotDot396` with a brute-force comparison against a reference implementation for names without `..` and a reference resolver for names with it); hidden-desktop probe `probe/dotdot_probe.ps1`; regression probes of 306 / 308 / 309 / 395
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: unchanged (linear in the name length)
**Constraints**: the output is never longer than the input (callers allocate `strlen + 1`); plug-in ABI untouched; no UI string
**Scale/Scope**: ~15 lines in `saltarlink.h`, comments in `untar.cpp`, ~40 lines of saltests

## Constitution Check

- I Build reproducibility: no new dependency. PASS
- II Backward compatibility: every name without a `..` component gives the same result (brute-force
  saltests check); names with `..` whose dropped component was not the first one give the same
  result; only the wrong results change. PASS
- III Incremental modernization: a local fix of one shared rule. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no interface change (the header is internal to the tar plug-in and
  saltests). PASS
- VI UI consistency: no UI change. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/396-tar-dotdot-name/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/name-rule.md
├── fix-log.md
├── probe/ (dotdot_probe.ps1, mkdotdot.py, results)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/saltarlink.h        # SalTarNormalizeNameU8: the ".." branch; header comment
src/plugins/tar/untar.cpp      # comment at the link-name normalization (no code change)
src/saltests/saltests.cpp      # TarNorm309 pin, new TestTarDotDot396
```

**Structure Decision**: the existing header-only rule (CLAUDE.md: shared rules for plug-ins are
header-only) - no new file.

## Complexity Tracking

None.
