# Contract - the tab key table (feature 312)

The single source for the key dispatch (panel and command line), the key shown in labels and
tooltips, and the list on the Configuration > Tabs page. Pure, in `src/common/saltabs.*`, covered by
`saltests`. Not a plug-in interface.

## Rows (display order)

| # | Key | Classic action (option off; tabs on for rows 5, 6, 8, 9) | Browser-like action (option on, tabs on) | Dispatched by tab code: classic / browser |
|---|---|---|---|---|
| 1 | Ctrl+T | Go to Shortcut or Link Target | New Tab | no / yes |
| 2 | Ctrl+W | Restore Selection | Close Tab | no / yes |
| 3 | Ctrl+Page Down | Go into the focused folder or archive | Next Tab | no / yes |
| 4 | Ctrl+Page Up | Go to the parent folder | Previous Tab | no / yes |
| 5 | Ctrl+Shift+T | New Tab | Reopen Closed Tab | yes / yes |
| 6 | Ctrl+Shift+W | Close Tab | Restore Selection | yes / yes |
| 7 | Ctrl+Shift+G | (none) | Go to Shortcut or Link Target | no / yes |
| 8 | Ctrl+Shift+Page Down | Next Tab | Next Tab | yes / yes |
| 9 | Ctrl+Shift+Page Up | Previous Tab | Previous Tab | yes / yes |
| 10 | Ctrl+Tab | Go to the command line | Go to the command line | no / no |
| 11 | (no key) | Reopen Closed Tab | - (row 5 shows it) | - |

Row 11 is listed in the classic mode only. With tabs off nothing is dispatched by the tab code (all
keys classic); the page then shows the list greyed for the checkbox's mode.

## Dispatch

`SalTabKeyDispatch(vk, mods, browserLike)` -> the action to run or `stkaNone` (continue the
existing handling). Alt pressed -> `stkaNone`. Actions run as `WM_COMMAND`:

| Action | Command |
|---|---|
| New / Close / Next / Previous Tab | `CM_ACTIVE_NEWTAB` / `_CLOSETAB` / `_NEXTTAB` / `_PREVTAB` |
| Reopen Closed Tab | `CM_ACTIVE_REOPENTAB` (2881; left 2882, right 2883) |
| Restore Selection | `CM_RESELECT` |
| Go to Shortcut or Link Target | `CM_AFOCUSSHORTCUT` |

## Labels

`SalTabKeyForAction(action, browserLike, &vk, &mods)` -> FALSE when the action has no key in the
mode. `SalTabKeyText(vk, mods, buf, size)` -> "Ctrl+Shift+Page Down" (English, the 078 form).
`SalTabLabelWithKey(label, keyText, out, size)`:
- label with `\t` -> text before it + (`\t` + key, or nothing when the key is empty);
- else label ending in " (...)" -> the parenthesised key replaced (or the part dropped when empty);
- else label + `\t` + key (unchanged when empty);
- FALSE (caller keeps the original) when the result does not fit.

Classic mode: every label is the loaded string, unchanged. Browser-like mode: labels of New Tab,
Close Tab, Next Tab, Previous Tab, Reopen Closed Tab, Restore Selection, Go to Shortcut or Link
Target and the tooltips naming those keys get the key of the mode.

## Plug-in hot keys

`IsSalHotKey`: + Ctrl+Shift+G (Plugins Manager refuses, settings import skips). At load a plug-in
key on Ctrl+Shift+G is kept (`IsSalHotKeyKeptAtLoad`); in the browser-like mode with tabs on the core
dispatch runs first.
