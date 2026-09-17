# 077 — fix-log (running record)

**Started**: 2026-09-17 · **Branch**: `077-fix-antivirus-findings` (from `main` at `0f615ad`) · **Rule**: every verification is run twice; both outputs are recorded here verbatim or by exact numbers.

## Baseline (T002, before any change)

- HEAD `0f615ad` (0.1.7, build 191 + feature 075). Release tree
  `build\tandemcommander\Release_x64`: **357 files**, no DLL in the tree root
  (the four runtime DLLs are absent), binaries built 2026-09-17 18:23–18:28
  from this HEAD and signed by the sweep earlier the same day.
- `dumpbin /imports tandemcommander.exe` (pre-change binary) contains:
  `5B8 SetUnhandledExceptionFilter`, `669 WriteProcessMemory`,
  `61A VirtualProtect` (kernel32).
- `tools\check_runtime_deps.py` does not exist yet.
- Archived published installer `setup\output\tandemcommander-0.1.7-x64-setup.exe`
  (SHA-256 `6731E14611B18C42B5AF268A03AA379F34E5332231DA8E1B602A99B5875F64DD`,
  verified) moved to the session scratchpad as
  `archived-published-0.1.7-setup.exe` — to be restored at the end (T034/T040).
- Machine-wide installation present: `C:\Program Files\Tandem Commander\`
  0.1.7 (`HKLM\…\Uninstall\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1`); no
  `tandemcommander.exe` / `salmon.exe` running; `%LOCALAPPDATA%\Tandem Commander\`
  exists and contains only `WebView2\` (no bug reports).
- saltests baseline (T007): Debug incremental build 8 s, BUILD SUCCEEDED;
  `saltests.exe` run 1 **1353 checks, 0 failed**; run 2 **1353 checks, 0 failed**.

## Task log

### T003–T006 — crash-injection harness and its baseline

Building the harness taught three things about the product that the plan
did not know; all three are now encoded in `probe/crash_inject.ps1`:

1. **An old report blocks the start.** With a leftover `*.TXT` in
   `%LOCALAPPDATA%\Tandem Commander\`, `salmon.exe` opens its dialog at
   start-up to offer the old report and the application's main thread waits
   in `SalmonCheckBugs` (`WaitForMultipleObjects`, seen with a non-invasive
   `cdb -pv` stack: `tandemcommander!SalmonCheckBugs+0x5d` ← `WinMainBody`)
   until that dialog is answered — the injected fault never executes and the
   window is "not responding". Two harness attempts (thread 0 / UI thread,
   90 s each) failed exactly this way. The probe now moves every existing
   report aside before starting.
2. **The fault must land on the window-owning thread and the thread must be
   woken.** `~0` happened to be the UI thread, but a thread blocked in
   `GetMessage` only resumes (and faults) on its next message; the probe
   resolves the thread with `GetWindowThreadProcessId` and posts `WM_NULL`
   after `.detach`. Injection while a debugger stays attached would not
   reach the registered filter at all (`UnhandledExceptionFilter` defers to
   the debugger) — hence attach → `r rip` → `.detach`.
3. **No minidump is ever produced (pre-existing, out of scope).**
   `src/salmon/minidump.cpp:16-20` loads `dbghelp.dll` only from the
   directory of `salmon.exe` (`utils\`), which neither the build tree nor
   the installed product contains, so `GenerateMiniDump` fails and only the
   text report is written by the application after `Done`. This has been so
   in every Tandem Commander release; recorded for `NEXT-WORK.md`. Parity in
   this feature therefore means the `.TXT` report (`Information About
   Exception` → `execution address = 0x…`).

Also learned: all 20 plugins are loaded and unloaded again during start-up
registration, so in steady state no `.spl` is loaded; for the plugin variant
the probe starts the program with `-l <probe.zip>` so `zip.spl` stays loaded.

**Baseline (pre-change binary of 18:24, signed):**

| Target | Result | Report | Faulting address |
|---|---|---|---|
| app | RESULT: OK | `4B6DA4D42B4A1AB9-NC017X64-260917-192656.TXT` (26,935 B) | `0x0000000000000000`, "access violation: write on 0x0", thread 0x6C54 |
| plugin (zip.spl) | RESULT: OK | `4B6DA4D42B4A1AB9-NC017X64-260917-192755.TXT` (26,721 B) | `0x00007FFEE93F0000` = image base of `zip.spl` [0x7FFEE93F0000..0x7FFEE9441000) |

Both: application exited after writing the report; salmon dialog
"Hlášení chyby programu Tandem Commander" shown; reports archived in the
scratchpad (`tc077-bugreports\baseline-*`). A stray report from the first
(failed) harness attempt (`…-191522.TXT`) was archived as well.

### T008–T009 — `tools/check_runtime_deps.py`

Run 1 and run 2 gave identical results:

| Case | Exit | Output |
|---|---|---|
| (a) current tree (no runtime) | 1 | `runtime closure FAILED: 55 unsatisfied import(s) in 216 module(s) scanned`; `--list` shows `concrt140.dll` only for `tandemcommander.exe`, `msvcp140.dll` for `7zip.spl codeview.spl filecomp.spl mdview.spl`, `fcremote.exe` and all `.slg` need nothing |
| (b) copy + 4 DLLs | 0 | `runtime closure OK: 220 module(s) scanned, 61 runtime import(s), shipped: concrt140.dll, msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll` |
| (c1) copy minus msvcp140.dll | 1 | 5 violations — the 4 plugins **and** `concrt140.dll needs msvcp140.dll` (the runtime's own dependency is part of the closure) |
| (c2) copy minus vcruntime140.dll | 1 | 29 violations (25 product modules + concrt140, msvcp140, vcruntime140_1, exif) |
| (d) missing tree | 2 | `ERROR: tree not found` |
| (e) non-PE `fake.dll` in tree | 0 | `note: skipped (not a PE file): fake.dll (no MZ header)` |

### T010 / T014 run 1 — `src/vcxproj/copy_vc_runtime.cmd`

| Case | Exit | Output |
|---|---|---|
| real VS → scratch dir | 0 | `Visual C++ runtime 14.40.33807: 4 file(s) copied from …\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT`; files 14.40.33810.0, all `Valid` (Microsoft) |
| empty `VS_INSTALL` dir | 1 | `ERROR: Visual C++ runtime not found: …\vs-empty\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt` + hint |
| version file present, no CRT dir | 1 | `ERROR: Visual C++ runtime not found: …\vs-nocrt\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT` + hint |
| missing out dir | 1 | `ERROR: copy_vc_runtime.cmd: output tree not found: …` |
| no arguments | 1 | `ERROR: copy_vc_runtime.cmd: missing <VS_INSTALL> argument` |

(Calling the helper from Git Bash mangles the quotes — use `cmd /c` from
PowerShell or a plain cmd prompt; `build.cmd` calls it from cmd.)

### T011 — wiring in `build.cmd`

Inserted after the full/non-full `plugins.ver` handling and before
`:clean_release_tree`, Release only: `copy_vc_runtime.cmd "!VS_INSTALL!"
"%OUT_DIR%"` (fallback `%VCToolsRedistDir%\..\..\..` when `VS_INSTALL` is
empty), then `python tools\check_runtime_deps.py "%OUT_DIR%"`; either failure
sets `BUILD_EXIT=1` with an `ERROR: Visual C++ runtime check failed …` line;
summary block gains `Runtime       : 4 file(s) shipped, closure OK`.

### T012–T013 — S1 run 1 and run 2

- **Run 1** `build.cmd full release` (log `build_release_s1_run1.log`):
  `BUILD SUCCEEDED`, `Visual C++ runtime 14.40.33807: 4 file(s) copied from
  …\VC\Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT`, `runtime closure OK:
  220 module(s) scanned, 61 runtime import(s), shipped: concrt140.dll,
  msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll`, summary
  `Runtime       : 4 file(s) shipped, closure OK`; 20 plugins, 189 language
  modules; tree **361 files** (357 + 4).
- **Run 2** the four DLLs deleted by hand (`root dlls after delete: 0`),
  then incremental `build.cmd release`: same three lines, the four files are
  back (14.40.33810.0), 361 files.

### T014 — S2 helper failure branches, run 2

Messages identical to run 1; exit codes captured without a pipe:
`empty-vs exit=1`, `no-crt-dir exit=1`, plus a new case "version file and
CRT directory present but `vcruntime140_1.dll` missing" →
`ERROR: Visual C++ runtime not found: …\Microsoft.VC143.CRT\vcruntime140_1.dll`,
`exit=1`; positive case `exit=0`, 4 files.

### T015 — S3 run 1 and run 2

Both `RESULT: OK`: `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, `MSVCP140.dll`,
`CONCRT140.dll` all loaded from
`E:\Projects\tandemcommander\build\tandemcommander\Release_x64\` (v14.40.33810.0),
none from `System32` — on a machine that has the system-wide runtime
14.51.36247 installed, i.e. the application directory wins the search
order (research R7, evidence 2).

### T016 — S10 on the tree + census

`MpCmdRun -Scan -ScanType 3 … -DisableRemediation` →
`Scanning …\Release_x64 found no threats.` Census by extension: `.slg 189,
.tab 70, .svg 63, .spl 20, .dll 8, .cfg 3, .exe 3, .set 2, .txt 2, .ver 1`
— identical to the baseline except `.dll 4 → 8`; the four additions are
exactly `concrt140.dll msvcp140.dll vcruntime140.dll vcruntime140_1.dll` in
the tree root.

### T017 — commits

`6ce6403 [076] Record the antivirus false-positive review`,
`5ffa4c8 [077] Specify, plan and task the antivirus-findings fixes`,
`eb5a050 [077] Ship the Visual C++ runtime application-locally`.

### T018–T021 — the patch removal

- `src/callstk.cpp`: the whole "PreventSetUnhandledExceptionFilter" section
  (banner, `MyDummySetUnhandledExceptionFilter`,
  `PreventSetUnhandledExceptionFilterAux` with its `VirtualProtect` /
  `WriteProcessMemory` trampoline, the `__try` wrapper — 2,745 characters)
  and its call in the first `CCallStack` constructor are gone; the call is
  replaced by a comment pointing at the new helper.
  `CallStk_ReassertTopLevelExceptionFilter()` (7 lines) sits next to
  `TopLevelExceptionFilter` / `OldUnhandledExceptionFilter`, inside the
  file's `#ifndef CALLSTK_DISABLE`.
- `src/callstk.h`: declaration in the free-function/macro block
  (`#ifndef CALLSTK_DISABLE`, second occurrence) and an `inline … {}` stub in
  its `#else`. **First attempt was wrong**: the first
  `#ifndef CALLSTK_DISABLE` in the header is *inside* `class CCallStack`, so
  the declaration became a member and `bugreprt.cpp` failed with
  `C3861 'CallStk_ReassertTopLevelExceptionFilter': identifier not found` in
  both configurations; moved and rebuilt.
- `src/bugreprt.cpp`: `AddNewlyLoadedModulesToGlobalModulesStore()` calls the
  helper first (comment references feature 077).
- `clang-format -i --style=file` (VS-bundled LLVM 17) on the three files;
  BOM and CRLF preserved (`efbbbf`, all lines CRLF). Diff vs HEAD:
  `callstk.cpp` −103/+29 net, `callstk.h` +8, `bugreprt.cpp` +5.
- Builds: `build.cmd release` (incremental) BUILD SUCCEEDED, runtime step
  ran again (`Runtime : 4 file(s) shipped, closure OK`); `build.cmd`
  (Debug) BUILD SUCCEEDED. No new warnings in the touched files (the
  pre-existing `pack1.cpp`/`salamdr2.cpp`/`zip.cpp` warnings are unchanged).

### T022 — S4 run 1 (incremental binary, 19:36:57, 3,333,120 B)

`dumpbin /imports` → `WriteProcessMemory` / `VirtualProtect`: **(none)**
(baseline had `669 WriteProcessMemory`, `61A VirtualProtect`).
Still imported, as expected and out of scope: `5B8 SetUnhandledExceptionFilter`,
`43F OpenProcess`, `118 CreateToolhelp32Snapshot`, `3B0 IsDebuggerPresent`.

### T024–T025 — S5 after the change (binary of 19:36:57)

| Run | Target | Result | Report | Faulting address |
|---|---|---|---|---|
| after-app-1 | app | RESULT: OK | `…-193743.TXT` (35,901 B) | `0x0`, thread 0x1EF8 |
| after-app-2 | app | RESULT: OK | `…-193754.TXT` (27,107 B) | `0x0`, thread 0x1F90 |
| after-plugin-1 | zip.spl | RESULT: OK | `…-193805.TXT` (26,878 B) | `0x00007FFEC95E0000` = zip.spl base, inside [0x7FFEC95E0000..0x7FFEC9631000) |
| after-plugin-2 | zip.spl | RESULT: OK | `…-193816.TXT` (26,882 B) | `0x00007FFEC95E0000`, inside the same range |

Every run: "Exception: access violation: write on …", application exited
after writing the report, salmon crash dialog shown — identical behaviour to
the baseline on the pre-change binary. (The first run after a rebuild lists
all 20 plugins as loaded: the start-up auto-registration of the bumped
`plugins.ver`; steady state loads none.)

### T023 — S4 run 2 (clean `build.cmd rebuild release`, binary 19:39:15, SHA-256 `BAD1459D…`)

Rebuild: BUILD SUCCEEDED (0 min 45 s), runtime step ran again
(`4 file(s) copied`, `runtime closure OK: 220 module(s) …`), tree 361 files.
`dumpbin /imports` → `WriteProcessMemory` / `VirtualProtect`: **(none)**;
`5B8 SetUnhandledExceptionFilter` still imported. Two independently linked
binaries (19:36:57 incremental, 19:39:15 clean) give the same answer.

### T026 — re-assert proof (FR-012), `probe/reassert_filter.ps1`

cdb attached to the running program with
`bp kernel32!SetUnhandledExceptionFilter ".echo HIT; r rcx; g"` and
`.sympath build\obj\Release_x64\Intermediate` (never `.symfix`).
`x tandemcommander!TopLevelExceptionFilter` = `0x00007ff6d6c153c0`.

| Run | Hits in 40 s | rcx of every hit |
|---|---|---|
| 1 | 2 | `0x00007ff6d6c153c0` = ours, `0x00007ff6d6c153c0` = ours → RESULT: OK |
| 2 | 2 | same two values → RESULT: OK |

Two hits ≈ the 15-second `IDT_ADDNEWMODULES` timer firing at ~15 s and
~30 s after attach; each re-registers exactly our filter. (A first attempt
of the probe failed on tooling, not on the product: the breakpoint command's
inner quotes cannot survive cdb's `-c` argument — the probe now feeds the
commands through `-cf <file>`; a second attempt then mis-parsed the echoed
`x` command line instead of its address line. Both fixes are in the probe.)

### S9 run 1 (after the US2 change)

`saltests.exe`: **1353 checks, 0 failed** (the test executable links only
`src\common` and is unaffected by `callstk.cpp` by construction — same as
feature 075 noted; the run proves the Debug tree is intact).

## Verification matrix

| Scenario | Run 1 | Run 2 | Notes |
|---|---|---|---|
| S1 build ships runtime | | | |
| S2 build fails without runtime | | | |
| S3 loaded from app dir | | | |
| S4 import table clean | | | |
| S5 crash parity — app | | | baseline: |
| S5 crash parity — plugin | | | baseline: |
| S5b re-assert proof | | | |
| S6 signing sweep + VerifyOnly | | | |
| S7 tampered runtime refused | | | |
| S8 install / uninstall | | | |
| S9 Debug build + saltests | | | |
| S10 Defender scan | | | |
| Integrated `build.cmd full release sign setup` | | | |

## Owed human step

_(filled at close)_

## Changelog draft

_(T038)_

## Side effects

_(filled at close)_
