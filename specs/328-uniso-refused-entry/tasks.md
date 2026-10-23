# Tasks: An ISO entry the panel listing refuses is left out and reported

**Input**: `specs/328-uniso-refused-entry/` - spec.md, plan.md, research.md, data-model.md, quickstart.md
**Tests**: saltests checks for the pure rule (CLAUDE.md: pure decisions in `src/common/` with saltests) and the hidden-desktop probe `probe/iso328_probe.ps1`.

## Phase 1: Setup

- [ ] T001 Start `specs/328-uniso-refused-entry/fix-log.md` with the measurement of step 3 (probe 0 / 6 at d61d0612, `probe/result_before.txt`, the gdeep.iso record dump of research R2)

## Phase 2: Foundational

- [ ] T002 [P] Create the header-only rule `src/common/salisonamefit.h`: `SalIsoPickFileName` (Rock Ridge / ISO 9660 / left out by `SalListingAcceptsFileU8`), `SalIsoFolderKeepsRockRidge` (subtree fits, length, counts), `CSalListingLeftOut` (count, first 10 paths, `Incomplete`, `Text`)
- [ ] T003 Add `TestIsoNameFit328` to `src/saltests/saltests.cpp` (include, call from `main`): file choice at the bounds, folder choice incl. the deep.iso numbers of research R3, the report text (whole paths, 10 then `...`, leading `\` dropped)

## Phase 3: User Story 1 - a deep image opens whole except what cannot be listed (P1)

**Independent test**: probe rows J-COPY, G-COPY, L-COPY.

- [ ] T004 [US1] `src/plugins/uniso/isoimage.h/.cpp`: `CISOImage` holds a `CSalListingLeftOut ListingLeftOut` and `NoteLeftOut(path, name)` / `NoteIncomplete()`
- [ ] T005 [US1] `src/plugins/uniso/iso9660.cpp/.h`: `AddFileDir` returns added / left out / failed (memory); it checks the listing rule first; a refused entry is noted on the image, never `dir->Clear`, no "Error"; a core refusal after the rule passed shows `IDS_ERROR` as before but without `Clear` and marks the listing incomplete
- [ ] T006 [US1] `src/plugins/uniso/iso9660.cpp` `ListDirectoryRe`: a left-out entry does not change `ret` (later folders are still descended), a left-out folder is not descended; count mode (`FitCheck`) counts the entries it would list (`FitCount`)
- [ ] T007 [US1] `src/plugins/uniso/uniso.cpp` `ListArchive`: after `ListImage`, when entries were left out, one error box (`GetErrorText(ERROR_FILENAME_EXCED_RANGE)` + the paths, `CSalListingLeftOut::Text`) and `CPluginDataInterface::ListingLeftOut` set (`uniso.h`)

## Phase 4: User Story 2 - Unpack + delete keeps an image not wholly extracted (P1)

**Independent test**: probe rows J-UNP-DEL, G-UNP-DEL.

- [ ] T008 [US2] `src/plugins/uniso/uniso.cpp` `UnpackWholeArchive`: when the listing's plug-in data says entries were left out, the extraction still runs and the function returns FALSE (the core keeps the image)

## Phase 5: User Story 3 - a deep Rock Ridge tree keeps its names where they fit (P2)

**Independent test**: probe rows G-COPY, X-COPY, L-COPY (names).

- [ ] T009 [US3] `src/plugins/uniso/iso9660.cpp` `ListDirectory`: the whole-volume fit check runs for every non-Joliet volume; when it finds a refusal the listing runs in decision mode (`Decide`) - `SuspVolume` stays as detected
- [ ] T010 [US3] `src/plugins/uniso/iso9660.cpp`: the ISO 9660 name of a Rock Ridge record (`MakeIsoName`, the raw identifier route of `MakeListedName`); count walks with `FitIsoNames`; in decision mode a Rock Ridge file uses `SalIsoPickFileName`, a Rock Ridge folder `SalIsoFolderKeepsRockRidge` from an all-Rock-Ridge fit walk and two count walks (its subtree then leaves decision mode when it fits whole); mode members saved and restored around nested walks

## Phase 6: Polish

- [ ] T011 Build (`.\build.cmd`), encoding guard (`python tools/check_encoding.py --strict`), saltests - numbers into `fix-log.md`
- [ ] T012 Probe `probe/iso328_probe.ps1` after -> `probe/result_after.txt` (12 / 0); negative controls (the old `Clear` path; decision mode off) recorded in `fix-log.md`
- [ ] T013 Regression probes 326 (28 / 0), 327 (77 / 0), 322 (18 / 0) -> `probe/regress_*.txt`
- [ ] T014 Inbox item for the UDF / XDVDFS / HFS+ / audio readers' refusal handling (`measure:328`)

## Dependencies

T001 -> T002 -> T003; T004 -> T005 -> T006 -> T007 -> T008; T006 -> T009 -> T010; T011..T013 after all code; T014 any time.
Parallel: T002 with T004 (different files).

## Implementation strategy

MVP = US1 + US2 (no wipe, report, fail-closed unpack); US3 then restores Rock Ridge names without
losing entries. All in one feature.
