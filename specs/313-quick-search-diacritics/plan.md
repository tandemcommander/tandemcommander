# Implementation Plan: Quick search ignores diacritics

**Branch**: `313-quick-search-diacritics` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/313-quick-search-diacritics/spec.md` (backlog item
`quick-search-ignores-diacritics`)

## Summary

The new quick-search mode (feature 244, unreleased - `CHANGELOG.md` *0.1.11 — unreleased*)
compares *keys*: per character the canonical decomposition in lower case. This feature makes the
key of a character also drop the combining marks of the Latin/Greek/Cyrillic diacritical-mark
blocks and fold seven letters without a decomposition (`ł ø đ ß ẞ æ œ ı` and capitals). The change
lives in one pure function of `src/common/salquickfilter.h` (`SalQFDetail::CharKeySystem`) plus
the two places that must now accept a character with an **empty** key (the per-character cache
and `SalQFBuildKey`). The panel code (`src/fileswn0.cpp`) and the 0.1.10 rule are untouched.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Windows `NormalizeString`, `LCMapStringEx` (already used); no new ones
**Storage**: N/A (no setting, no registry value)
**Testing**: `saltests` (pure rules), hidden-desktop probes `probe/qs313_probe.ps1` and
`specs/244-quick-search-substring-filter/probe/qs244_probe.ps1` (functional, option off, `-Perf`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: typing over 100,000 names as in 244 (Release <= 32 ms per keystroke after
the first; first non-ASCII keystroke within 10 % of the 291 ms baseline)
**Constraints**: header-only rule, no allocation per character, per-character cache kept (the key
of a BMP character is computed once)
**Scale/Scope**: one header, its saltests section, the manual page, the changelog

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency; vendored only. PASS |
| II. Backward compatibility | The changed rule is the new mode of feature 244, which is not released yet (0.1.11 unreleased); the option-off rule (0.1.10) is untouched and checked (saltests M1 0 differences, probe D09/D10 and the 244 option-off run identical). The direction (ignore accents) is the maintainer's decision of 2026-10-22. PASS |
| III. Incremental modernization | One pure function; the panel code unchanged. PASS |
| IV. Windows commitment | Uses Win32 normalisation/case mapping as before. PASS |
| V. Plugin architecture | No plug-in interface touched (`salquickfilter.h` is core-only). PASS |
| VI. UI consistency | No new UI, no string; the manual page updated. PASS |

Standing rules touched: WTF-8 names (keys decode WTF-8 as before; no `A` API, no `CP_ACP`);
"never cut a path" (no buffer of a name is shortened; key buffers grow on the heap as before).

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/313-quick-search-diacritics/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/salquickfilter-fold.md
├── fix-log.md
├── probe/qs313_probe.ps1 (+ result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salquickfilter.h        the folding (CharKeySystem), the empty-key cache marker,
                                   SalQFBuildKey / SalQFBuildMaskKeys accepting empty keys,
                                   header comment
src/saltests/saltests.cpp          TestQuickFilter244: adjusted cases + the 313 folding cases
help/src/hh/salamand/basicwork_qsearch.htm   "accents are ignored"
CHANGELOG.md                       entry under 0.1.11 — unreleased
```

**Structure Decision**: existing single-project layout; no new file in `src/`.

## Complexity Tracking

None.
