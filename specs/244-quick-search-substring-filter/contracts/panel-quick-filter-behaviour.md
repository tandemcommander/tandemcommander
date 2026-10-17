# Contract: panel behaviour while a quick-filter search runs

What the user, the plug-ins and the other panel can rely on. The option
*Quick search finds text anywhere …* is on unless stated.

## Keys in the searching panel

| Key | Effect | Search |
|-----|--------|--------|
| printable character (Space included) | appended if ≥ 1 item matches the longer text, else ignored | runs |
| Backspace | last character removed; items matching again reappear | runs; **ends** when the text becomes empty |
| Left | text = matched part of the focused name minus its last character (wildcards dropped, as today) | runs |
| Right | text extended by the focused name's character after the match | runs |
| Up/Down/PgUp/PgDn/Home/End | move among visible items; with Shift select as today; with Alt jump among visible selected items | runs |
| Insert | select/unselect the focused item, focus moves to the next visible item | runs |
| Enter, double-click | as today; if the directory changes, the new one is shown complete | ends on a directory change |
| Esc | all items visible, focus kept, selection kept | **ends** |
| Tab, click into the other panel | the other panel becomes active | **ends** |
| Ctrl+Shift+T/W/PgUp/PgDn, tab click | another tab is shown | **ends** |

## Commands

- Every command acting on items (copy, move, delete, pack, unpack, view, edit, rename, attributes, properties, compress/encrypt, e-mail, clipboard copy/cut, drag source, user-menu, file list, plug-in commands) sees **only the visible items**: the visible selected items, or the focused item if none is visible-selected. It does not end the search.
- Selection commands (select all, unselect all, invert, by mask, by focused name/extension, reselect, store/restore selection) act on visible items only.
- After the command, the listing refreshes, still filtered by the same text. Two exceptions end the search: an item the command asks to focus (new folder, renamed item) that does not match, and a refresh that leaves no match.
- A path change, by command, hot path, history, Back, drive change or a plug-in, ends the search **before** the path history records the panel's position.
- Sort and view mode changes keep the search; the visible items follow the new sort.

## Plug-in interface

There is no ABI change. `GetPanelItem`, `GetPanelSelectedItem`,
`GetPanelSelection`, `GetPanelFocusedItem` and `SelectPanelItem` work on the
visible items. Plug-ins never see the hidden ones, the same way they never
see items hidden by the panel filter.

## Display

- The directory line shows the path, then the search: `Search: <text> (<visible> of <total>)`. With the directory line hidden, the information line shows it instead of its usual content. When the space is too short the path is shortened first; a character is never cut.
- The searching panel's normal background and empty area are tinted (`SalQFTint`). Focused and selected colours, per-file-type colours with their own background, and the other panel are unchanged.
- The caret stands after the end of the match in the focused name.
- When the search ends, the tint, the text and the caret disappear in the same repaint.

## Never

- An item hidden by the search is changed by a command.
- The selection, the panel filter, hidden names, sort, view mode or a stored setting changes because a search started or ended.
- An item hidden by the panel filter, by the hidden/system-files setting or by hidden names is shown by the search.
- The search text or the filtered view is stored.

## Option off

Exactly 0.1.10:

- prefix matching;
- all items visible;
- no tint and no directory-line text;
- the search ends at every point it ended before.
