# Implementation Plan: Importing a configuration file never writes or deletes keys outside the program's own root

**Branch**: `263-import-foreign-reg-keys` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/263-import-foreign-reg-keys/spec.md`

## Summary

The reglib parser `Parse()` (`src/reglib/src/regparse.cpp`) gets an optional *allowed root*: when it
is given, every key line and every delete line must name `HKEY_CURRENT_USER` + the root or a key
below it, otherwise `Parse()` stops before acting on that line and returns the new code
`RPE_KEY_OUTSIDE_ROOT` (appended to `eRPE_ERROR`). `ImportConfiguration()` (`src/salamdr2.cpp`)
passes `SalamanderConfigurationRoots[0]` to both passes (the check in memory and the write to the
registry); `RPE_KEY_OUTSIDE_ROOT` and "no key under our root" are reported with the existing
`IDS_IMPORTCFG_NOTREG`, the question `IDS_IMPORTCFG_NOTOURVER` is no longer asked. The decision
"is this key name inside the root" is a header-only rule `src/common/salregroot.h`
(`SalRegKeyIsInsideRoot`) checked by `saltests`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; reglib (compiled into the core, `INSIDE_SALAMANDER`, code-page
build: `LPTSTR` = `char*`, UTF-8 names since feature 174)
**Storage**: the registry key `HKCU\Software\Tandem Commander\0.1` - only narrowed, layout unchanged
**Testing**: `saltests` (the rule), the hidden-desktop probe `probe/import263_probe.ps1` (5 rows),
build
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: one prefix comparison per key line - negligible
**Constraints**: no new UI string (rule 084), no plug-in ABI change, files of our own export import
unchanged, nothing written before the whole file is checked
**Scale/Scope**: `src/common/salregroot.h` (new), `src/reglib/src/regparse.{h,cpp}`,
`src/salamdr2.cpp`, `src/saltests/saltests.cpp`, `src/vcxproj/salamand.vcxproj{,.filters}` (header
listed)

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Build reproducibility | no dependency, header-only rule | PASS |
| II Backward compatibility | the program's own exports import unchanged (probe OURS, OWNDEL); the removed path ("import it anyway" and foreign keys in a mixed file) is the one that wrote other products' keys, which principle II itself forbids ("never writes Open Salamander, Altap Salamander or Newt Commander configuration") - justified below | PASS (justified) |
| III Incremental modernization | a guard in the existing parser, no rewrite | PASS |
| IV Windows commitment | WinAPI only | PASS |
| V Plug-in architecture | reglib's `Parse()` is internal to the core (one caller); `spl_*.h` untouched | PASS |
| VI UI consistency | existing message text, no new string | PASS |

Re-check after Phase 1: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/263-import-foreign-reg-keys/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/import-root-rule.md
├── probe/import263_probe.ps1, result_*.txt
├── fix-log.md  (running log)
└── tasks.md   (speckit-tasks)
```

### Source Code (repository root)

```text
src/common/salregroot.h          new: SalRegKeyIsInsideRoot (pure rule)
src/reglib/src/regparse.h        RPE_KEY_OUTSIDE_ROOT appended; Parse(..., LPCTSTR onlyUnderHKCU = NULL)
src/reglib/src/regparse.cpp      the check at every key / delete line
src/salamdr2.cpp                 ImportConfiguration: both passes restricted; refusal messages
src/saltests/saltests.cpp        TestRegImportRoot263
src/vcxproj/salamand.vcxproj(.filters)  the new header listed
```

**Structure Decision**: core only; the rule header-only in `src/common/` like the other pure rules.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| A file the old build imported (after *Yes*, or a mixed file silently) is now refused | the old behaviour wrote and deleted other programs' keys (measured) and could write Altap / Open Salamander keys, contrary to principle II | skipping only the foreign keys guesses the intent of a file the program never writes, and naming them needs a new UI string (spec Clarifications) |
