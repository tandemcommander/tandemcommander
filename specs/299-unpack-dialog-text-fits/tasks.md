# Tasks: The Unpack dialog never cuts a long target path or mask

**Input**: Design documents from `specs/299-unpack-dialog-text-fits/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refusal.md, quickstart.md

**Tests**: the hidden-desktop probe `probe/unpack299_probe.ps1` (the item asks for a probe row per
field, before FAIL / after PASS, and a control). No `saltests` rule is added (plan: the decision is
the existing `DlgItemTextFitsU8`).

## Phase 1: Setup

- [X] T001 Confirm the measurement before the fix is recorded: `specs/299-unpack-dialog-text-fits/probe/result_before.txt` (3 FAIL: path-cjk, path-ascii, mask-cjk; controls PASS) and its summary in `specs/299-unpack-dialog-text-fits/fix-log.md`

## Phase 2: Foundational

- [X] T002 Declare `virtual void Validate(CTransferInfo& ti);` in `class CUnpackDialog` in `src/dialogs.h` (public, next to `Transfer`)

## Phase 3: User Story 1 - A long target path is refused, never cut (P1)

**Goal**: OK with a target path of more than 259 UTF-8 bytes shows "The path specified is too long.", the dialog stays, nothing unpacked.
**Independent Test**: probe rows `path-cjk`, `path-ascii`, control `ctl-path`.

- [X] T003 [US1] Add `CUnpackDialog::Validate` in `src/dialogs3.cpp` (before `CUnpackDialog::Transfer`, `CALL_STACK_MESSAGE1`): first `if (!DlgItemTextFitsU8(HWindow, IDE_PATH, &ti, MAX_PATH)) return;` with a comment `// feature 299: never cut (the caller's buffers are MAX_PATH bytes)`

## Phase 4: User Story 2 - A long mask is refused, never cut (P1)

**Goal**: OK with a mask of more than 259 UTF-8 bytes refused the same way.
**Independent Test**: probe row `mask-cjk`, control `ctl`.

- [X] T004 [US2] In `CUnpackDialog::Validate` in `src/dialogs3.cpp`, after the path check: `DlgItemTextFitsU8(HWindow, IDE_MASK, &ti, MAX_PATH);`

## Phase 5: Polish & verification

- [X] T005 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T006 PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`; `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`; `git diff main -- src/lang` empty (no new string, FR-005)
- [X] T007 Run the probe after the fix (quickstart step 2) -> `specs/299-unpack-dialog-text-fits/probe/result_after.txt`: every row PASS, registry restored identical; first add the row `both` to `specs/299-unpack-dialog-text-fits/probe/unpack299_probe.ps1` (path and mask too long, "Delete archive after unpacking" checked: refused for the path field, a.zip kept, nothing under tgt) and run it on the build before the fix too (analyze C1)
- [X] T008 Negative control: with `Validate`'s body disabled (temporary, not committed) the probe's 3 refuse rows must FAIL again - or record why the before run already is the negative control - in `specs/299-unpack-dialog-text-fits/fix-log.md`
- [X] T009 Regression: 204's probe row `f9-zip` (`specs/204-unpack-short-name-folder/probe/unpack_dir_probe.ps1 -Only f9-zip`) -> `specs/299-unpack-dialog-text-fits/probe/regress_204.txt` PASS
- [X] T010 Record after / regression results and commands in `specs/299-unpack-dialog-text-fits/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005..T010. US1 and US2 share one function; US2 adds a line after
US1's. T005 and T009 are independent of each other once T006 built.

## Parallel examples

- T005 (encoding guard) can run while T006 builds.

## Implementation strategy

MVP = US1 (the path, where files land in another folder); US2 completes the item in the same
function. One commit for the source change.
