# Quickstart — Verifying mdview on the Shared WebView2 Host (081)

This is the hand-over required by spec FR-011: everything that proves the
migration, in order, with expected outcomes. Sections A–D are the **on-screen
checklist for a person**; the gates before them are automated and are run by
the implementation (results in `fix-log.md`).

## 0. Prerequisites

- **Build tree**: `OPENSAL_BUILD_DIR` is unset on this machine, so `build.cmd`
  uses its default and everything lives under
  `E:\Projects\tandemcommander\build\tandemcommander\` (research R7). Do not
  set the variable for this pass, or you will compare against a stale tree on
  `D:`.
- **Reference tree** (pre-migration): `build\tandemcommander\Debug_x64_prefix081\`
  — a copy of the Debug x64 tree of `main` `6b4d7af` made before the first
  build of this branch. Start it with
  `Debug_x64_prefix081\tandemcommander.exe -t REF081`. **Do not delete it
  before section A–D is done.**
- **Migrated tree**: `build\tandemcommander\Debug_x64\` after `build.cmd` on
  this branch (Release: `Release_x64\` after `build.cmd full release`).
- **Fixtures**: `specs\081-mdview-shared-webhost\fixtures\security\` (copy the
  folder to a scratch location such as `%TEMP%\md081\` so relative links and
  the `assets\dot.png` image resolve exactly as a user's folder would).
- **Process watch**: `tasklist /fi "imagename eq msedgewebview2.exe"` or Task
  Manager grouped under Tandem Commander.
- **Network monitor** (section B only): any of Wireshark on the active
  adapter, `netsh trace start capture=yes`, or Fiddler with HTTPS decryption
  **off** (we only need to see whether a connection is attempted).
- Both trees share the registry (`HKCU\Software\Tandem Commander\0.1`), so
  scheme, zoom and window placement are identical — that is what makes a
  side-by-side comparison meaningful.

## 1. Automated gates (run by the implementation; re-runnable)

All of these were run during implementation; the measured results are in
[`fix-log.md`](fix-log.md). Re-run any of them from the repository root.

| Gate | Command | Pass | Measured |
|---|---|---|---|
| G1 | `build.cmd` then `build.cmd full release` (**do not set `OPENSAL_BUILD_DIR`**) | both exit 0 | 0 errors; both trees carry `plugins\mdview\mdview.spl` linked with `webhost.obj`+`webkeeper.obj`; Release runtime closure OK |
| G2 | `rg '^\s*#\s*include\s*[<"](wrl\.h\|WebView2\.h\|WebView2EnvironmentOptions\.h)' src/plugins/` → nothing; `rg -c "disable-features=msWebOOUI" src/` → one file; `ls src/plugins/mdview/webview.*` → absent | as stated | all three hold. **Use the `#include` form**: a bare `rg -l "wrl\.h"` also matches prose in comments and documentation, which cost one confused minute |
| G3 | `tests\mdview_htmlgen_test\build_and_run.cmd` | `RESULT: PASS` | **29 passed, 0 failed** |
| G4 | `python specs\081-mdview-shared-webhost\probe\check_csp_compat.py --extra tests\mdview_htmlgen_test\sample.md` | exit 0 | control document **0 blocked**, `sample.md` **0 blocked**, every hostile fixture matched its declared layer |
| G5 | `powershell -NoProfile -File specs\081-mdview-shared-webhost\probe\mdview_probe.ps1 -Exe <tree>\tandemcommander.exe -Scenario all` | every scenario `PASS` | **24 checks, 0 failed** (smoke 5, hostile 9, keeper-warm 3, keeper-crash 3, cold-close 2, cross-warm 2); Release smoke 5/5 |
| G6 | `powershell -NoProfile -File specs\081-mdview-shared-webhost\probe\render_diff.ps1 -Ref <ref tree>\tandemcommander.exe -New <tree>\tandemcommander.exe` | ≤ 0.1 % differing pixels | **0 of 729,144 pixels** differ; PNGs in `probe/out/` |
| G7 | independent review of `git diff main...081-mdview-shared-webhost -- src/` (069 protocol) | no blocker | see `fix-log.md` |

> **Expect a "Heap Message — Detected memory leaks!" dialog when a *Debug*
> build exits.** It is the pre-existing leak recorded in feature 078 and it
> appears on the reference build too; it is not a regression of this feature.
> The probes dismiss it. Do not report it as a finding of the on-screen pass.

## 2. On-screen checklist (a person; ~45 minutes)

Run each row on the **migrated** tree; for rows marked ⇄ run it on the
reference tree too and compare. Record `same` / `stricter` / `DIFFERENT`
(+ note) in the table at the end. Any `DIFFERENT` is a finding → fix →
independent review → gates again.

### A — Viewing parity (spec User Story 1)

| # | Step | Expected | ⇄ |
|---|---|---|---|
| A1 | F3 on `10-legit-control.md` | renders: table grid with left/centre/right alignment, highlighted `c` block, the inline dot image, the `data:` image, `<kbd>`/`<sub>`/`<details>` rendered not literal; theme background from the first frame, never white | ⇄ |
| A2 | F9, Shift+F9, View ▸ Color Scheme ▸ pick two schemes, View ▸ *Follow system theme* on/off | scheme changes immediately; the choice survives close + reopen | ⇄ |
| A3 | Ctrl+wheel up/down, Ctrl+Plus, Ctrl+Minus, Ctrl+0, Ctrl+Numpad 0; View ▸ Zoom In/Out/Reset | content zooms; title shows `(NNN%)` live; the percentage survives close + reopen | ⇄ |
| A4 | Ctrl+F `dot`, OK; F3; Shift+F3; Ctrl+F `zzz-nomatch` | matches highlighted, view jumps next/previous; the no-match term shows the *not found* box | ⇄ |
| A5 | Ctrl+U; scroll; Ctrl+F in source; Ctrl+U again | raw source shown, title gains `[Source]`; find works in source; toggles back to rendered | ⇄ |
| A6 | click, in order: the `#anchor` link, the `10b-linked.md` link, the `notes.txt` link, the `https://` link, the `mailto:` link, the `ftp://` link | anchor scrolls; a **second viewer window** opens on `10b-linked.md`; the `.txt` shows its resolved path only (nothing launched); `https` and `mailto` open the system handler; `ftp` → *link blocked* | ⇄ |
| A7 | F3 on `04-remote-image.md`; View ▸ *Load Remote Images* | placeholder with the URL as tooltip before consent. After consent the slot stays **empty**: `example.invalid` cannot resolve by design (RFC 2606), so the fetch fails — that is the expected outcome on both builds, and what matters is that no request was attempted *before* consent (row B4) | ⇄ |
| A8 | Options ▸ Theme ▸ Dark in the main window, open a viewer | menu bar and popups drawn dark; Alt+V opens View; mnemonics work | ⇄ |
| A9 | (if a VM without the WebView2 runtime is at hand) F3 on a `.md` | the built-in text viewer opens; no new message text | ⇄ |
| A10 | resize the viewer with the mouse; Alt+Tab away and back; press PgDn | content fills the window at every size; PgDn scrolls without a click | ⇄ |

### B — Hostile corpus (spec User Story 2) — network monitor running

Open each file with F3, look at the screen, look at the monitor, close.

| # | File | Expected | Monitor |
|---|---|---|---|
| B1 | `01-script-tag.md` | script text shown literally or not at all; **title unchanged** (the script would rename it) | no request |
| B2 | `02-event-handlers.md` | nothing fires; no dialog | no request |
| B3 | `03-javascript-link.md` | clicking either link → *link blocked* | no request |
| B4 | `04-remote-image.md` (no consent) | placeholders | **no request to example.invalid** |
| B5 | `05-iframe.md` | empty area / nothing | no request |
| B6 | `06-meta-refresh.md` | view stays on the document | no request |
| B7 | `07-form.md` | clicking *Submit* does nothing (silently — accepted delta) | no request |
| B8 | `08-path-traversal-image.md` | three placeholders | no request; nothing read outside the folder (Process Monitor optional) |
| B9 | `09-download-link.md` | clicking **each of the five** links: **no download bubble, nothing saved in `%USERPROFILE%\Downloads`**. This is the one hardening you can see: on the reference build the `data:` link may produce a bubble or a saved file | no request |

### C — Keeper (spec User Story 3; feature 065 quickstart 1, 3, 4, 5, 7)

| # | Step | Expected |
|---|---|---|
| C1 | start the migrated tree fresh; browse, view a `.txt` with F3; do **not** open Markdown | no `msedgewebview2.exe` under Tandem Commander |
| C2 | F3 on a `.md` (cold), close; wait ≥ 60 s | the engine tree is still running; `%LOCALAPPDATA%\Tandem Commander\WebView2` exists; no `mdview.WebView2` folder |
| C3 | F3 on another `.md` | instant — no perceptible blank stage |
| C4 | with no viewer open: `taskkill /f /im msedgewebview2.exe`; F3 on a `.md` | works (one cold start); close; F3 again → instant |
| C5 | Plugins Manager ▸ Markdown Viewer ▸ Configure ▸ uncheck *Keep the rendering engine ready…* ▸ OK (no viewer open); wait ~1 min | engine tree exits; F3 → cold; close; F3 → cold again; re-check the option → next view arms; view/close/view → instant |
| C6 | F3 on `a.md` and **immediately** F3 on `b.md` during the cold start | both render; no crash, no error |
| C7 | keeper armed, no viewer: Plugins Manager ▸ Unload Markdown Viewer | unloads cleanly; engine tree exits; Load again; F3 → works; close; F3 → **instant** (the class was released — 069 F-P6-01) |
| C8 | open `hello.cpp` with the Code Viewer first (fresh session), close it, then F3 on a `.md` | the Markdown view attaches **warm** (either plugin's keeper warms the other) |

> Rows C1–C4, C6 and C8 are covered by `mdview_probe.ps1` (G5) and passed
> there; run them by hand only if you want to see them. **C5 and C7 are the
> ones that genuinely need you**: they go through the Plugins Manager, which
> the probe does not drive.

### D — Hardening (spec User Story 2 scenario 4–5; contract §5)

| # | Step | Expected |
|---|---|---|
| D1 | A1 passed | inline styles, local image, `data:` image all render under the CSP |
| D2 | B5, B6, B7 | refused (now by policy, before by the interceptor) — same or stricter |
| D3 | B9 | no download, no bubble — **stricter** than reference |
| D4 | *(optional, needs the Salamander Trace Server — a plugin's `TRACE_*` goes through `SalamanderDebug`, not `OutputDebugString`, so no DBWIN tool can see it)*: attach the Trace Server, open a Markdown file on a Debug build, look for `lockdown regression` | zero hits. Without the Trace Server this row is covered indirectly: the lockdown is the same code codeview runs, and D1–D3 show its effect |

### Result table

| Row | Result | Note |
|---|---|---|
| A1–A10 | | |
| B1–B9 | | |
| C1–C8 | | |
| D1–D4 | | |

Record the table (date, tree, tester) at the end of
`specs/081-mdview-shared-webhost/fix-log.md` and, if all rows pass, close the
"owed" markers in `specs/NEXT-WORK.md` item 3 and
`specs/070-source-viewer-plugin/REMAINING-WORK.md` §2.
