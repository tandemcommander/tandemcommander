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

### T004 — Security fixture corpus

<!-- filled after authoring -->

### T003 — 069-protocol check: HEAD matches research R1

| Check | Expected (research) | Measured at `6b4d7af` | |
|---|---|---|---|
| `git log -1 -- src/plugins/mdview/webview.cpp` | `b9498d9` (feature 069, 2026-08-24) | `b9498d9` | ✅ |
| `git log -1 -- src/common/webhost/` | `ec7b796` (feature 070, 2026-08-27) | `ec7b796` | ✅ |
| `rg -c "disable-features=msWebOOUI" src/` | 3 files | `webkeeper.cpp:1`, `webhost.cpp:1`, `mdview/webview.cpp:1` | ✅ |
| `rg -n MdKeeperArmed src/` | declared + defined, called nowhere | `webview.h:81`, `webview.cpp:898` only | ✅ |

The premise of the whole feature — mdview's copy untouched since the lift, the
arguments literal written three times, `MdKeeperArmed` dead — holds at HEAD.

### T004 — Security fixture corpus

<!-- filled after authoring -->
