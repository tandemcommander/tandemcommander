# Tasks: The mask hints link fits in every translated dialog

**Input**: `specs/409-mask-hints-clipped/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)

## Phase 1: Setup

- [X] T001 Start `specs/409-mask-hints-clipped/fix-log.md` with the HEAD measurement (layout checker output at f38220a2: 55 clipped `#102` rows in enabled languages, the per-language counts, the CROSS total) and keep `%TEMP%\tcpa\lc_before.txt` as the baseline

## Phase 2: Foundational

- [X] T002 Write the room check `specs/409-mask-hints-clipped/probe/hint_room_check.py`: reads the English template `src/lang/lang.rc` at HEAD (`git show <base>:src/lang/lang.rc`) and in the tree, and for every `IDC_FILEMASK_HINT` row checks the right edge is unchanged, the new rectangle overlaps no control it did not overlap at HEAD (dropdown combos at their closed height), it stays inside the dialog, and its width is at least `translate.layout.estimate_width` of every enabled language's current `.slt` text; prints one PASS/FAIL row per dialog and `TOTAL: <n> failed`
- [X] T003 Run the room check at HEAD as the negative control (expect FAIL rows: widths below the estimates) and record it in `specs/409-mask-hints-clipped/fix-log.md`

## Phase 3: User Story 1 + 2 - the link fits in all 11 dialogs (P1)

**Goal**: no clipped `#102` row in an enabled language; English unchanged.
**Independent test**: quickstart steps 1-3.

- [X] T004 [US1] Widen the 11 `RTEXT ... IDC_FILEMASK_HINT` rows of `src/lang/lang.rc` to the left keeping `x + cx` (cx 84, D2350 120), per research.md R3
- [X] T005 [US1] Pin the wordings of research.md R5 in `translations/ui-overrides.json` (`salamand.german|french|spanish|romanian`, keys `#mask hints` and `#extended mask hints`) with a `_feature_409` note list
- [X] T006 [US1] Translation refresh of module `salamand` by stop-rules §2.13: build, export templates, dry run (expect 0 gaps beyond the module's leftover `english_fallback` rows), real merge with `--formality prefer_more`, read back, `slt --verify`, `build.cmd full`; record in `fix-log.md` *Translations* (pins, gaps, characters, layout drift per language)
- [X] T007 [US1] Run the layout checker and the room check after the change; compare the `CROSS` rows with the baseline; record in `fix-log.md`
- [X] T008 [US1] Write `specs/409-mask-hints-clipped/probe/comparedirs_shot.ps1` (style of `specs/166-translation-layout/probe/cfgshot_probe.ps1`: registry backup/restore, refuse when the program runs, command 737 Compare Directories, PrintWindow picture) and take pictures in czech, french and english before (build of HEAD's translations) and after; record the rows in `fix-log.md`

## Phase 4: User Story 3 - the Romanian text (P2)

- [X] T009 [US3] Check every Romanian `#102` row in `translations/romanian/salamand.slt` reads "indicii pentru măști" (D2350 "indicii pentru măști extinse"); record in `fix-log.md`

## Phase 5: Polish

- [X] T010 Log a line in each `translations-clipped-labels-<lang>` item (`BL log`) that its `#102` rows are done by feature 409
- [X] T011 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `build.cmd full` -> `BUILD SUCCEEDED`
- [X] T012 Draft the answer to GitHub issue #11 in `specs/409-mask-hints-clipped/reply.md` (copy `issue.md` too)

## Dependencies

T001 -> T002 -> T003 -> T004/T005 (parallel, different files) -> T006 -> T007, T008, T009 -> T010-T012.

## Implementation strategy

One increment: the width and the pins land together with the refresh (T004-T006); everything else is verification and records.
