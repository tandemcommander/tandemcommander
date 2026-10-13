# Triage: diskmap (feature 130)

Read: the 14 `LoadStr` uses of `DiskMapPlugin/DiskMapPlugin.cpp`, the plug-in's own string
classes (`DiskMap/Utils.CZLocalizer.h/.cpp`, `Utils.CZString.h`, `Utils.CStringFormatter.h`)
and every use of `CZResourceString` in `DiskMap/*.h` (title, load animation, log window, tool
tip, shell menu, abort text). No build, nothing run.

## 1. How the names are encoded

- The build is not `UNICODE` (`LoadStr` fills a `char` buffer with `LoadString`,
  `DiskMapPlugin.cpp:213-224`), so `TCHAR` is `char`.
- Paths and names are UTF-8 (`TreeMap.FileData.CZFile.h:117`, `CZRoot.h:135`:
  `SplU8ToWExtAlloc(path)`; `GUI.ToolTip.h:110`: "UTF-8 name/path").
- The resource texts of the DiskMap window come from `CZLocalizer` = `LoadStringA` = **code
  page** (`Utils.CZLocalizer.cpp:19`).
- Every text is drawn through `ZTextToW` (`Utils.CZString.h:23-40`): UTF-8 when the whole text
  is valid UTF-8, else the code page. So a code-page text alone and a UTF-8 name alone are both
  right; only a text that holds both goes wrong.

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `GUI.MainWindow.h:504-533` `SetPath`, the window title | `IDS_DISKMAP_TITLEPREFIX` (cp; German `DiskMap – `, Ukrainian `DiskMap — `, Russian, Chinese non-ASCII) | the scanned path, UTF-8 | `ZSetWindowText` -> `ZTextToW` -> `SplSetWindowTitleW` | **FIXED**: composed wide (prefix by `MultiByteToWideChar(CP_ACP)`, path by `SplU8ToWAlloc`), buffer as long as the text, `SplSetWindowTitleW`; the old composition stays as the fallback for a path that is not valid UTF-8 |
| `Utils.CStringFormatter.h:229-262` `FormatLongFileSize` | `IDS_DISKMAP_FORMAT_BYTE*` (cp) appended byte by byte | number | `ZExtTextOut` (directory line, tool tip values) | RIGHT AS IT IS (number + code page) |
| `GUI.LogWindow.h:209-243` | level name (cp), message, path - **one per column**, each converted by `SplDisplayTextToWAlloc` | - | list view (`LVN_GETDISPINFOW`) | RIGHT AS IT IS (feature 121; no composition) |
| `TreeMap.FileData.CZRoot.h:64-80` `LogError` | none: `FormatMessageA` text (cp) is the message column, the path its own column | - | log window | RIGHT AS IT IS |
| `GUI.ToolTip.h:574-607` | headers (cp) and values drawn by separate calls; title = name (UTF-8) alone | - | `ZExtTextOut` / `ExtTextOutA` | RIGHT AS IT IS |
| `GUI.LoadAnimation.h:202-246`, `GUI.DiskMapView.h:95-125`, `GUI.ShellMenu.h:380-383, 518-520`, `GUI.MainWindow.h:112`, `GUI.LogWindow.h:34, 109-119` | constant texts (cp) | - | `ExtTextOutA`, `InsertMenu` A, window titles, column headers | RIGHT AS IT IS |
| `DiskMapPlugin.cpp:346-352` About | literal with `VERSINFO_COPYRIGHT` | `IDS_PLUGIN_NAME`, `IDS_PLUGIN_DESCRIPTION` (cp) | `SalMessageBox` | RIGHT AS IT IS |
| `DiskMapPlugin.cpp:154-160`, `317`, `325-328`, `387` | constant texts | - | `SalMessageBoxEx`, `MessageBox`, core | RIGHT AS IT IS |

Counts: **1 fixed**, 7 rows right as they are, 0 recorded.

No `LoadStrU8` was added: the fixed place is in the DiskMap library part, which has its own
localizer and no access to the plug-in's `LoadStr`; the prefix is converted from the code page
on the spot.

## 3. How to reach the fixed place

**German** user interface (the shipped language whose prefix is not ASCII): a panel in a
folder with a letter outside ASCII (`C:\Übung\Příliš`), Plugins > DiskMap. The title read
`DiskMap – C:\Ãœbung\...` (the whole title through the code page); now the path is exact.
Czech / English are the control (ASCII prefix - identical before and after).

**Spanish**, read from the code, not measured: the title was `Mapa del disco - ` **without the
path** - the buffer was `16 + path length` and the 17-byte prefix left no room, so
`CZStringBuffer::AppendAt` (`Utils.CZString.h:264-278`) silently skipped the path. The wide
composition shows it. Worth one probe row.

## 4. Other defects seen (not fixed)

1. `Utils.CZString.h:264-278` `CZStringBuffer::AppendAt`: the bound is `len + p > _c`, so a text
   that fills the buffer exactly writes its terminator one byte past it (`_s[_c]`); and it
   copies with `_tcscpy(…, s)` although it was given a length. A text that does not fit is
   dropped without a sign (the Spanish title above).
2. `Utils.CZLocalizer.h:20`: all texts share `100 * count` characters; a translation set longer
   than that leaves the last ids as `ERROR LOADING STRING` (not the case today, not counted).
3. `Utils.CStringFormatter.h:262`: `*s = 0` after the appended word is not bounded by `slen`
   (the source's own `TODO`).
4. `GUI.DiskMapView.h:109, 125`, `GUI.LoadAnimation.h`, `GUI.ToolTip.h:604-607`: resource texts
   are drawn with `ExtTextOutA` / measured with `GetTextExtentPoint32A` - right for the
   system's code page, `?` for a language outside it (as every `A` text of the program).
5. `GUI.ToolTip.h:188`: `_tcscpy(this->_stitle, this->_file->GetName())` into
   `_stitle[3 * MAX_PATH + 1]` - fits a name component (255 characters x 3 bytes); the other
   branches pass the buffer size. Not followed further.
