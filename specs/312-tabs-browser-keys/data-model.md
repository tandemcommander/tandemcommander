# Data model - 312 tabs browser keys

## Configuration value

| Field | Type | Default | Stored | Notes |
|---|---|---|---|---|
| `Configuration.PanelTabsBrowserKeys` | int (BOOL) | 0 | `Configuration\Browser Tab Shortcuts` REG_DWORD, written with the configuration | absent = off; absence also marks a configuration written before 312 (remembered page mapped once) |

In effect only while `Configuration.PanelTabs` is on: `SalTabKeysBrowserLike(tabsOn, option)`.

## Tab key row (pure, `saltabs.h`)

| Field | Meaning |
|---|---|
| `Vk` | virtual key (`'T'`, `'W'`, `'G'`, `VK_NEXT`, `VK_PRIOR`, `VK_TAB`), 0 = no key |
| `Mods` | `SAL_TABKEY_CTRL` / `SAL_TABKEY_SHIFT` bits (Alt never part of a row) |
| `Classic`, `Browser` | the action of the key in each mode (`CSalTabKeyAction`) |

Actions: `stkaNone`, `stkaNewTab`, `stkaCloseTab`, `stkaNextTab`, `stkaPrevTab`, `stkaReopenTab`,
`stkaRestoreSel`, `stkaGoToShortcut`, `stkaEnterFocused`, `stkaParentDir`, `stkaCommandLine`.
The rows are the contract table ([contracts/tab-keys.md](contracts/tab-keys.md)).

Rules:
- dispatched by the tab code = the action of the mode, except `stkaNone` and except when the action
  equals the classic action and is not a tab action (New / Close / Next / Prev / Reopen) - those keep
  their existing code (Ctrl+T, Ctrl+W, Ctrl+PgDn / PgUp, Ctrl+Tab in the classic mode, Ctrl+Tab
  always);
- the key shown for an action in a mode = the first row (table order) whose action in that mode is
  it; none -> no key.

## Closed tab (panel, memory only)

`CPanelTab` (unchanged fields: record, focus name, top index, x offset, selection, top-index memory,
worked flag, own `CPathHistory`, visited) + `ClosedIndex` (its index in the strip when it was closed).

`CPanelTabs.Closed`: newest last, at most `SAL_TABS_CLOSED_MAX` = 10.

Transitions:
- close (Close Tab / Close Other Tabs / Close Tabs to the Right / middle click): detached from
  `Tabs`, `ClosedIndex` set, pushed; the oldest beyond 10 deleted.
- reopen: popped; inserted at `min(ClosedIndex, Tabs.Count)`; shown (`SwitchToTab`); a refused
  show -> detached again and pushed back (same place at the top).
- tabs turned off: all deleted.
- program exit: deleted with the panel (never saved).
- Clear History (Configuration > History): all closed tabs are forgotten (review 1, SHOULD 1 - they hold
  folders and selected names).
- a plug-in FS closed: the closed tabs' histories are cleared like the open tabs'.

## Remembered Configuration page

`SalCfgPageIndexFrom311(index)` = `index >= 7 ? index + 1 : index` (the Tabs page is inserted at 7),
applied once at load to a configuration without `Browser Tab Shortcuts`.
