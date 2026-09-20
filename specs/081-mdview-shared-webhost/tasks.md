# Tasks: mdview onto the Shared WebView2 Host (081)

**Input**: Design documents from `specs/081-mdview-shared-webhost/`
**Prerequisites**: plan.md, spec.md, research.md (R1–R14), data-model.md,
contracts/mdview-host-config.md, contracts/browser-arguments-single-source.md,
quickstart.md

**Tests**: the spec makes verification artefacts deliverables (fixtures FR/US2,
probes R10, harness script FR-014, on-screen checklist FR-011), so the test and
probe tasks below are mandatory, not optional.

**Organization**: the migration itself is one indivisible code change (no user
story is testable before mdview compiles on the shared host), so it is the
Foundational phase; the user-story phases then deliver each story's **evidence**
and story-specific artefacts. Every phase ends with a commit.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 viewing parity · US2 hostile documents · US3 keeper · US4 one copy for the maintainer · US5 hand-over

## Path Conventions

Repository root `E:\Projects\tandemcommander`. **`OPENSAL_BUILD_DIR` is not set
on this machine**, so `build.cmd` uses its documented default `.\build\`
(build.cmd:67–69) and the live tree is
`E:\Projects\tandemcommander\build\tandemcommander\{Debug_x64,Release_x64}\`
— verified newer (mdview.spl 2026-09-20 09:00) than the `D:\Build\OpenSal\`
tree CLAUDE.md's quick start suggests (2026-09-19). Every task below uses the
local tree; reference tree `build\tandemcommander\Debug_x64_prefix081\`;
scratch fixtures `%TEMP%\md081\`.

---

## Phase 1: Setup (evidence baseline — BEFORE the first build of this branch)

**Purpose**: preserve the pre-migration reference, confirm the sites are as
research describes (069 protocol), author the shared fixture corpus.

- [X] T001 Pin the build tree in `specs/081-mdview-shared-webhost/fix-log.md` (create it: header, baseline commit `6b4d7af`, branch, date): record that `OPENSAL_BUILD_DIR` is unset in every scope (process/user/machine) so `build.cmd` defaults to `.\build\`, that the live Debug tree is `build\tandemcommander\Debug_x64\` (`tandemcommander.exe` 2026-09-20 09:46, `plugins\mdview\mdview.spl` 09:00, `plugins\codeview\codeview.spl` 09:00, 233 MB / 432 files excluding `Intermediate`), and that the stale `D:\Build\OpenSal\` tree (2026-09-19) is **not** used by this feature — with the one-line reason, since CLAUDE.md's quick start sets the variable
- [X] T002 Preserve the reference tree **before any build on this branch**: `robocopy build\tandemcommander\Debug_x64 build\tandemcommander\Debug_x64_prefix081 /E /XD Intermediate /NFL /NDL /NJH /NJS` (≈233 MB, E: has 162 GB free; `build\` is gitignored); verify `Debug_x64_prefix081\tandemcommander.exe` and `plugins\mdview\mdview.spl` exist, start it once with `-t REF081` and close it to prove it runs standalone; note size, file count and the mdview.spl timestamp in `fix-log.md` (research R7)
- [X] T003 [P] 069-protocol check that HEAD matches research R1: `git log -1 --format=%h -- src/plugins/mdview/webview.cpp` is `b9498d9` and `-- src/common/webhost/` is `ec7b796`; `rg -c "disable-features=msWebOOUI" src/` reports 3 (`mdview/webview.cpp`, `webhost.cpp`, `webkeeper.cpp`); `rg MdKeeperArmed src/` hits only `webview.h/.cpp`; record in `fix-log.md`
- [X] T004 [P] Author the security fixture corpus per research R8 in `specs/081-mdview-shared-webhost/fixtures/security/`: `01-script-tag.md`, `02-event-handlers.md`, `03-javascript-link.md`, `04-remote-image.md`, `05-iframe.md`, `06-meta-refresh.md`, `07-form.md`, `08-path-traversal-image.md`, `09-download-link.md`, `10-legit-control.md` (inline `<style>`, `style=` attributes, `![dot](assets/dot.png)`, a `data:image/png;base64` 1×1 image, `<kbd>`, `<sub>`, `<details>`, an aligned table, a fenced `c` block, a `[top](#top)` anchor link, `[b](10b-linked.md)`, `[notes](notes.txt)`, `https://`, `mailto:`, `ftp://` links), `10b-linked.md`, `notes.txt`, `assets/dot.png` (generate the 1×1 PNG with Python `zlib`+`struct`, no third-party module), and `README.md` (one line per file: construct → expected on screen → which checklist row)
- [X] T005 [P] Add a `.gitattributes`-safe copy step to `quickstart.md` § 0 if missing and copy the corpus to `%TEMP%\md081\` for the probes (`robocopy specs\081-mdview-shared-webhost\fixtures\security %TEMP%\md081 /E`)
- [X] T006 Commit Phase 1: `[081] Evidence baseline: reference tree recorded, fixture corpus` (fixtures + fix-log; the reference tree lives outside the repository)

---

## Phase 2: Foundational — the migration (blocks every story)

**Purpose**: mdview compiles and runs on `CTcWebHost` + `CTcWebKeeper`; its own
host copy is gone. Contract: `contracts/mdview-host-config.md`; shapes:
`data-model.md`; decisions: research R2/R3.

**⚠️ CRITICAL**: no story evidence can be gathered before T017 is green.

- [X] T007 Create `src/plugins/mdview/webglue.h` (COM-free; SPDX header; includes `<string>`, `"webhost.h"`, `"htmlgen.h"`): declare `void MdConfigureHost(TcWebHostConfig& cfg, const MdHtmlResult* doc);`, `void MdCleanupOldUserDataFolder();`, `void MdKeeperArm();`, `void MdKeeperDisarm();` with the header comment stating that all WebView2/COM usage now lives in `src/common/webhost/` and what stays here (contract §1–§4); do **not** declare `MdKeeperArmed()` (research R2)
- [X] T008 Create `src/plugins/mdview/webglue.cpp`: move from `webview.cpp` unchanged the helpers `MakeExtPath`, `ReadFileBytes`, `FetchRemote` (WinHTTP, `<winhttp.h>`), the janitor `CMdUdfJanitorThread` + `MdCleanupOldUserDataFolder` (now using `SHGetFolderPathW` only for the *old* folder path); rewrite `SniffContentType` to return bare media types; implement `MdConfigureHost` per contract §1–§3 (`VirtualHost L"mdview.invalid"`, `DocumentPath L"doc.html"`, `ScriptsEnabled=false`, `WebMessagesEnabled=false`, `TraceName="mdview"`, `Serve` lambda capturing `doc` — `doc.html` → 200 `text/html; charset=utf-8` `doc->html`; `img/<n>` → 200 sniffed or **404 `Not Found`/`application/octet-stream`** returned as `true`; else `false`; `Accelerator` lambda with the 0.1.7 map verbatim); implement `MdKeeperArm/Disarm` over one `static CTcWebKeeper` with `TcWebKeeperConfig{L"TandemMdKeeperWnd", DLLInstance, "mdview keeper"}`; `#include "precomp.h"`, `"webglue.h"`, `"webkeeper.h"` — **no** `<wrl.h>`/`WebView2.h`
- [X] T009 Update `src/plugins/mdview/viewer.h`: `class CMdWebHost;` → `class CTcWebHost;`; `CMdWebHost* Web;` → `CTcWebHost* Web;`; add `int DocVersion; // bumped whenever Html is regenerated; Navigate(DocVersion, …) cache-busts` (data-model §4)
- [X] T010 Update `src/plugins/mdview/viewer.cpp`: includes `"webview.h"` → `"webglue.h"` + `"webhost.h"`; constructor `DocVersion = 0`; `ViewFile` and `WM_CREATE`: `CMdWebHost::RuntimeAvailable()` → `CTcWebHost::RuntimeAvailable()`; `WM_CREATE`: `Web = new CTcWebHost(); TcWebHostConfig cfg; MdConfigureHost(cfg, &Html); CTcWebHost::Callbacks cb; … Web->Create(HWindow, TcWebUserDataFolder(), cfg, cb);` keeping the five callbacks 1:1 (data-model §2); `ShowDocument`: `Web->SetDocument(&Html, DocDir)` → `DocVersion++`, `Web->Navigate(fragment)` → `Web->Navigate(DocVersion, fragment)`; `DoFind`: `SetDocument` → `DocVersion++`, `Web->Navigate()` → `Web->Navigate(DocVersion)`, `Navigate(L"mdfind-…")` → `Navigate(DocVersion, L"mdfind-…")`; `OnReady`: `SetDocument` → `DocVersion++`, `Navigate()` → `Navigate(DocVersion)`; `MdUserDataFolder()` → `TcWebUserDataFolder()`; leave `ActivateLink`, `InitViewer`'s `HACCEL` table and everything else untouched (constitution III)
- [X] T011 Update `src/plugins/mdview/mdview.cpp`: `#include "webview.h" // feature 065: MdKeeperDisarm (COM-free header)` → `#include "webglue.h" // feature 081: MdKeeperDisarm wrapper over the shared CTcWebKeeper`; the two `MdKeeperDisarm()` call sites stay as they are
- [X] T012 [P] Update `src/plugins/mdview/vcxproj/mdview.props`: `AdditionalIncludeDirectories` → `..\..\..\common\dep\webview2\include;..\..\..\common\webhost;..\..\..\common\dep\md4c;%(AdditionalIncludeDirectories)` (codeview.props precedent; link libraries unchanged)
- [X] T013 [P] Update `src/plugins/mdview/vcxproj/mdview.vcxproj`: add `ClCompile` `..\..\..\common\webhost\webhost.cpp` and `..\..\..\common\webhost\webkeeper.cpp` (before `..\mdview.cpp`, as codeview.vcxproj does), replace `ClCompile ..\webview.cpp` → `..\webglue.cpp`; add `ClInclude` `..\..\..\common\webhost\webhost.h`, `..\..\..\common\webhost\webkeeper.h`, replace `ClInclude ..\webview.h` → `..\webglue.h`
- [X] T014 `git rm src/plugins/mdview/webview.cpp src/plugins/mdview/webview.h`
- [X] T015 Debug build: close any running Debug `tandemcommander.exe` (LNK1104 otherwise), run `build.cmd` from the repo root (**do not set `OPENSAL_BUILD_DIR`** — T001 pinned the default `.\build\`); fix compile/link errors **inside the new/changed mdview files only** (a needed change to the shared host is a finding to record, not a silent edit); confirm `Debug_x64\plugins\mdview\mdview.spl` rebuilt and `codeview.spl` also rebuilt (shared sources compile twice); record the build log tail in `fix-log.md`
- [X] T016 `clang-format -i` on `webglue.h`, `webglue.cpp`, `viewer.h`, `viewer.cpp`, `mdview.cpp` (repository `.clang-format`); rebuild if anything moved; verify files stay UTF-8-BOM (`tools/check_encoding.py` runs inside `build.cmd`)
- [X] T017 Smoke by hand-in-the-loop driver before committing: start the Debug tree with `specs/080-restart-manager-upgrade/probe/tc_drive.ps1 -Action start -Exe …\Debug_x64\tandemcommander.exe -Left %TEMP%\md081 -TitlePrefix T081`, `-Action key -Vk 0x28` (Down) then `-Vk 0x72` (F3), `-Action dialogs` must list a `*Markdown Viewer*` window and `tasklist` must show `msedgewebview2.exe`; `-Action closewnd -Title "Markdown Viewer"`; `-Action close`; record in `fix-log.md`
- [X] T018 Commit Phase 2 as one revertible change: `[081] Markdown Viewer renders through the shared WebView2 host` (message names what moved, what stayed, and the 404 preservation)

**Checkpoint**: mdview runs on the shared host; stories can now be evidenced.

---

## Phase 3: User Story 1 — Viewing works exactly as before (Priority: P1) 🎯 MVP

**Goal**: rows A1–A10 of `quickstart.md` provably "same" as the reference tree.

**Independent Test**: the smoke probe passes on the migrated Debug tree, the
generator harness is green, and the pixel diff of the legit control against
the reference tree is ≤ 0.1 %.

- [X] T019 [P] [US1] Create `tests/mdview_htmlgen_test/build_and_run.cmd` (research R9): locate VS via `vswhere` like `build.cmd`, call `VsDevCmd.bat -arch=x64`, `cl /nologo /EHsc /std:c++latest /W3 /D_CRT_SECURE_NO_WARNINGS /DUNICODE /D_UNICODE /I..\..\src\plugins\mdview /I..\..\src\plugins\shared /I..\..\src\common\dep\md4c /I..\..\src\common\dep\webview2\include /Foobj\ test_main.cpp ..\..\src\plugins\mdview\htmlgen.cpp ..\..\src\plugins\mdview\render.cpp ..\..\src\plugins\mdview\highlight.cpp ..\..\src\common\dep\md4c\md4c.c /link /out:obj\htmlgen_test.exe`, the same for `dump_main.cpp` → `obj\htmlgen_dump.exe`; run the test, print `RESULT: PASS|FAIL` from the `[FAIL]` count; add `obj/` to `tests/mdview_htmlgen_test/.gitignore`; if the link needs plugin symbols (`LoadStr`, `SalamanderGeneral`, `DLLInstance`, `HLanguage`), add `tests/mdview_htmlgen_test/test_stubs.cpp` with the minimal definitions and record which were needed in `fix-log.md`
- [X] T020 [US1] Run `build_and_run.cmd`; record the `[PASS]` count (the FR-014 baseline — the harness inputs are untouched by this feature) in `fix-log.md`
- [X] T021 [P] [US1] Create `specs/081-mdview-shared-webhost/probe/mdview_probe.ps1` (Windows PowerShell 5.1; reuse the P/Invoke block and window-finding of `specs/080-restart-manager-upgrade/probe/tc_drive.ps1`, one instance identified by pid, title prefix `T081`; parameters `-Exe`, `-Fixtures`, `-Scenario <name|all>`; every scenario prints `PASS`/`FAIL` with measured values and exits non-zero on any `FAIL`): scenario **smoke** — start with `-l <Fixtures>`, Down + F3 on `10-legit-control.md`, wait for a `*Markdown Viewer*` top-level window (≤ 15 s), assert `msedgewebview2.exe` children exist, post `WM_COMMAND` `CM_VIEW_ZOOMIN`(109) → title contains `(110%)`, `CM_VIEW_ZOOMRESET`(111) → `(100%)`, `CM_FILE_OPENTEXT`(101) → `[Source]`, again → gone, `CM_SCHEME_NEXT`(210) ×3 and `CM_SCHEME_PREV`(211) ×3 → window still alive, `CM_EDIT_FINDNEXT`(106) with no term → a dialog titled like the plugin appears (Find), close it with `WM_CLOSE`; `closewnd`; assert the process is alive; scenario **release-smoke** — same against a Release exe
- [X] T022 [P] [US1] Create `specs/081-mdview-shared-webhost/probe/render_diff.ps1` (PS 5.1, `System.Drawing`): parameters `-Ref`, `-New`, `-File`, `-Out`; for each exe: start with `-l <folder of File>`, Down + F3, wait for the viewer, `SetWindowPos` it to a fixed rect (e.g. 100,100,1000,800), wait 1.5 s, `CopyFromScreen` of the client rect (`GetClientRect` + `ClientToScreen`), save PNG, close viewer and app; compare the two bitmaps pixel by pixel (channel tolerance 8/255), print `differing pixels: N / total (P %)`, `PASS` if ≤ 0.1 %; save a red-marked diff PNG when failing
- [X] T023 [US1] Run `mdview_probe.ps1 -Scenario smoke` and `render_diff.ps1` (reference = `build\tandemcommander\Debug_x64_prefix081`, new = `build\tandemcommander\Debug_x64`, file = `%TEMP%\md081\10-legit-control.md`); paste the printed results and the PNG paths into `fix-log.md`; any FAIL is a finding → fix in the mdview glue/viewer → rebuild → rerun
- [X] T024 [US1] Release build `build.cmd full release` (G1); run `mdview_probe.ps1 -Scenario release-smoke -Exe build\tandemcommander\Release_x64\tandemcommander.exe`; record; confirm `tools/check_runtime_deps.py` passed inside the build
- [X] T025 [US1] Commit Phase 3: `[081] Evidence: generator harness script, smoke and render-diff probes`

**Checkpoint**: US1 evidenced by machine; rows A2/A6–A9 remain for the person (quickstart § A).

---

## Phase 4: User Story 2 — Hostile documents stay harmless (Priority: P1)

**Goal**: rows B1–B9 and D1–D4 evidenced as far as a machine can; the CSP is
proven not to block the generator's own output.

**Independent Test**: `check_csp_compat.py` reports 0 blocked references for the
legit control; the hostile-corpus probe shows one window per file, no dialog,
no process growth; the Debug trace contains no `lockdown regression`.

- [X] T026 [P] [US2] Create `specs/081-mdview-shared-webhost/probe/check_csp_compat.py` (Python 3.13 stdlib): run `tests\mdview_htmlgen_test\obj\htmlgen_dump.exe <fixture> <out.html>` for every `fixtures/security/*.md` and `tests/mdview_htmlgen_test/sample.md` (a `--docdir` argument pointing at the fixture folder so `assets/dot.png` resolves), parse each output with `html.parser`, collect every `src`, `href` (of `<link>`), `srcset`, `poster`, `action`, `<style>`/`style=` `url(...)`, `<script>`, `<iframe>`/`<object>`/`<embed>`, `<base>`, `<form>`; classify against `kCspStatic` (allowed: `https://mdview.invalid/img/<n>`, `data:` in `img`; everything else blocked); print a per-file table; exit 1 if `10-legit-control.md` has any blocked reference or if a hostile file's blocked set is empty (the fixture would not test anything)
- [X] T027 [US2] Run `check_csp_compat.py`; paste the table into `fix-log.md`; if the legit control shows a blocked reference, decide per research R4 whether the fixture or the analysis is wrong (the CSP itself is not to be relaxed)
- [X] T028 [US2] Extend `probe/mdview_probe.ps1` with scenario **hostile** — for each `0?-*.md` in `-Fixtures` (not `10-*`): position the panel cursor on it (Home, then Down n times), F3, wait for the viewer, assert exactly one new visible top-level window of the process (no message box, no download bubble window of class `Chrome_WidgetWin_*` outside the viewer's rect), assert the `msedgewebview2.exe` process count did not grow beyond the tree size seen after the first view, for `01-script-tag.md` assert the window title still contains `01-script-tag.md - Markdown Viewer`, `closewnd`; print one PASS/FAIL line per file
- [X] T029 [US2] Run `mdview_probe.ps1 -Scenario hostile` on the Debug tree; record in `fix-log.md`
- [X] T030 [US2] **Not achievable as planned, replaced** (see fix-log T030): a plugin's TRACE goes through `SalamanderDebug`, not `OutputDebugString`, so no DBWIN tool can capture `AssertLockdown`. The listener was written, run and deleted; the claim is instead made by code path (the CSP reaches `doc.html` despite the `?v=` cache-buster) plus D1-D3 behaviour, and quickstart row D4 now says the Trace Server is needed. ~~start the Debug tree under a DBWIN listener (recipe in `specs/078-panel-tabs/fix-log.md`; or `Sysinternals DebugView` if present), run `-Scenario smoke`, save the trace to `specs/081-mdview-shared-webhost/probe/out/trace-smoke.txt` (gitignored dir — add `probe/out/` to a `.gitignore` in the feature dir), assert `Select-String "lockdown regression"` → 0 hits and `Select-String "mdview: controller ready"` ≥ 1 (TraceName parity) and `"mdview keeper: armed"` ≥ 1; record
- [X] T031 [US2] Commit Phase 4: `[081] Evidence: CSP compatibility check, hostile-corpus probe, lockdown read-back`

**Checkpoint**: US2 evidenced by machine; the network monitor (B column) remains for the person (quickstart § B).

---

## Phase 5: User Story 3 — The second view is still instant (Priority: P2)

**Goal**: 065 scenarios 1, 4, 5 automated; 3 and 7 handed to the person.

**Independent Test**: keeper scenarios print PASS with measured times.

- [X] T032 [US3] Extend `probe/mdview_probe.ps1` with scenarios: **keeper-warm** — fresh start, F3 (measure t_cold = F3 → viewer window), close, sleep 65 s, assert `msedgewebview2.exe` tree still belongs to the pid (parent chain), F3 (t_warm1), close, immediately F3 (t_back2back), close; PASS if the tree survived and `t_warm1 ≤ 2 × t_back2back` (print all three); **keeper-crash** — with the keeper armed and no viewer, `taskkill /f /im msedgewebview2.exe` (only processes whose parent chain reaches the pid), F3 → viewer appears (t_cold2), close, F3 → viewer (t_warm2), PASS if `t_warm2 ≤ 2 × t_back2back`; **cold-close** — 10 × (F3, `closewnd` within 100 ms) on a fresh engine tree (kill it before each iteration with no viewer open), assert the process is alive after each and one final normal open works; under the DBWIN listener assert no `Detected memory leaks` block naming `mdview.spl` / `webglue.cpp` / `webhost.cpp`; **cross-warm** — fresh start, F3 on a `.cpp` in `-Fixtures` (add `hello.cpp` to the corpus folder; codeview is the default F3 viewer for it), wait for `*Code Viewer*`/codeview title, close, F3 on `10-legit-control.md` (t_md), PASS if `t_md ≤ 2 × t_back2back` (either plugin's keeper warms the other)
- [X] T033 [US3] Run the four keeper scenarios on the Debug tree; record times and verdicts in `fix-log.md`; a FAIL on `cold-close` is a finding in the glue lifetime (the shared host's `alive` guard covers the host; the `Serve` capture of `&Html` must not outlive the window) → fix → rerun
- [X] T034 [US3] Commit Phase 5: `[081] Evidence: keeper warmth, crash re-arm, close-during-cold-start, cross-plugin warmth`

**Checkpoint**: US3 evidenced by machine; C5 (Plugins Manager toggle) and C7 (unload/reload) remain for the person (quickstart § C).

---

## Phase 6: User Story 4 — One copy of the host for the maintainer (Priority: P2)

**Goal**: the browser-arguments set exists once; guards prove the consolidation;
the living documentation says the migration is complete.

**Independent Test**: G2 guards pass; grep of the living documents finds no
"mdview still carries its own copy".

- [X] T035 [US4] Shared host, one arguments source (contract `browser-arguments-single-source.md`): add `const wchar_t* TcWebBrowserArguments();` to `src/common/webhost/webhost.h` (COM-free section, with the contract comment); in `src/common/webhost/webhost.cpp` define it once and make `TcWebBuildEnvOptions()` call `options->put_AdditionalBrowserArguments(TcWebBrowserArguments())`; in `src/common/webhost/webkeeper.cpp` replace `TcWebKeeperEnvOptions`'s literal with `TcWebBrowserArguments()` and fix its comment ("rebuilt here … by including the one definition below" was never true); `build.cmd` (both plugins recompile the shared sources); commit separately: `[081] Shared WebView2 host: the browser-arguments set is defined once`
- [X] T036 [US4] Static guards (quickstart G2): `rg -l "wrl\.h|WebView2\.h|WebView2EnvironmentOptions\.h" src/plugins/mdview/` → empty; `rg -c "disable-features=msWebOOUI" src/` → only `src/common/webhost/webhost.cpp:1`; `test ! -e src/plugins/mdview/webview.cpp`; `dumpbin /imports` (PowerShell only — Defender quirk) of the new `build\tandemcommander\Debug_x64\plugins\mdview\mdview.spl` lists the same import DLLs as the reference `Debug_x64_prefix081\plugins\mdview\mdview.spl` (winhttp, shlwapi, ole32 …); paste results into `fix-log.md`
- [X] T037 [P] [US4] Update `architecture/11-webview2-integration.md`: "Status of the migration" paragraph → complete (feature 081, both plugins on `src/common/webhost/`), §2.2 → the set lives in `webhost.cpp` `TcWebBrowserArguments()` (quote the value; "extending it" = one edit there), §2.4 → "each plugin arms its own `CTcWebKeeper`" (the shared component now exists; the core-hosted service stays deferred), §2.5 → "done; a third consumer adds `webhost.cpp`/`webkeeper.cpp` to its project and a `TcWebHostConfig`", §3 build checklist → `mdview.props`/`codeview.props` include dir + the two `ClCompile` items, COM confinement → "inside `src/common/webhost/*.cpp` only; plugin glue is COM-free (`webglue.cpp` in both plugins)", §4 references → `src/common/webhost/webhost.{h,cpp}`, `webkeeper.{h,cpp}`; mdview glue as `src/plugins/mdview/webglue.{h,cpp}`; add 081 to the header's feature list
- [X] T038 [P] [US4] Update `specs/070-source-viewer-plugin/contracts/webview-host-sharing.md` §4: append "Verification record (feature 081, 2026-09-20)" listing what was proven by which artefact (G1–G7 with the fix-log pointer) and that the on-screen pass is owed; and `specs/070-source-viewer-plugin/REMAINING-WORK.md` §2: prepend "✅ DONE (feature 081)" with pointers to `specs/081-mdview-shared-webhost/closing-report.md` and the owed GUI pass
- [X] T039 [P] [US4] Update `specs/NEXT-WORK.md`: item 4 first bullet → "✅ DONE (feature 081, 2026-09-20)" with the same pointers; add the 081 on-screen checklist to item 3's list of owed sweeps (`081 quickstart.md § A–D`); update the *Revised* line
- [X] T040 [P] [US4] Append to `src/plugins/mdview/IMPLEMENTATION_NOTES.md` a "v2.3 — Feature 081: onto the shared WebView2 host" section: what moved where, what stayed (`webglue.cpp`), the hardening inherited (contract §5 table, short), `DocVersion` in the window, `MdKeeperArmed` dropped, the probes and the owed GUI pass; correct the v2.2 sentence "its `.vcxproj` has never been committed" → "built by `tests/mdview_htmlgen_test/build_and_run.cmd` since feature 081"
- [X] T041 [P] [US4] Update `CLAUDE.md`: in the WebView2 shared-engine bullet replace "the shared options helper in `src/plugins/mdview/webview.cpp`" with "`TcWebBrowserArguments()` in `src/common/webhost/webhost.cpp`" and "second consumer lifts the helper" → "both plugins are on `src/common/webhost/` since feature 081"; add a `- 081-mdview-shared-webhost:` entry to **Recent Changes** in the house style (what, why, the hardening deltas, what is owed, record pointers)
- [X] T042 [P] [US4] `CHANGELOG.md` → `## [0.1.8] — unreleased` → `### Changed`: add the entry drafted in research R12 (Markdown Viewer on the shared hardened surface; nothing changes for ordinary documents; downloads refused; CSP; keeper unchanged)
- [X] T043 [US4] Commit Phase 6 documentation: `[081] Records: architecture contract complete, handoffs closed, changelog`

**Checkpoint**: SC-001, SC-002, SC-007 hold.

---

## Phase 7: User Story 5 — The hand-over to the person (Priority: P3)

**Goal**: a stranger can run the on-screen pass from one file.

**Independent Test**: `quickstart.md` § 0–2 reference only artefacts that exist, name the reference tree that exists, and every row has an expected outcome.

- [X] T044 [US5] Revise `specs/081-mdview-shared-webhost/quickstart.md` against reality: exact probe parameters as implemented (T021/T022/T026/T028/T032), the measured gate results moved to a "Gate results (implementation, date)" line per gate pointing at `fix-log.md`, any row whose expectation the probes refined (e.g. A7 when `example.invalid` is unresolvable, B9 bubble behaviour on the reference), the `hello.cpp` fixture for C8, and the exact Plugins Manager path for C5/C7 in the English UI
- [X] T045 [US5] Write `specs/081-mdview-shared-webhost/fix-log.md` closing section: gate table G1–G8 with result and evidence pointer; "Owed to a person" list (quickstart § A2/A6–A9, § B network column, § C5/C7, § D eye check); the empty result table for the tester to fill; the DBWIN/leak notes
- [X] T046 [US5] Commit Phase 7: `[081] Hand-over: quickstart against reality, fix-log gate table`

---

## Phase 8: Polish & Cross-Cutting

- [X] T047 Independent review (G7, 069 protocol): spawn a reviewer agent that did not write the code over `git diff main...081-mdview-shared-webhost -- src/` with the contract `contracts/mdview-host-config.md`, research R1/R3/R4 and the question set "is any lockdown relaxed? does anything outlive the window? is the 404 preserved? is the accelerator map byte-identical to 0.1.7? does codeview's behaviour change?"; record the verdict and every finding in `fix-log.md`; fix accepted findings in the mdview glue/viewer, rebuild, rerun T023/T029/T033 for the touched area
- [X] T048 Final full builds after review fixes: `build.cmd` and `build.cmd full release`; rerun G2 guards (T036), `build_and_run.cmd` (T020) and `check_csp_compat.py` (T027); record
- [X] T049 Write `specs/081-mdview-shared-webhost/closing-report.md` (house style of 078/079/080): what was done, evidence table with numbers (lines removed/added, PASS counts, pixel-diff %, timings), the hardening deltas, what is owed to a person and where the checklist is, what changed in the shared host (one accessor) and that codeview recompiled with it, no ABI change (interface 106), no version bump
- [X] T050 Final commit `[081] Closing report`; leave the branch un-merged and report the merge as the user's decision (constitution: PR against `main`)

---

## Dependencies & Execution Order

- **Phase 1 (T001–T006)** first — T002 **must** precede the first `build.cmd` of this branch (it copies the tree that build overwrites). T003, T004, T005 are parallel.
- **Phase 2 (T007–T018)**: T007 → T008 (header before body); T009 → T010; T011, T012, T013 parallel with T008–T010; T014 after T010/T011 (nothing includes `webview.h` any more); T015 after all edits; T016 → T017 → T018.
- **Phases 3–5** depend on T018. T019 ∥ T021 ∥ T022 (three different new files); T020 after T019; T023 after T021+T022; T024 after T023. T026 ∥ (T028 extends the probe file — after T021); T027 after T026 and T019 (needs `htmlgen_dump.exe`); T030 after T021. T032 extends the probe file — after T028.
- **Phase 6**: T035 is independent of the migration and may run any time after T006, but its build (both plugins) is cheapest after T015; T036 after T018 + T035; T037–T042 parallel (six different files), best after T033 so the records describe verified facts; T043 after them.
- **Phase 7** after Phases 3–6. **Phase 8** last; T047 may start as soon as T035 and T018 are in.

### User Story Dependencies

- **US1, US2, US3** share Phase 2 and the probe script (`mdview_probe.ps1`: T021 → T028 → T032 sequential); otherwise independent.
- **US4**'s code task (T035) is independent; its documentation depends on the evidence of US1–US3 only for truthfulness.
- **US5** depends on everything before it.

## Parallel Examples

```text
# Phase 1, after T001–T002:
T003 069-protocol HEAD check          | T004 fixture corpus         | T005 copy corpus to %TEMP%\md081

# Phase 2, after T007 and T009:
T008 webglue.cpp | T010 viewer.cpp | T011 mdview.cpp include | T012 mdview.props | T013 mdview.vcxproj

# Phase 3 start:
T019 build_and_run.cmd | T021 mdview_probe.ps1 (smoke) | T022 render_diff.ps1

# Phase 6 documentation:
T037 architecture/11 | T038 070 contract + REMAINING-WORK | T039 NEXT-WORK | T040 IMPLEMENTATION_NOTES | T041 CLAUDE.md | T042 CHANGELOG
```

## Implementation Strategy

**MVP = Phases 1–3**: the migration plus the machine evidence that viewing is
unchanged (smoke, harness, pixel diff). It is already shippable in the sense
that mdview is on the shared host and nothing visible moved; Phases 4–5 add the
security and keeper evidence the spec demands before the feature is *accepted*;
Phase 6 makes the consolidation literally true (one arguments literal) and tells
the documentation; Phase 7 hands over; Phase 8 reviews and closes.

**Incremental commits**: one per phase (T006, T018, T025, T031, T034, T035,
T043, T046, T050) so a regression can be bisected to the migration commit alone
and the evidence commits never touch `src/`.

## Notes

- Never run `build.cmd` while a Debug `tandemcommander.exe` with `mdview.spl` loaded is running (LNK1104); the probes always close their instance.
- Run the probes' `Start-Process` without `-Wait` (it waits for the process tree); pass `/switch`-style arguments from PowerShell, not Bash (Git Bash rewrites them) — feature 080 traps.
- `dumpbin` only from PowerShell (Defender blocks some tool command lines in Bash).
- The shared host's invariants are **not** to be edited for mdview's benefit; if T015/T023 seem to need it, that is a finding for `fix-log.md` and a decision, not a quick fix (contract §6).
- Keep `fix-log.md` running from T001 (memory: document progress in the specs dir while working).
