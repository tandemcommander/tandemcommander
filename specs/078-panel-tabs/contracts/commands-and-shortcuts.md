# Contract: tab commands, shortcuts and menus

**Feature**: 078 · **Research**: R9–R11, R20 · **Spec**: FR-030–FR-033, US4

## 1. Command ids (`src/resource.rh2`, free block 2860-2889)

Established order *active, left, right* (as `CM_ACTIVE_CHANGEDIR 862 /
CM_LEFT_CHANGEDIR 863 / CM_RIGHT_CHANGEDIR 864`).

| Command | `CM_ACTIVE_*` | `CM_LEFT_*` | `CM_RIGHT_*` | Acts on |
|---|---|---|---|---|
| New Tab | `CM_ACTIVE_NEWTAB` 2860 | 2861 | 2862 | panel; new tab at its current location, appended, activated |
| Close Tab | `CM_ACTIVE_CLOSETAB` 2863 | 2864 | 2865 | the panel's active tab, or `ContextTabIndex` when set |
| Next Tab | `CM_ACTIVE_NEXTTAB` 2866 | 2867 | 2868 | cycles forward |
| Previous Tab | `CM_ACTIVE_PREVTAB` 2869 | 2870 | 2871 | cycles backward |
| Duplicate Tab | `CM_ACTIVE_DUPTAB` 2872 | 2873 | 2874 | copy after the original (or after `ContextTabIndex`), activated |
| Close Other Tabs | `CM_ACTIVE_CLOSEOTHERTABS` 2875 | 2876 | 2877 | keeps the active tab (or `ContextTabIndex`) |
| Close Tabs to the Right | `CM_ACTIVE_CLOSETABSRIGHT` 2878 | 2879 | 2880 | right of the active tab (or `ContextTabIndex`) |

Popups: `CML_LEFT_TABS 5956`, `CML_RIGHT_TABS 5957`. Help id: `IDH_TABSTRIP`
(free range 143-490 at `resource.rh2:46`).

`CM_ACTIVE_*` resolves the panel with `GetActivePanel()`; `CM_LEFT_*` /
`CM_RIGHT_*` use `LeftPanel` / `RightPanel` directly, exactly like the other
per-side commands (`src/mainwnd3.cpp:3773-3789`). All handlers are no-ops
while `Configuration.PanelTabs` is off (they can still arrive from a stale
posted message).

## 2. Menus (`src/menu4.cpp`)

Appended at the **end** of the *Left* menu (`:21-47`) and the *Right* menu
(`:225-251`):

```
{MNTT_SP, -1,                       MNTS_B | MNTS_I | MNTS_A, 0, -1, 0, NULL},
{MNTT_PB, IDS_MENU_LEFT_TABS,       MNTS_B | MNTS_I | MNTS_A, CML_LEFT_TABS, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_NEW,         MNTS_B | MNTS_I | MNTS_A, CM_LEFT_NEWTAB, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_DUPLICATE,   MNTS_B | MNTS_I | MNTS_A, CM_LEFT_DUPTAB, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_CLOSE,       MNTS_B | MNTS_I | MNTS_A, CM_LEFT_CLOSETAB, -1, 0, NULL},
{MNTT_SP, -1,                       MNTS_B | MNTS_I | MNTS_A, 0, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_NEXT,        MNTS_B | MNTS_I | MNTS_A, CM_LEFT_NEXTTAB, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_PREVIOUS,    MNTS_B | MNTS_I | MNTS_A, CM_LEFT_PREVTAB, -1, 0, NULL},
{MNTT_SP, -1,                       MNTS_B | MNTS_I | MNTS_A, 0, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_CLOSEOTHERS, MNTS_B | MNTS_I | MNTS_A, CM_LEFT_CLOSEOTHERTABS, -1, 0, NULL},
{MNTT_IT, IDS_MENU_TAB_CLOSERIGHT,  MNTS_B | MNTS_I | MNTS_A, CM_LEFT_CLOSETABSRIGHT, -1, 0, NULL},
{MNTT_PE},
```

- All skill levels (Clarification Q4).
- **Hidden while tabs are off**: in `WM_USER_INITMENUPOPUP` for `CML_LEFT` /
  `CML_RIGHT` the trailing separator + submenu are removed with
  `RemoveItemsRange` when `!Configuration.PanelTabs` and re-inserted (from the
  template rows) when on — the `CML_LEFT_GO` idiom (`src/mainwnd3.cpp:4820-4844`).
- **Enable state** in `WM_USER_INITMENUPOPUP` for `CML_LEFT_TABS` /
  `CML_RIGHT_TABS`: Close Tab / Close Other Tabs / Close Tabs to the Right
  greyed with `EnableItem` when they cannot apply (only tab; no tabs to the
  right).

## 3. Strings (`src/texts.rh2` from 14212, `src/lang/texts.rc2`)

| Id | English text |
|---|---|
| `IDS_MENU_LEFT_TABS` / `IDS_MENU_RIGHT_TABS` | `&Tabs` |
| `IDS_MENU_TAB_NEW` | `&New Tab\tCtrl+Shift+T` |
| `IDS_MENU_TAB_DUPLICATE` | `&Duplicate Tab` |
| `IDS_MENU_TAB_CLOSE` | `&Close Tab\tCtrl+Shift+W` |
| `IDS_MENU_TAB_NEXT` | `Ne&xt Tab\tCtrl+Shift+Page Down` |
| `IDS_MENU_TAB_PREVIOUS` | `&Previous Tab\tCtrl+Shift+Page Up` |
| `IDS_MENU_TAB_CLOSEOTHERS` | `Close &Other Tabs` |
| `IDS_MENU_TAB_CLOSERIGHT` | `Close Tabs to the &Right` |
| `IDS_TABS_TT_NEW` | `New Tab (Ctrl+Shift+T)` |
| `IDS_TABS_TT_LIST` | `All Tabs` |
| `IDS_TABS_CLOSECONFIRM` | `%d tab(s) will be closed when tabs are turned off. Continue?` (composed with `LoadStrU8`; plural handling via `ExpandPluralString` only if a language needs it — decided when the string is written) |

The context menu re-uses the `IDS_MENU_TAB_*` strings without the `\t`
shortcut part where the menu code strips it (as other ad-hoc menus do with
`LoadStr`).

## 4. Shortcuts

| Key | Command | Today | With tabs on | With tabs off |
|---|---|---|---|---|
| Ctrl+Shift+T | New Tab (active panel) | nothing (letter branch excludes Ctrl+Shift, `src/fileswn0.cpp:1323-1333`) | posts `CM_ACTIVE_NEWTAB` | unchanged (nothing) |
| Ctrl+Shift+W | Close Tab | nothing | posts `CM_ACTIVE_CLOSETAB` | unchanged (nothing) |
| Ctrl+Shift+PgDn | Next Tab | undocumented duplicate of Shift+PgDn (page + select) | posts `CM_ACTIVE_NEXTTAB` | the duplicate returns |
| Ctrl+Shift+PgUp | Previous Tab | undocumented duplicate of Shift+PgUp | posts `CM_ACTIVE_PREVTAB` | the duplicate returns |

- Dispatch: at the top of `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp:1104`),
  before the existing `VK_NEXT`/`VK_PRIOR` and letter branches, guarded by
  `Configuration.PanelTabs && controlPressed && shiftPressed && !altPressed`;
  falls through otherwise. **Not** in the accelerator tables (they would
  swallow the keys even with tabs off).
- Reservation: `case CONTROL_SHIFT:` added under `'T'`, `'W'`, `VK_PRIOR`,
  `VK_NEXT` in `IsSalHotKey` (`src/keyboard.cpp`), unconditionally, so a plugin
  cannot claim them.
- Scope: the keys act while a panel has the focus (as Ctrl+T / Ctrl+W do);
  in the command line box they keep their editing meaning.
- Ctrl+Tab, Ctrl+T, Ctrl+W, Ctrl+PgUp/PgDn, Tab and every documented shortcut
  are untouched (FR-031). Ctrl+Shift+Tab keeps switching panels.

## 5. Manual

`shortcuts_keyboard.htm` gains the four rows (modelled on the
Ctrl+Shift+Left/Right row, line 161); `windows_tabstrip.htm` (new) documents
the strip and the context menu; `windows_panel.htm` mentions the strip;
`configuration_appea.htm` documents *Show tabs in panels* and the "tabs will
be closed" confirmation; `salamand.hhc` / `.hhk` entries;
`[ALIAS] IDH_TABSTRIP=hh\salamand\windows_tabstrip.htm` in `salamand.hhp`.
