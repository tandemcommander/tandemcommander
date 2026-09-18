# Quickstart: validating Panel Tabs

**Feature**: 078 · **Contracts**: [contracts/](contracts/) ·
**Data model**: [data-model.md](data-model.md) · **Research**: [research.md](research.md)

This is the validation guide — what to run and what must happen — not an
implementation walk-through. Every step maps to a spec requirement or success
criterion (in brackets). Steps 3–13 are a human GUI matrix: `saltests` cannot
link the panel code (`src/saltests` links `src/common/` only).

## Prerequisites

- Windows 11, VS2022 C++ workload, Python on `PATH` (the encoding guard is
  mandatory: `build.cmd` fails without it).
- `temp\deepl_key.txt` present (translation refresh); `pip install -e tools` once.
- The local SFTP test server (`docker start tandem-sftp`, `localhost:2222`,
  `tctest` / `tandem123`) for the plugin-file-system scenarios; an FTP server
  is optional (the FTP plugin's detached-connection behaviour is the one
  Clarification Q1 names).
- Test folders: `D:\Work` (plain), a folder with spaces + non-ASCII
  (`G:\Můj disk\Nový projekt` or `…\Test ěščř\`), a UNC share, a ZIP archive
  with a text file you can edit from inside the archive, a directory with
  ≥ 10,000 entries (generate with a script), the feature-066 fixture names
  (`Lone<U+D800>surrogate.txt`).
- A file-system monitor (Process Monitor) for SC-006.

## 1. Build and unit tests

```bat
build.cmd                                   :: Debug x64 incremental; encoding guard --strict inside
%OPENSAL_BUILD_DIR%tandemcommander\Debug_x64\saltests\saltests.exe
```

Expected: build green with `Encoding guard` reporting `TOTAL: 0`; `saltests`
ends with `saltests: N checks, 0 failed`, N ≥ 1353 + the new
`TestPanelTabs078()` checks: title derivation (plain directory, drive root,
UNC root, archive root and inside, `fsname:userpart` with and without
components, trailing separators, non-ASCII, unpaired surrogate bytes),
`IndexAfterClose` (closing left of / at / right of the active tab; last-tab
close is refused), `Cycle` wrap-around both ways, `Move` in both directions
with the active index following, `Clamp` (sort range, view index, empty
location).

Also confirm no new report-only hits mention the new files:

```bat
python tools\check_encoding.py --draft --format list | findstr /i "tabwnd paneltabs saltabs"
```

## 2. Translation refresh (once, after all strings land)

```bat
src\vcxproj\build_langs.cmd --export-templates --module salamand
cd tools
python -m translate.merge --module salamand --dry-run      :: ~13 strings + 1 control × 8 languages
python -m translate.merge --module salamand
python -m translate.slt --verify
cd ..
build.cmd full
```

Expected: only the new rows are reported; `slt --verify` byte-exact; all 8
`.slg` build. Then open the *Left* menu in Czech and German and check the
*Tabs* submenu wording; pin the *Tab* term per language in
`translations/ui-overrides.json` (`_feature_078` note) where the machine
result is wrong, re-run `merge`, commit the `.slt` files and `.origin`
sidecars. Do **not** run `build.cmd full` between adding strings and this
step (the language build fails by design until the refresh).

## 3. First start, default on (FR-002, FR-004, US1-7)

1. Delete `HKCU\Software\Tandem Commander\0.1` (or use a fresh user).
2. Start. **Expected**: each panel shows a strip with one tab titled by its
   directory (`Windows` for the system directory, or `C:\` at a root) and a
   `+` button; everything else is identical to 0.1.7.
3. Configuration ▸ Appearance: *Show tabs in panels* is checked.

## 4. Basic tab work (US1, FR-006–FR-018)

1. Left panel at `D:\Work`, press `+` → second tab `Work`, active, cursor on
   the first item (US1-1). Go to `C:\Users\<me>` in it → title `<me>`.
2. Click tab 1 → `D:\Work` again with the cursor where it was; select three
   files, switch away and back → the same three are selected, same scroll
   position (US1-2, FR-018).
3. Navigate a tab to a drive root → title `D:\`; to `\\server\share` → title
   `\\server\share`; into `a.zip` → title `a.zip`; into `a.zip\sub` →
   `sub` (US1-3, FR-007).
4. Three tabs, middle one active, close it → the right one becomes active
   (US1-4); close until one remains → no `×` on it, middle click on it does
   nothing, *Close Tab* greyed in the menu (FR-012).
5. Right panel inactive: click one of its tabs → right panel active *and* that
   tab shown, in one click; the caret is in the list, not on the strip
   (US1-6, FR-011, FR-013). Press Tab → other panel, as always.
6. Left tab shows `D:\Work`, a left background tab shows `E:\Archive`; F5 →
   files land in the **right** panel's active tab directory (US1-5).
7. Same directory in two tabs: create a file through tab 1, switch to tab 2
   → the file is there (re-read on activation).

## 5. Nothing else changes (US2, SC-001, SC-002)

Run the existing manual matrix twice — copy/move/delete/rename, Create
Directory, Compare Directories, Swap Panels, Zoom, one and two Drive Bars,
hot paths, Back/Forward, List of Working Directories, Change Directory, the
command line, an SFTP session, an archive, every top-level menu, the
Configuration dialog, the bug-report dialog:

- **(a)** tabs **off** (uncheck the option): zero differences from 0.1.7
  other than the new checkbox; no strip, no *Tabs* submenu in *Left*/*Right*,
  Ctrl+Shift+T/W do nothing, Ctrl+Shift+PgUp/PgDn page-and-select as
  Shift+PgUp/PgDn (US2-1, FR-003).
- **(b)** tabs **on**, several tabs per panel: identical results against the
  active tabs; Swap moves whole tab sets and active tabs (US2-3); Zoom keeps
  all tabs (US2-4); both Drive Bars follow the active tabs (US2-5); Compare
  compares the two active tabs (US2-6); every shipped plugin loads
  (Plugins Manager shows interface 106; US2-7).

## 6. Plugin file systems and archives (FR-019–FR-021, Clarifications Q1, Q2)

1. SFTP tab: connect in tab 1, open a disk tab 2, switch to it → the SFTP
   plugin's own leave behaviour (connection closed or kept per its rules);
   switch back → the kept connection is re-used, or a fresh connect with the
   login prompt; the listing is current.
2. Refusal: in an archive tab edit a file from inside the archive (F4), keep
   the editor open, switch tabs → the archive-update prompt appears; choose
   *Cancel* → the switch does not happen, the strip still shows the archive
   tab active, the listing is intact (FR-020, SC-007). Same with a plugin
   that asks before closing its connection, answering *Cancel*.
3. Close an SFTP tab (×, middle click, *Close Tab*) → the tab closes; the
   Change Drive menu (Alt+F1) still lists a kept connection exactly as after
   navigating away; F12 *Disconnect* ends it (Q1).
4. Background tab whose directory you delete in Explorer → nothing happens;
   click it → the panel lands on the nearest existing parent (or the rescue
   path), the tab stays open there and its title follows (US2-8, FR-021).
5. Duplicate an SFTP tab → two tabs, one connection; switching between them
   detaches/re-attaches without a second login (research R15).

## 7. Persistence (US3, FR-027–FR-029, SC-004, Q2, Q5)

1. Left: three tabs (disk, archive, SFTP), second active; right: two tabs;
   exit with *Save configuration on exit* on. Restart → same tabs, order,
   titles and active tabs; the active disk tab is listed; the archive and
   SFTP tabs open only when clicked (archive reopened; SFTP connects with
   its login prompt) (US3-1, US3-3).
2. Exit while an SFTP tab is active → restart starts that panel in its last
   disk path (today's rule), tab title follows (US3-2, FR-028).
3. Make a background tab's directory disappear before restarting; click it
   after restart → fallback as in §6.4 (US3-4).
4. Options ▸ *Export Configuration*; import on another user account → tabs
   come along (US3-5). Inspect the `.reg`: `Left Panel\Tabs\0\Path` … present,
   no password anywhere in an SFTP location (FR-027).
5. Start with a 0.1.7 registry (or delete `Tabs` + `Active Tab`) → one tab
   per panel at the stored path (US3-6).
6. Open tabs, then kill the process (Task Manager) → restart shows the tabs
   of the last save only (US3-7, Q5). Confirm with Process Monitor that
   opening/closing/moving tabs writes **nothing** under the registry root.
7. With the option off, exit and inspect: `Tabs` holds exactly one entry per
   side; the legacy `Path` is the disk path.

## 8. Keyboard (US4, FR-030, FR-031, SC-005)

1. Ctrl+Shift+T → new tab; Ctrl+Shift+PgDn ×3 on three tabs → 2 → 3 → 1;
   Ctrl+Shift+PgUp → back; Ctrl+Shift+W → closes (US4-1, US4-2).
2. *Left* / *Right* menus show the *Tabs* submenu with the shortcuts at
   Beginner, Intermediate and Advanced skill level (Q4); with tabs off the
   submenu is absent (US4-3).
3. Ctrl+T still goes to a shortcut's target, Ctrl+W still restores the
   selection, Ctrl+Tab still focuses the command line, Ctrl+PgUp/PgDn still
   navigate, Tab and Ctrl+Shift+Tab still switch panels (US4-4, FR-031).
4. With the command line focused, Ctrl+Shift+T/W do what they did.
5. Plugins ▸ Plugins Manager ▸ assign a hotkey: Ctrl+Shift+T is refused as a
   Tandem Commander shortcut.

## 9. Mouse (US5, FR-032, FR-033)

1. Middle-click a folder → new background tab with that folder, current tab
   stays active; middle-click `..` → parent in a new tab; middle-click a file
   → nothing (US5-1). In an archive and on SFTP too.
2. Middle-click a tab → closes (never the last) (US5-2).
3. Drag `Music` before `Work` → order `Music, Work, Photos`; drag then press
   Escape → order unchanged (US5-3).
4. Hover a shortened tab → tooltip with the full location; hover `+` →
   "New Tab (Ctrl+Shift+T)" (US5-4).
5. Right-click a tab → *New Tab*, *Duplicate Tab*, *Close Tab*, *Close Other
   Tabs*, *Close Tabs to the Right*, greyed where they cannot apply; each does
   what it says on the **clicked** tab (US5-5, US5-6). Right-click the strip
   background → only *New Tab* enabled. Right-click the Directory Line /
   Header Line / Information Line / items → unchanged menus (FR-033).

## 10. Many tabs, narrow panels, themes (FR-008–FR-010, SC-006)

1. Open 20 tabs in each panel → one row; titles shrink with ellipses; when
   they no longer fit the `▾` button appears and lists all 20 with the
   current one checked; choosing one activates it; the active tab is always
   visible (Q3).
2. Zoom the other panel / drag the splitter to the minimum → the strip still
   shows the active tab, `+` and, when needed, `▾`.
3. Idle five minutes with 20 background tabs (some on SFTP, some on a
   network share) with Process Monitor filtered to `tandemcommander.exe`: no
   file-system or network activity attributable to background tabs; the
   process's thread count equals the two-panel baseline (SC-006).
4. Switch between two local tabs of a 10,000-entry directory → under one
   second (SC-003).
5. Options ▸ Theme ▸ Dark, and each colour scheme: strip colours follow;
   active tab of the active panel uses the active-caption colours, the
   inactive panel's the inactive ones (FR-010).
6. Change the system font size / Windows display scaling (sign out/in) →
   strip height follows `EnvFont`.

## 11. Option semantics (FR-001, FR-005)

1. Uncheck *Show tabs in panels* with 3 + 2 tabs open → the dialog says
   3 tabs will be closed and asks; *No* keeps the dialog open; *Yes* + OK →
   strips gone at once, each panel shows its former active tab (US1-8).
2. Re-check → strips back with one tab each, no re-listing visible.

## 12. Encoding fixtures (FR-036, SC-009)

Tabs on `G:\Můj disk\Nový projekt`, a Chinese-named folder, and the
feature-066 `Lone<U+D800>surrogate.txt` directory: titles and tooltips match
the Directory Line character for character; `tools\check_encoding.py` stays
at `TOTAL: 0`.

## 13. Languages (FR-034, SC-008)

Switch the UI language through all 8 shipped languages: *Tabs* submenu,
context menu, tooltips, the option label and the close confirmation are
translated; accelerators unique per menu (the merge step verifies).

## 14. Release gate (constitution, Release Documentation)

`CHANGELOG.md` *Added* entry (tabs on by default; how to turn them off;
shortcuts; the Ctrl+Shift+PgUp/PgDn note), version 0.1.8 / build 192 in
`src/plugins/shared/spl_vers.h`, `setup/tandemcommander.iss`, `CLAUDE.md`;
`build.cmd full release`; `saltests` green; the matrix above recorded in
`fix-log.md`.
