# Implementation Plan: mdview onto the Shared WebView2 Host

**Branch**: `081-mdview-shared-webhost` | **Date**: 2026-09-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/081-mdview-shared-webhost/spec.md`

## Summary

The Markdown Viewer plugin still carries its own 900-line copy of the WebView2
host (`src/plugins/mdview/webview.cpp`) although feature 070 lifted that code
to `src/common/webhost/` and built the Code Viewer on it. This feature deletes
the copy and makes mdview the second consumer of `CTcWebHost` + `CTcWebKeeper`,
exactly as the 070 contract predicted: the plugin keeps a COM-free glue file
(`webglue.{h,cpp}`) with its document/image server, accelerator map, keeper
wrappers and the pre-065 cache-folder janitor; the viewer window owns the
document version. The shared host is a strict superset of the copy (research
R1), so mdview gains a content security policy on its document, download
refusal and the close-during-cold-start guard while every user-visible
behaviour stays as in 0.1.7. The browser-arguments literal, present three times
today, is reduced to one accessor (`TcWebBrowserArguments()`). Acceptance is
automated where posted-message driving and pixel comparison allow (research
R10) and handed to a person as a written checklist (`quickstart.md`) for the
rest.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS 2022)
**Primary Dependencies**: vendored WebView2 SDK 1.0.4078.44
(`src/common/dep/webview2/`, static loader), WRL from the Windows SDK (only
inside `src/common/webhost/*.cpp`), WinHTTP (mdview-only, consented remote
images), md4c (mdview-only), plugin shared sources (`src/plugins/shared/`)
**Storage**: registry values unchanged (`KeepReady`, schemes, zoom, placement
under the plugin key); cache folder `%LOCALAPPDATA%\Tandem Commander\WebView2`
unchanged
**Testing**: `build.cmd` (Debug x64) and `build.cmd full release`;
`tests/mdview_htmlgen_test/` via a new `build_and_run.cmd` (the project file
was never committed — R9); static guards (grep: no `wrl.h`/`WebView2.h` under
`src/plugins/mdview/`, exactly one browser-arguments literal in `src/`);
PowerShell probes derived from 080's `tc_drive.ps1` (open/zoom/source/scheme
smoke, keeper warmth, crash re-arm, close-during-cold-start leak check,
hostile-corpus dialog/process check, pixel diff against the reference tree);
on-screen checklist for a person (`quickstart.md`)
**Target Platform**: Windows 11 x64 (x86 configurations must still compile)
**Project Type**: desktop-application plugin — consolidation onto a
source-lifted shared component (no new DLL)
**Performance Goals**: feature 065 SC-001/SC-002 unchanged — first view no
slower than 0.1.7; warm second view within 2× the back-to-back time
**Constraints**: plugin interface 106 untouched; no new binary; no UI string
change; nothing in the lockdown relaxed; mdview contains no COM/WebView2
include; browser-arguments literal count in `src/` == 1
**Scale/Scope**: −902 lines (`webview.cpp`) −82 (`webview.h`), ≈ +230 lines
glue, ≈ 30 lines in `viewer.{h,cpp}`/`mdview.cpp`, 2 build files, 3 shared-host
lines, 12 fixture files, 2–3 probe scripts, 7 documents

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. Build Reproducibility | one command (`build.cmd`) builds mdview with the shared sources; no manual copy step; the test harness gets a committed script instead of an uncommitted project file | **PASS** |
| II. Backward Compatibility | user-visible behaviour identical to 0.1.7 (FR-003); the only deltas are stricter refusals of hostile content (FR-005, R1/R4), i.e. no regression of a behaviour users depend on; no configuration change; no config-version bump | **PASS** — deltas enumerated and each shown to be a refusal of something that never rendered legitimately |
| III. Incremental Modernization | one concern (the second half of the 070 lift), one reviewable/revertible commit series; no adjacent refactor — `ActivateLink`'s literal origin string, the accelerator table in `InitViewer`, `htmlgen` untouched. The one shared-host edit (browser-arguments accessor, R5) is the completion of the very contract this feature implements, not an adjacent tidy-up | **PASS** |
| IV. Windows Platform Commitment | pure WinAPI/COM; no new dependency | **PASS** |
| V. Plugin Architecture Preservation | `src/plugins/shared/` untouched; interface 106; the shared host stays source-lifted (070 contract §3.2) | **PASS** |
| VI. UI Consistency | no dialog or control changes | **PASS** |
| Release Documentation | `CHANGELOG.md` 0.1.8 *Changed* entry, truthful about scope (R12); no version bump (ships inside the unreleased 0.1.8) | **PASS** |
| Workflow | descriptive English commit messages; `clang-format` on touched files; build verification before merge | **PASS** |

**Post-design re-check (after Phase 1)**: no new violation. The design adds
one exported function to the shared header and one glue file to the plugin —
both within the 070 contract's stated shape. Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/081-mdview-shared-webhost/
├── spec.md                          # feature specification
├── plan.md                          # this file
├── research.md                      # R1–R14: deltas, decisions, risks
├── data-model.md                    # host configuration, keeper, document version
├── quickstart.md                    # automated gates + the on-screen checklist (FR-011)
├── contracts/
│   ├── mdview-host-config.md        # mdview's per-plugin configuration of the shared host
│   └── browser-arguments-single-source.md
├── fixtures/
│   └── security/                    # the hostile corpus + legit control (R8)
│       ├── README.md
│       ├── 01-script-tag.md … 09-download-link.md
│       ├── 10-legit-control.md, 10b-linked.md
│       └── assets/dot.png
├── probe/
│   ├── mdview_probe.ps1             # posted-message driver scenarios (R10)
│   ├── render_diff.ps1              # pixel diff reference vs migrated
│   └── check_csp_compat.py          # generator-output resource classifier
├── checklists/requirements.md
├── tasks.md                         # /speckit-tasks output
└── fix-log.md                       # running record during implementation
```

### Source Code (repository root)

```text
src/common/webhost/
├── webhost.h            # + const wchar_t* TcWebBrowserArguments();
├── webhost.cpp          # literal defined once; TcWebBuildEnvOptions() uses it
├── webkeeper.h          # unchanged
└── webkeeper.cpp        # options builder calls TcWebBrowserArguments()

src/plugins/mdview/
├── webview.h            # DELETED
├── webview.cpp          # DELETED (902 lines)
├── webglue.h            # NEW: MdConfigureHost, MdCleanupOldUserDataFolder, MdKeeperArm/Disarm
├── webglue.cpp          # NEW: Serve (doc + img/<n>, ReadFileBytes, FetchRemote, SniffContentType),
│                        #      accelerator map, keeper wrappers, UDF janitor — COM-free
├── viewer.h             # CTcWebHost* Web; int DocVersion
├── viewer.cpp           # include webglue.h + webhost.h; Create(cfg); DocVersion++; Navigate(DocVersion, …)
├── mdview.cpp           # include webglue.h (MdKeeperDisarm call sites unchanged)
├── IMPLEMENTATION_NOTES.md  # v2.3 section
└── vcxproj/
    ├── mdview.props     # + ..\..\..\common\webhost include dir
    └── mdview.vcxproj   # + webhost.cpp/.h, webkeeper.cpp/.h; webview → webglue

tests/mdview_htmlgen_test/
└── build_and_run.cmd    # NEW: cl.exe recipe (R9); test_stubs.cpp only if the link needs it

architecture/11-webview2-integration.md      # migration complete; single source named
specs/070-source-viewer-plugin/contracts/webview-host-sharing.md   # §4 verification recorded
specs/070-source-viewer-plugin/REMAINING-WORK.md                   # §2 done
specs/NEXT-WORK.md                                                 # item 4 done; GUI pass → item 3
CLAUDE.md                                                          # Recent Changes; WebView2 bullet
CHANGELOG.md                                                       # 0.1.8 Changed
```

**Structure Decision**: single desktop-application repository; the change is
confined to one plugin directory, four lines in the shared host, its build
files, one test script and the documentation set. No new project, no new
solution entry, no `plugins.cfg` change.

## Design (Phase 1 summary — details in `contracts/` and `data-model.md`)

1. **Glue file** (`webglue.{h,cpp}`, R2/R3): `MdConfigureHost(cfg, &Html)`
   sets `VirtualHost = L"mdview.invalid"`, `DocumentPath = L"doc.html"`,
   `ScriptsEnabled = false`, `WebMessagesEnabled = false`,
   `TraceName = "mdview"`, `Serve` (doc → 200 + CSP by the host; `img/<n>` →
   200 sniffed / 404), `Accelerator` (F3/Shift+F3, Esc, F9/Shift+F9, Ctrl+F,
   Ctrl+U, Ctrl+0/Numpad-0 — the 0.1.7 map verbatim). Keeper wrappers own the
   `TcWebKeeperConfig{L"TandemMdKeeperWnd", DLLInstance, "mdview keeper"}`.
2. **Viewer window** (`viewer.{h,cpp}`): `Web = new CTcWebHost()`;
   `Web->Create(HWindow, TcWebUserDataFolder(), cfg, cb)`; the three
   `SetDocument` sites become `DocVersion++`; `Navigate(DocVersion, frag)`;
   `RuntimeAvailable()` calls move to `CTcWebHost::`. Callbacks map 1:1
   (`OnReady`, `OnActivateLink`, `OnInitFailed`, `OnProcessFailed`,
   `OnZoomChanged`; `OnWebMessage` unused).
3. **Shared host** (R5): `TcWebBrowserArguments()` in `webhost.h/.cpp`; the
   keeper's options builder calls it. No other shared-host change.
4. **Build**: `mdview.props` include dir; `mdview.vcxproj` items.
5. **Evidence**: fixtures (R8), probes (R10), test-harness script (R9),
   reference tree `Debug_x64_prefix081` (R7) created before the first build.
6. **Records**: documents of R11; `CHANGELOG.md` (R12); `fix-log.md` kept
   during implementation.

## Verification strategy

| Gate | What | Automated? |
|---|---|---|
| G1 | `build.cmd` (Debug x64) green; `build.cmd full release` green | yes |
| G2 | static guards: no `wrl.h`/`WebView2.h`/`WebView2EnvironmentOptions.h` include under `src/plugins/mdview/`; `rg -c "disable-features=msWebOOUI" src/` == 1; `webview.cpp/.h` absent | yes |
| G3 | `tests/mdview_htmlgen_test/build_and_run.cmd` — all `[PASS]`, count recorded | yes |
| G4 | `check_csp_compat.py` over the fixture corpus + `sample.md`: legit control zero blocked references | yes |
| G5 | `mdview_probe.ps1`: open/zoom/source/scheme smoke; keeper warmth after 60 s; crash re-arm; ten close-during-cold-start cycles with the DBWIN leak listener; hostile corpus → one window each, no dialogs, no extra processes | yes (Debug build, on this desktop) |
| G6 | `render_diff.ps1`: legit control rendered by reference and migrated trees, ≤ 0.1 % differing pixels | yes |
| G7 | independent review of the diff (069 protocol) before merge | yes (agent) |
| G8 | on-screen checklist (`quickstart.md` § C): network monitor over the hostile corpus, KeepReady toggle via Plugins Manager, unload/reload, dark menus, follow-system, eye over A1–A10 vs reference | **person** — recorded as owed |

## Complexity Tracking

> No Constitution Check violations — nothing to justify.
