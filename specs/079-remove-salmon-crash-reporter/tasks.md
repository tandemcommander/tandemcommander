# Tasks: Remove the salmon.exe Crash Reporter

**Input**: Design documents from `specs/079-remove-salmon-crash-reporter/`
**Prerequisites**: plan.md, spec.md, research.md (R1–R11), data-model.md, contracts/crash-report.md, contracts/process-list-record.md, quickstart.md

**Tests**: The specification demands thorough testing (SC-001…SC-007), so verification tasks are included: unit checks in `saltests`, two PowerShell probes, build/tool sweeps and greps. The unit checks are written before the helper they exercise.

**Organization**: Grouped by user story. Because deleting the helper's client (`src/salmoncl.*`) is what makes the start-up prompt disappear, US3's code change is inseparable from US1's deletion; US3 therefore carries its own probe and verification only. The crash path (US2) must be in place **before** the helper is deleted (US1), otherwise the exception filter has nothing to call — see Dependencies.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Every task names its files; `<out>` = `%OPENSAL_BUILD_DIR%tandemcommander` (`D:\Build\OpenSal\tandemcommander` on the reference machine)

## Path Conventions

Single MSBuild solution: sources in `src/`, shared library in `src/common/`, unit tests in `src/saltests/`, projects in `src/vcxproj/`, tooling in `tools/`, translations in `translations/`, feature records in `specs/079-remove-salmon-crash-reporter/` (abbreviated `specs/079/` below).

---

## Phase 1: Setup (baseline and record)

**Purpose**: Capture the pre-change state the success criteria are measured against, and open the running record.

- [X] T001 Create `specs/079/fix-log.md` (running record, one dated entry per task group) with the baseline: HEAD commit, `saltests.exe` result from the existing `<out>\Debug_x64\saltests\saltests.exe` (expected 1405/0), the `git grep -i -l salmon` inventory (count and the file list outside `specs/`, `CHANGELOG.md`, `src/common/dep/`, `src/plugins/codeview/web/`, `temp/`), and the presence of `<out>\Debug_x64\utils\salmon.exe` (yes — it is the stale-output case R9 covers)
- [X] T002 [P] Check how `LoadStrW`/`LoadStr` behave for a missing string id (read `src/salamdr1.cpp` or wherever `LoadStrW` is defined, grep `LoadStrW` in `src/*.cpp`) and note in `specs/079/fix-log.md` whether an intermediate build without the refreshed `.slg` would show a placeholder — this decides whether the translation refresh in T008 must precede the first probe run (it does if a placeholder is returned)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: The pure name formatter (unit-tested) and the two new strings, so the in-process crash path (US2) can be built and shown in every language.

**⚠️ CRITICAL**: US2 needs T003–T006; the first end-to-end probe (T014) needs T008 (refreshed `.slg`).

- [X] T003 Create `src/common/salbugreport.h` and `src/common/salbugreport.cpp`: `BOOL SalFormatBugReportName(WCHAR* out, int outLen, const char* shortVersion, const SYSTEMTIME& t, int suffix)` producing `TC<shortVersion>-YYYYMMDD-HHMMSS[-suffix].TXT`, upper-case ASCII, digits written by hand (no CRT/user32 call — this runs inside a crash), returns FALSE when `out` is too small or `suffix` is outside 0…99 or `shortVersion` contains a character outside `A-Za-z0-9`; SPDX header "2026 Pavel Stupka", UTF-8-BOM, English comments (research R3, R5)
- [X] T004 Add `..\common\salbugreport.cpp`/`.h` to `src/vcxproj/salamand.vcxproj` and `src/vcxproj/salamand.vcxproj.filters` (next to `saltabs.*`), and `..\..\common\salbugreport.cpp` to `src/vcxproj/saltests/saltests.vcxproj` (next to `saltabs.cpp`)
- [X] T005 Add `static void TestBugReport079()` to `src/saltests/saltests.cpp` and call it after `TestPanelTabs078()`: checks for the exact name for a known `SYSTEMTIME`, upper-casing of a lower-case version tag (`018x64` → `TC018X64-…`), suffix 0 omitted / 7 → `-7` / 99 → `-99` / 100 → FALSE, only `A-Z0-9-.` in the output, FALSE on a buffer one character too small, TRUE on the exact size, FALSE on a version tag containing `\` or a space; build the Debug solution (`build.cmd`) and run `<out>\Debug_x64\saltests\saltests.exe` — expect 1405 + new checks, 0 failed; record in `specs/079/fix-log.md`
- [X] T006 Add `#define IDS_BUGREPORT_SAVED 14101` and `#define IDS_BUGREPORT_NOTSAVED 14102` to `src/texts.rh2` under a new comment `// bug report written by the application itself (feature 079)` directly after the `IDS_SALMON_NOT_RUNNING` line, and the two English strings to `src/lang/texts.rc2` after the `IDS_SALMON_NOT_RUNNING` line (exact texts in research R8; one `%s` each; `\n` line breaks as the neighbouring strings use them)
- [X] T007 Translation refresh #1 (2 new strings, 8 enabled languages): from the repository root `src\vcxproj\build_langs.cmd --export-templates --module salamand`, then `cd tools` and `python -m translate.merge --module salamand`; if `translate.merge` reports a missing usage context for the two ids, add it where `tools/translate/uicontext.py` keeps the `salamand` domain entries and rerun; then `build.cmd full` from the root must exit 0 (all 8 `.slt` import); record the DeepL character count and the validation result in `specs/079/fix-log.md`
- [X] T008 Review the eight machine translations of the two strings in `translations/<lang>/salamand.slt` (cs, de, es, fr, hu, nl, ro, sk): the `%s` placeholder and the GitHub URL must survive verbatim, and the register must match the neighbouring strings; pin corrections under a `_feature_079` block in `translations/ui-overrides.json` and rerun `python -m translate.merge --module salamand` if any pin was added

**Checkpoint**: `build.cmd full` green with the new strings in every language; `saltests` green with `TestBugReport079`.

---

## Phase 3: User Story 2 — A crash still leaves a usable report and tells the user where it is (Priority: P1)

**Goal**: The application names the report, creates the folder, writes the report, shows the closing message and terminates with exit code 1 — without any helper (contracts/crash-report.md C2–C5).

**Independent Test**: The 079 crash probe (T014) against a build in which the helper still exists but is never signalled: report written, message shown with the path, exit code 1, no `salmon.exe` involvement.

- [X] T009 [US2] `src/callstk.h`: change `CreateBugReportFile`'s last parameter to `const WCHAR* bugReportFileName`; delete the stale declaration `BOOL StartSalmonProcess(BOOL enableRestartAS);` (line ~30); leave everything else
- [X] T010 [US2] `src/callstk.cpp` `CTBRData`: change `BugReportPath` to `const WCHAR*`, add `HANDLE MessageDone`; create it with the other three events in the `FirstCallstack` block of `CCallStack::CCallStack` (manual-reset, non-signalled; the thread is started only if all four exist) and close it in `~CCallStack` next to the others
- [X] T011 [US2] `src/callstk.cpp`: add two static helpers above `HandleException`: `BuildBugReportPath(WCHAR* path /*MAX_PATH*/)` — `SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, SHGFP_TYPE_CURRENT, …)`, append `\Tandem Commander`, `CreateDirectoryW` (ignore `ERROR_ALREADY_EXISTS`), `GetLocalTime`, `SalFormatBugReportName(…, VERSINFO_SAL_SHORT_VERSION, lt, suffix)` for suffix 0…99 until `GetFileAttributesW` reports `INVALID_FILE_ATTRIBUTES`, returns FALSE only when the folder path could not be resolved; and `ShowBugReportMessage(const WCHAR* path, BOOL saved)` — text from `LoadStrW(saved ? IDS_BUGREPORT_SAVED : IDS_BUGREPORT_NOTSAVED)` when `HLanguage != NULL`, else the English fallback literals (byte-identical to `texts.rc2`), formatted with `wsprintfW` into a static `WCHAR[2048]`, caption `SALAMANDER_TEXT_VERSION` widened by `MultiByteToWideChar(CP_ACP)`, `MessageBoxW(NULL, …, MB_OK | MB_ICONERROR | MB_SETFOREGROUND | MB_TOPMOST)`; include `<shlobj.h>` if not already reachable through `precomp.h`, and `"common/salbugreport.h"` (check how `saltabs.h` is included in `src/` and follow it)
- [X] T012 [US2] `src/callstk.cpp` `CreateBugReportFile`: open with `CreateFileW(bugReportFileName, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL)`; no other change to the body
- [X] T013 [US2] `src/callstk.cpp` `ThreadBugReportF`: after `CreateBugReportFile` and the existing shell-extension / icon-overlay notices, keep `SetEvent(data->EventProcessed)` where it is, then call `ShowBugReportMessage(data->BugReportPath, ret)` and `SetEvent(data->MessageDone)`
- [X] T014 [US2] `src/callstk.cpp` `HandleException`: (a) replace the salmon comment block at the top with one describing the in-process path; (b) re-entry guard — a static `HandlingThreadID`; if `CCallStack::ExceptionExists` and `HandlingThreadID == GetCurrentThreadId()` then `TerminateProcess(GetCurrentProcess(), 1)` before anything else, otherwise the existing `while (ExceptionExists) Sleep(1000)` and set both; (c) replace `SalmonFireAndWait(e, bugReportPath)` with `static WCHAR bugReportPath[MAX_PATH]; BOOL havePath = BuildBugReportPath(bugReportPath);` (on FALSE the path buffer holds the intended folder and `saved` will be FALSE); (d) treat `curThreadID == BugReportThreadID` like "no thread" (`reportInThisThread = TRUE`, skip the handshake, never `SuspendThread` the current thread); (e) after a successful `EventProcessed` wait, `WaitForSingleObject(TBRData.MessageDone, INFINITE)`; (f) in the inline path, after `CreateBugReportFile(...)`, `ShowBugReportMessage(bugReportPath, written)`; (g) remove `#include "salmoncl.h"` (line 13) and add the `salbugreport.h` include if T011 did not; keep `TerminateProcess(GetCurrentProcess(), 1)`
- [X] T015 [US2] Build Debug (`build.cmd`, encoding guard inside) and run `saltests.exe`; then write `specs/079/probe/crash_inject.ps1` derived from `specs/077-fix-antivirus-findings/probe/crash_inject.ps1`: drop every wait for / kill of `salmon.exe`; after the fault wait for the `.TXT` **and** for a `#32770` window owned by the process whose caption equals `Tandem Commander <version>` (P/Invoke `EnumWindows` + `GetWindowThreadProcessId` + `GetClassName` + `GetWindowText`), read the message text with `SendMessage(WM_GETTEXT)` on the child control with id `0xFFFF`, assert it contains the report's full path, print it, post `WM_COMMAND` `IDOK` to the box, wait for exit (≤ 15 s), assert `ExitCode == 1`, assert `Get-Process salmon` is empty; keep `-Target app|plugin`, `-Tag`, `-Archive`, the report archiving and the `execution address` check; print `RESULT: OK/FAIL`
- [X] T016 [US2] Run the probe on the Debug build for `-Target app` and `-Target plugin` (one run each at this checkpoint); paste the report name, the message text and the exit code into `specs/079/fix-log.md`; if the message shows a placeholder instead of text, T002's finding applies and the `.slg` in the tree must be rebuilt with `build.cmd full` first

**Checkpoint**: crash → report in `%LOCALAPPDATA%\Tandem Commander\` (folder created on demand) → message with the path → exit code 1; the helper is still launched but idle.

---

## Phase 4: User Story 1 — The product ships and runs without the helper (Priority: P1) 🎯 MVP

**Goal**: No `salmon.exe` anywhere (sources, projects, build output, installer payload); the application starts one process and never talks to a helper (FR-001…FR-003, FR-011…FR-013).

**Independent Test**: Full Debug and Release builds; `Get-ChildItem -Recurse -Filter salmon*` on both trees is empty while `utils\` keeps its other files; `.sln`/`.iss` greps empty; runtime-dependency check and signing inventory clean; one product process during a session.

- [ ] T017 [US1] `src/salamdr1.cpp`: move `EnableExceptionsOn64()` verbatim from `src/salmoncl.cpp` into this file as a `static` function above the WinMain wrapper (keep its comments and the `PROCESS_CALLBACK_FILTER_ENABLED` define), replace the `if (SalmonInit()) { ret = WinMainCRTStartup(); } else MessageBox(...)` block (~lines 101–110) with `EnableExceptionsOn64(); ret = WinMainCRTStartup();`, delete the `SalmonSetSLG(Configuration.SLGName);` call and its comment (~4087–4088) and the `SalmonCheckBugs();` call and its comment (~4604–4605), and drop `#include "salmoncl.h"` (line 43)
- [ ] T018 [P] [US1] `src/tasklist.h`: rename `SalmonPID` to `Reserved1` with the comment `// feature 079: was the crash reporter's PID; kept for layout compatibility, always 0`, set it to 0 in the constructor and delete the `HSalmonProcess` lines (extern at ~35 and the two lines in the constructor); `src/tasklist.cpp`: delete the `AllowSetForegroundWindow(...SalmonPID)` line and the "pustime jeho Salmon" comments (~574, 582), delete the `BugReportPath` global and its comment (~38–39); `src/consts.h`: delete `extern char BugReportPath[MAX_PATH];` (~1773); mirror the rename and the deletions in `tools/salbreak/tasklist.h` and `tools/salbreak/tasklist.cpp` (contracts/process-list-record.md)
- [ ] T019 [US1] Delete the helper: `git rm src/salmoncl.cpp src/salmoncl.h`, `git rm -r src/salmon src/vcxproj/salmon`; remove the `salmoncl.cpp`/`salmoncl.h` items from `src/vcxproj/salamand.vcxproj` (~540, ~856) and `src/vcxproj/salamand.vcxproj.filters` (~300, ~638); in `src/vcxproj/salamand.sln` delete the `Project(...) = "salmon"` block (line 146 and its `EndProject`) and the ten `{41909C30-FBE0-46CD-8B37-362D5A1F8329}.*` configuration lines (873–882); confirm no other reference to the GUID remains (`grep -n 41909C30 src/vcxproj/salamand.sln`)
- [ ] T020 [P] [US1] Language resources: delete the `IDD_SALMON_MAIN` template (lines ~2094–2109, through its `END`) and its `DESIGNINFO` block (~2316–2322) from `src/lang/lang.rc`; delete `IDD_SALMON_MAIN` and `IDC_SALMON_*` (6130–6140) from `src/lang/lang.rh`; delete the `IDS_SALMON_*` lines including the commented `IDS_SALMON_FAILED` and `IDS_SALMON_NOT_RUNNING` (~1893–1933) from `src/lang/texts.rc2`, keeping the two 079 strings; delete the `IDS_SALMON_*` defines and the `// salmon.exe is not running` comment (2626–2666) from `src/texts.rh2`, keeping the 079 block; check that no other source references `IDS_SALMON_` or `IDD_SALMON_` (`git grep -n "IDS_SALMON_\|IDD_SALMON_\|IDC_SALMON_" src`)
- [ ] T021 [P] [US1] Delete the `salmon` line (82) from `src/plugins/shared/baseaddr_x64.txt` and `src/plugins/shared/baseaddr_x86.txt`
- [ ] T022 [P] [US1] `build.cmd`: after the language-policy reconcile stage (find the block starting at the comment near line 163) add a stale-output cleanup that deletes `%OUT_DIR%\utils\salmon.exe` and `%OUT_DIR%\utils\salmon.pdb` if present, with a comment `:: feature 079: the crash reporter salmon.exe was removed; MSBuild rebuild only cleans projects still in the solution, so an older output tree would keep (and the installer would ship) the stale binary` — use the same `OUT_DIR` variable and echo style as the neighbouring reconcile messages
- [ ] T023 [US1] Translation refresh #2 (removal of 41 strings and the dialog): `src\vcxproj\build_langs.cmd --export-templates --module salamand`, `cd tools`, `python -m translate.merge --module salamand` (expect 0 new translations, rows removed), then from the root `build.cmd full` and `build.cmd full release`, both exit 0; `grep -il "salmon\|Bug Reporter" translations/*/salamand.slt` must list only the three disabled languages; record counts in `specs/079/fix-log.md`
- [ ] T024 [US1] Shipped-tree verification (quickstart §3): `Get-ChildItem <out>\Debug_x64, <out>\Release_x64 -Recurse -Filter 'salmon*'` empty; `<out>\Release_x64\utils` still lists `sqlite.dll`, `salopen.exe`, `salextx64.dll` (and whatever else it listed before — compare with the T001 baseline); `python tools\check_runtime_deps.py <out>\Release_x64` OK; run the signing sweep in its non-signing/inventory mode (read the header of `tools/codesign/sign_release.ps1` for the right switch; if only the real sweep exists and the certificate is present, run `build.cmd full release sign`) and confirm its inventory has no `utils\salmon.exe`; `Select-String salmon src\vcxproj\salamand.sln, setup\tandemcommander.iss` empty; `src\vcxproj\salamand.gen.slnf` no longer lists the project; record in `specs/079/fix-log.md`
- [ ] T025 [US1] Run `specs/079/probe/crash_inject.ps1` three times for `-Target app` and three times for `-Target plugin` on the Debug build and once for `app` on the Release build (SC-004); record every report name, message text excerpt, exit code and `salmon.exe processes: 0` line in `specs/079/fix-log.md`
- [ ] T026 [US1] Manual/driven scenario 5 (report not writable): stop the app, rename `%LOCALAPPDATA%\Tandem Commander` aside and create a zero-byte **file** of that name, run the probe with `-Target app` and `-Tag notsaved` expecting the "could not be saved" text and exit code 1 (extend the probe with a `-ExpectNotSaved` switch that flips the text assertion), then delete the file and restore the folder; record

**Checkpoint**: MVP — the helper is gone from the repository, both build trees and the installer payload; crashes still end in a report and a message.

---

## Phase 5: User Story 3 — Start-up is never interrupted or blocked by old reports (Priority: P2)

**Goal**: With stale reports present, or with a fresh registry, start-up shows no prompt and never blocks; the `Bug Reporter` registry key is never touched (FR-004, FR-011; SC-002, SC-003).

**Independent Test**: `specs/079/probe/startup_probe.ps1 -StaleReports` and `-FreshRegistry` both print `RESULT: OK`.

- [ ] T027 [US3] Write `specs/079/probe/startup_probe.ps1` (Windows PowerShell 5.1, ASCII): parameters `-Exe`, `-StaleReports`, `-FreshRegistry`, `-SettleSec 5`, `-Archive`; refuses to run if any `tandemcommander.exe` is running; `-StaleReports` plants `TC018X64-20260101-000000.TXT`, `OLD-DUMP.DMP`, `OLD-REPORT.7Z` (non-empty) in `%LOCALAPPDATA%\Tandem Commander` and records name/size/LastWriteTime; `-FreshRegistry` runs `reg export "HKCU\Software\Tandem Commander" <Archive>\tc-backup-<timestamp>.reg /y`, verifies the file is > 1 KB, then `reg delete "HKCU\Software\Tandem Commander\0.1" /f`; both modes start the exe, poll up to 30 s for `MainWindowHandle`, then for `SettleSec` enumerate top-level `#32770` windows owned by the process (log every caption; a language chooser is answered with Enter and logged; any caption containing `Bug Report` or equal to the version caption fails the run), assert `Responding`, assert exactly one process named `tandemcommander` and zero named `salmon`, assert `HKCU\Software\Tandem Commander\Bug Reporter` was not created (`-FreshRegistry`) or its `ID`/LastWriteTime unchanged (`-StaleReports`, if the key exists), post `WM_CLOSE`, wait ≤ 15 s for exit; `-StaleReports` re-checks the three files; `-FreshRegistry` finally `reg delete ... /f` the key the run wrote and `reg import` the backup, then verifies `Configuration\Language` (or another value present in the backup) is back; prints `RESULT: OK/FAIL`
- [ ] T028 [US3] Run both modes against the Debug build (and `-StaleReports` once against Release); paste the dialog log, process counts and the `registry restored: OK` line into `specs/079/fix-log.md`; if the user's own instance is running at the time, record the scenario as owed instead of killing it
- [ ] T029 [US3] Task List *Break* (spec US2 scenario 6, contracts/process-list-record.md): check whether `tools/salbreak` has a project (`ls tools/salbreak`); if it builds with MSBuild in a minute, build it and run `salbreak <pid>` against a running Debug instance — expect the closing message with a report path, exit code 1 and a second instance unaffected; otherwise drive *Help > Task List > Break* from a second Debug instance with a small PowerShell keyboard driver (pattern in `specs/078-panel-tabs/fix-log.md`); record the outcome in `specs/079/fix-log.md`

**Checkpoint**: start-up scenarios and the Break path verified; registry untouched.

---

## Phase 6: User Story 4 — The repository carries no dead crash-reporter baggage (Priority: P3)

**Goal**: Tooling, documentation and the change log no longer know the helper (FR-013, FR-014; SC-007).

**Independent Test**: `git grep -i -l salmon -- . ':!specs' ':!CHANGELOG.md' ':!src/common/dep' ':!src/plugins/codeview/web' ':!temp'` prints nothing; the encoding checker and the brand generator run clean.

- [ ] T030 [P] [US4] `tools/check_encoding.py` line ~155: remove `"salmon/"` from the exclusion tuple; run `python tools\check_encoding.py` (the way `build.cmd` invokes it — copy the command line from `build.cmd`) and confirm strict `TOTAL: 0` and an unchanged draft count; record both numbers
- [ ] T031 [P] [US4] `tools/brand/gen_icons.py` line ~52: remove `"src/salmon/res/salmon.ico"`; `tools/brand/README.md`: remove the crash-reporter mention in the `icon-master.png` row (line 12), the `src/salmon/res/salmon.ico` item (line 26) and `src/salmon/res/` in the directory list (line 44); run `python tools\brand\gen_icons.py` and check `git status` — regenerated icons must be byte-identical (if any `.ico` differs, `git checkout -- <file>` and note the non-determinism in the fix-log)
- [ ] T032 [P] [US4] `architecture/01-project-overview.md`: remove the `salmon\ Crash detection and reporting` tree line (60); `architecture/02-solution-structure.md`: remove the salmon row (160) and adjust any project/utility count it states (82 → 81 projects; "5 utilities" → 4 if salmon was counted there — read the table headings to decide)
- [ ] T033 [P] [US4] `help/src/hh/salamand/othertask_tasklist.htm` (lines ~17–20 and 32–34) and `help/src/hh/salamand/dlgboxes_tasks.htm` (line 30): reword so that *Break* "makes the selected task write a bug report to `%LOCALAPPDATA%\Tandem Commander` and show a message with the report's location; you can attach the report to an issue at github.com/tandemcommander/tandemcommander" — touch only those sentences (the pages' Open Salamander naming and 2023 footer are the separate follow-up recorded in 071)
- [ ] T034 [US4] `CHANGELOG.md`: insert `## [Unreleased]` above `## [0.1.8] — 2026-09-18` with **Removed** (the crash-reporting helper `salmon.exe` and its start-up "older bug reports were found" prompt; why: antivirus false positives, no upload since 0.1.0, no memory dump ever produced) and **Changed** (after a crash the program itself shows a message naming the saved report; the report folder is created when needed — previously a report was silently lost when `%LOCALAPPDATA%\Tandem Commander` did not exist yet; report names now `TC<version>-<date>-<time>.TXT`); truthful about scope (no memory dumps, unchanged report content), no version bump
- [ ] T035 [US4] `CLAUDE.md`: line 33 — drop `salmon` from the list of standalone `.rc` files; line 67 — remove the `salmon/ Crash reporter` tree line; Key Facts — `82 projects` → `81` and `5 utilities` → `4` (verify against T032's reading); in the 077 paragraph turn the "Found on the way, out of scope: `salmon.exe` loads dbghelp.dll…" sentence into "…(both removed with the helper in feature 079)"; add a `079-remove-salmon-crash-reporter` paragraph to Recent Changes in the house style (what, why, the in-process message, the `Reserved1` slot, verification, no version bump)
- [ ] T036 [US4] Repository grep (SC-007): `git grep -i -l salmon -- . ':!specs' ':!CHANGELOG.md' ':!src/common/dep' ':!src/plugins/codeview/web' ':!temp'` must print nothing, and `git grep -n "Bug Reporter" -- src tools help` must print nothing; fix any hit and record the final result in `specs/079/fix-log.md`

**Checkpoint**: nothing outside historical records refers to the helper.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T037 Format every touched C++ file with the repository `clang-format` (`.clang-format` at the root; `normalize.ps1` needs pwsh 7, which this machine lacks — run `clang-format -i` from the VS toolset on `src/callstk.cpp`, `src/callstk.h`, `src/salamdr1.cpp`, `src/tasklist.cpp`, `src/tasklist.h`, `src/consts.h`, `src/common/salbugreport.cpp`, `src/common/salbugreport.h`, `src/saltests/saltests.cpp`, `tools/salbreak/tasklist.*`) and confirm the diff is whitespace-only; confirm every new/edited source keeps its UTF-8 BOM
- [ ] T038 Final gate (quickstart §1–§7 in full): `build.cmd full` (Debug) exit 0, `saltests.exe` all checks 0 failed, `build.cmd full release` exit 0, tree greps, `check_runtime_deps.py`, signing inventory, crash probe (3× app, 3× plugin Debug; 1× app Release), start-up probe (both modes), repository grep; record the whole matrix with numbers in `specs/079/fix-log.md`
- [ ] T039 Write `specs/079/closing-report.md` (what changed, what was verified with which numbers, what is owed to a human — e.g. a real antivirus re-test on the reporting user's machine, the Windows Sandbox clean-install start still owed from 077) and update `specs/NEXT-WORK.md` if it lists the salmon items from 077
- [ ] T040 Commit in reviewable groups with `[079]` messages (foundation + US2 crash path; US1 removal incl. translations; US3 probes; US4 tooling/docs/changelog; polish/closing), each after its checkpoint is green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → **Foundational (Phase 2)** → **US2 (Phase 3)** → **US1 (Phase 4)** → **US3 (Phase 5)** → **US4 (Phase 6)** → **Polish (Phase 7)**.
- The story order deliberately differs from the priority order: US2 (the in-process crash path) must exist before US1 deletes the helper's client, because `HandleException` includes `salmoncl.h` and calls `SalmonFireAndWait`; deleting first would leave the build broken and the crash path dead. US3 is realised by US1's deletion (T017 removes the start-up calls) and only adds its probe. US4 is independent of US3 and could run in parallel with it.

### Within stories

- T003 → T004 → T005 (formatter before its project entries before its tests); T006 → T007 → T008 (ids before strings before refresh before review).
- T009–T014 edit `callstk.h`/`callstk.cpp` and are sequential; T015 (probe) needs T014 built; T016 needs T015 and T007.
- T017, T018, T019, T020, T021, T022 touch different files; T019 must follow T017 and T014 (nothing may still include `salmoncl.h`); T023 needs T019–T022; T024–T026 need T023.
- T027 → T028; T029 is independent of T027/T028.
- T030–T033 are parallel; T034/T035 after T032 (counts); T036 last in the phase.

### Parallel Opportunities

- Phase 2: T003 ∥ T006 (different files); T004 after T003.
- Phase 4: T018 ∥ T020 ∥ T021 ∥ T022 while T017 is done, then T019.
- Phase 6: T030 ∥ T031 ∥ T032 ∥ T033.

---

## Parallel Example: User Story 1

```text
# After T017 (salamdr1.cpp) is in place, launch together:
Task: "T018 tasklist.h/.cpp, consts.h, tools/salbreak: Reserved1, drop HSalmonProcess/BugReportPath"
Task: "T020 lang.rc/lang.rh/texts.rc2/texts.rh2: drop IDD_SALMON_MAIN and IDS_SALMON_*"
Task: "T021 baseaddr_x64.txt/baseaddr_x86.txt: drop the salmon line"
Task: "T022 build.cmd: stale utils\salmon.exe cleanup"
# Then T019 (delete files, projects, solution entries), then T023 (refresh + full builds).
```

---

## Implementation Strategy

### MVP First (US2 + US1)

1. Phase 1 baseline, Phase 2 formatter + strings + refresh #1.
2. Phase 3: in-process crash path; probe once (helper still present, idle).
3. Phase 4: delete the helper everywhere; refresh #2; full Debug + Release; tree checks; probe 3+3+1.
4. **STOP and VALIDATE**: SC-001, SC-004, SC-005 hold → the product can ship without the helper.

### Incremental Delivery

5. Phase 5: start-up probe (stale reports, fresh registry), Break scenario → SC-002, SC-003.
6. Phase 6: tooling, docs, change log, repository grep → SC-006 (translations), SC-007.
7. Phase 7: formatting, final gate matrix, closing report, commits.

---

## Notes

- Every verification task ends by pasting the actual numbers into `specs/079/fix-log.md`; the closing report summarises them.
- The probes refuse to run while another `tandemcommander.exe` is running; never stop a process the probe did not start.
- `-FreshRegistry` rewrites the user's configuration key: backup first, verify the backup, restore, verify the restore — in that order, no exceptions.
- No version bump anywhere (`spl_vers.h`, `tandemcommander.iss`, `CLAUDE.md` stay at 0.1.8 / 192).
