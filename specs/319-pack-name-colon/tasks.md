# Tasks: Pack refuses an archive name whose last part holds a colon

**Input**: Design documents from `specs/319-pack-name-colon/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the spec (FR-005, SC-001 - SC-003): saltests checks of the rule and the
hidden-desktop probe rows.

## Phase 1: Setup

- [X] T001 Record the measurement at e9c35c2e (probe `before`: 6 FAIL / 18 PASS, the command, reachability, consumers of `SalPackName*`) in specs/319-pack-name-colon/fix-log.md

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `SalPackNameHasStreamColon(const char* fullName)` (drive prefix `X:` skipped, last part after the last `\` or `/`, TRUE when it holds `:`) and extend the header comment for 319 in src/common/salpackname.h
- [X] T003 Add `TestPackName319` (colon in the last part relative / absolute / UNC / after `/`, leading and only colon, UTF-8 name with a colon; not refused: drive prefixes `C:\x.zip`, `C:x.zip`, a colon in a folder part only, full-width colon U+FF1A, no colon, NULL, empty, a name ending in a separator) and call it next to `TestPackName318` in src/saltests/saltests.cpp

## Phase 3: User Story 1 - A colon in the archive name is refused (P1) MVP

**Goal**: OK on `report:zip`, `rep:x.zip`, `<src>\abs:x.zip`, `plain/rep:x.zip` shows "The path specified is invalid." and the dialog again; nothing created.
**Independent Test**: probe rows colon-ext, colon-mid, colon-abs, colon-slash.

- [X] T004 [US1] In `CFilesWindow::Pack`, refuse after `SalGetFullName` also when `SalPackNameHasStreamColon(fileBuf)` (the same `IDS_PATHISINVALID` route, not gated by `FileExists`), and extend the comment for 319 in src/fileswn7.cpp

## Phase 4: User Story 2 - An existing file is not given a hidden stream (P1)

**Goal**: an existing `report` (with or without a stream `zip.zip`) stays unchanged; nothing new.
**Independent Test**: probe rows colon-exist, colon-stream.

- [X] T005 [US2] Confirm that T004's refusal is unconditional (an existing stream `report:zip.zip` counts as existing for `FileExists`) - the probe rows colon-exist and colon-stream in specs/319-pack-name-colon/probe/pack319_probe.ps1 cover it; no further code

## Phase 5: User Story 3 - Drive-letter names and the other names pack as before (P2)

**Goal**: item 0, `<src>\abs.zip`, `C:rel.zip` packed; `report.` and the empty entry refused as before.
**Independent Test**: control rows of the probe; 318's probe.

- [X] T006 [US3] Build (`.\build.cmd`), run saltests (0 failed) and a negative control (the rule's colon test disabled temporarily -> the new checks fail), record in specs/319-pack-name-colon/fix-log.md
- [X] T007 [US3] Run specs/319-pack-name-colon/probe/pack319_probe.ps1 `after` on the hidden desktop (all PASS, registry identical) -> specs/319-pack-name-colon/probe/result_after.txt
- [X] T008 [US3] Run 318's probe as a regression -> specs/319-pack-name-colon/probe/regress_318.txt (all PASS)

## Phase 6: Polish

- [X] T009 `python tools/check_encoding.py --strict` (TOTAL: 0) and clang-format of the changed lines in src/common/salpackname.h, src/saltests/saltests.cpp, src/fileswn7.cpp; results in specs/319-pack-name-colon/fix-log.md

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009. US1 and US2 share T004;
US3 is the verification of both.

## Parallel opportunities

T002 and the probe preparation are independent; T007 and T008 run one after another (one program
at a time on the hidden desktop).

## Implementation strategy

MVP = T002 - T004 (the rule and the refusal); the rest proves it.
