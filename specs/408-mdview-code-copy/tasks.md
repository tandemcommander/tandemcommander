# Tasks: Markdown Viewer — copy a code block to the clipboard

**Input**: `specs/408-mdview-code-copy/` (spec, plan, research, data-model, contracts, quickstart)
**Tests**: required by the project rules (pure rules in the mdview harness, a GUI probe).

## Phase 1: Setup

- [ ] T001 Add the string ids `IDS_CODE_COPY` 2197, `IDS_CODE_COPY_TIP` 2198, `IDS_CODE_COPIED` 2199 (free slots of bundle 137) to `src/plugins/mdview/mdview.rh2` and their English texts "Copy", "Copy the code to the clipboard", "Copied" to `src/plugins/mdview/lang/lang.rc2`

## Phase 2: Foundational (generator and pure rules)

- [ ] T002 Declare `MdCopyUi`, `MdHtmlResult::codeBlocks`, `MdCodeClipboardText`, `MdParseCopyLink` (`MDCOPY_NONE/REFUSED/OK`, `MD_COPY_FAMILY`) and the new `copyUi` parameter of `MdRenderHtml` (before `lim`) in `src/plugins/mdview/htmlgen.h`
- [ ] T003 In `src/plugins/mdview/htmlgen.cpp`: `EmitCodeBlock` wraps the block in `div.tc-code` with the `a.tc-copy` link and records the source in `codeBlocks` when `copyUi` has a base; `MdRenderHtml` appends the copy CSS and the two `tc-copied-<k>` notices only when at least one block was emitted; `MdBuildSourceHtml` clears `codeBlocks`
- [ ] T004 Implement `MdCodeClipboardText` and `MdParseCopyLink` in `src/plugins/mdview/htmlgen.cpp` per `contracts/copy-address.md`
- [ ] T005 Add harness assertions in `tests/mdview_htmlgen_test/test_main.cpp`: one control per block (fenced with/without language, indented, in a list, in a quote, empty), `codeBlocks` content, link `href` = base + n, escaped label/tooltip/notice, the CSS and notices only with blocks, a document without code blocks byte-identical with and without `copyUi`, no controls without a base, source view without controls, `MdCodeClipboardText` (CR LF, last LF dropped, NUL, non-ASCII, empty), `MdParseCopyLink` (exact, wrong token, wrong serial, out of range, leading zero, sign, extra path, query, fragment, empty number, too many digits, other in-host link -> NONE, other scheme -> NONE)
- [ ] T006 Run `tests\mdview_htmlgen_test\build_and_run.cmd` -> PASS; negative control: the new rows fail against the HEAD generator (recorded in `fix-log.md`)

## Phase 3: User Story 1 - copy with one click (P1)

- [ ] T007 [US1] `src/plugins/mdview/viewer.h`: members `CopyToken`, `CopySerial`, `CopyBase`, `CopyNotice`; method `CopyCodeBlock(size_t n)`
- [ ] T008 [US1] `src/plugins/mdview/viewer.cpp`: make the token with `SalGenRandom` (`../../common/salrandom.h`) at window creation; `RebuildHtml` builds `CopyBase` (empty in source mode or without a token) and passes `MdCopyUi` with `LoadStrW` texts converted to UTF-8
- [ ] T009 [US1] `src/plugins/mdview/viewer.cpp`: `ActivateLink` asks `MdParseCopyLink` first; OK -> `CopyCodeBlock`; REFUSED -> return; `CopyCodeBlock` copies with `CopyTextToClipboardW` (explicit length, guarded to `INT_MAX`) and on success navigates to the alternating notice fragment
- [ ] T010 [US1] Debug-only seam `TC_MDVIEW_PROBE_COPY_LOG` in `CopyCodeBlock` per `contracts/probe-seam.md`

## Phase 4: User Story 3 - the viewer stays locked down (P1)

- [ ] T011 [US3] Confirm no change under `src/common/webhost/` and `MdConfigureHost` keeps scripts and web messages off (`git diff`), record in `fix-log.md`

## Phase 5: User Story 2 - keyboard and themes (P2)

- [ ] T012 [US2] CSS in `src/plugins/mdview/htmlgen.cpp`: the control visible on `.tc-code:hover` and `:focus`, a focus outline, theme variables only (`--bg`, `--fg`, `--tb`), `user-select:none`; notice with theme variables

## Phase 6: Polish & verification

- [ ] T013 Probe `specs/408-mdview-code-copy/probe/copy408_probe.ps1`: rows OPEN, SHOWN (hover shows the control), COPY-1/COPY-3 (seam file = expected text), NOTICE (notice pixels appear, then fade), NOSCROLL, AGAIN (second copy shows the notice again), FORGED-MD / FORGED-HTML (a document link with a wrong token copies nothing, opens no box), LINK (a `foo.txt` link still opens the box), SOURCE (Ctrl+U page has no control), KEY (Tab + Enter copies; NOT DRIVEN if keys cannot be posted); run before (HEAD build) and after
- [ ] T014 Two-stage `.slt` refresh of the module `mdview` (stop-rules §2.13), `translations/*/mdview.slt`, pins in `translations/ui-overrides.json` if needed
- [ ] T015 Encoding guard `python tools/check_encoding.py --strict`, `.\build.cmd full`, harness, probe after; record in `fix-log.md`
- [ ] T016 Manual: mention the copy control where the manual describes the Markdown Viewer (`help/`), if it has such a page; record if not
- [ ] T017 Person check line for the release checklist (real clipboard, look in light/dark schemes)

## Dependencies

T001 -> T002 -> T003/T004 -> T005 -> T006 -> T007..T010 -> T012 -> T013 -> T014 -> T015.
T011, T016, T017 any time after T010.

## Parallel opportunities

T003 and T004 touch different functions of one file (sequential edits); T016/T017 are
independent of the probe.

## Implementation strategy

MVP = Phases 1-3 (a click copies). US3 is a property kept by construction; US2 is CSS.
