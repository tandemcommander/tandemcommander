# Implementation Plan: Registry Editor shows the "KEY" text correctly in every language

**Branch**: `124-regedt-key-text` (from `main` at `50321995`) | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)
**Input**: GitHub issue #3 (`issues/issue_3.md`)

## Summary

The Registry Editor plug-in gives the panel two texts that it loads from its language module
as code-page text although the core displays them as UTF-8: the word for a key (information
line; the Size column only works through the core's fallback for invalid UTF-8) and the
selection sentence. Both become UTF-8, made from the wide resource text. The word is kept a
second time as wide text for the plug-in's own Find window, which today converts the code-page
copy and would be broken by a UTF-8 one. Nothing outside `src/plugins/regedt` changes.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; the plug-in's existing `LoadStrW` (`SG->LoadStrW`) and `WStrToU8` (`utils.h`)
**Storage**: N/A
**Testing**: GUI probe on the hidden desktop (`probe/regkey_probe.ps1`: capture + text recognition for the owner-drawn panel and information line, `LVM_GETITEMTEXTW` for the Find window), run on the 0.1.9 baseline and on the fixed build, nine languages; a static check of every translation's length (`probe/check_key_lengths.py`); `tools/check_encoding.py` strict; `saltests` unchanged (it cannot compile plug-in code and no core rule changes)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, one plug-in (`regedt.spl`)
**Performance Goals**: none - the texts are prepared once (`InitFS`) or per information-line update, as today
**Constraints**: plug-in interface 107 unchanged; no new or changed string (no `.slt` refresh); a text is never cut (CLAUDE.md, 097/098/101)
**Scale/Scope**: 4 source files of one plug-in, about 40 changed lines

## Constitution Check

| Principle | Verdict |
|-----------|---------|
| I. Build reproducibility | PASS - no build, dependency or project change |
| II. Backward compatibility | PASS - no configuration, registry or file format touched |
| III. Incremental modernization | PASS - the plug-in moves two more texts to the UTF-8 contract it already follows for names |
| IV. Windows commitment | PASS |
| V. Plugin architecture preservation | PASS - no interface change; the plug-in uses services it already uses |
| VI. UI consistency | PASS - the texts are the translators' own, shown as written |

Re-checked after design: unchanged.

## Stages

| Stage | Content |
|---|---|
| S0 measure | done before the spec: `probe/regkey_result_before_v019.txt` (3 languages wrong on the focused line, 5 on the selection line, Size column and Find window right everywhere) |
| S1 key text | `fs.cpp` / `regedt.h`: `KeyText` becomes UTF-8 with room for any translation, `KeyTextW` is the wide original; both set in `InitFS` from `LoadStrW(IDS_KEY)`; a text that does not fit or does not convert is replaced by `KEY` (never cut). `finddlg.cpp`: the Size cell copies `KeyTextW` |
| S2 selection text | `regedt.cpp` / `regedt.h`: `LoadStrU8(resID, buf, size)` (wide text to UTF-8, fallback to the code-page text when the conversion is refused). `fs4.cpp`: `ExpandPluralSelection` and the size prefix take their templates through it; the template buffers grow (a UTF-8 template is up to three times longer) |
| S3 tests and gates | Debug build; `tools/check_encoding.py`; `probe/check_key_lengths.py`; probe on the fixed build (all nine languages, 0 FAIL) and the before/after table; independent review (refute-first); records (`fix-log.md`, FEATURE-HISTORY, CHANGELOG `[Unreleased]`, `issues/issue_3_report.md`) |

## Project Structure

```text
src/plugins/regedt/
├── regedt.h      # KeyText (UTF-8) + KeyTextW, LoadStrU8 declaration
├── regedt.cpp    # LoadStrU8
├── fs.cpp        # InitFS: both forms of the key text
├── fs4.cpp       # selection templates as UTF-8
└── finddlg.cpp   # Size cell from KeyTextW

specs/124-regedt-key-text/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
└── probe/        # regkey_probe.ps1, shotocr_lib.ps1, check_key_lengths.py, results, shots/
```

**Structure Decision**: the plug-in's own files only. No header under `src/common/`: there is
no rule here that another module shares - the decision is "which encoding does this sink take",
which the plug-in already answers with `WStrToU8` for names.

No contracts directory: the feature exposes no interface (plug-in interface 107 is untouched).

## Complexity Tracking

No violations.
