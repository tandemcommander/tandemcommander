# Fix Log — Feature 081: mdview onto the Shared WebView2 Host

Running record kept during implementation (project convention). Baseline
commit `6b4d7af` on `main`, branch `081-mdview-shared-webhost`, started
2026-09-20.

---

## Phase 1 — Evidence baseline

### T001 — Which build tree is live

`OPENSAL_BUILD_DIR` is **unset in every scope** on this machine (process, user,
machine), so `build.cmd` uses its documented default `.\build\`
(`build.cmd:67-69`). CLAUDE.md's quick start shows
`set OPENSAL_BUILD_DIR=D:\Build\OpenSal\`, and that tree exists — but it is
**stale**, and this feature does not use it.

| Tree | `tandemcommander.exe` | `plugins\mdview\mdview.spl` | `plugins\codeview\codeview.spl` |
|---|---|---|---|
| `E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\` (live) | 2026-09-20 09:46:55 | 2026-09-20 09:00:39 | 2026-09-20 09:00:39 |
| `D:\Build\OpenSal\tandemcommander\Debug_x64\` (stale) | 2026-09-19 10:18:06 | 2026-09-19 09:53:20 | — |
| `D:\Build\OpenSal\tandemcommander\Release_x64\` (stale) | — | 2026-09-19 10:18:24 | — |

Live Debug tree size excluding `Intermediate\`: **233 MB, 432 files**.
Free space on `E:`: 162 GB. `build\` is gitignored (`.gitignore:2`).

**Decision recorded in `research.md` R7 and `quickstart.md` § 0**: everything
in this feature builds into and compares against the repo-local tree. Do not
set `OPENSAL_BUILD_DIR` for this work.

### T002 — Reference tree preserved

`build\tandemcommander\Debug_x64_prefix081\` — **432 files, 233 MB**, no
`Intermediate\` directory, byte counts identical to the source;
`tandemcommander.exe` 2026-09-20 09:46:55, `plugins\mdview\mdview.spl` and
`plugins\codeview\codeview.spl` 09:00:39. Started standalone
(`-t REF081 -l <specs folder>`), main window
`REF081 - Release_x64 - Tandem Commander 0.1.8 (x64) ST`, closed with
`WM_CLOSE`, process gone. **Do not delete before the on-screen pass.**

**Trap hit (recorded env quirk, cost one attempt)**: `robocopy … /E /XD …` run
through the Bash tool fails with `ERROR : Invalid Parameter #3 : "E:/"` —
Git Bash rewrites `/E` into a path. Run robocopy from PowerShell. (Same trap
as feature 080's installer switches; `exit 1` from robocopy means *files
copied*, not failure.)

### T002b — Baseline observation: the Debug build already leaks at exit

Closing the **reference** build (pure start → close, no Markdown viewed) pops
a `#32770` dialog titled **`Heap Message`** whose static text is
**`Detected memory leaks!`**; the process only exits after it is dismissed
(`BM_CLICK` on `IDOK`). This is the state of `main`, not something this
feature introduces — the intermittent Debug-CRT leak at exit recorded in
`specs/078-panel-tabs/fix-log.md` and reconfirmed in 079.

Consequences for this feature, decided now rather than at T033:

1. every probe that closes the application MUST dismiss a `Heap Message`
   dialog and MUST NOT count its mere presence as a failure;
2. the T033 close-during-cold-start leak check compares the **detail** of the
   leak (the DBWIN text, which names the allocating file) against the same
   scenario run on the reference tree — a leak naming `webglue.cpp`,
   `webhost.cpp` or `webkeeper.cpp` is a finding; the pre-existing one is not;
3. `quickstart.md` § C must tell the person the dialog is expected on Debug
   builds so it is not reported as a regression.

### T003 — 069-protocol check: HEAD matches research R1

| Check | Expected (research) | Measured at `6b4d7af` | |
|---|---|---|---|
| `git log -1 -- src/plugins/mdview/webview.cpp` | `b9498d9` (feature 069, 2026-08-24) | `b9498d9` | ✅ |
| `git log -1 -- src/common/webhost/` | `ec7b796` (feature 070, 2026-08-27) | `ec7b796` | ✅ |
| `rg -c "disable-features=msWebOOUI" src/` | 3 files | `webkeeper.cpp:1`, `webhost.cpp:1`, `mdview/webview.cpp:1` | ✅ |
| `rg -n MdKeeperArmed src/` | declared + defined, called nowhere | `webview.h:81`, `webview.cpp:898` only | ✅ |

The premise of the whole feature — mdview's copy untouched since the lift, the
arguments literal written three times, `MdKeeperArmed` dead — holds at HEAD.

### T004/T005 — Security fixture corpus

Authored under `fixtures/security/` (research R8): nine hostile files, one
legitimate control, a link target, a text-link target, a `.cpp` for the
cross-plugin warmth row, the two image assets and their stdlib generator, plus
a `README.md` mapping every file to its checklist row. 16 committed files,
~21 KB of text.

Each file carries a `MARKER-nn` line so "it passed" is readable on screen
without knowing the internals, and each hostile construct is written in
several forms (a `<script>` that is inline, external, module and deferred; a
remote image as `<img>`, `srcset`, `<picture>`, protocol-relative, `url()` in
a style and `@font-face`) — a single form would let a partial refusal look
like a full one.

Design notes worth keeping:

- **`document.title` is not a usable script detector here.** The viewer sets
  its own window title from the file path, so a script changing the page title
  would be invisible. Every hostile file therefore uses *body replacement*
  (`document.body.innerHTML = '<h1>PWNED</h1>'`), which is unmissable.
- **`example.invalid` cannot resolve** (RFC 2606), so a request that *is*
  attempted fails quietly and the absence of a picture proves nothing. The
  network monitor is the proof; `README.md` says so and the B rows carry a
  monitor column.
- The image assets are generated by `gen_assets.py` from `zlib` + `struct`
  (no Pillow — unlike `tools/brand/gen_icons.py`), and the `data:` URI is
  substituted into the control document once, at authoring time.

Copied to `%TEMP%\md081\` for the probes (17 entries incl. `assets\`).
`probe/out/` added to a feature-local `.gitignore`.

---

## Phase 2 — the migration

### T007–T014 — what moved, what stayed

`webview.{h,cpp}` (984 lines) deleted; `webglue.{h,cpp}` (≈330 lines) written.
The glue keeps exactly what research R2/R3 said it would: `MakeExtPath`,
`ReadFileBytes`, `FetchRemote`, `SniffContentType`, the UDF janitor thread,
`MdConfigureHost` (origin, scripts/messages off, the `Serve` and `Accelerator`
callbacks) and the two keeper wrappers. `MdKeeperArmed()` was not carried over
(dead at HEAD, T003). `viewer.{h,cpp}`, `mdview.cpp`, `mdview.props` and
`mdview.vcxproj` follow the plan unchanged.

**A defect caught while writing, not by a test.** The first version of the
image branch read the bytes into a `std::vector` local to the `Serve` lambda
and handed `out.Data = bytes.data()` to the host. That dangles: the shared host
copies the buffer in `MakeAndSetResponse` → `SHCreateMemStream`, which runs
*after* the callback returns. codeview never met this because its answers are a
module resource and a window member, both of which outlive everything, so the
contract's first wording ("the host copies them before returning") was simply
wrong and was corrected with the code. The fix is one scratch buffer per host,
owned by the lambda through a captured `shared_ptr`, cleared and shrunk on the
refusal path; `WebResourceRequested` is raised on the controller's own thread,
so two requests never overlap. Recorded in
`contracts/mdview-host-config.md` § *Buffer lifetime — the trap in this
callback*.

Three comments elsewhere in the plugin (`htmlgen.h`, `render.cpp`, `render.h`)
pointed the reader at `webview.cpp`/`webview.h`; they now name
`src/common/webhost/` and `webglue.h`. Nothing else in those files was touched.

### T015 — Debug build

`build.cmd` (repo-local tree): **BUILD SUCCEEDED, 0 errors, 9 warnings**, all
pre-existing (`md4c.c` C4267 ×3, `salamdr2.cpp` C4018, `zip.cpp` C4244,
`LNK4198 base key 'mdview' not found` ×2 — mdview has never had an entry in
`baseaddr_x64.txt`). `mdview.spl` 1,875,968 B, and the link line shows
`webhost.obj` and `webkeeper.obj` among its inputs — the shared host is now
compiled into this plugin. The compile line carries
`/I..\..\..\common\webhost`. No change was needed anywhere in
`src/common/webhost/` to make mdview build on it.

**Trap hit (recorded env quirk)**: a background `cmd /c "build.cmd"` does not
find the script — it needs the absolute path.

### T016 — formatting and encoding

`clang-format` is not on `PATH`; it ships with VS at
`…\VC\Tools\Llvm\bin\clang-format.exe` (17.0.3). Of the five touched files only
`viewer.h` was reformatted (comment alignment after the new member).

**Encoding, corrected observation**: CLAUDE.md says the tree is UTF-8-BOM, and
the legacy core is (`src/mainwnd1.cpp` starts `EF BB BF`), but **every mdview
and codeview source has no BOM** — including the deleted `webview.cpp` and the
shared `webhost.cpp` at HEAD. The new files match their neighbours; nothing to
fix. (`tools/check_encoding.py`, which runs inside `build.cmd`, has no BOM
rule and passed.)

### T017 — driver smoke on the migrated build

Driven through `specs/080-restart-manager-upgrade/probe/tc_drive.ps1` against
the Debug tree, fixtures in `%TEMP%\md081`:

| Step | Result |
|---|---|
| F3 (`CM_VIEW`, 742) on a fixture | viewer window `…\02-event-handlers.md - Markdown Viewer (100%)`, class `MDView - WinLib Universal Window2` |
| engine process | exactly **1** `msedgewebview2.exe` child of our pid |
| `CM_VIEW_ZOOMIN` ×2 | title `(110%)` → `(120%)` |
| `CM_VIEW_ZOOMRESET` | title `(100%)` |
| `CM_FILE_OPENTEXT` ×2 | `[Source]` appears, then disappears |
| `CM_SCHEME_NEXT` / `_PREV` | window alive, no dialog (this is the regenerate → `DocVersion++` → `Navigate` path) |
| stray windows | none |

Two things learned for the probe script (T021): the panel that F3 acts on is
the **active** one, so both `-l` and `-r` must point at the fixtures (the first
attempt posted keys to the left list while the right panel was active and
nothing opened); and `WM_COMMAND CM_VIEW` is far more reliable than posting a
`VK_F3` key.

---

## Phase 3 — evidence for User Story 1

### T019/T020 — the generator harness can be run again

`tests/mdview_htmlgen_test/build_and_run.cmd` written: locate VS with
`vswhere`, `vcvarsall x64`, compile `md4c.c` as C and the three generator
sources plus `test_main.cpp` as C++, run, report. **29 assertions passed, 0
failed** — the FR-014 baseline, and the same count feature 022 recorded, so the
generator is untouched by this feature (as it must be: nothing in
`htmlgen/render/highlight` was edited).

No stub objects were needed: those three translation units reference no plugin
global (no `LoadStr`, no `SalamanderGeneral`, no `TRACE_*`, no `HANDLES`), so
the planned `test_stubs.cpp` does not exist. The script also has a `dump` mode
that builds `dump_main.cpp` for the CSP check.

Two cmd traps cost a run each and are worth remembering:

- `for /f "usebackq" %%i in (`"%VSWHERE%" … ^` …`)` mangles a quoted path with
  spaces; `build.cmd`'s pattern (redirect to a temp file, `set /p`) is used
  instead — and it is the reason build.cmd does it that way.
- `/Fo"<dir>\prefix"` with several source files is `D8036`; `/Fo` must name a
  directory (trailing backslash).
- A harmless `'vswhere.exe' is not recognized` line came from inside
  `vcvarsall.bat`; its output is now silenced with `2>&1`.

### T026/T027 — the content policy costs no legitimate element

`probe/check_csp_compat.py` renders every fixture with the committed dumper and
classifies each resource reference against the scripts-off CSP the shared host
serves.

**The corpus is not uniform, and the first version of the check pretended it
was.** Three hostile fixtures legitimately produce *zero* blocked references,
because the layer that refuses them leaves nothing in the HTML: `javascript:`
links and `<a download>` are anchors the **navigation gate / download handler**
refuse at runtime, and the traversal images are refused by the **generator**,
which emits a placeholder instead of a URL. The check now carries a per-fixture
`LAYER` table and asserts the *right* layer, which makes it a record of who
refuses what rather than a crude count.

Result (`RESULT: PASS`, exit 0):

| fixture | layer | inline styles | allowed | blocked | verdict |
|---|---|---|---|---|---|
| `01-script-tag.md` | csp | 0 | 0 | 2 | refused by CSP |
| `02-event-handlers.md` | csp | 1 | 0 | 1 | refused by CSP |
| `03-javascript-link.md` | navigation | 0 | 0 | 0 | runtime gate |
| `04-remote-image.md` | csp | 2 | 0 | 9 | refused by CSP |
| `05-iframe.md` | csp | 2 | 0 | 8 | refused by CSP |
| `06-meta-refresh.md` | csp | 0 | 1 | 1 | refused by CSP (`base-uri 'none'`) |
| `07-form.md` | csp | 0 | 0 | 3 | refused by CSP (`form-action 'none'`) |
| `08-path-traversal-image.md` | generator | 0 | 1 | 0 | refused by generator |
| `09-download-link.md` | navigation | 0 | 0 | 0 | runtime gate |
| **`10-legit-control.md`** | control | **13** | **3** | **0** | **CLEAN** |
| `10b-linked.md` | target | 0 | 0 | 0 | n/a |
| **`sample.md`** (the harness's own document) | control | **15** | **1** | **0** | **CLEAN** |

The two control rows are the evidence for FR-006/SC-003: 28 inline styles, two
own-origin images and one `data:` image survive the policy, and nothing a
Markdown document may legitimately contain is refused. `06`'s row is the
prettiest one — the hostile `<base>` is blocked while the local image below it
still resolves to `https://mdview.invalid/img/0`, because the generator had
already resolved it.

### T021/T023 — the runtime probe, and 0 differing pixels

`probe/mdview_probe.ps1` (posted messages only, one instance, derived from
080's `tc_drive.ps1`) — **24 checks, 0 failed** on the Debug tree, plus a
Release smoke of 5/5:

| Scenario | Checks | Result |
|---|---|---|
| `smoke` | 5 | viewer opens in 106 ms; 7 engine processes are ours; zoom 110 % → 120 % → reset; `[Source]` on and off; scheme cycling leaves the window alive with no dialog |
| `hostile` | 9 | each of the nine hostile fixtures: exactly one viewer, **0 dialogs**, engine count flat at 7, the title still names the file (nothing navigated away) |
| `keeper-warm` | 3 | cold 106 ms; after **65 s with no viewer** 6 engine processes are still ours (keeper armed); warm open **95 ms** vs back-to-back **95 ms** (065 SC-002 wants ≤ 2×) |
| `keeper-crash` | 3 | 6 processes killed; the next view works (95 ms); the one after it is warm again (92 ms) |
| `cold-close` | 2 | 10 open-and-close-within-100 ms cycles, the process survives all of them, and a normal open still works (96 ms) — the case mdview's own host did **not** guard |
| `cross-warm` | 2 | the Code Viewer opens `hello.cpp` first (`… [C++] - Prohlížeč kódu` — this machine runs the Czech UI), and the first Markdown view is then **94 ms** vs 95 ms back-to-back: either plugin's keeper warms the other |

**A bug in the probe, not in the product**, worth remembering: the first run
reported `smoke/source` as FAIL although the toggle demonstrably worked. In a
PowerShell `-like` pattern `[Source]` is a *character class*, so
`'…Markdown Viewer (100%)' -like '*[Source]*'` is true for almost any string
and the negative half of the check could never hold. The script uses
`.Contains('[Source]')`.

`probe/render_diff.ps1` captures the client area of the viewer showing
`10-legit-control.md` from the **reference** tree and from the **migrated**
tree at the same fixed rectangle, and compares them:

```
client area   : 984x741 = 729144 pixels
differing     : 0 (0 %) with a per-channel tolerance of 8
RESULT: PASS
```

**Zero differing pixels.** The captured image (`probe/out/render-migrated.png`)
shows the inline-`<style>` box with its green border and rounded corners, the
`style=` paragraph, the magenta stylesheet class and the local image — i.e. the
document renders completely under the new content policy, and identically to
the build that had no policy at all.

Two notes on the probe scripts themselves: the pixel comparison runs in a small
C# `LockBits` helper because 729 k `GetPixel` calls through the PowerShell
interop take minutes; and `$PSScriptRoot` is **not** populated while a
parameter default is evaluated under `-File`, which silently dropped the first
captures into the current drive's root (`E:\out`). Both are fixed in the
committed scripts.

### T024 — Release

`build.cmd full release`: **0 errors**, 20 plugins registered, 189 language
modules, `tools/check_runtime_deps.py` reports *runtime closure OK, 219
modules scanned, 59 runtime imports*, 4 CRT files shipped. Release smoke 5/5.

### T035/T036 — one browser-arguments set, and the guards

`TcWebBrowserArguments()` added to the COM-free `webhost.h`, defined once in
`webhost.cpp`; `TcWebBuildEnvOptions()` and the keeper's options builder both
call it. Only the WRL options *object* is still built in two places — it
cannot cross a COM-free header — which is precisely the distinction
`webkeeper.cpp`'s old comment got wrong when it claimed to "include the one
definition below".

Both plugins relinked with the change (`codeview.spl` and `mdview.spl` both
list `webhost.obj`/`webkeeper.obj`), so a shared-host edit is compiled twice on
every build and cannot rot in one consumer.

Guards:

| Guard | Result |
|---|---|
| `rg -c "disable-features=msWebOOUI" src/` | `src/common/webhost/webhost.cpp:1` — one file |
| `rg '^\s*#\s*include\s*[<"](wrl\.h\|WebView2\.h\|WebView2EnvironmentOptions\.h)' src/plugins/` | nothing — neither plugin includes a COM or WebView2 header |
| `rg -l '^\s*#\s*include\s*[<"]wrl\.h' src/` | only `webhost.cpp` and `webkeeper.cpp` |
| `ls src/plugins/mdview/webview.*` | absent |

**Write the include guard as an `#include` pattern.** A bare
`rg -l "wrl\.h" src/plugins/mdview/` matches two files — `webglue.h` and
`IMPLEMENTATION_NOTES.md` — because both *mention* the header in prose while
stating that it is not included.

### T030 — the planned lockdown read-back check does not work here (and what replaces it)

The plan wanted to capture the shared host's Debug-only `AssertLockdown`
output (`"<plugin>: lockdown regression, <setting> is not ..."`) with a DBWIN
listener. **A listener was written, run, and then deleted**, because in this
codebase it can never see those lines: a plugin's `TRACE_*` does not call
`OutputDebugString`. `src/plugins/shared/dbg.cpp:266`
(`C__Trace::SendMessageToServer`) forwards to `SalamanderDebug->TraceI/TraceE`,
i.e. into the core, which talks to the **Salamander Trace Server** — a separate
application that is not part of this tree. The listener did capture one line
from our process during a smoke run (`RecursiveDirectoryCreate( …\Tandem
Commander\WebView2\EBWebView directory exists )`), but that comes from
Microsoft's WebView2 loader, not from us.

Rather than leave a tool that looks like it proves something it cannot, the
script is gone and the claim is made three other ways:

1. **The lockdown is applied by the same code that codeview has run since
   070** — there is no mdview-specific branch in it; the only per-plugin inputs
   are `ScriptsEnabled` and `WebMessagesEnabled`, which mdview sets to `false`
   (`webglue.cpp:161-162`), exactly as its own host did.
2. **The CSP demonstrably reaches mdview's document**, by code path:
   `webhost.cpp:155` strips the query (`PathOnly`), so the `?v=<n>`
   cache-buster does not defeat the comparison at `webhost.cpp:164`
   (`rel == impl->cfg.DocumentPath`); mdview sets `DocumentPath = L"doc.html"`
   (`webglue.cpp:157`) and answers exactly that path (`webglue.cpp:179`); with
   `ScriptsEnabled == false` the header appended is `kCspStatic`
   (`webhost.cpp:167`). And it is *effective*: the content the policy permits
   renders (G4, G6) while the hostile corpus shows nothing loading (G5).
3. **Reading the settings back is still compiled in** and will fire for
   whoever runs the product with the Trace Server attached; the on-screen
   checklist's D4 row says so instead of pretending a probe covered it.

---

## Phase 8 — closing

### T048 — final verification, after every commit on the branch

| Gate | Result |
|---|---|
| G1 Debug | `build.cmd` — BUILD SUCCEEDED, 0 errors |
| G1 Release | `build.cmd full release` — BUILD SUCCEEDED, 0 errors, 20 plugins, 189 language modules, runtime closure OK (219 modules, 59 runtime imports, 4 CRT files) |
| G2 guards | `disable-features=msWebOOUI` → **1 file** (`src/common/webhost/webhost.cpp`); `#include` of `wrl.h`/`WebView2.h`/`WebView2EnvironmentOptions.h` under `src/plugins/` → **none**; `src/plugins/mdview/webview.cpp` → **absent** |
| G3 | `build_and_run.cmd` — **29 passed, 0 failed** |
| G4 | `check_csp_compat.py` — **PASS**, control document and `sample.md` clean |
| G5 | `mdview_probe.ps1` — 24 checks Debug, 5 Release smoke, **0 failed** |
| G6 | `render_diff.ps1` — **0 / 729,144 differing pixels** |

### T047 — independent review: no blocker, 3 SHOULD-FIX, all fixed

An agent that did not write the code reviewed `git diff main...HEAD -- src/`
against the contract and research R1–R4, with the deleted `webview.cpp` from
`main` beside it. It confirmed parity item by item — the accelerator map is the
same key set (and the `(vk, ctrl, shift)` argument order matches the host's
call site, which is the kind of silent swap this review exists to catch), the
content-type strings are the old ones minus the prefix the host now adds, the
document-version bumps happen at the same three sites the same number of times,
and the navigation gate and default-deny are textually unchanged. It also
verified what I had only argued: that the `doc` pointer cannot dangle
(`~CViewerWindow` destroys the host in its body, before `Html` goes away) and
that the single scratch buffer cannot be clobbered re-entrantly.

Three findings, **all fixed in this feature**:

**S1 — the keeper leaked its state block, and it is very probably the 078/079
mystery leak.** `CTcWebKeeperAccess::S()` allocates `CTcWebKeeperState` with
`new` on the first `Arm()` *or* `Disarm()`; `CTcWebKeeper` had no destructor
and nothing ever deleted it. Because `MdKeeperDisarm()` is called
unconditionally on the unload path, the block leaked **even in a session where
no Markdown file was viewed**. The pre-081 mdview keeper used a file-static
struct and allocated nothing, so this is a regression my change introduced for
mdview — and a defect codeview has carried since feature 070.

The size is the interesting part. I measured it independently rather than
trusting the review: a stand-in struct with the same members compiled x64
gives **`sizeof = 88`**. Features 078 and 079 both record an unexplained
*"one 88-byte block from a plugin module unloaded before the dump"*
(`#File Error#(84)`) — which is exactly how this allocation presents when the
debug CRT dumps after the `.spl` is gone. I state it as the **most likely
explanation, not as proven**: confirming it needs the allocation stack from a
dump, which needs the Trace Server or a debugger. Whoever next sees that leak
report should check whether it is gone.

Fixed with a destructor on `CTcWebKeeper` (plus deleted copy operations — a
copied keeper would release its window class twice). It disarms first if the
plugin never did, then frees the block. Note this also means the feature's own
leak check could not have caught it: T033 compared the migrated tree against a
reference tree that already contained codeview's identical leak.

**S2 — the image scratch buffer kept the last image resident for the window's
life.** `clear()` does not release capacity and `shrink_to_fit()` was only on
the refusal path, so a served 64 MB local image (or 32 MB remote) stayed
allocated until the viewer window closed; the pre-081 function-local vector
freed it at once. Fixed by releasing the capacity at the **start** of the next
image request (`std::vector<BYTE>().swap(*scratch)`) — it cannot be released at
the end of the current one, because the host has not copied the bytes yet.
Retention is now bounded to one request-to-request interval. The contract's
buffer-lifetime section says so.

**S3 — a comment in the shared keeper was factually false.** It claimed the
class is unregistered only on the unload path "because `ReleaseAll` also runs
when the browser dies mid-session". The browser-death path calls `Disarm()`
(`webkeeper.cpp:73`), not `ReleaseAll()`, so the class *is* released there. The
reviewer traced the consequence and it is not a functional regression — the
window is destroyed and `GWLP_USERDATA` cleared before `UnregisterClassW`, so
it succeeds, and the next `Arm()` re-registers — but the comment was inherited
from mdview's own keeper, where it had been true. Corrected to describe what
the code does, with the 069 requirement kept explicit.

Two of the six NOTEs were also acted on: the dead `doc == NULL` branch now says
why it is kept, and the 404's new `Content-Type` is listed among the contract's
accepted deltas. The stale prose the reviewer found in
`IMPLEMENTATION_NOTES.md` sits in the historical v2.0–v2.2 sections, which the
new v2.3 section supersedes — left as an append-only record — but the dangling
*"precedent: mdview's webview.cpp"* in `webhost.cpp` was corrected.

### T048b — re-verification after the review fixes

| Gate | Result |
|---|---|
| Debug build | 0 errors |
| Release build | 0 errors, runtime closure OK (219 modules) |
| `mdview_probe.ps1` smoke / hostile / cold-close / cross-warm | **18 checks, 0 failed** (the keeper scenarios were not re-run: the two long ones take ~4 min and nothing in the fixes touches arming — the destructor runs at DLL unload, after every scenario ends) |
| generator harness | 29 passed, 0 failed |
| arguments literal | one file (`webhost.cpp`) |

The `cold-close` scenario matters most here: it is the one that exercises the
keeper allocation and release path ten times in a row, and it stayed green.
