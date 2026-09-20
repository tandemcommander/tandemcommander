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

| Gate | Command | Pass |
|---|---|---|
| G1 | `build.cmd` then `build.cmd full release` (repo root, `OPENSAL_BUILD_DIR=D:\Build\OpenSal\`) | both exit 0; `plugins\mdview\mdview.spl` present in both trees |
| G2 | `rg -l "wrl\.h|WebView2\.h|WebView2EnvironmentOptions\.h" src/plugins/mdview/` → no output; `rg -c "disable-features=msWebOOUI" src/` → exactly `src/common/webhost/webhost.cpp:1`; `src/plugins/mdview/webview.cpp` and `.h` do not exist | as stated |
| G3 | `tests\mdview_htmlgen_test\build_and_run.cmd` | `RESULT: PASS`, `[FAIL]` count 0, `[PASS]` count recorded in `fix-log.md` |
| G4 | `python specs\081-mdview-shared-webhost\probe\check_csp_compat.py` (renders every fixture with the dumper and classifies resource references) | `10-legit-control.md`: 0 blocked; hostile files: blocked set equals the constructs the file exists to test |
| G5 | `powershell -File specs\081-mdview-shared-webhost\probe\mdview_probe.ps1 -Exe <Debug tree>\tandemcommander.exe -Fixtures %TEMP%\md081` | every scenario prints `PASS` (open/zoom/source/scheme; keeper alive after 60 s; warm reopen ≤ 2× back-to-back; kill → view → warm; 10× close-during-cold-start, no leak from `mdview.spl`; hostile corpus: one window each, no dialog, no process growth) |
| G6 | `powershell -File specs\081-mdview-shared-webhost\probe\render_diff.ps1 -Ref <ref tree>\tandemcommander.exe -New <Debug tree>\tandemcommander.exe -File %TEMP%\md081\10-legit-control.md` | differing pixels ≤ 0.1 % of the viewer client area; both PNGs saved beside the log |
| G7 | independent review of `git diff main...081-mdview-shared-webhost` (069 protocol) | no blocker |

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
| A7 | F3 on `04-remote-image.md`; View ▸ *Load Remote Images* | placeholder with the URL as tooltip before consent; after consent the image loads (or an empty slot if `example.invalid` cannot resolve — same as reference) | ⇄ |
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
| B9 | `09-download-link.md` | clicking either link: **no download bubble, nothing saved** (stricter than reference — on the reference a bubble may appear) | no request |

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
| C8 | open a `.cpp` with the Code Viewer first (fresh session), close it, then F3 on a `.md` | the Markdown view attaches **warm** (either plugin's keeper warms the other) |

### D — Hardening (spec User Story 2 scenario 4–5; contract §5)

| # | Step | Expected |
|---|---|---|
| D1 | A1 passed | inline styles, local image, `data:` image all render under the CSP |
| D2 | B5, B6, B7 | refused (now by policy, before by the interceptor) — same or stricter |
| D3 | B9 | no download, no bubble — **stricter** than reference |
| D4 | Debug build only: run G5 with the DBWIN listener; grep the trace for `lockdown regression` | zero hits |

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
