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
