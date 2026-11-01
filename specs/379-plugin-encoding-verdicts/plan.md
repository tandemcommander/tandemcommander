# Implementation Plan: every finding of the plug-in encoding scan has a verdict

**Branch**: `379-plugin-encoding-verdicts` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/379-plugin-encoding-verdicts/spec.md`

## Summary

Finish feature 255's review of the sites `tools/check_encoding.py --plugins` reports, at HEAD
3e0da39c: keep 255's verdicts that its reviews left standing (re-checked against the lines at HEAD,
carried over as `// encoding-check: allow <rule> - <reason>` markers), record row 41 as fixed by
269, re-judge rows 3 / 67 / 68 / 75 as latent real defects with one backlog item per plug-in, give
the 4 new Code Viewer findings their verdict, and write the complete table (`verdicts.md`, 82
sites). The scan afterwards reports exactly the real-defect rows. Comments only in the sources; the
guard script is unchanged.

## Technical Context

**Language/Version**: C++20 (MSVC v143) for the annotated sources; Python 3 for the guard
**Primary Dependencies**: none new
**Storage**: N/A
**Testing**: `python tools/check_encoding.py --plugins` (count and sites), `--strict` (core stays
0), `build.cmd` (comments compile), a negative control (one added bad line is reported; markers
stripped in a copy give back the baseline)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + its plug-ins; this feature touches the review record only
**Performance Goals**: N/A
**Constraints**: plug-ins are built without `UNICODE` - un-suffixed Win32 calls are ANSI; plug-in
text from the core is UTF-8, names WTF-8 (066, 089, interface 104)
**Scale/Scope**: 82 sites (78 of 239 + 4 new) in 19 plug-ins (+ `shared/lukas`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | only comment lines change; `build.cmd` unchanged | PASS |
| II. Backward compatibility | no behaviour change; plug-in ABI untouched | PASS |
| III. Incremental modernization | review first, fixes as their own features (item's Approach) | PASS |
| IV. Windows commitment | no change | PASS |
| V. Plugin architecture preservation | no interface change; markers are comments | PASS |
| VI. UI consistency | no UI change, no strings | PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/379-plugin-encoding-verdicts/
├── spec.md
├── plan.md
├── research.md            # verdict criteria, the re-judged rows, grouping
├── data-model.md          # the verdict table's shape
├── quickstart.md          # how to re-check the result
├── verdicts.md            # the 82 rows (implementation)
├── baseline_3e0da39c.txt  # the scan at HEAD before the feature (81)
├── 255-*.{md,txt}         # feature 255's record (carried over)
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/plugins/<plugin>/...   # one-line `// encoding-check: allow ...` comments on false positives
backlog/items/<slug>/      # one item per real-defect group (via bin/backlog.sh)
```

**Structure Decision**: no new code; annotations next to the code they explain (the guard's
documented mechanism), the table in the feature folder.

## Complexity Tracking

None.
