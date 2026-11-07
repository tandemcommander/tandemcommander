# Implementation Plan: The mask hints link fits in every translated dialog

**Branch**: `409-mask-hints-clipped` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/409-mask-hints-clipped/spec.md`

## Summary

The right-aligned mask-hints link (control 102, `IDC_FILEMASK_HINT`) is narrower than its translated
text in 11 core dialogs, so its left part is cut. Fix: (1) pin shorter / corrected wordings for
German, French, Spanish and Romanian in `translations/ui-overrides.json`; (2) widen the 11 English
controls in `src/lang/lang.rc` to the left, keeping their right edge, to 84 du ("mask hints") and
120 du (D2350 "extended mask hints") - at least the merge's own width estimate of every enabled
language's text, so the merge's widening pass leaves them alone; (3) run the two-stage `.slt`
refresh of module `salamand` (geometry and pins reach every language); (4) prove it with the
layout checker, a room check of the English layout and pictures of Compare Directories.

## Technical Context

**Language/Version**: Win32 resource script (`lang.rc`), Python 3 tools (`tools/translate`), PowerShell probes
**Primary Dependencies**: `tools/translate` merge (DeepL only for gaps - expected 0), `build_langs.cmd`
**Storage**: N/A (the probe backs up and restores the product's registry key)
**Testing**: `specs/166-translation-layout/probe/layout_check.py`; a new room check `specs/409-mask-hints-clipped/probe/hint_room_check.py`; hidden-desktop picture probe `specs/409-mask-hints-clipped/probe/comparedirs_shot.ps1`
**Target Platform**: Windows 11, x64
**Project Type**: desktop application (translations and dialog layout)
**Performance Goals**: N/A
**Constraints**: right edge of every link unchanged; no new overlap or `CROSS` row; English unchanged to the user
**Scale/Scope**: 11 dialogs x 8 enabled languages; module `salamand` only

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | No new tool or dependency; `build.cmd full` imports the refreshed `.slt`. PASS |
| II. Backward compatibility | No setting, file or plug-in interface changes; English dialogs look the same. PASS |
| III. Incremental modernization | A layout fix in place; upstream names stay. PASS |
| IV. Windows commitment | Pure resource change. PASS |
| V. Plug-in architecture | Untouched. PASS |
| VI. UI consistency | Link text fits; right alignment with the field above kept. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/409-mask-hints-clipped/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
├── closing-report.md
└── probe/
    ├── hint_room_check.py      # English layout: right edge kept, no new overlap, estimate fits
    ├── comparedirs_shot.ps1    # hidden-desktop picture of Compare Directories in a language
    └── result_*.txt, *.png
```

### Source Code (repository root)

```text
src/lang/lang.rc                       # 11 RTEXT IDC_FILEMASK_HINT rows: x and cx
translations/ui-overrides.json         # salamand: "#mask hints", "#extended mask hints" pins (de, fr, es, ro)
translations/<language>/salamand.slt   # refreshed by translate.merge (geometry + pins)
translations/<language>/salamand.origin
```

**Structure Decision**: no code change; the English template and the translation corpus only.

## Complexity Tracking

None.
