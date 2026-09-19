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

(pending)

## Phase 5 — US3 start-up probes

(pending)

## Phase 6 — US4 tooling, docs, changelog

(pending)

## Phase 7 — Final gate

(pending)
