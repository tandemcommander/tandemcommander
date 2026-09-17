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

### T028 — `tools/codesign/sign_release.ps1` amended

Per `contracts/signing-exemption.md`: `$RuntimeNamePattern` (identical to the
Python checker's), `$MicrosoftSubjectPattern = 'O=Microsoft Corporation'`,
`Test-MicrosoftExempt` (Valid + Microsoft signer; catalog-type results judged
by the embedded signer like `Test-SignedByCurrent`), `Test-RuntimeName`;
classification order Runtime-invalid → Ours-valid → Microsoft-exempt → sign;
runtime-invalid files fail the run before anything is touched
(`ERROR: runtime file is not validly signed by Microsoft: <path>`, or
`RUNTIME FILE NOT MICROSOFT-SIGNED: <path>` under `-VerifyOnly`); summary
`Signed: N  Skipped: M  Exempt (Microsoft): E  Failed: K  (of T)`; the final
verification and `-VerifyOnly` count exempt files as verified. ASCII, CRLF,
Windows PowerShell 5.1. `specs/050-code-signing/contracts/signing-cli.md`
§1 amended with a pointer (T032).

### T029–T030 — S6 run 1 and run 2 (tree of the clean rebuild, 220 candidates)

| Run | Sweep | VerifyOnly |
|---|---|---|
| 1 | `To sign : 48 (skipping 168 already signed)` → `Signed: 48  Skipped: 168  Exempt (Microsoft): 4  Failed: 0  (of 220)`, `Verified : 220 of 220`, exit 0 (4 signtool batches, SimplySign unattended) | `VerifyOnly : 216 of 220 artifacts signed by the configured certificate, 4 Microsoft-exempt.`, exit 0 |
| 2 | `Signed: 0  Skipped: 216  Exempt (Microsoft): 4  Failed: 0  (of 220)`, `All artifacts already signed by the configured certificate (or Microsoft-exempt).`, exit 0 | same line, exit 0 |

After both sweeps the four runtime files still report `Valid` with signer
`CN=Microsoft Windows Software Compatibility Publisher` — never re-signed.
(Only 48 files needed signing: the clean rebuild relinks the 25 PE modules
and `english.slg`s; the other language modules kept their signatures.)

### T031 — S7 run 1 and run 2, `probe/sign_exempt_negative.ps1`

| Run | Tampered file | Sweep | VerifyOnly | Files changed in the copy |
|---|---|---|---|---|
| 1 | `concrt140.dll` (Valid → NotSigned after appending one byte) | exit 1, `ERROR: runtime file is not validly signed by Microsoft: …\concrt140.dll` | exit 1, `RUNTIME FILE NOT MICROSOFT-SIGNED: …\concrt140.dll` | 0 |
| 2 | `vcruntime140.dll` | exit 1, same line for `vcruntime140.dll` | exit 1, same | 0 |

Both `RESULT: OK`; the sweep stopped after the classification, before any
signtool call.

### T033–T034 — S8 run 1 and run 2 (packaging), S10 on the installer

`setup\build_setup.cmd sign` (from Git Bash, default `PSModulePath`): sweep
`Signed: 0  Skipped: 216  Exempt (Microsoft): 4`, Inno `Successful compile`,
`Installer signed and verified`; installer 8,281,072 B (was 8,002,480 B for
the published 0.1.7 — the four runtime DLLs), SHA-256 `ED0BC2F2…C7A4`,
signer *Open Source Developer Pavel Stupka*; Defender: `found no threats`.

| Run | Install (`/VERYSILENT /CURRENTUSER /DIR=<scratch>\tc-inst /NOICONS /SUPPRESSMSGBOXES /NORESTART`) | In the folder | Uninstall (`unins000.exe /VERYSILENT`) |
|---|---|---|---|
| 1 | exit 0 | 364 files; `vcruntime140.dll vcruntime140_1.dll msvcp140.dll concrt140.dll` Valid / Microsoft; `tandemcommander.exe`, `utils\salmon.exe` Valid / project cert | exit 0; folder emptied (the self-deleting `unins000.exe` last), HKCU key gone |
| 2 | exit 0, log `Installation process succeeded.` | same; HKCU `…\Uninstall\{35C0B0DC-…}_is1` present with `InstallLocation=<scratch>\tc-inst\`, `DisplayVersion=0.1.7` | exit 0; same |

The machine-wide installation (`C:\Program Files\Tandem Commander\`,
exe of 2026-08-29 11:46:42, HKLM key `Tandem Commander 0.1.7`) is untouched
before and after both runs. The test installer is kept in the scratchpad as
`test-installer-077-run1.exe`; the archived published 0.1.7 installer was
restored into `setup\output` (SHA-256 `6731E146…F64DD`, match=True).

### S9 run 1 (after the US2 change)

`saltests.exe`: **1353 checks, 0 failed** (the test executable links only
`src\common` and is unaffected by `callstk.cpp` by construction — same as
feature 075 noted; the run proves the Debug tree is intact).

## Verification matrix

| Scenario | Run 1 | Run 2 | Notes |
|---|---|---|---|
| S1 build ships runtime | ✅ full build: 4 copied, closure OK, 361 files | ✅ DLLs deleted, incremental build restored them | T012–T013 |
| S2 build fails without runtime | ✅ checker: 55 unsatisfied on the old tree; helper: 4 failure branches exit 1 | ✅ identical (+ "one file missing" case) | T009, T014 |
| S3 loaded from app dir | ✅ 4/4 from `Release_x64\` | ✅ 4/4 | T015; system-wide 14.51 present and ignored |
| S4 import table clean | ✅ incremental binary 19:36:57 | ✅ clean-rebuilt binary 19:39:15 | T022–T023 |
| S5 crash parity — app | ✅ report, address 0x0 | ✅ | baseline on pre-change binary: ✅ (T006) |
| S5 crash parity — plugin (zip.spl) | ✅ report, address = zip.spl base | ✅ | baseline: ✅ (T006) |
| S5b re-assert proof | ✅ 2 hits / 40 s, rcx = ours | ✅ 2 hits, rcx = ours | T026 |
| S6 signing sweep + VerifyOnly | ✅ 48 signed, 4 exempt, 220/220; VerifyOnly 0 | ✅ 0 signed, 4 exempt; VerifyOnly 0 | T029–T030 |
| S7 tampered runtime refused | ✅ concrt140.dll, nothing modified | ✅ vcruntime140.dll | T031 |
| S8 install / uninstall | ✅ 364 files, signatures, key, clean removal | ✅ + HKCU key contents verified | T033–T034; machine-wide install untouched |
| S9 Debug build + saltests | ✅ 1353/0 | ✅ 1353/0 | T007 baseline 1353/0 ×2, T039 ×2 |
| S10 Defender scan | ✅ tree: no threats | ✅ installer: no threats | T016, T034 |
| Integrated `build.cmd full release sign setup` | ✅ 2 min 54 s; 168 signed + 4 exempt; installer signed | ✅ 0 min 28 s; 0 signed + 4 exempt (idempotent); installer signed | T040; both installers Defender-clean |

## Owed human step

**Clean-machine start** (spec User Story 1, acceptance scenario 1; research
R7). Not reachable from this session: not elevated, Windows Sandbox not
installed (needs the optional feature + reboot), Hyper-V present but
`Get-VM` denied, Docker offers Linux containers only. What substitutes for
it here — and why it is strong evidence, not proof: (1) the import closure
of all 220 shipped PE files resolves inside the tree root, including the
runtime's own dependencies (`check_runtime_deps.py`, T009/T012); (2) on
this machine, which *has* the system-wide runtime 14.51.36247, the running
program loads all four runtime modules from its own directory (T015) — the
loader's application-directory-first order is what a clean machine relies
on; (3) the signed installer places and removes the four files (T033–T034).

To close it: on a Windows 10/11 VM or Windows Sandbox with **no**
"Microsoft Visual C++ 2015-2022 Redistributable (x64)" entry in *Installed
apps*, run the signed installer, launch Tandem Commander from the final
page, confirm the main window opens and *Plugins → Plugins Manager* lists
all 20 plugins; record Windows build, the absence of the redistributable
entry and the result here.

### T039 — S9 run 1 and run 2 (after all code changes)

`build.cmd` (Debug, incremental) BUILD SUCCEEDED earlier in T021;
`saltests.exe`: run 1 **1353 checks, 0 failed**; run 2 **1353 checks,
0 failed** — identical to the T007 baseline.

### T040 — integrated `build.cmd full release sign setup`, run 1 and run 2

| Run | Build | Runtime step | Sweep (`build.cmd … sign`) | `build_setup.cmd sign` | Result |
|---|---|---|---|---|---|
| 1 | BUILD SUCCEEDED, 2 min 54 s (full: 189 language modules rebuilt) | `4 file(s) copied`, `runtime closure OK: 220 …` | `Signed: 168  Skipped: 48  Exempt (Microsoft): 4  Failed: 0  (of 220)` | sweep `Signed: 0 … Exempt (Microsoft): 4`, `Installer signed and verified` | summary `Runtime : 4 file(s) shipped, closure OK`, `Code signing : OK`, `Installer : OK`; installer 8,280,312 B |
| 2 | BUILD SUCCEEDED, 0 min 28 s (nothing to rebuild) | same | `Signed: 0  Skipped: 216  Exempt (Microsoft): 4  Failed: 0  (of 220)` (idempotent) | same, installer re-compiled and signed | same summary; installer 8,280,656 B |

Both installers `MpCmdRun` → `found no threats`; kept in the scratchpad as
`test-installer-077-pipeline1.exe` / `…pipeline2.exe`; the archived published
0.1.7 installer restored into `setup\output` after each run (SHA-256
`6731E146…F64DD` re-verified).

### T042 — close

All 43 tasks done except the owed human step recorded above. Final tree:
361 files, 220 PE candidates (216 project-signed, 4 Microsoft-exempt),
`tandemcommander.exe` without `WriteProcessMemory`/`VirtualProtect`.
Pre-existing defects found on the way and handed to `specs/NEXT-WORK.md`
§0: minidumps never produced (`dbghelp.dll` not shipped next to
`salmon.exe`), and an old bug report blocking start-up in `SalmonCheckBugs`.

## Changelog draft

For `CHANGELOG.md` under the next version (the bump and the entry are made
together at the ship gate; wording in the user's terms per the constitution):

```markdown
### Fixed

- **The program starts on a computer that has no Microsoft Visual C++
  runtime installed.** Every version from 0.1.0 to 0.1.7 depended on the
  "Microsoft Visual C++ 2015-2022 Redistributable (x64)" being present, but
  neither installed it nor said so: on a computer without it the installer
  finished normally and Tandem Commander then refused to start with
  *"The code execution cannot proceed because VCRUNTIME140.dll was not
  found"*. The runtime files now ship inside the program folder, so no
  separate installation is needed. Nothing changes on computers that already
  had the runtime.

### Changed

- **Starting the program no longer rewrites Windows system code in memory.**
  Since its Open Salamander days the program patched a Windows function
  (`SetUnhandledExceptionFilter`) inside its own process at every start so
  that no add-on could take over crash reporting. Behaviour-based antivirus
  engines treat exactly this pattern as suspicious, and it is one likely
  reason for false alarms such as the reported Avast detection. The patch is
  gone; crash reports are produced exactly as before, and the reporter simply
  re-registers itself periodically instead. Crash *minidumps* were never
  produced by any release (a missing helper library) and still are not — the
  text report is unchanged; this is recorded as a separate follow-up.
```

## Side effects

- `setup\output\tandemcommander-0.1.7-x64-setup.exe` (archived published
  installer, SHA-256 `6731E146…F64DD`) was moved aside before every
  packaging build and restored afterwards, hash-verified each time; the
  test installers built here stay in the session scratchpad
  (`test-installer-077-run1.exe`, plus the pipeline runs').
- Two silent per-user installs into the scratchpad were made and removed
  (HKCU uninstall key created and deleted both times); the machine-wide
  0.1.7 installation in `C:\Program Files\Tandem Commander\` was not
  touched (exe timestamp and HKLM key unchanged).
- Seven injected crashes of throw-away instances of the built program; their
  reports (`*-NC017X64-*.TXT`) were moved out of
  `%LOCALAPPDATA%\Tandem Commander\` into `%TEMP%\tc077-bugreports\` so the
  next start does not offer them (see T003–T006 learning 1). The directory
  is left as it was found (only `WebView2\`).
- The Release tree in `build\` is fully signed (216 project + 4 Microsoft)
  and contains the four runtime DLLs; the Debug tree was rebuilt with the
  change; `build\obj\Release_x64\Intermediate\` holds the PDB the
  breakpoint probe used.
- `%TEMP%\tc077-reassert.log/.cdb` and the copied trees `tc-signneg-*` in
  the scratchpad are inspection leftovers, safe to delete.
- Git: five commits on `077-fix-antivirus-findings` (076 record, 077 design,
  US1, US2, US3) plus the closing commit; nothing pushed.

## Final state of the import table

`dumpbin /imports tandemcommander.exe` (clean-rebuilt 19:39:15 and every
later build): no `WriteProcessMemory`, no `VirtualProtect`;
`SetUnhandledExceptionFilter`, `OpenProcess`, `CreateToolhelp32Snapshot`,
`IsDebuggerPresent` remain (legitimate uses, out of scope — 076 §3.4).
