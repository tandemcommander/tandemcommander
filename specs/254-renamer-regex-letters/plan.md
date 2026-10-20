# Implementation Plan: Renamer regular expressions work on whole letters of UTF-8 names

**Branch**: `254-renamer-regex-letters` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/254-renamer-regex-letters/spec.md`

## Summary

The Renamer's regular-expression engine (`src/plugins/renamer/regexp.cpp`, Henry Spencer's
byte engine) learns UTF-8 "letters" (units): every point where it steps, backs off, classifies or
starts a match works on whole units decided by a new header-only rule set
`src/common/salu8letter.h` (saltests-checked). Classes get a variable-length operand: the ASCII /
invalid-byte bitmap of today plus code-point ranges and Unicode type tests for everything else.
`\x` escapes that form one character become one unit. Feature 210's shared fold
(`salu8fold.h`) folds the final sigma with sigma. `CRenamer::RESubst` skips a whole unit after an
empty match; the plain "Whole words" search uses the new classification; the histories dedupe by
`SalNameOrderEqualCI`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143; the Renamer builds with `/J` (unsigned
`char`) - the shared header must not depend on it (saltests builds with signed `char`)
**Primary Dependencies**: Win32 (`GetStringTypeW`, `CharLowerBuffW`), `icu.dll` from System32
(`u_charType`, loaded at first use with `LOAD_LIBRARY_SEARCH_SYSTEM32`, optional)
**Storage**: N/A (nothing stored; the Renamer's registry options unchanged)
**Testing**: `saltests` (new checks for `salu8letter.h` and the sigma fold), hidden-desktop probe
`probe/ren_regex_probe.ps1` (19 rows), regression probes of 196, 199, 206-210
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (Renamer `.spl`)
**Performance Goals**: names are short (< 1 KB); per-unit classification calls are acceptable
**Constraints**: ASCII-only expressions on ASCII names behave exactly as before (FR-012); no UI
string added or removed; plug-in ABI untouched
**Scale/Scope**: `regexp.cpp` (compile + match), `regexp.h`, `crenamer.cpp` (RESubst skip, whole
words), `dialogs.cpp` (history), `salu8fold.h` (sigma), new `salu8letter.h`, `saltests.cpp`

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency in the build; `icu.dll` is a system DLL loaded at run time, nothing vendored, nothing linked | PASS |
| II. Backward compatibility | ASCII expressions on ASCII names unchanged (probe controls asc-wb, asc-dot; regression probes); the registry options and their meaning unchanged | PASS |
| III. Incremental modernization | the engine is kept (syntax, error codes, options); only stepping and classes change | PASS |
| IV. Windows commitment | `icu.dll` is part of Windows 10 1903+ / every Windows 11; fallback when absent | PASS |
| V. Plugin architecture | no change to `spl_*.h`, `LAST_VERSION_OF_SALAMANDER`, any contract | PASS |
| VI. UI consistency | no dialog or string change | PASS |

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/254-renamer-regex-letters/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/salu8letter.md     # the header's rules (internal contract, saltests)
├── fix-log.md
├── probe/ren_regex_probe.ps1    # + result_*.txt
└── tasks.md
```

### Source Code

```text
src/common/salu8letter.h          # NEW: units (step, back, boundary), classification, word test
src/common/salu8fold.h            # SalU8FoldCodePoint (final sigma), whole-word helpers moved out
src/plugins/renamer/regexp.cpp    # engine: units in '.', classes, literals, \x, \b, look-behind,
                                  # STAR/PLUS/UG*, RegRepeat, RegMatchSimple, RegExec starts
src/plugins/renamer/regexp.h      # class-builder members, unit helpers
src/plugins/renamer/crenamer.cpp  # RESubst: empty-match skip by a unit; whole words via salu8letter.h
src/plugins/renamer/crename2.cpp  # include unchanged (SalU8Advance stays in salu8fold.h)
src/plugins/renamer/dialogs.cpp   # HistoryComboBox: SalNameOrderEqualCI
src/saltests/saltests.cpp         # checks for salu8letter.h, sigma
```

**Structure Decision**: one shared header for the pure rules (CLAUDE.md working method), engine
changes local to the Renamer.

## Complexity Tracking

None.
