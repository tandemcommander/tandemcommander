# DiskMap - items of feature 131

Source of the items: `specs/130-plugin-mixed-templates/triage/diskmap.md`, section 4.
Changed files: `src/plugins/diskmap/DiskMap/Utils.CZString.h`, `GUI.DirectoryLine.h`,
`Utils.CStringFormatter.h`, `src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp`.

**Nothing here was compiled in the plug-in's project and nothing was run in the program** (the
brief forbids both). Run outside the repository
(`specs/131-plugin-defect-batch/probe/pictview-diskmap-peviewer/`): `zbuf.cpp` (the old and the
new `AppendAt` side by side, debug heap) and `fix.cpp` (checks of the class `CZStringBuffer`
**cut out of the edited header** by `mkexcerpt.sh`). `GUI.DirectoryLine.h`,
`Utils.CStringFormatter.h` and `DiskMapPlugin.cpp` were changed by reading only - the first
build is owed.

## 5. `CZStringBuffer::AppendAt` - the off-by-one terminator and the silently dropped text

**FIXED** (both parts), with the one caller that loses a path.

### What the note said and what I found

- *Off-by-one*: real. `AppendAt(s, len, pos)` let through `len + p == _c` and then wrote the
  terminator at `_s[_c]`; `AppendAt(c, pos)` let through `p == _c - 1` and wrote it at
  `_s[_c]` as well; and the string version copied **the whole** `s` with `_tcscpy`, whatever
  `len` said. Measured (`zbuf.cpp`, debug heap, `_CrtCheckMemory`): 264 bytes into a 264-byte
  buffer, 263 bytes + one character, and `len = 4` of a 16-byte text into 8 bytes each end with
  "HEAP CORRUPTION DETECTED: ... wrote to memory after end of heap buffer". In a Release
  build the one byte usually lands in the allocator's padding (not measured in the program).
- *Dropped text*: real. A text that does not fit is not written and nothing tells the caller;
  the old content of the buffer stays.

### Every caller

| Caller | Buffer | Finding |
|---|---|---|
| `GUI.DirectoryLine.h` `SetPath` / `SetSubPath` (the directory line under the menu) | `new CZStringBuffer(MAX_PATH + 4)` = 264 **bytes** for a UTF-8 path | **the defect** - see below |
| `GUI.MainWindow.h:526-528` (the title's fallback composition of feature 130) | `prefixLen + pathLen + 1` | exact: both appends fit with the terminator, before and after. No path lost. (Before feature 130 the buffer was 16 + path - the Spanish title lost its path; that is fixed there.) |
| `GUI.LoadAnimation.h:57`, `GUI.ToolTip.h:245` (`_values[]`), `GUI.DirectoryLine.h` `_sizestrlong` / `_sizestrshort` | 64 / 32 / `MAX_DATELEN` | never go through `Append*`: `CStringFormatter` writes into `_s` directly (friend class). Numbers and dates, no path. See note 3 below. |
| `CZStringBuffer(TCHAR const* s)` (constructor) | `strlen + 1` | used nowhere. It allocated and set the length but **did not copy** the text; one `memcpy` added so that it is not a trap. |

### The directory line: how a user gets there, what was lost

The plug-in takes the panel path into `curPath[3 * MAX_PATH]` (`DiskMapPlugin.cpp:737`,
UTF-8), so a root path may have up to 779 bytes; the directory line kept 264.

- Action: a panel in a folder whose path is **over 263 bytes of UTF-8** - 90 CJK letters, 135
  Cyrillic or Greek letters, a deep Czech path with many accented letters (all far below the
  260-character limit, no long-path setup needed) - then Plugins > DiskMap.
- Before:
  - path of 265+ bytes: `SetPath` -> `AppendAt` drops it. The directory line is **empty**
    (`_rootLen` 0). After zooming into a subfolder `sub` the line reads `\sub`
    (`SetSubPath` appends at position 0), and the right-click menu on it is opened for the
    path `\sub` (`OnContextMenu` -> `ShowDirMenu` -> the shell's menu, with its Delete, and
    "Open" -> `OpenFolder`): **a folder of that name in the root of the current drive, if there
    is one, not the folder shown**.
  - root of up to 263 bytes and a subfolder that makes the whole longer: the subfolder part is
    dropped, the line keeps showing the **previous** subfolder (or the root with a backslash),
    and the menu acts on that other folder.
  - path of exactly 264 bytes (or 263 and any zoom): the terminator is written one byte behind
    the heap block.
- Read, not run in the program. The window title and the map itself were right (they do not use
  this buffer) - only the line and its menu.

### The fix

- `Utils.CZString.h`: new `CanAppendAt(len, pos)` (pure: fits **with** the terminator);
  both `AppendAt` use it; the string version copies exactly `len` characters (`memcpy`).
  A text that does not fit is still not written - the class has a fixed size - but a caller
  can ask first.
- `GUI.DirectoryLine.h`:
  - `DL_PATH_BUFSIZE` = `6 * MAX_PATH + 3` (the size the scanner uses for "path + name",
    `TreeMap.FileData.CZRoot.h:45`): the root (<= 779 bytes) + `\` + the path inside it
    (`GetSubDirName` into `buff[3 * MAX_PATH]`, <= 779 bytes) always fit.
  - the arrays indexed by positions in that path follow: `_nodes` (`/ 2 + 2`, and the loop in
    `UpdateValues` now stops before the last entry, which the end mark needs), `_pathtemp`
    (`+ 3`: the path with "..." is at most 2 bytes longer), `dx` in `PrecalcTextSize` (`+ 1`
    for its sentinel), `buff` in `OnContextMenu` (it was `3 * MAX_PATH`: `GetSubString` **cuts**
    what does not fit, and the cut path went to the shell menu - now the buffer cannot be too
    small and the result is also compared with the wanted length).
  - fail closed: `SetPath` / `SetSubPath` ask `CanAppendAt`; if a path ever does not fit, the
    line is emptied and marked `_pathLost` - no click (zoom out) and no context menu from it
    until the next `SetPath`. Not reachable with today's callers (their own buffers are
    smaller); it replaces "an older text stays and is acted upon".
- `DiskMapPlugin.cpp` `FocusFile` / `OpenFolder`: a name that does not fit `FocusPathBuf`
  (`3 * MAX_PATH`) is refused (returns FALSE) instead of being cut by `lstrcpyn` and focused /
  opened in the panel under another name. Reachable at the edge: `GetSelectedFileName` fills
  `buff[3 * MAX_PATH + 1]`, so a full name of exactly 780 bytes lost its last byte. The refusal
  is silent - the callers ignore the result and the plug-in has no "too long" string (the
  scanner's "Path is too long." is an English literal for the log window); nearest behaviour:
  the command does nothing.

### How to test

- Probe row A (the easiest): create `C:\Temp\<90 CJK letters>\sub\file.bin` (some MB, so the
  folder is drawn); panel in `C:\Temp\<90 CJK letters>`; Plugins > DiskMap. Expected: the
  directory line shows the whole path (an ellipsis in the middle when the window is narrow).
  Before: empty line. Then zoom into `sub` (the map's Zoom In on its box): the line ends with `\sub`;
  right-click the last part of the line: the shell menu of `...\<90 CJK letters>\sub` (check
  "Properties" -> location). Before: the line read `\sub`.
- Probe row B: a root path of exactly 264 and of 263 bytes (ASCII letters will do) with page
  heap / a Debug build: no heap corruption report on closing the window. Before: reported.
- Control: an ASCII path under 200 bytes - identical before and after.
- Unit cases for `CZStringBuffer` (all in `fix.cpp`, pass): exact fill refused and buffer
  unchanged; one less accepted; a character at the last free position refused, one before
  accepted; `pos` behind the text = at the end; `len` shorter than the source; `Append` of a
  `CZString` and of a text; the copying constructor; the title composition of
  `GUI.MainWindow.h`.

### What I am not sure about

- `GUI.DirectoryLine.h` is a header with much window code - my change was not compiled. The
  stack array `dx` is now 6.3 KB (was 3.1 KB) in a paint handler; fine for the main thread.
- A path with more than 127 parts: `_mouseNode` values above `NODEID_MAXP` (0x7F) are not
  taken as path parts and 0x80 means the size text (`NODEID_SIZE`) - a limit that was there
  before (132 parts fitted 264 bytes) and is easier to reach with the larger buffer (clicking
  part 128 shows the size tooltip / does nothing). Not changed.

## Other notes of the triage

- **Note 2** (`Utils.CZLocalizer.h:20`, all texts share `100 * count` characters): **LEFT** -
  not reachable with today's texts (as the triage says). Read in `Utils.CZLocalizer.cpp:15-31`:
  each `LoadString` gets the room that is left, so the text that crosses the end is **cut**
  (by `LoadStringA`, possibly inside a double-byte character) and the following ids read
  `ERROR LOADING STRING`; when the room is used up exactly, `LoadString` is called with a size
  of 0 - what `LoadStringA` does then was not measured. Also there: the length stored for a
  missing text is `ARRAYSIZE(szStrLoadError)`, one more than its length. A fix belongs with a
  change of the localizer (a buffer per text), not here.
- **Note 3** (`Utils.CStringFormatter.h` `FormatLongFileSize`, `*s = 0` not bounded):
  **FIXED** - the condition was `slen > bytelen` but the code writes a space, the word and the
  terminator (`bytelen + 2`); now `slen > bytelen + 1`. Not reachable with today's sizes
  (64 bytes for "18 446 744 073 709 551 615 bytes (16,00 EB)"-like texts and the shipped
  words); a translation with a very long word for "bytes" would have reached it. No probe row;
  unit case if the formatter ever gets a seam: `slen == number + bytelen + 1` -> the word is
  left out, the text ends after the number.
- **Note 4** (`ExtTextOutA` for resource texts): **LEFT** - correct for the system code page,
  as every `A` text of the program; not a defect of this batch.
- **Note 5** (`GUI.ToolTip.h:188`, `_tcscpy(_stitle, GetName())`): **NOT A DEFECT** - a name
  part is at most 255 UTF-16 units = 765 bytes (`SplWToU8` into `cFileName[3 * MAX_PATH]`,
  `TreeMap.FileData.CZDirectory.cpp:131, 195`), `_stitle` has 781.

## Seen on the way, not changed (candidates for `specs/NEXT-WORK.md`)

- **`CZFile::GetFullName` / `GetRelativeName` skip a part that does not fit and go on**
  (`TreeMap.FileData.CZFile.cpp:8-28`, `30-57`): when a parent's name did not fit the buffer
  the parent's shorter text is returned, and a child whose own name still fits is appended to
  it - the result is the path of **another** file (`root\file.txt` for
  `root\<long folder>\file.txt`), or of the parent folder when only the file name did not fit.
  The callers give it to the shell menu (`GUI.DiskMapView.h:201-214`, with Delete), to "Focus"
  and to the icon loader, with buffers of `3 * MAX_PATH + 1` bytes, while the scanner accepts
  folders up to about 782 bytes and files below them (`TreeMap.FileData.CZDirectory.cpp:157`).
  Needs a full name over 780 bytes, i.e. over 260 UTF-16 units - whether the shell then gives
  a menu at all was not measured. A wrong path that can reach a Delete: worth its own item.
- The log's path column: `CZString(CZFile*)` uses `2 * MAX_PATH + 1` bytes
  (`Utils.CZString.h:173`) - the same cut for the log text (display only).
