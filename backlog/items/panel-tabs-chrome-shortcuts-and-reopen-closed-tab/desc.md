---
title: Panel tabs: a Tabs settings page, opt-in browser-like shortcuts, Reopen Closed Tab
type: feature
status: in-progress
severity: 4
area: panels-ui
source: manual
who: both
created: 2026-10-22
updated: 2026-10-22
verified: 2026-10-22 4a7d5595
effort: L
feature: 312
related: [panel-tabs-078-release-pass-and-leak-watch]
depends-on: []
reason: -
---

# Panel tabs: a Tabs settings page, opt-in browser-like shortcuts, Reopen Closed Tab

## Problem

Panel tabs (feature 078) use Chrome's tab keys with Shift added
(Ctrl+Shift+T new, Ctrl+Shift+W close, Ctrl+Shift+Page Down / Page Up next /
previous), because 078 kept every documented shortcut's meaning (spec
FR-031). Users who know the plain browser keys cannot have them; a tab closed
by mistake cannot be brought back; and the tab settings are one checkbox on
the Appearance page.

**Maintainer decisions (2026-10-22).** The classic keys stay the default -
users praise Tandem Commander for keeping the classic Salamander behaviour,
so nothing changes for anyone who does not opt in:

1. A new **Tabs** page in Configuration holds everything about tabs.
   *Show tabs in panels* moves there from Appearance.
2. On that page a new option **Browser-like tab shortcuts**, **off by
   default**. With it on (and tabs on):

   | Key | Browser-like (option on) | Classic (option off, today) |
   |---|---|---|
   | Ctrl+T | New Tab | Go to Shortcut or Link Target |
   | Ctrl+W | Close Tab | Restore Selection |
   | Ctrl+Page Down | Next Tab | go into the focused directory or archive |
   | Ctrl+Page Up | Previous Tab | go to the parent directory |
   | Ctrl+Shift+T | **Reopen Closed Tab** | New Tab (078) |
   | Ctrl+Shift+W | Restore Selection | Close Tab (078) |
   | Ctrl+Shift+G | Go to Shortcut or Link Target | (free) |
   | Ctrl+Shift+Page Down / Up | Next / Previous Tab (kept) | Next / Previous Tab (078) |

   In the browser-like mode Ctrl+Page Up / Down have no replacement key
   (Backspace and Enter remain).
3. **Ctrl+Tab stays exactly as it is** in both modes.
4. The Tabs page **lists the tab shortcuts and what they do**; switching the
   option's checkbox **updates the list at once** (before OK).
5. A new command **Reopen Closed Tab** in both modes; in the classic mode it
   has no key (the *Tabs* submenu and the strip's context menu only).
6. **Tabs** is added to the toolbar context menu next to the other bars, and
   the same entry under **Options > Show**, both toggling *Show tabs in
   panels*.

## Evidence

At bc59b9ac, by reading:

- Tab keys today: `CFilesWindow` key handler, `src/fileswn0.cpp:1712-1733`
  (guarded by `Configuration.PanelTabs`, posts `CM_ACTIVE_NEWTAB` /
  `_CLOSETAB` / `_NEXTTAB` / `_PREVTAB`); reserved for plug-ins in
  `IsSalHotKey`, `src/keyboard.cpp:91`, `:104`, `:611` (`CONTROL_SHIFT`
  cases marked feature 078). Ctrl+Shift+G is reserved by nobody in
  `IsSalHotKey` and is no shipped plug-in's default (`SALHOTKEY(` in
  `src/plugins`; the default Ctrl+Shift letters are A B C D F M R S T U V Z).
- Ctrl+T / Ctrl+W: `CMainWindow::HandleCtrlLetter`, `src/mainwnd4.cpp:1447`
  (`CM_AFOCUSSHORTCUT`) and `:1456` (`CM_RESELECT`); also reached from the
  command line, `src/editwnd.cpp:849`.
- Ctrl+Page Down / Up: `src/fileswn0.cpp:1880` (`CtrlPageDnOrEnter`) and
  `:1888` (`CtrlPageUpOrBackspace`); command line `src/editwnd.cpp:989`.
  `CtrlPageDnOrEnter` (`src/fileswn0.cpp:802`) enters only a directory, an
  archive or a Nethood item and never runs a file.
- Go to Shortcut or Link Target: `CFilesWindow::FocusShortcutTarget`,
  `src/fileswn0.cpp:823`; Commands menu `src/menu4.cpp:148` (`MNTS_A` only:
  visible at the Advanced skill level only); toolbar button
  `GoToShortcutTarget`, `src/toolbar4.cpp:232`; labels with `\tCtrl+T`:
  `IDS_MENU_CMD_FOCUSLNK`, `IDS_TBTT_FOCUSSHORTCUT`
  (`src/lang/texts.rc2:100`, `:838`).
- Ctrl+Tab: the panel's `VK_TAB` branch has no modifier test
  (`src/fileswn0.cpp` ~1904, `MainWindow->ChangePanel()`); manual
  `shortcuts_keyboard.htm:202`.
- Tab commands: `src/paneltabs.cpp` (`CloseTab` :390, `CloseOtherTabs` :406,
  `CloseTabsToRight` :420, `CMainWindow::HandleTabCommand` :555); ids
  `CM_*` 2860-2880; labels `IDS_MENU_TAB_*`, `src/lang/texts.rc2:1892-1898`.
- *Show tabs in panels*: `CCfgPageAppearance::Transfer`,
  `src/dialogs5.cpp:2938` (`IDC_PANELTABS`, the "N tab(s) will be closed"
  confirmation at :2967); default `src/dialogs4.cpp:385`.
- Configuration pages: `src/dialogs4.cpp:705-740` - the order is indexed
  (`/*00*/`...`/*28*/`) and the constructor's `Configuration.LastFocusedPage`
  depends on it (the comment there warns); feature 071 added *Command Shell*
  as page 15 - the precedent for a new page.
- Options > Show: `src/menu4.cpp:207-214` (`IDS_MENU_OPT_VSB_*`,
  `CM_TOGGLE*`); toolbar context menu: `CMainWindow::OnWmContextMenu`,
  `src/mainwnd1.cpp` ~2594-2630; check marks `src/mainwnd3.cpp` ~5396.
- Manual: `help/src/hh/salamand/shortcuts_keyboard.htm:189-190`, `:284`,
  `:287`; `windows_tabstrip.htm:44`, `:70`; the Appearance and Keyboard
  configuration pages.
- Rationale of the 078 choice: `specs/078-panel-tabs/research.md` ~350-375,
  `spec.md` FR-031.

## Expected

- With the option **off** (default) every key does exactly what it does in
  0.1.10, tabs on or off; the only visible changes are the new Tabs page,
  the moved checkbox, the *Tabs* entries in the toolbar context menu and
  Options > Show, and *Reopen Closed Tab* in the menus.
- With the option **on** and tabs on, the keys of the table do the
  browser-like meanings in the panel **and** with the focus in the command
  line. With tabs off, the option has no effect (classic keys); the option's
  checkbox is disabled while *Show tabs in panels* is off.
- The Tabs page shows a read-only list of the tab shortcuts and their
  actions; toggling the option's checkbox updates it immediately; all texts
  translated.
- Menu labels show the key of the active mode (`\tCtrl+T` on New Tab or on
  Go to Shortcut or Link Target, etc.) - the menus are rebuilt or relabelled
  when the option changes.
- **Reopen Closed Tab**: a per-panel stack in memory only (never written to
  the registry, never a password); Close Tab, Close Other Tabs and Close Tabs
  to the Right push each tab separately; capped (10-20, decide in the spec);
  reopening restores the whole remembered state (location, view, sort,
  filter, cursor, selection, scroll, its own path history) in the panel it
  was closed from, at its old position where possible; an archive or plug-in
  FS tab opens lazily like a tab restored at start-up; disabled when the
  stack is empty.
- Go to Shortcut or Link Target becomes visible in the Commands menu at every
  skill level.
- `IsSalHotKey` keeps the 078 reservations and adds Ctrl+Shift+G. The spec
  decides what happens to a user's existing plug-in hot key on Ctrl+Shift+G
  (Plugins Manager).
- The option is a new `Configuration` value (default 0) saved with the
  configuration; an older configuration without it reads as off.
- Manual (new page for the Tabs configuration page, `shortcuts_keyboard.htm`,
  `windows_tabstrip.htm`, the Appearance page), all eight languages
  (two-stage `.slt` refresh), `CHANGELOG.md` under the unreleased section;
  `saltests` for the pure rules (shortcut table per mode, closed-tab stack
  push / cap / reopen index).

## Approach

- Keep the 078 dispatch pattern: the panel's key handler and the command
  line's handler, before `HandleCtrlLetter` and the paging branch, guarded by
  `Configuration.PanelTabs` and the new option; not in the accelerator
  tables.
- One pure table (key -> command per mode) in `src/common/` serves the
  dispatch, the menu labels and the list on the Tabs page, so the three
  cannot disagree.
- New page: insert it so that `LastFocusedPage` of an existing configuration
  still opens the page it meant (or map old indexes); measure with a stored
  `LastFocusedPage` from 0.1.10.
- Moving *Show tabs in panels* removes the checkbox from Appearance; its
  three groups move back up 12 dialog units (078 moved them down).
- Reopen: push a copy of the `CPanelTab` record on close (the record already
  carries the state; `CSalTabRecord` clamping in `src/common/saltabs.*`).

## Notes

- The decisions above were made in conversation with the maintainer on
  2026-10-22, after weighing a default change: the classic keys are kept
  because users value the classic behaviour; Ctrl+Page Up / Down follow the
  convention of Salamander, Total Commander and FAR (parent / enter), so
  they change only for those who opt in.
- Not verified: whether Ctrl+Shift+G is consumed anywhere outside
  `IsSalHotKey` (measure first in the panel, the command line and with
  plug-ins loaded).
- Person part (`who: both`): the real keyboard in the panel and the command
  line in both modes, and a look at the Tabs page in the eight languages -
  the hidden desktop has no real keyboard (record as NOT DRIVEN). Related:
  the 078 Release pass item.

## Log

- 2026-10-22 — created (source manual)
- 2026-10-22 — maintainer decision 2026-10-22: classic keys stay the default; browser-like tab shortcuts as an opt-in option on a new Tabs configuration page; Reopen Closed Tab; Tabs in the toolbar context menu and Options > Show
- 2026-10-22 — moved to Next position 1
- 2026-10-22 — verified at 4a7d5595: gap at 4a7d5595: no browser-like option, no Reopen Closed Tab, no Tabs page; Ctrl+Shift+G unhandled in panel, command line, IsSalHotKey
- 2026-10-22 — run started, feature 312
