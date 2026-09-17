# Tasks: Fix the two product findings of the antivirus review

**Input**: Design documents from `/specs/077-fix-antivirus-findings/`
**Prerequisites**: plan.md, spec.md, research.md (R1–R11), data-model.md, contracts/ (runtime-deployment.md, signing-exemption.md), quickstart.md (S1–S10)

**Tests**: REQUESTED by the maintainer ("test the whole program and every change in great detail, each change at least twice"). Every verification task below states its "run twice" rule; both runs are recorded in `fix-log.md` with their actual output.

**Organization**: grouped by user story; each story is an independent, testable increment and ends in its own commit (constitution: one concern per commit, `[077]`-prefixed message).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[Story]**: US1 = runtime ships with the product (P1); US2 = no code modification of system modules (P2); US3 = signing keeps Microsoft's signature (P3)

## Path Conventions

Single project at repository root: product sources in `src/`, build entry `build.cmd`, tooling in `tools/`, build helpers in `src/vcxproj/`, feature record and probes in `specs/077-fix-antivirus-findings/`. Build output `build\tandemcommander\Release_x64` (`OPENSAL_BUILD_DIR` unset). Session scratchpad for throwaway copies: `C:\Users\pavel\AppData\Local\Temp\claude\E--Projects-tandemcommander\<session>\scratchpad`.

---

## Phase 1: Setup (record, probes, baselines)

**Purpose**: the running record, the three committed probes, and the "before" measurements every "twice" comparison needs.

- [x] T001 Create `specs/077-fix-antivirus-findings/fix-log.md` (sections: Baseline, per-task log T00x…, Verification matrix S1–S10 with run 1 / run 2 columns, Owed human step, Changelog draft, Side effects) and the empty directory `specs/077-fix-antivirus-findings/probe/`
- [x] T002 Record the baseline in `specs/077-fix-antivirus-findings/fix-log.md`: HEAD commit, Release tree file list and count (357 files at 0f615ad), `dumpbin /imports` lines for `WriteProcessMemory` and `VirtualProtect` in `build\tandemcommander\Release_x64\tandemcommander.exe` (present today), absence of runtime DLLs in the tree root, `tools\check_runtime_deps.py` not yet existing; move the archived published installer `setup\output\tandemcommander-0.1.7-x64-setup.exe` (SHA-256 `6731E146…F64DD`) to the scratchpad and note it (research R9)
- [x] T003 [P] Write `specs/077-fix-antivirus-findings/probe/crash_inject.ps1` (research R6): params `-Exe`, `-Target app|plugin`, `-PluginModule zip.spl`, `-TimeoutSec 60`; starts the program, waits for its main window, snapshots `%LOCALAPPDATA%\Tandem Commander\` (`NC0.1.7*` files), attaches `C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe -p <pid>` with a command string that sets `~0 r rip=0` (app) or `rip=<image base of the plugin module from the process module list>` (plugin) and then `.detach; q`; waits for a new `.txt` + `.dmp` pair, parses the faulting address from the text report, prints `RESULT: OK|FAIL`, module attribution, file names; closes the Bug Reporter (`salmon.exe`) and any leftover `tandemcommander.exe`; exit 0 only on OK
- [x] T004 [P] Write `specs/077-fix-antivirus-findings/probe/check_loaded_crt.ps1` (research R7 evidence 2): params `-Exe`; starts the program, waits for the main window, reads `Get-Process` module list, prints the load path of `vcruntime140.dll vcruntime140_1.dll msvcp140.dll concrt140.dll`, `RESULT: OK` iff all four are under the executable's directory (and none under `System32`), closes the program via `WM_CLOSE`, exit code accordingly
- [x] T005 [P] Write `specs/077-fix-antivirus-findings/probe/sign_exempt_negative.ps1` (quickstart S7): params `-Tree`, `-Tamper concrt140.dll`; copies the tree to the scratchpad, zeroes the PE security directory entry of the tampered file (same technique as `Remove-PeSignature` in `sign_release.ps1`, or appends one byte), records all file timestamps, runs `tools\codesign\sign_release.ps1 -Root <copy>` and `-VerifyOnly`, asserts exit 1, the `ERROR: runtime file is not validly signed by Microsoft` line, and that no file timestamp changed; prints `RESULT: OK|FAIL`
- [x] T006 Harness baseline (quickstart S5 "baseline"): run `probe/crash_inject.ps1 -Target app` and `-Target plugin` once each against the **current, pre-change** `build\tandemcommander\Release_x64\tandemcommander.exe`; both must produce a report — record file names and faulting addresses in `fix-log.md`; if a run fails, fix the probe (not the product) before continuing
- [x] T007 Test-suite baseline: `build.cmd` (Debug) then `build\tandemcommander\Debug_x64\saltests\saltests.exe`; record the totals (expected 1353 checks / 0 failures) in `fix-log.md`

---

## Phase 2: Foundational

No blocking prerequisites: the three stories touch disjoint files (`build.cmd` + `tools/check_runtime_deps.py` + `src/vcxproj/copy_vc_runtime.cmd` / `src/callstk.*` + `src/bugreprt.cpp` / `tools/codesign/sign_release.ps1`). The shared *runtime-name pattern* (data-model.md §1) is written identically into the Python checker (US1) and the PowerShell sweep (US3); the contract text is its single source.

**Checkpoint**: Phase 1 complete — story implementation can begin.

---

## Phase 3: User Story 1 — The program starts on a machine without the Visual C++ runtime (Priority: P1) 🎯 MVP

**Goal**: every Release build carries `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `concrt140.dll` in the tree root, copied automatically from the located Visual Studio installation, with a build-failing closure check; the installer packages them.

**Independent Test**: quickstart S1–S3 (build twice, checker negative twice, loaded-module origin twice) + S10 scan.

### Implementation for User Story 1

- [x] T008 [US1] Create `tools/check_runtime_deps.py` per `contracts/runtime-deployment.md` §2: stdlib PE parser (PE32/PE32+; import directory entry 1 and delay-load entry 13; RVA→file-offset via section table), runtime-name pattern from data-model.md §1 as the default `--pattern`, `--list` output, exit codes 0/1/2, ASCII output, UTF-8-BOM source
- [x] T009 [US1] Checker self-test, run 1 and run 2: (a) on the current tree without runtime files → exit 1 with `<module> needs VCRUNTIME140.dll (not shipped)` for all 25 modules (`--list` shows CONCRT140 only for tandemcommander.exe, MSVCP140 for 7zip/codeview/filecomp/mdview); (b) on a scratch copy with the four DLLs added by hand → exit 0; (c) quickstart S2 negatives: copy minus `msvcp140.dll` → 4 violations, copy minus `vcruntime140.dll` → 25 violations. Record both runs' output in `fix-log.md`
- [x] T010 [US1] Create `src/vcxproj/copy_vc_runtime.cmd <VS_INSTALL> <OUT_DIR>` per `contracts/runtime-deployment.md` §1: read `<VS_INSTALL>\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt`, copy the four files from `VC\Redist\MSVC\<v>\x64\Microsoft.VC143.CRT\` to `<OUT_DIR>`, print the success line, `ERROR: Visual C++ runtime not found: <path>` + hint and exit 1 on any missing piece; no absolute paths
- [x] T011 [US1] Wire it into `build.cmd`: for `release` builds (full and incremental), after `:populate_runtime` / the non-full `plugins.ver` sync and before `:clean_release_tree`, `call "%~dp0src\vcxproj\copy_vc_runtime.cmd" "!VS_INSTALL!" "%OUT_DIR%"` (fallback `%VCToolsRedistDir%\..\..\..` when `VS_INSTALL` is empty), then `python "%~dp0tools\check_runtime_deps.py" "%OUT_DIR%"`; any failure sets `BUILD_EXIT=1` with `ERROR: Visual C++ runtime check failed`; summary block gains a `Runtime       : 4 file(s), closure OK` line; confirm `:clean_release_tree` is untouched
- [x] T012 [US1] Quickstart S1 run 1: `build.cmd full release` → BUILD SUCCEEDED, log lines per contract, four DLLs in the tree root with valid `O=Microsoft Corporation` signatures, `check_runtime_deps.py --list` output; record in `fix-log.md`
- [x] T013 [US1] Quickstart S1 run 2: delete the four DLLs from the tree, run incremental `build.cmd release` → the files are back, closure OK; record
- [x] T014 [US1] Quickstart S2 missing-toolchain simulation, run 1 and run 2: `src\vcxproj\copy_vc_runtime.cmd <empty scratch dir> <scratch out>` → `ERROR: Visual C++ runtime not found: …` exit 1; second run with a scratch `VS_INSTALL` that has the version file but no `Microsoft.VC143.CRT` directory → same error naming the directory; record
- [x] T015 [US1] Quickstart S3 run 1 and run 2: `probe/check_loaded_crt.ps1 -Exe build\tandemcommander\Release_x64\tandemcommander.exe` → all four runtime modules loaded from the tree, `RESULT: OK` twice; record module paths
- [x] T016 [US1] Quickstart S10 on the tree (`MpCmdRun -Scan -ScanType 3 -File build\tandemcommander\Release_x64 -DisableRemediation` → no threats) and file-list diff against the T002 baseline (only the four DLLs added); record
- [x] T017 [US1] Commit `[077] Ship the Visual C++ runtime application-locally` (`build.cmd`, `src/vcxproj/copy_vc_runtime.cmd`, `tools/check_runtime_deps.py`, `specs/077-…/contracts/runtime-deployment.md` if refined, `fix-log.md` progress)

**Checkpoint**: a Release tree that starts without a system-wide runtime (evidence chain R7), verified twice.

---

## Phase 4: User Story 2 — Starting the program no longer looks like malware to a behaviour shield (Priority: P2)

**Goal**: the kernel32 patch is gone; the top-level exception filter is registered and periodically re-asserted by supported calls only; crash reporting parity is proven with injected faults.

**Independent Test**: quickstart S4 (import table, two independent binaries), S5 (crash proofs, app ×2 and plugin ×2), plus the re-assert breakpoint proof ×2.

### Implementation for User Story 2

- [x] T018 [US2] In `src/callstk.cpp` delete `MyDummySetUnhandledExceptionFilter`, `PreventSetUnhandledExceptionFilterAux`, `PreventSetUnhandledExceptionFilter` (lines 60–141 incl. the `#if defined _M_X64 || defined _M_IX86 … #error` guard and the `LoadLibrary("kernel32.dll")` in it) and the call at line 283 together with its explanatory comment (replace with a two-line comment stating that the filter is re-asserted by `CallStk_ReassertTopLevelExceptionFilter` instead); add `void CallStk_ReassertTopLevelExceptionFilter()` next to `TopLevelExceptionFilter`: `LPTOP_LEVEL_EXCEPTION_FILTER prev = SetUnhandledExceptionFilter(TopLevelExceptionFilter); if (prev != TopLevelExceptionFilter && prev != OldUnhandledExceptionFilter && prev != NULL) TRACE_I("…foreign top-level exception filter displaced…");` inside `#ifndef CALLSTK_DISABLE`
- [x] T019 [US2] Declare `void CallStk_ReassertTopLevelExceptionFilter();` in `src/callstk.h` (inside the `#ifndef CALLSTK_DISABLE` block, with an empty inline stub in the `CALLSTK_DISABLE` branch so callers compile either way)
- [x] T020 [US2] In `src/bugreprt.cpp` `AddNewlyLoadedModulesToGlobalModulesStore()` call `CallStk_ReassertTopLevelExceptionFilter();` as the first statement of the function body's `__try` block (main thread, every 15 s via `IDT_ADDNEWMODULES`), with a one-line comment referencing feature 077
- [x] T021 [US2] `clang-format` the three touched files (repository `.clang-format`), verify UTF-8-BOM preserved, then incremental `build.cmd release` and `build.cmd` (Debug) both succeed with no new warnings in `callstk.cpp`/`bugreprt.cpp`
- [x] T022 [US2] Quickstart S4 run 1 (the incremental binary): `dumpbin /imports tandemcommander.exe | findstr /i "WriteProcessMemory VirtualProtect"` → empty; also confirm `SetUnhandledExceptionFilter` is still imported; record
- [x] T023 [US2] Quickstart S4 run 2: `build.cmd rebuild release` (full clean) then the same `dumpbin` check on the new binary → empty; `check_runtime_deps.py` still OK after the rebuild (runtime step ran again); record
- [x] T024 [US2] Quickstart S5 after the change, `-Target app` run 1 and run 2: `probe/crash_inject.ps1` → `RESULT: OK`, new report + minidump each time; record file names and faulting address (0x0)
- [x] T025 [US2] Quickstart S5 after the change, `-Target plugin` run 1 and run 2: `probe/crash_inject.ps1 -Target plugin -PluginModule zip.spl` → `RESULT: OK`, faulting address inside `zip.spl`'s module range, report attributes it there; record
- [x] T026 [US2] Re-assert proof (FR-012) run 1 and run 2: under `cdb` (`.sympath` = the Release `obj` PDB dir of `salamand`, never `.symfix`), `bp kernel32!SetUnhandledExceptionFilter ".echo HIT; r rcx; g"`, let the program run 40 s → at least two HITs after start with `rcx` = address of `tandemcommander!TopLevelExceptionFilter` (compare with `x tandemcommander!TopLevelExceptionFilter`); record both sessions' output in `fix-log.md`
- [x] T027 [US2] Commit `[077] Remove the in-process kernel32 patch; re-assert the crash filter the supported way` (`src/callstk.cpp`, `src/callstk.h`, `src/bugreprt.cpp`, `probe/crash_inject.ps1`, `fix-log.md` progress)

**Checkpoint**: no system-module code modification; crash reporting parity proven 2× per variant.

---

## Phase 5: User Story 3 — The signed release keeps Microsoft's signature on the runtime files (Priority: P3)

**Goal**: `sign_release.ps1` exempts validly Microsoft-signed files, refuses runtime files without a valid Microsoft signature, reports `Exempt (Microsoft): N`; the signed installer carries and removes the runtime.

**Independent Test**: quickstart S6 (sweep ×2, VerifyOnly ×2), S7 (negative ×2), S8 (install/uninstall ×2), S10 on the installer.

### Implementation for User Story 3

- [x] T028 [US3] Amend `tools/codesign/sign_release.ps1` per `contracts/signing-exemption.md`: add `$RuntimeNamePattern`; `Test-MicrosoftExempt` (Valid + signer subject matches `O=Microsoft Corporation`; for catalog-type results inspect the embedded signer like `Test-SignedByCurrent` does); pre-flight loop that fails (exit 1, nothing modified) for runtime-named files that are not Microsoft-exempt; classification order Runtime-invalid → Ours-valid → Microsoft-exempt → sign; `$exemptCount` in the summary line `Signed: N  Skipped: M  Exempt (Microsoft): E  Failed: K  (of T)`; final verification and `-VerifyOnly` treat exempt as verified and print `RUNTIME FILE NOT MICROSOFT-SIGNED: <path>` for violations; Windows PowerShell 5.1, ASCII only
- [x] T029 [US3] Quickstart S6 run 1: `sign_release.ps1 -Root build\tandemcommander\Release_x64` from Git Bash with the default `PSModulePath` (SimplySign Desktop running) → `Exempt (Microsoft): 4`, `Verified : 220 of 220`, exit 0; the four runtime files still show the Microsoft signer; then `-VerifyOnly` → exit 0; record
- [x] T030 [US3] Quickstart S6 run 2 (idempotence): repeat the sweep → `Signed: 0  Skipped: 216  Exempt (Microsoft): 4`, exit 0; `-VerifyOnly` → exit 0; record
- [x] T031 [US3] Quickstart S7 run 1 and run 2: `probe/sign_exempt_negative.ps1 -Tree build\tandemcommander\Release_x64 -Tamper concrt140.dll`, then `-Tamper vcruntime140.dll` → `RESULT: OK` (sweep exit 1, error line names the file, no timestamp changed) both times; record
- [x] T032 [US3] Amend `specs/050-code-signing/contracts/signing-cli.md` §1 per-file behaviour with a pointer to `specs/077-fix-antivirus-findings/contracts/signing-exemption.md` and the new summary format
- [x] T033 [US3] Quickstart S8 run 1: `setup\build_setup.cmd sign` (archived installer already moved aside in T002) → signed installer; silent per-user install to `<scratch>\tc-inst` (`/VERYSILENT /CURRENTUSER /DIR=… /NOICONS /SUPPRESSMSGBOXES /NORESTART /LOG=…`) → four runtime DLLs present with Microsoft signatures, `tandemcommander.exe` with the project signature, HKCU uninstall key created, machine-wide install (`C:\Program Files\Tandem Commander\`, HKLM key) untouched; `unins000.exe /VERYSILENT` → folder and key gone; record
- [x] T034 [US3] Quickstart S8 run 2: repeat install → verify → uninstall; then `MpCmdRun` scan of the installer (S10) → no threats; move the test installer to the scratchpad and restore the archived published installer into `setup\output`, verify its SHA-256 `6731E146…F64DD`; record
- [ ] T035 [US3] Commit `[077] Signing sweep: keep Microsoft's signature on the runtime files` (`tools/codesign/sign_release.ps1`, `specs/050-code-signing/contracts/signing-cli.md`, `probe/sign_exempt_negative.ps1`, `probe/check_loaded_crt.ps1`, `fix-log.md` progress)

**Checkpoint**: signed release with Microsoft-signed runtime, packaging proven 2×.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: documentation, records, whole-product regression runs, integrated pipeline runs.

- [x] T036 [P] Update `architecture/03-build-pipeline.md` §"Populate Build Directory" (the runtime copy is now part of `build.cmd release`; `!populate_build_dir.cmd` is legacy) and §"Post-Build Steps" (closure check), and add the plugin-author note on application-local runtime precedence to `architecture/06-plugin-architecture.md` §"Plugin Build Configuration" (FR-015)
- [x] T037 [P] Update `CLAUDE.md`: "Missing deps" line (runtime now shipped), a `077-fix-antivirus-findings` entry under Recent Changes; update `specs/NEXT-WORK.md` (item done, link to fix-log); mark §3.2 and §3.3 of `specs/076-avast-false-positive-review/review-report.md` as implemented by 077 (short note, keep the analysis)
- [x] T038 [P] Draft the `CHANGELOG.md` entry (Fixed: starts without a separately installed Visual C++ runtime; Changed: start-up no longer modifies system code — user terms, truthful about scope) in `fix-log.md` §"Changelog draft"; no version bump (ship gate)
- [x] T039 Quickstart S9 run 1 and run 2: `build.cmd` (Debug) + `saltests.exe` → same totals as T007 (1353/0) twice; record
- [ ] T040 Integrated pipeline run 1: `build.cmd full release sign setup` from Git Bash (default `PSModulePath`) → BUILD SUCCEEDED, runtime line, closure OK, sweep `Exempt (Microsoft): 4`, installer signed; run 2: repeat the same command → idempotent (0 signed, 4 exempt), installer rebuilt; keep the resulting installers in the scratchpad and restore the archived published installer again; record
- [x] T041 Run `tools/check_encoding.py` (the build guard) and, if `pwsh` 7 is available, `normalize.ps1` in check mode on the touched files; confirm UTF-8-BOM and clang-format conformance of `src/callstk.cpp`, `src/callstk.h`, `src/bugreprt.cpp`, `tools/check_runtime_deps.py`
- [ ] T042 Close `fix-log.md`: verification matrix S1–S10 with both runs' verdicts, the owed human step (clean-machine start, exact steps from quickstart), side effects (archived installer moved/restored, HKCU test installs removed, scratchpad artefacts), and the final state of `dumpbin /imports`
- [ ] T043 Commit `[077] Record the verification runs and update the documentation` (`architecture/*`, `CLAUDE.md`, `specs/NEXT-WORK.md`, `specs/076-…/review-report.md`, `specs/077-…/*`)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: starts immediately; T003–T005 in parallel; T006 needs T003 and the existing pre-change Release build; T007 needs a Debug build
- **Foundational (Phase 2)**: nothing to do
- **US1 (Phase 3)**: after T002 (baseline) — T008→T009→T010→T011→T012→T013→T014→T015→T016→T017
- **US2 (Phase 4)**: after T006 (harness proven on the old binary); independent of US1 in files, but run after US1 so every later build also exercises the runtime step — T018/T019/T020 → T021 → T022 → T023 → T024 → T025 → T026 → T027
- **US3 (Phase 5)**: after US1 (needs the runtime files in the tree to exercise the exemption) — T028 → T029 → T030 → T031 → T032 → T033 → T034 → T035
- **Polish (Phase 6)**: after all stories; T036–T038 in parallel; T039–T041 sequential (each drives a build); T042 → T043 last

### User Story Dependencies

- **US1 (P1)**: none
- **US2 (P2)**: none on other stories (files disjoint); needs the Phase 1 harness baseline
- **US3 (P3)**: needs US1's runtime files present to test the exemption; the script change itself is independent

### Parallel Opportunities

- T003, T004, T005 (three probe scripts)
- T036, T037, T038 (documentation)
- Within US1, T009's negative copies can be prepared while T010 is written

---

## Parallel Example: Phase 1

```bash
Task: "Write probe/crash_inject.ps1"           # T003
Task: "Write probe/check_loaded_crt.ps1"       # T004
Task: "Write probe/sign_exempt_negative.ps1"   # T005
```

## Parallel Example: Phase 6

```bash
Task: "Update architecture/03 and 06"          # T036
Task: "Update CLAUDE.md, NEXT-WORK.md, 076 report"   # T037
Task: "Draft the CHANGELOG entry in fix-log.md"      # T038
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 (record, probes, baselines)
2. Phase 3 (US1) → **STOP and VALIDATE** with S1–S3 twice → commit
3. A release built at this point already fixes the hard start failure

### Incremental Delivery

1. US1 → runtime ships (commit 1)
2. US2 → patch removed, crash parity proven (commit 2)
3. US3 → signing exemption, packaging proven (commit 3)
4. Polish → docs, regression runs, integrated pipeline ×2 (commit 4)

### Single-implementer order used here

Phase 1 → US1 → US2 → US3 → Polish, sequentially; every verification task
performed twice with both outputs recorded before the next task starts.

---

## Notes

- "Run twice" = two independent executions, both outputs in `fix-log.md`
- The archived published installer in `setup\output` is moved aside in T002 and restored in T034 and again after T040
- Never run the signing sweep from the pwsh 7 tool (Windows PowerShell 5.1 module path issue) — use Git Bash/cmd with the default `PSModulePath`
- The `[077]` commit prefix follows the repository convention; no push
