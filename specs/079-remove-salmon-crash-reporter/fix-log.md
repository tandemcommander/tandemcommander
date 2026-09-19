# Fix log — 079 Remove the salmon.exe Crash Reporter

Running record, newest entries at the bottom of each section. Numbers are
pasted from the actual tool output.

## Baseline (T001, 2026-09-19)

- HEAD before implementation: `5a8f56b` (branch
  `079-remove-salmon-crash-reporter`; spec 473d7d6, plan f9a10ac, tasks
  5a8f56b).
- `saltests.exe` in the existing Debug tree
  (`D:\Build\OpenSal\tandemcommander\Debug_x64\saltests\`): `1301 checks, 0
  failed`. The tree dates from 2026-08-26, i.e. before feature 078 landed
  (078 records 1405); the first Debug build of this feature re-establishes the
  1405 baseline before anything is added.
- Helper present in the stale tree: `Debug_x64\utils\salmon.exe` +
  `salmon.pdb` next to `sqlite.dll/.exp/.lib/.pdb` — exactly the stale-output
  case research R9 covers. No `Release_x64` tree exists on this machine.
- `git grep -i -l salmon` outside `specs/`, `CHANGELOG.md`,
  `src/common/dep/`, `src/plugins/codeview/web/`, `temp/`: **45 files**
  (`.specify/feature.json` is among them only because the feature directory
  name contains the word; it is Spec Kit state and changes with every feature,
  so SC-007 excludes it; CLAUDE.md, 2 architecture docs, 6 core sources, 4
  resource files, 3 project files + solution, 7 helper sources, 2 project
  files of the helper, 2 base-address tables, 3 tools files, 2 salbreak files,
  11 `salamand.slt`).

## T002 — `LoadStrW` on a missing id

`src/salamdr2.cpp:129`: `LoadStringW` returning 0 yields the literal
`"ERROR LOADING WIDE STRING"` (and `TRACE_E`). Consequence: the first
end-to-end probe (T016) must run against a tree whose `english.slg` was
rebuilt after the translation refresh (T007), otherwise the message box would
show the placeholder.

Second consequence, found while reading it: `LoadStrW`/`LoadStr` take
`__StrCriticalSection`. A crash while that section is held (e.g. inside
`LoadStr`) would deadlock the bug-report thread inside the closing-message
code, and the crashing thread would then wait for `MessageDone` forever.
The message code therefore calls `LoadStringW(HLanguage, …)` directly into
its own static buffer instead of `LoadStrW` (the existing `IDS_SHELLEXTCRASH`
notice keeps its `LoadStr`; unchanged, pre-existing).

## Phase 2 — Foundational

- 2026-09-19 T003–T005: `src/common/salbugreport.h/.cpp` (`SalFormatBugReportName`,
  hand-written digits, no CRT/user32) wired into `salamand.vcxproj`
  (+`.filters`), `saltests.vcxproj` and `src/precomp.h`; `TestBugReport079`
  adds 22 checks. First Debug build failed only in saltests (25 errors, one
  cause): a buffer named `small` — a Windows macro (`#define small char`);
  renamed `tight`. Second build `BUILD SUCCEEDED`; **`saltests: 1427 checks,
  0 failed`** (1405 + 22).
- T006: `IDS_BUGREPORT_SAVED` 14101 / `IDS_BUGREPORT_NOTSAVED` 14102 in
  `src/texts.rh2` + `src/lang/texts.rc2`; the rebuilt `Debug_x64\lang\english.slg`
  contains the new text (byte search, UTF-16).
- T007 translation refresh #1: `build_langs.cmd --export-templates --module
  salamand` → template 3495 lines with 14101/14102. **First merge translated
  nothing** ("0 unique gaps" ×8): `translate.merge` resolves templates from
  the repo's `build\tandemcommander\translator\templates` (stale copy from
  2026-09-18) and ignores `OPENSAL_BUILD_DIR`. Re-run with
  `--templates D:/Build/OpenSal/tandemcommander/translator/templates`:
  **2 unique gaps × 8 languages, ~365 chars each (≈2,920 DeepL characters),
  validation failures: 0**. Recorded in memory (`translate-merge-templates-path`).
- T008 review: `%s` and the GitHub URL intact in all 8; cs/sk/hu/ro formal
  and idiomatic; **de/fr/nl/es came back informal** (du / tu / je / tú —
  corpus counts: de `Sie` 197 vs `du` 1, fr `vous` 22 vs `tu` 1, nl `u` 107
  vs `je` 2, the informal hits being the new string itself). Pinned the four
  `IDS_BUGREPORT_SAVED` texts in `translations/ui-overrides.json`
  (`_feature_079` note); third merge applied them (0 API calls, 0 failures);
  verified `Wenn Sie dabei` / `Si vous souhaitez` / `Als u wilt` / `Si desea
  ayudar` present once each.

- **Incident (pins)**: the first pin insertion and its "repair" were run as
  Python inside a Bash heredoc; this tool's shell collapses `\\` to `\`, so
  the JSON received a real newline instead of the literal two-character
  `\n` the `.slt` format requires. Effect: four `salamand.slt` grew to 3500
  rows (the pinned text split over lines) and `build.cmd full` killed
  `translator.exe` after 30 s for german/french/dutch/spanish ("opened an
  error message box"). Fixed by running the repair from a script file,
  `git checkout` of the four languages' `.slt`/`.origin`, and a re-merge
  (**2 × 365 chars × 4 languages more; total DeepL this feature ≈ 5,840
  characters**, validation failures 0). All 8 files back at 3495 rows, the
  formal text on one line each. `build.cmd full` (Debug): **BUILD SUCCEEDED,
  language modules built 189 (all shipped languages)**; `german.slg`
  contains `Wenn Sie dabei` (UTF-16 byte search). Quirk recorded in memory.

## Phase 3 — US2 in-process crash path

- 2026-09-19 T009–T014: `callstk.h` (`CreateBugReportFile` takes `const
  WCHAR*`, stale `StartSalmonProcess` declaration dropped), `callstk.cpp`
  (`CTBRData.MessageDone` + wide `BugReportPath`; event created/closed with
  the other three; `ThreadBugReportF` signals `EventProcessed` *before* the
  notices and the closing message, then `MessageDone`; `CreateBugReportFile`
  uses `CreateFileW` and returns FALSE when the file cannot be created;
  new `BuildBugReportPath` / `ShowBugReportMessage` — `LoadStringW` directly,
  not `LoadStrW`, see T002; `HandleException` rewritten per
  contracts/crash-report.md C4 with the re-entry guard and the
  "crash inside the bug-report thread" guard). One compile error on the way:
  the header declaration still said `const char*` (fixed). Comments avoid
  the helper's name so SC-007's grep stays clean.
- T015–T016 probe `probe/crash_inject.ps1` (from 077). Three probe defects
  found and fixed before the first green run, none in the product:
  (1) PowerShell binds `$null` to `""` for a `string` P/Invoke parameter, so
  `FindWindowEx(..., '#32770', $null)` matched only windows with an *empty*
  caption — the message box was never found; NULL now goes in as
  `IntPtr.Zero` through explicit overloads (same fix in `startup_probe.ps1`);
  (2) a MessageBox ignores a posted `WM_COMMAND/IDOK` — the probe now clicks
  the OK button (`BM_CLICK`), dismissed in ~200 ms; (3) the still-present
  helper renames the report after the process dies (its old WER-style
  rename), so the report is now read while the message is still up.
  A first diagnostic script attached cdb with an invalid thread id and
  killed the process on `q` — discarded, not evidence.
- **Checkpoint results (Debug, helper still launched but idle,
  `-AllowHelper`)**:
  - `-Target app`: report `TC018X64-20260919-094552.TXT` (24,611 bytes),
    `Exception: access violation: write on 0x0000000000000000`,
    `execution address = 0x0000000000000000`; message caption `Tandem
    Commander 0.1.8 (x64)`, text in Czech (the user's UI language) naming
    `C:\Users\pavel\AppData\Local\Tandem Commander\TC018X64-20260919-094552.TXT`;
    dismissed by BM_CLICK; **exit code 1**. (The run printed FAIL only
    because the helper had renamed the file before the late read — fixed as
    (3) above; the archived report carries the lines quoted here.)
  - `-Target plugin` (zip.spl at 0x10021100000): report
    `TC018X64-20260919-094712.TXT` (24,368 bytes), `execution address =
    0x0000010021100000`, inside `[0x10021100000..0x10021224000)`; Czech
    message with the path; dismissed after 203 ms; exit code 1;
    **RESULT: OK**.
  - The folder `%LOCALAPPDATA%\Tandem Commander` existed on this machine
    (WebView2 user data folder); the create-on-demand branch is exercised
    in T025/T026 after the helper is gone.

## Phase 4 — US1 removal

- 2026-09-19 T017: `salamdr1.cpp` — `EnableExceptionsOn64` moved in verbatim
  as a static function (no-op on x64), the WinMain wrapper calls it and then
  `WinMainCRTStartup()`; the `SalmonInit` branch with its English
  "initialization has failed" box, the `SalmonSetSLG` call and the
  `SalmonCheckBugs` call are gone, as is the include.
- T018: `CProcessListItem::SalmonPID` → `Reserved1` (same `DWORD`, same
  offset, `= 0`), `HSalmonProcess` extern and constructor lines removed,
  the second `AllowSetForegroundWindow` on a Break removed
  (`tasklist.cpp`), dead `BugReportPath` global + `consts.h` extern +
  its orphaned comment removed; `tools/salbreak/tasklist.*` mirrored.
- T019: `git rm` of `src/salmoncl.cpp/.h`, `src/salmon/` (16 files incl.
  `res/`), `src/vcxproj/salmon/` (5 files) — 24 files; `salamand.sln`
  project block (2 lines) + 10 configuration lines for
  `{41909C30-…}` removed by script, GUID no longer present; `salamand.vcxproj`
  + `.filters` lost their `salmoncl.*` items.
- T020: `lang.rc` template (18 lines) + DESIGNINFO block (7 lines),
  `lang.rh` 11 ids, `texts.rc2` 40 lines (39 strings + the commented
  `IDS_SALMON_FAILED`), `texts.rh2` 39 defines + 2 comments — all by script
  with count assertions; `IDS_BUGREPORT_*` kept at 14101/14102.
- T021: `baseaddr_x64.txt` / `baseaddr_x86.txt` line 82 dropped (CRLF kept).
- T022: `build.cmd` — "Removed helper cleanup (feature 079)" stage after the
  language policy stage deletes a stale `utils\salmon.exe` / `.pdb` with a
  `Reconcile:` message; this is the one place outside the records that must
  name the file (it is the file it deletes).
- T030/T031 (pulled forward, same files untouched by the build):
  `check_encoding.py` exclusion tuple no longer lists the helper;
  `gen_icons.py` `ICO_TARGETS` and `tools/brand/README.md` (3 mentions)
  cleaned; the regeneration check runs after the build.
- Translation refresh #2 attempt before rebuilding: the exported template
  still carried the 41 rows — `build_langs.cmd --export-templates` exports
  from the *built* English module, so the Debug build must precede the
  export (noted for the quickstart).

- Post-removal Debug build (`build.cmd`): **BUILD SUCCEEDED** (29 s),
  `Reconcile: removed stale utils\salmon.exe (crash reporter removed in
  feature 079)` printed by the new stage, `utils\` now `sqlite.dll/.exp/.lib/.pdb`
  only, `salamand.gen.slnf` no longer lists the project, `saltests: 1427
  checks, 0 failed`, `english.slg` without the old strings and with the new
  one.
- **Translation refresh #2 — incident and repair.** Export from the rebuilt
  module: template 3433 rows (was 3495), no helper rows. The merge then
  reported **46 unique gaps per language and sent 27,512 DeepL characters**
  (quota 467,510 → 443,094): the matcher's identity for string-table rows is
  `(STRINGTABLE, bundle-number, id)` (`tools/translate/match.py`
  `entry_key`), and removing four whole 16-id bundles renumbered every later
  bundle (`[STRINGTABLE 158]` → `154`), so all rows after the removed block
  missed their legacy match and were machine-retranslated — **human
  translations displaced** (e.g. cs 14151, hu 078's close-confirmation
  which even failed placeholder validation). Repair (script
  `restore_shifted.py`, kept in the session scratchpad; method recorded
  here): for every string-table row whose id exists in HEAD, the HEAD line
  replaces the merged line and the HEAD provenance is written under the
  tool's new bundle-numbered key — czech 23 rows, german 14, french 14,
  dutch 17, hungarian 18, romanian 20, slovak 18, spanish 14 (**138 rows**;
  provenance entries 13–15 per language). After the repair the diff against
  HEAD contains only removals (52 removed ids per language: 39 strings +
  `IDS_SALMON_NOT_RUNNING` + 12 dialog rows) and the bundle renumbering;
  `translate.merge --dry-run` reports 0 gaps / 0 validation failures for all
  8; 3433 rows each; the four formal pins intact. Lesson for the tooling
  (not fixed here, out of scope): the identity should not depend on the
  bundle ordinal.
- T031 check: `python tools\brand\gen_icons.py` regenerated every `.ico` and
  `logo.png` byte-identical (`git status` shows no image diff).
- `tools/salbreak` builds (Release|Win32 only — the project has no x64
  configuration; the process list is x86/x64-shared by design), output
  ignored via `.gitignore`.

## Phase 5 — US3 start-up probes

- 2026-09-19 `startup_probe.ps1 -StaleReports` (Debug, helper gone), first
  run: no helper, main window in 0.9 s, responding, one product process,
  three planted files untouched — but at exit the Debug CRT heap checker
  raised **"Heap Message: Detected memory leaks!"** and the probe's
  `WM_COMMAND/IDOK` did not dismiss it (a MessageBox needs `BM_CLICK`, see
  Phase 3), so the run ended FAIL on the exit timeout. Second run (probe now
  reads dialog texts and clicks the button): **RESULT: OK**, `exited on
  WM_CLOSE with code 0`, no heap message at all — the leak report is
  intermittent, matching 078's record ("two of eight runs, one 88-byte block
  from a plugin module unloaded before the dump"). A DBWIN listener is used
  below to capture the dump when it recurs, so it can be attributed rather
  than assumed.
- `-StaleReports` runs 2 and 3 (under the listener): **RESULT: OK** both,
  main window in 0.4 s, no dialog, one process, no helper, exit code 0, files
  untouched; no leak report in either.
- `-FreshRegistry` run 1: behaviour OK (backup 365,476 bytes, `0.1` key
  deleted, start in 0.4 s, no dialog, responding, one process, no helper,
  exit code 0) but the script itself aborted at the restore step — `reg.exe`
  prints its success message on stderr and `$ErrorActionPreference = 'Stop'`
  turned that into a terminating error *after* the `reg import` had run.
  Verified by hand before anything else: `Configuration\Language =
  czech.slg` as in the backup, all 389 subkeys of the backup present (the
  only diff line is the root key itself, which `reg query /s` does not
  list). Probe fixed: `reg.exe` is called through a helper that relaxes the
  error preference for the call and reads `$LASTEXITCODE` (a first attempt
  through `cmd /c` broke on quoting and failed before touching the registry).
- `-FreshRegistry` run 2 (fixed script, under the listener): **RESULT: OK**,
  `registry restored: OK (Configuration\Language = 'czech.slg')`, 389 keys.
  At exit the Debug heap checker reported a leak; **dump captured** (pid
  23460): `#File Error#(84) : {16097} normal block at 0x0000000101F7BA40, 88
  bytes long. Data: 00 00 … (16 zero bytes)`, `88 bytes in 1 Normal Blocks`,
  `202804 bytes in 237 CRT Blocks`. This is byte-for-byte the block feature
  078 recorded on 0.1.8 before this feature ("one block, 88 bytes, first 16
  bytes zero, `#File Error#(84)`" — a plugin module unloaded before the
  dump), so it is **pre-existing and unrelated to 079**; it shows on the
  fresh-registry (first-run) path in 2 of 2 runs and in 0 of 3 stale-report
  runs here. Left as recorded in 078.
- T029 Task List Break: `tools/salbreak` (Release|Win32) started next to a
  Debug instance and its global hotkey Ctrl+Alt+Shift+F12 sent by
  `SendKeys`: closing message `Tandem Commander 0.1.8 (x64)` naming
  `…\TC018X64-20260919-100716.TXT` (23,133 bytes, `Exception: open
  salamander break exception`), dismissed, **exit code 1, RESULT: OK** —
  the message came from the bug-report thread while the main thread was
  idle, as designed.
- SC-007 grep (`git grep -i -l salmon` outside `specs/`, `CHANGELOG.md`,
  third-party sources and `.specify/`): `build.cmd` (the cleanup stage must
  name the file it deletes) and the three **disabled** languages'
  `salamand.slt` (chinesesimplified, russian, ukrainian — not refreshed by
  policy since 046; already flagged as a re-enabling precondition). No hit
  in `src/`, `tools/`, `help/`, `architecture/`, `CLAUDE.md`; `Bug Reporter`
  absent from `src`, `tools`, `help`.
- T023 builds after the translation repair: `build.cmd full` (Debug)
  **BUILD SUCCEEDED**, language modules built 189; Debug tree: no `salmon*`
  outside stale *Intermediate* scaffolding (`Intermediate\salmoncl.obj`,
  `plugins\Intermediate\salmon\…` — Debug keeps its Intermediate directories
  by design; the 079 cleanup stage now removes those two as well), `utils\`
  = sqlite only, `saltests: 1427 checks, 0 failed`, all 9 `.slg` free of the
  old helper string.
- T025 crash probe series on Debug, helper gone (no `-AllowHelper`):
  **app 3/3 OK** (reports `TC018X64-20260919-101059/101108/101116.TXT`,
  33,088 / 24,902 / 24,895 bytes, `execution address = 0x0`, message
  caption `Tandem Commander 0.1.8 (x64)`, dismissed by BM_CLICK in ~210 ms,
  **exit code 1**, `salmon.exe processes: 0`), **plugin 3/3 OK** (zip.spl,
  `execution address = 0x0000010021100000` inside
  `[0x10021100000..0x10021224000)`, 24,643 / 24,658 / 24,659 bytes, exit
  code 1).
- **T026 (report not writable) found a real defect in the fallback.** With
  `%LOCALAPPDATA%\Tandem Commander` replaced by a zero-byte *file*, the
  thread's `CreateFileW` failed as intended, the crashing (UI) thread took
  the inline path and called `MessageBoxW` — and the probe's diagnostics
  showed the box **created but invisible** (`#32770 … visible=False`) with
  the process *not responding*. Cause: a modal loop on the crashing thread
  dispatches messages to its windows; their handlers enter call-stack macros,
  and `CCallStack::Push` suspends any thread that does so while an exception
  is active unless its stack is marked `DontSuspend` — the UI thread
  suspended itself (the bug-report thread is created with `DontSuspend`
  for exactly this reason; the old comment "Opening dialog windows freezes,
  so this cannot be used" in `HandleException` is the same lesson). Fix:
  (1) the bug-report thread shows the closing message in **both** outcomes
  (`ShowBugReportMessage(path, ret)`), and the crashing thread no longer
  retries inline after a reported failure (the same path fails the same way);
  (2) the remaining inline fallback (thread unusable / timed out) marks the
  current thread's `CCallStack` `DontSuspend = TRUE` before the box.
  Contract C4 updated. Re-verified below after the rebuild.
- After the rebuild (`build.cmd`, BUILD SUCCEEDED): app and plugin probes
  **OK** again (exit code 1, dismissed in ~212 ms); **T026 OK** — the Czech
  "could not be saved" message names the intended path
  `C:\Users\pavel\AppData\Local\Tandem Commander\TC018X64-20260919-101732.TXT`,
  dismissed in 217 ms, **exit code 1** (the probe's first assertion looked for
  the English wording; it now checks the path, language-neutral).
- T024 shipped-tree checks on the Release build of this state: **BUILD
  SUCCEEDED** (1 min 20 s), 189 language modules, `Visual C++ runtime
  14.40.33807: 4 file(s) copied`, `runtime closure OK: 219 module(s) scanned,
  59 runtime import(s)`; `Release_x64` recursive search for `salmon*`: **0**;
  `utils\` = `sqlite.dll` only; `sign_release.ps1 -VerifyOnly` inventory
  (unsigned build, every candidate listed as not signed by the current
  certificate, as expected) contains no `utils\salmon.exe`.

## Phase 7 — Final gate

- T037 formatting: VS 2022's `clang-format` 17.0.3 with the repository
  `.clang-format` over the touched C++ files. Whitespace-only results kept:
  `callstk.cpp` (8 lines), `precomp.h` (4: include-comment alignment),
  `tools/salbreak/tasklist.cpp` (2). `saltests.cpp` was **reverted to HEAD**:
  the tool also reflowed pre-existing 069/071/078 lines (string-literal
  splits) that this feature does not touch — constitution III; the only 079
  line it wanted to change was a comment column. The two new
  `salbugreport.*` files received the UTF-8 BOM the house rule requires
  (`saltests.cpp` never had one; left as found).
- T038 final gate on the final sources (after formatting), 2026-09-19:
  - `build.cmd full` (Debug): **BUILD SUCCEEDED**, 189 language modules,
    encoding guard `--strict` **TOTAL: 0 finding(s)** (run directly as well;
    the `salmon/` exclusion is gone from the checker); `build.cmd full
    release`: **BUILD SUCCEEDED**, 189 language modules, runtime 4 files
    shipped, closure OK.
  - Debug tree: `salmon*` files **0** (the cleanup stage now also removes the
    stale Intermediate scaffolding), `utils\` = sqlite only;
    **`saltests: 1427 checks, 0 failed`**.
  - Debug crash matrix: **app 3/3 OK, plugin (zip.spl) 3/3 OK**, exit code 1
    each; **not-writable OK** (exit code 1, message names the intended
    path); **stale reports OK** (one process, no helper, files untouched,
    exit 0); **fresh registry OK** (backup → run → restore verified,
    `Configuration\Language = 'czech.slg'`; the pre-existing Debug-CRT leak
    box appeared on this first-run path again and was dismissed); **Task
    List Break OK** (exit code 1).
  - Release tree: `salmon*` files **0**, `utils\` = `sqlite.dll`;
    `check_runtime_deps.py`: `runtime closure OK: 219 module(s) scanned, 59
    runtime import(s)`; `sign_release.ps1 -VerifyOnly` inventory: **215
    candidate lines, 0 naming the helper** (unsigned build, so every
    candidate is "not signed by the current certificate" — expected).
  - Release crash probe (app): report `TC018X64-20260919-102048.TXT`
    (28,163 bytes), exit code 1, **OK**; Release stale-reports start-up:
    **OK**.
  - `salamand.sln` / `tandemcommander.iss`: 0 matches. Repository grep
    (SC-007): `CLAUDE.md` (the feature paragraph names what was removed —
    a record, like the change log), `build.cmd` (cleanup stage) and the
    three disabled languages' retained `salamand.slt`; nothing in `src/`,
    `tools/`, `help/`, `architecture/`.

## Phase 6 — US4 tooling, docs, changelog

(pending)

## Phase 7 — Final gate

(pending)
