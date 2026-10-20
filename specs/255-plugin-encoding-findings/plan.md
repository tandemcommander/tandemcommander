# Implementation Plan: every finding of the plug-in encoding scan has a verdict

**Branch**: `255-plugin-encoding-findings` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/255-plugin-encoding-findings/spec.md`

## Summary

Read each of the 78 sites `tools/check_encoding.py --plugins` reports (at e849e68c), with its
producer and its consumer, and decide: *false positive* - annotate the line with the guard's
existing marker `// encoding-check: allow <rule> - <reason>`; *real defect* - leave the line
reported and record a backlog item per plug-in and defect class. The verdicts go into
`verdicts.md`; the scan afterwards reports exactly the real-defect rows. No product behaviour
changes (comments only in plug-in sources); the guard script itself is unchanged.

## Technical Context

**Language/Version**: C++20 (MSVC v143) for the annotated sources; Python 3 for the guard
**Primary Dependencies**: none new
**Storage**: N/A
**Testing**: `python tools/check_encoding.py --plugins` (count and sites), `--strict` (core stays
0), `build.cmd` (comments compile), a negative control (one added bad line is reported)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + its plug-ins; this feature touches the review record only
**Performance Goals**: N/A
**Constraints**: plug-ins are built without `UNICODE` (no `CharacterSet` in
`src/plugins/shared/vcxproj/*.props` or the plug-in projects) - un-suffixed Win32 calls are ANSI;
plug-in text from the core is UTF-8 (interface 104, `splunicode.h`), names are WTF-8 (066, 089)
**Scale/Scope**: 78 findings in 22 plug-ins (+ `shared/lukas`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no build input changes except comments; `build.cmd` unchanged | PASS |
| II. Backward compatibility | no behaviour change; plug-in ABI untouched | PASS |
| III. Incremental modernization | review first, fixes as their own features (item's Approach) | PASS |
| IV. Windows commitment | no change | PASS |
| V. Plugin architecture preservation | no interface change; markers are comments | PASS |
| VI. UI consistency | no UI change | PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/255-plugin-encoding-findings/
├── spec.md
├── plan.md
├── research.md      # verdict criteria per rule, grouping of real defects
├── data-model.md    # the verdict table's shape
├── quickstart.md    # how to re-check the result
├── verdicts.md      # the 78 rows (written during implementation)
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/plugins/<plugin>/...   # one-line `// encoding-check: allow ...` comments on false positives
backlog/items/<slug>/      # one item per real-defect group (via the backlog tool)
```

**Structure Decision**: no new code; annotations stay next to the code they explain (the guard's
documented mechanism), the table in the feature folder.

## Complexity Tracking

None.
