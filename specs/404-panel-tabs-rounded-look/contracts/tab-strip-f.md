# Contract - the tab strip, variant F (feature 404)

Supersedes the drawing and the left-button part of `specs/078-panel-tabs/contracts/tab-strip-ui.md`;
everything else of that contract (focus, tooltips, list button, middle click, context menu
ownership, persistence) stays.

## Geometry (96 DPI; every value x `GetScaleForSystemDPI() / 100`, font values unscaled)

| Item | Value |
|---|---|
| height H | `2 + EnvFontCharHeight + 2 + 2 + 8` |
| content band | y = 3 .. H (text, icon, X, + centred in it) |
| tabs left | 8 |
| tab width | equal; min / max = 6 / 20 x avg char + 2 x 10 + 8 + 16 + 6 |
| icon | x = tab left + 10, 16 x 16 (`IconSizes[ICONSIZE_16]`), y = 3 + (H - 3 - 16) / 2 |
| title | from icon right + 6 to tab right - 10, or to X left - 6 while the X shows |
| X box | 8 x 8, right = tab right - 8, top = 3 + (H - 3 - 8) / 2 |
| plus | box left = tabs left + n x width + 2, width H; centre y = 3 + (H - 3) / 2 |

## Colours

| Item | Default | Dark | High Contrast |
|---|---|---|---|
| strip background | face -> shadow 22 % | face -> shadow 50 % | face |
| active tab | caption bk / fg (active panel + window active: `ACTIVE_CAPTION_*`, else `INACTIVE_CAPTION_*`) | same | same |
| inactive text | text -> strip 38 % | text -> strip 30 % | text |
| hover pill | strip -> text 7 % | strip -> text 10 % | highlight (system) - text in highlight text |
| separator | shadow -> strip 30 % | highlight | shadow |
| X | fg -> bg 25 %, hover: fg + circle bg -> fg 14 % | circle 20 % | fg, circle as Default |
| + | dim text, hover: text + circle in hover colour | same | text |

## Mouse

| Gesture | Result |
|---|---|
| left down on a tab body | activate (as before); arm a drag |
| move past `SM_CXDRAG` / `SM_CYDRAG` | live drag: tab follows x, neighbours slide (150 ms ease-out) |
| left up while dragging | glide into the slot, one `MoveTab(from, to)` |
| Esc / capture lost / `WM_CANCELMODE` / right down while dragging | glide back, order unchanged |
| left down on X | pressed X, no switch, no drag |
| left up on the same X | `CloseTab` |
| left up elsewhere / capture lost | nothing |
| middle up on the same tab as middle down | `CloseTab` (unchanged) |

## Context menu (local id -> command)

| # | Item | Enabled | Command |
|---|---|---|---|
| 1 | New Tab | always | `CM_*_NEWTAB` |
| 7 | New Tab as Other Panel | other panel has a location | `CM_LEFT_NEWTABASOTHER` 2887 / `CM_RIGHT_NEWTABASOTHER` 2888 |
| 2 | Duplicate Tab | on a tab | `CM_*_DUPTAB` |
| 8 | Move to Other Panel | on a tab, count > 1, tabs shown in the other panel | `CM_LEFT_MOVETABTOOTHER` 2885 / `CM_RIGHT_MOVETABTOOTHER` 2886 |
| - | separator | | |
| 3, 6, 4, 5 | Close Tab, Reopen Closed Tab, Close Other Tabs, Close Tabs to the Right | as before | as before |

A command id names the panel whose strip opened the menu; `Tabs.ContextTabIndex` names the tab.
Posted to the main window, so a probe can post it the same way.

## Move to Other Panel (panel P, tab i, other panel O)

1. If i is P's active tab: `P.CaptureActiveTab()`.
2. Copy i's record; `O.Tabs.Add(rec, -1)`; `O.SwitchToTab(last)`; failure -> remove it, stop.
3. `P.CloseTab`-like removal of i **without** `RemoveToClosed` (switch away first when i is active;
   refusal -> remove O's new tab, `O.SwitchToTab(previous active)`, stop).
