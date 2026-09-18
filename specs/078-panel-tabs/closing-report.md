# Feature 078 — Panel Tabs: closing report

Written at the end of the implementation session (2026-09-18). The running
record with every driven check and its evidence is `fix-log.md`; this report
states what shipped, where it departs from the plan, and what is still open.

## What shipped

- **Tabs in both panels**, on by default (Clarification Q1 of the spec: a
  documented exception to the opt-in principle). Design **Model A** of
  research R1: each panel keeps its single `CFilesWindow`; a tab is a
  remembered view state (`CPanelTab`, `src/paneltabs.*`) — location in the
  external form of `GetGeneralPath`, view template, sort, reverse, filter,
  cursor name, top index, x offset, selection, parent-directory scroll memory,
  its own `CPathHistory`. Switching a tab is an ordinary path change through
  the **unchanged** `ChangeDir`: capture → pre-set sort/filter/view → change →
  restore; `CHPPFR_CANNOTCLOSEPATH` reverts everything. Archives and plugin
  file systems therefore keep exactly their own leave rules.
- **Strip** `CTabWindow` (`src/tabwnd.*`): owner-drawn on the shared
  `ItemBitmap` with the caption palette, hot tracking, `+`, close box on the
  active tab, list button on overflow, middle click, drag to reorder, own
  context menu, tooltips; never takes the keyboard focus.
- **Pure rules** in `src/common/saltabs.*` (title derivation incl. drive/UNC/FS
  roots and WTF-8 truncation, index after close, cycling, move, record
  clamping) covered by `saltests` (1353 → 1405 checks).
- **Commands**: 21 `CM_*` ids (2860–2880), *Tabs* submenu appended to the
  *Left* and *Right* menus (removed while off), Ctrl+Shift+T / W / Page Down /
  Page Up dispatched in `OnSysKeyDown` and reserved in `IsSalHotKey`.
- **Persistence**: `{Left,Right} Panel\Tabs\<n>` + `Active Tab`, legacy values
  unchanged for the active tab, written only with the configuration;
  `Configuration\Panel Tabs` (REG_DWORD, default 1). No `THIS_CONFIG_VERSION`
  bump. Restored archive/FS tabs open lazily; no password is ever stored.
- **Option** *Show tabs in panels* on the Appearance page (the three groups
  below it moved 12 dialog units down), with the "N tab(s) will be closed"
  confirmation; off = the 0.1.7 window, byte for byte in behaviour.
- **Plugin ABI untouched** — no interface change (106); the only
  `src/plugins/shared/` diff is the mandated version bump in `spl_vers.h`.
- **Manual** (`windows_tabstrip.htm` new; panel, shortcuts and Appearance
  pages; TOC, index, alias), **translations** (12 strings × 8 languages,
  pins under `_feature_078`), **release bookkeeping** (0.1.8 / build 192,
  `CHANGELOG.md`, `CLAUDE.md`).

## The two `CPathHistory` verifications of T017 (research R4)

1. `CPathHistory::AddPath` returns early when the new path equals the actual
   item, so swapping the panel's history pointer to the target tab *before*
   `ChangeDir` does not duplicate the target's top entry.
2. `ChangeActualPathData` only touches the actual item when the path matches,
   so the leaving panel's cursor is recorded by the explicit
   `RefreshPathHistoryData()` and the target history is left alone.

Both hold at HEAD (`src/salamdr3.cpp`), see `fix-log.md`, Decisions.

## Deviations from the plan

- `ToggleTabStrip` lives in `src/paneltabs.cpp`, not `fileswn2.cpp`.
- The active index is set *before* `ChangeDir` (the title hook in
  `DirectoryLineSetText` must write to the target record); a refused leave
  puts it back. Consequence: while the leave prompts are open the strip already
  paints the target tab as active. Cosmetic.
- `SwitchToTab` brackets `ChangeDir` with `BeginStopRefresh()`/
  `EndStopRefresh()` — the same guard `ChangeDir` applies around the Change
  Directory dialog — after the incident described below.
- quickstart §6.2 assumed the archive-update prompt offers *Cancel*. The
  *Archive Update* dialog only updates or ignores; a leave is refused only by a
  packer plugin's `CanCloseArchive` question or a plugin FS answering FALSE,
  which none of the shipped plugins do in the driven scenarios. The revert
  path is verified by code reading.
- The SFTP plugin (v1) never detaches: every leave closes the session and
  every return reconnects from the saved bookmark without a prompt. That is
  the plugin's rule and therefore the required behaviour (Clarification Q1),
  but "two tabs on one connection" means "two tabs that reconnect silently".
- The build was proven with Debug builds and a PowerShell GUI driver; the
  Release build and the installer are the release-gate items below.

## Open items

1. **Leak report at exit (Debug CRT), twice.** One `88 bytes` block,
   `#File Error#(84)`, zeroed head — allocated by a module unloaded before the
   dump (a plugin; only ftp, pictview and unchm register their module names
   for the leak reporter). Six other runs, including the long US1–US5 session
   and the same archive flow with tabs off, exited clean. Recipe: run the
   Debug build under the DBWIN listener (`dbglisten.ps1` in the session
   scratchpad — a 40-line PowerShell/C# program) and read the dump; identify
   the block with `_CrtSetBreakAlloc` under a debugger or by making the plugins
   call `AddModuleWithPossibleMemoryLeaks`.
2. **One wrong landing, not reproduced.** In the first archive-leave run the
   panel ended in `D:\Downloads` with the second tab active while a USB drive
   was being plugged in. Three exact re-runs were correct. The refresh guard
   above is the mitigation; a device arrival during the leave prompts should be
   re-tested deliberately (plug a removable drive while *Archive Update* is
   open).
3. **Human-owed GUI steps** (this session could drive the application but not
   everything): quickstart §5 remaining items (move/delete/rename in several
   tabs, hot paths, Working Directories, two Drive Bars, bug report dialog,
   plugin load sweep), §7.1–7.4 and 7.6 (archive + SFTP tabs across a restart,
   `Export Configuration` `.reg` inspection, kill-and-restart, Process Monitor
   proof of no registry writes on tab changes), §8.4 (Ctrl+Shift+T/W with the
   command line focused), §9.1 inside an archive, §9.3 Escape during a drag,
   §9.5 strip-background menu, §10.2–10.6 (narrow panel, five-minute idle,
   10,000-entry switch timing, themes, scaling), §13 visual pass over all
   eight languages, §14 release gate (signing, installer).
4. **Follow-ups outside the feature**: cached listings for background tabs
   (today a return re-reads), a *New Tab* toolbar button, dropping files onto
   a tab, and a display-index separate from the active index so the strip does
   not repaint the target early. The main-window caption is still ANSI (shows
   `?` for non-code-page names) — pre-existing, cluster B-1 of feature 069.
5. **Translations**: machine output reviewed by reading only; a native check
   of the eight languages' *Tabs* strings is worth a minute each.
