# Research — mdview onto the Shared WebView2 Host (081)

**Baseline**: `main` at `6b4d7af` (0.1.8 unreleased, build 192), branch
`081-mdview-shared-webhost`. Every statement below was checked against that
revision on 2026-09-20; the feature-069 protocol ("is the site still as
described at HEAD?") applies to each before it is acted on.

## R1 — What the two copies are, and how they differ

Read side by side: `src/plugins/mdview/webview.cpp` (902 lines, last touched
by feature 069 on 2026-08-24 — the keeper-class fix F-P6-01) and
`src/common/webhost/webhost.cpp` + `webkeeper.cpp` (lifted by feature 070 on
2026-08-26, last touched 2026-08-27 by the stabilization review). **mdview's
copy received no change since the lift.** The shared component differs from it
in these ways — every one stricter or safer, none a relaxation:

| # | Shared host has | mdview copy has | Kind |
|---|---|---|---|
| 1 | `Content-Security-Policy` header on the document response (`kCspStatic` when scripts are off: `default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`) | none | hardening — **the only delta that can block content**, see R4 |
| 2 | `add_DownloadStarting` → cancel + handled (`ICoreWebView2_4`, QI) | engine default | hardening |
| 3 | `add_PermissionRequested` → deny | engine default | hardening (unreachable with scripts off) |
| 4 | `put_AreDefaultScriptDialogsEnabled(FALSE)` | not set | hardening (unreachable with scripts off) |
| 5 | `AddWebResourceRequestedFilterWithRequestSourceKinds(ALL)` on runtime 111+, fallback to the document-only filter | document-only filter | wider interception (matters only for workers — none in mdview) |
| 6 | `std::shared_ptr<bool> alive` liveness token: creation completions after `Destroy()` are no-ops; a controller delivered late is `Close()`d | none — a viewer closed during a cold start could free the impl under a queued completion (070 stabilization review F02 notes mdview deletes the host only after its message loop drains, so it was *latent*, not reproduced) | robustness |
| 7 | `pendingCx/pendingCy`: a `Resize()` before the controller exists is honoured at ready; else `GetClientRect` | always `GetClientRect` | equivalent for mdview (surface = whole client area) |
| 8 | Debug `AssertLockdown` reads every setting back, `TRACE_E` on mismatch | none | diagnostics |
| 9 | `TRACE_I(impl->cfg.TraceName << …)` | `TRACE_I("mdview: …")` | cosmetic; `TraceName = "mdview"` restores the prefix |
| 10 | `Navigate(int version, fragment)` — the version is the caller's | `SetDocument()` bumps an internal `docVersion`; `Navigate(fragment)` | API shape; the counter moves to the window (R2) |
| 11 | `Serve` callback: relative path in, `TcWebResponse` out; host prefixes `Content-Type: `, appends CSP for the document, 403 for `false` | `ServeRequest` inline: doc → 200, `img/<n>` → 200/404, else 403 | mdview's server becomes the callback (R3) |
| 12 | keeper: per-instance state, hidden-window class from config, `TC_KEEPER_DIED` → `Disarm()` (releases **and unregisters the class**; the next `Arm()` re-registers) | keeper: globals, `MdKeeperReleaseAll()` on death (class kept) | equivalent outcome — re-arm works either way; the shared keeper has run in codeview since 070 |
| 13 | web-message channel (off unless configured) | none | off for mdview — no change |

Conclusion: the shared component is a strict superset. What mdview must keep
is exactly the list the 070 contract §1 predicted: remote-image fetch, the
`img/<n>` table, the `.md` link gate, HTML generation, the `doc.html?v=`
scheme — plus the accelerator map and the pre-065 folder janitor.

## R2 — Decision: shape of the mdview glue

**Decision**: replace `webview.{h,cpp}` with `webglue.{h,cpp}` (the codeview
name for the same role). It is **COM-free** — no `<wrl.h>`, no `WebView2.h`
anywhere in the plugin — and contains:

- `void MdConfigureHost(TcWebHostConfig& cfg, const MdHtmlResult* doc)` —
  fills the per-plugin configuration (R3) and the accelerator map;
- `std::wstring MdUserDataFolder()` is **gone**: callers use
  `TcWebUserDataFolder()`;
- `void MdCleanupOldUserDataFolder()` — unchanged (mdview history, `CThread`
  janitor);
- `void MdKeeperArm()` / `void MdKeeperDisarm()` — thin wrappers over one
  `static CTcWebKeeper` configured with `L"TandemMdKeeperWnd"`, `DLLInstance`,
  `"mdview keeper"`. The wrappers keep the two call sites (`ViewFile`,
  `Release`, the configuration dialog) textually unchanged and keep the keeper
  configuration in one place. `MdKeeperArmed()` is declared and defined today
  but **called nowhere** (grep over `src/`); it is not carried over.

`viewer.h` holds `CTcWebHost* Web` and a new `int DocVersion` (codeview
precedent: `CViewerWindow::DocVersion`). The three `SetDocument` sites become
`DocVersion++`, and every `Navigate(frag)` becomes `Navigate(DocVersion, frag)`;
`SetDocument`'s `docDir` argument was stored and never read — dropped.

**Rationale**: mirrors codeview exactly, so a reader of one plugin knows the
other; the viewer window owns the document, so it should own the document's
version; wrappers over the keeper avoid spreading the class name and the
`DLLInstance` into three files.

**Alternatives considered**: (a) keep `CMdWebHost` as an adapter class over
`CTcWebHost` — a third layer with no consumer but mdview, and it would keep
the misleading claim that the host lives in mdview; (b) a global
`CTcWebKeeper MdKeeper` used directly like codeview's `CvKeeper` — fine, but
the wrappers cost three lines and remove two `extern`s; (c) keep the file name
`webview.cpp` — its header comment says "all WebView2/COM usage is confined to
webview.cpp", which stops being true; a new name states the new truth.

## R3 — Decision: the `Serve` callback and the missing-image status

The shared host hands the callback the path **without** the leading slash and
with query/fragment stripped (`doc.html`, `img/3`), and expects
`TcWebResponse.ContentType` to be the bare media type (the host prefixes
`Content-Type: `). mdview's `SniffContentType` returns strings with the prefix
— it is trimmed to bare media types.

| Path | Answer |
|---|---|
| `doc.html` | 200, `text/html; charset=utf-8`, the document bytes; the host adds `kCspStatic` |
| `img/<n>`, `n` in range, bytes readable (local `ReadFileBytes`, or remote `FetchRemote` — the table holds a remote entry only after per-document consent) | 200, sniffed media type |
| `img/<n>`, out of range or unreadable | **404 `Not Found`**, `application/octet-stream`, empty body — through `TcWebResponse.Status/Reason` (return `true`), preserving mdview's status; returning `false` would turn it into the host's 403 |
| anything else | `false` → the host's 403 (default-deny invariant) |

The document pointer captured by the callback is `&CViewerWindow::Html`, a
member whose address is fixed for the window's life (codeview needed a double
indirection because it re-points; mdview does not). No request can arrive
before the first `Navigate`, which follows the first `RebuildHtml`, so the
"doc not yet set" branch of the old code has no equivalent to preserve.

## R4 — CSP compatibility of the generated document (verified in the generator)

`kCspStatic` permits: inline styles (`style-src 'unsafe-inline'`), images from
the own origin and `data:` URIs (`img-src 'self' data:`); forbids everything
else (`default-src 'none'`), `<base>`, form submission, framing.

Grep over `src/plugins/mdview/htmlgen.cpp` for `font-face`, `url(`, `<base`,
`<link`, `<script`, `<iframe`, `@import`, `Content-Security`: the generator
emits a `<meta charset>` and `<meta name="color-scheme">`, inline `<style>`
per theme, images as `https://mdview.invalid/img/<n>` (`EmitImage`) or the
original `data:` URI passed through (`StartsWithCI(wsrc, L"data:")`), search
marks and `hl-*` spans. **No web fonts, no external stylesheets, no scripts,
no `<base>`.** Raw HTML from the Markdown source passes through verbatim
(feature 021 FR-020); whatever it references was already refused by the
default-deny interceptor — under the CSP it is refused one layer earlier with
the same visible result. Two edge deltas, both stricter:

- an embedded `<form>` submission used to reach `NavigationStarting`, be
  cancelled and produce the *link blocked* message; `form-action 'none'` now
  refuses it before navigation, silently. Recorded in the spec as accepted.
- `<a download>` used to reach the engine's default download path (a request
  to the own origin → 403 → a failed-download bubble, or a `data:` download
  succeeding); `DownloadStarting` now cancels it. Row D3 of the checklist.

## R5 — Decision: the browser-arguments set in exactly one place

Today the literal `--disable-background-networking --disable-sync
--disable-component-update --disable-features=msWebOOUI,msPdfOOUI` exists
three times: `mdview/webview.cpp` (`MdBuildEnvOptions`), `webhost.cpp`
(`TcWebBuildEnvOptions`) and `webkeeper.cpp` (`TcWebKeeperEnvOptions`, whose
comment even says "webhost.cpp owns that set; it is rebuilt here … by including
the one definition below" — it is not included, it is retyped).

**Decision**: add `const wchar_t* TcWebBrowserArguments();` to the COM-free
`webhost.h`, define the literal once in `webhost.cpp`, and have both
`TcWebBuildEnvOptions()` and the keeper's options builder call it. The
`CoreWebView2EnvironmentOptions` object itself cannot cross the COM-free header
(WRL), so the *string* is what is shared; the two `Make<>()` calls are
boilerplate, not policy.

**Rationale**: contract §2.2 says one set; `architecture/11` §2.2 must be able
to name one file and one function. A guard (`rg -c "disable-features=msWebOOUI"
src/` must be 1) makes drift visible.

**Alternatives**: an internal `webhost_impl.h` shared by the two `.cpp` files
(would carry WRL; more surface for a one-string need); leave the keeper's copy
(would leave the contract untrue after this feature).

## R6 — Keeper parity, including the unload/reload path

Feature 069 F-P6-01: the keeper class must be released on unload or the next
`RegisterClassW` fails with `ERROR_CLASS_ALREADY_EXISTS` and *instant view*
silently dies for the session. `CTcWebKeeper::Disarm()` unregisters
(`UnregisterClassIfRegistered`) and is called from `CPluginInterface::Release`
via `MdKeeperDisarm()`; codeview has exercised this path. The class name stays
`TandemMdKeeperWnd` (070 contract §1 "kept for continuity"); codeview's is
`TandemCvKeeperWnd`, so both keepers may be armed at once.

Difference #12 of R1 (browser death → `Disarm()` unregisters the class, next
`Arm()` re-registers) is behaviourally equivalent to mdview's "keep the class,
recreate the window": both end with the next view arming again. Checklist row
C4 proves it on the migrated plugin.

## R7 — Decision: the reference build for side-by-side comparison

**Which tree is live**: `OPENSAL_BUILD_DIR` is **unset** on this machine in
every scope, so `build.cmd` uses its documented default `.\build\`
(build.cmd:67–69) — even though CLAUDE.md's quick start shows
`set OPENSAL_BUILD_DIR=D:\Build\OpenSal\`. Measured 2026-09-20:

| Tree | `tandemcommander.exe` | `plugins\mdview\mdview.spl` |
|---|---|---|
| `E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\` | 09-20 09:46 | 09-20 09:00 |
| `D:\Build\OpenSal\tandemcommander\Debug_x64\` | 09-19 10:18 | 09-19 09:53 |

The repo-local tree is the current one (233 MB / 432 files without
`Intermediate\`; `codeview.spl` present, same timestamp) and is where this
feature builds; the `D:` tree is stale and is left alone.

**Decision**: before the first build of this branch, copy the live Debug tree
(excluding `Intermediate\`) to
`E:\Projects\tandemcommander\build\tandemcommander\Debug_x64_prefix081\`
(`build\` is gitignored; E: has 162 GB free). It is an independently runnable
reference (`tandemcommander.exe -t REF081 …`) — the 069 precedent
(`Release_x64_prefix069`). It shares the registry with the migrated build,
which is what a side-by-side comparison wants (same schemes, zoom, placement).

**Alternative rejected**: keep only `mdview.spl` and swap files — the plugin
is locked while loaded, so a comparison would need restarts and file swaps
between every row.

## R8 — The security fixture corpus does not exist

`specs/021-mdview-html-renderer/quickstart.md` describes fixtures under
`specs/021-mdview-html-renderer/fixtures/security/`; **no `fixtures/` directory
exists under 021** (glob, 2026-09-20). The spec's User Story 2 relied on it.

**Decision**: author the corpus under
`specs/081-mdview-shared-webhost/fixtures/security/` (spec corrected to point
there) — one hostile construct per file so a failing row names its cause:

| File | Construct | Expected on screen |
|---|---|---|
| `01-script-tag.md` | `<script>document.title='PWNED'</script>` + `<script src=https://…>` | literal text not run; title unchanged |
| `02-event-handlers.md` | `<img src=x onerror=…>`, `<div onclick=…>`, `<body onload=…>` | nothing fires |
| `03-javascript-link.md` | `[x](javascript:alert(1))` and raw `<a href="javascript:…">` | click → *link blocked* |
| `04-remote-image.md` | `![](https://example.invalid/a.png)` + raw `<img src="https://…">` | placeholder / empty; **zero network** without consent |
| `05-iframe.md` | `<iframe src="https://…">`, `<object>`, `<embed>` | nothing loads; zero network |
| `06-meta-refresh.md` | `<meta http-equiv="refresh" content="0;url=https://…">` | view stays on the document |
| `07-form.md` | `<form action="https://…" method="post"><button>` | submit refused; no navigation (silently — R4) |
| `08-path-traversal-image.md` | `![](../../secret.png)`, `![](C:\Windows\win.ini)`, `![](\\server\share\x.png)` | refused (placeholder), as 021 |
| `09-download-link.md` | `<a href="data:application/octet-stream;base64,AAAA" download="x.bin">` and `<a href="x.bin" download>` | **no download, no bubble** (D3) |
| `10-legit-control.md` | inline `<style>`, `style=` attributes, a local image `assets/dot.png`, a `data:` PNG, `<kbd>`, `<sub>`, `<details>`, a table with alignment, a fenced `c` block, a `#anchor` link, a `[b](10b-linked.md)` link | **everything renders**; anchor scrolls; `.md` link opens a window |
| `10b-linked.md` | target of the `.md` link | opens in a new viewer |
| `assets/dot.png` | 1×1 PNG | inline image in `10-legit-control.md` |
| `README.md` | what each file proves and how to run the pass | — |

The generator-level half of the check is automatable: `dump_main.cpp` renders
each fixture to HTML and `probe/check_csp_compat.py` lists every resource
reference in the output and classifies it as *allowed by `kCspStatic`* (own
origin `img/<n>`, `data:`) or *blocked*; the legit control must have zero
blocked references and the hostile files' blocked references must be exactly
the hostile ones. The runtime half (network monitor) stays with the person.

## R9 — The generator test harness has no committed project file

`tests/mdview_htmlgen_test/` holds `test_main.cpp`, `dump_main.cpp`,
`sample.md`; its `.vcxproj` "has never been committed" (mdview
`IMPLEMENTATION_NOTES.md`, v2.2 verification status). The sources include the
plugin's `precomp.h`, so they need the plugin include paths and the
`IDS_THEME_FIRST` ids.

**Decision**: add `tests/mdview_htmlgen_test/build_and_run.cmd` — a direct
`cl.exe` recipe from a VS developer prompt (located via `vswhere`, the
`build.cmd` pattern), compiling `test_main.cpp` + `htmlgen.cpp` + `render.cpp`
+ `highlight.cpp` + `md4c.c` with `/I src/plugins/mdview /I src/plugins/shared
/I src/common/dep/md4c /I src/common/dep/webview2/include`, into the scratch
`obj\` folder (gitignored), then running it and failing on any `[FAIL]`. If the
link needs a symbol the plugin defines elsewhere (`LoadStr`,
`SalamanderGeneral`), a `test_stubs.cpp` provides it — to be discovered at the
first build, not guessed here. The harness itself is untouched (FR-014:
"assertion count unchanged" is measured against its first green run).

## R10 — What can be automated, what is owed to a person

Precedent: feature 080's `probe/tc_drive.ps1` drives one `tandemcommander.exe`
instance purely by posted messages (`-l` sets the left panel path; `key` posts
`WM_KEYDOWN/UP` to the panel list; `dialogs` lists visible top-level windows
with class and title; `closewnd` closes by title; `command` posts `WM_COMMAND`).
mdview's viewer is a top-level window titled `<path> - Markdown Viewer
[Source] (NNN%)` and answers `WM_COMMAND` ids 101–211 (`mdview.h`).

**Automatable (probe `probe/mdview_probe.ps1`, Windows PowerShell 5.1)**:

- open a fixture (Down, F3), assert a `*Markdown Viewer*` window appears and a
  `msedgewebview2.exe` tree belongs to the process;
- post `CM_VIEW_ZOOMIN`/`CM_VIEW_ZOOMRESET`/`CM_FILE_OPENTEXT`/`CM_SCHEME_NEXT`
  to the viewer and assert the title changes `(110%)` → `(100%)`, `[Source]`
  appears and disappears, no crash;
- close the viewer; wait 60 s; assert the engine tree is still alive
  (keeper); reopen; assert the open-to-title time is ≤ 2× the back-to-back
  time (065 SC-002);
- `taskkill /f /im msedgewebview2.exe` with no viewer open; reopen; assert it
  works; close; reopen; assert warm again (065 scenario 4);
- open every hostile fixture in turn; assert exactly one new top-level window
  (the viewer) and no dialog appears, and the process count of
  `msedgewebview2.exe` does not grow beyond the shared tree;
- close-during-cold-start: F3 and `closewnd` within 100 ms, ten times;
  assert the process is alive and the Debug-CRT dump (DBWIN listener recipe
  from 078) shows no leak from `mdview.spl`;
- **pixel diff** (`probe/render_diff.ps1`): the same fixture rendered by the
  reference tree and the migrated tree at the same placement, screenshot of
  the viewer client area via `System.Drawing` `CopyFromScreen`, per-pixel
  difference ≤ 0.1 % of pixels (anti-aliasing tolerance). Both trees share
  the WebView2 runtime and the registry (zoom, scheme, placement), so a
  differing image would be a real difference in the served document or the
  surface settings.

**Owed to a person** (`quickstart.md` § C): the network monitor over the
hostile corpus, the *Keep the rendering engine ready* toggle through the
Plugins Manager configuration dialog (a modal dialog reached through another
modal dialog — drivable but brittle), plugin unload/reload through the Plugins
Manager, the dark-menu rendering, follow-system theme, and the eye over rows
A1–A10 against the reference tree.

## R11 — Documentation set to update (FR-010) and what is historical

Living documents — **update**: `architecture/11-webview2-integration.md`
(status paragraph → complete; §2.2 helper location → `webhost.cpp`
`TcWebBrowserArguments()`; §2.4 "until a shared component exists" → exists;
§2.5 → done, with the rule for a *third* consumer; §3 build checklist → both
`.props`; §4 references → `src/common/webhost/`), `specs/070-source-viewer-plugin/contracts/webview-host-sharing.md`
(§4 verification: record what was verified and by which artefact),
`specs/070-source-viewer-plugin/REMAINING-WORK.md` §2 (done marker + pointer),
`specs/NEXT-WORK.md` item 4 (done; the GUI pass joins item 3),
`src/plugins/mdview/IMPLEMENTATION_NOTES.md` (new "v2.3 — Feature 081"
section), `CLAUDE.md` (Recent Changes entry; the WebView2 bullet's "shared
options helper in `src/plugins/mdview/webview.cpp`" → `webhost.cpp`),
`CHANGELOG.md` (0.1.8 *Changed*).

Historical records — **leave**: `specs/065-*/contracts/keeper.md` (declares
`MdKeeperArmed` and `webview.cpp`), `specs/021-*/contracts/webhost.md`
(`CMdWebHost`), `specs/070-*/stabilization-review.md` line 118 ("mdview still
uses its own copy") — they describe the state at their time; SC-007 counts
living documents only.

## R12 — Changelog wording (FR-013)

Under `## [0.1.8] — unreleased` → `### Changed`:

> **Markdown Viewer: same hardened rendering surface as the Code Viewer.**
> The Markdown Viewer now renders through the shared engine host the Code
> Viewer introduced, so both viewers apply one and the same security lockdown.
> For ordinary documents nothing changes. For a hostile document the viewer
> now additionally refuses file downloads it starts (`<a download>`), and the
> served document carries a content security policy, so an element the
> viewer already refused to fetch is refused one layer earlier. Scripts stay
> off, the network stays closed, and the *instant second view* behaves as
> before.

Truthful about scope: no visible change for ordinary documents; names the
two hardenings a user can observe; does not claim fixes it does not make.

## R13 — Build integration facts

- `plugin_base.props`: `PrecompiledHeader=Use`, `PrecompiledHeaderFile=precomp.h`
  for every `ClCompile` item — `webhost.cpp`/`webkeeper.cpp` begin with
  `#include "precomp.h"` and compile against the *consuming* plugin's PCH
  (codeview today; mdview's `precomp.h` provides the same `dbg.h`, `<string>`,
  `<vector>`, `<functional>`, and the debug `new` macro the two files suspend).
- `mdview.props`: add `..\..\..\common\webhost` to `AdditionalIncludeDirectories`
  (codeview.props precedent); link libraries already include `shlwapi.lib`,
  `ole32.lib`, `winhttp.lib`, `version.lib`, `WebView2LoaderStatic.lib` —
  unchanged.
- `mdview.vcxproj`: `ClCompile` items `..\..\..\common\webhost\webhost.cpp`,
  `webkeeper.cpp`; `ClInclude` `webhost.h`, `webkeeper.h`; `..\webview.cpp/.h`
  → `..\webglue.cpp/.h`.
- `plugins.cfg`: `mdview=on`, `codeview=on` — both build by default, so a
  shared-host change is compiled twice on every `build.cmd`.
- `.clang-format` at the repository root; format only the files this feature
  touches (constitution III).

## R14 — Risks and their checks

| Risk | Check |
|---|---|
| CSP blocks something the generator emits that R4 missed | `check_csp_compat.py` over every fixture and `tests/mdview_htmlgen_test/sample.md`; pixel diff of the legit control |
| 404 → 403 change for a broken image alters the placeholder | R3 keeps 404 through `Status`; row A7 |
| `Resize` before ready differs (`pendingCx`) | mdview sizes on `WM_SIZE` after `WM_CREATE`; either path yields the client rect; row A10 |
| keeper class unregistered on browser death breaks re-arm | row C4 (kill → view → view) on the migrated plugin |
| PCH mismatch compiling `webhost.cpp` under mdview's `precomp.h` | the Debug build itself; `<richedit.h>` in mdview's PCH is irrelevant to the host |
| the reference tree ages / is deleted | created before the first build; `quickstart.md` names it and says do not delete before the pass |
