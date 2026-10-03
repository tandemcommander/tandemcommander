# Feature 098 — long-path overruns found by the 097 review

Measurement only. No product source changed, no rebuild, no commit. Build under
test: `build\tandemcommander\Debug_x64\tandemcommander.exe` (Debug; the RTC error
hook `_RTC_SetErrorFuncW`/`MyRTCErrorFunc` is live, so a stack-frame or
cast-to-smaller-type check turns into the product's own crash report + message).
GUI driven on a hidden desktop via `tools\run_on_hidden_desktop.ps1`; no
`C:\Program Files` instance was running. Registry `HKCU\Software\Tandem Commander`
exported before and restored after — **SHA-256 identical**
(`1AB614304771DBE00A71EAB448FDF988EA7BCC409DE1D48407F2BB6CE63BF769`). No process or
scratch left. WinRAR is **not** installed (`C:\Program Files\WinRAR` absent); 7-Zip
26.03 console present. Probe: `probe\overrun_probe.ps1`; logs
`probe\overrun_result*.txt` and the captured crash report are quoted below.

---

## D1 — crash navigating plain disk folders ~7,500–8,200 chars deep — **CONFIRMED (driven)**

**Driven.** Built one chain of 180-byte components, entered a short start folder,
walked in by End+Enter. At **level 41, a 7,475-byte path**, the program raised its
RTC exception and wrote `TC018X64-20261003-062432.TXT`. Crash report (verbatim):

```
RTC Error
  Error Number: 1
  Description: Cast to smaller type causing loss of data
Call Stacks (real innermost frames):
  CFilesWindow::Execute(1)  <- CtrlPageDnOrEnter(0xD)  (Enter navigation)
  CFilesWindow::ChangePathToDisk
  CFilesWindow::CommonRefresh
  CFilesWindow::DirectoryLineSetText()
  CStatusWindow::SetText
  CStatusWindow::BuildHotTrackItems()
```

**Cause.** `src\stswnd.cpp:379-380`, end of `CStatusWindow::BuildHotTrackItems()`:

```cpp
it->PixelsOffset = (WORD)pixelsOffset;
it->Pixels = it->Chars > 0 ? (WORD)(AlpDX[it->Offset + it->Chars - 1] - pixelsOffset) : 0;
```

`CHotTrackItem` (`src\stswnd.h:52`) stores `Offset/Chars/PixelsOffset/Pixels` as
**`WORD` (16-bit)**. For the directory line the deepest hot-track item spans the
whole path, so `it->Pixels` = the path's **total rendered pixel width**. At ~7,475
characters in the system GUI font at 125% DPI that width is ≈ 65,554 > 65,535, so
the `(WORD)` cast loses data and `/RTCc` (cast-to-smaller-type, the active check —
`SmallerTypeCheck` is on in `plugin_debug.props`; the main app still ships the
check here) fires. It is **length-driven, not component-count-driven**: every
disk item has `Offset == 0`, the number of items (one per path component) only
grows a heap `TDirectArray`; what overflows is the single pixel-width value. A
chain of many 1-byte components would trip at the same *pixel* width (≈3,750
two-char levels) — so the "few long vs many short" question resolves to: only the
rendered width matters. The 7,500–8,200 range the reviewer reported is the same
value at different DPI/font metrics. `Offset`/`Chars` would additionally overflow
at 65,535 *characters* — a deeper, second limit of the same `WORD` fields.

**Since when.** The `WORD` struct is from the initial Open Salamander commit
`3945ecf7`; v0.1.8 has it. Reachable once panel paths could exceed MAX_PATH
(feature 004, shipped 0.1.0). The reviewer saw it on pre-097 and current — matches.

**User action.** Navigate (Enter / typing step by step / Alt+F12 history) into a
real disk directory whose rendered path exceeds ~65,535 px (≈7.5 k chars). The
program shows its crash dialog and exits. It is the practical ceiling of long-path
support, not data loss.

**Smallest safe fix.** Widen `CHotTrackItem::Pixels` and `PixelsOffset` (and, to
remove the 65,535-char limit, `Offset`/`Chars`) from `WORD` to `int`, and the
hit-test arithmetic in `FindHotTrackItem` (`stswnd.cpp:762`) accordingly; the
drawing/measuring code already uses `int` `AlpDX`. Cost: a few bytes per item.
**Twins (same `WORD`/pixel assumption):** `FindHotTrackItem` compares `xPos`
against `PixelsOffset`+`Pixels`; `SetSubTexts` builds `WORD charOffset/charLen`
(`stswnd.cpp:345`) — bottom info line, bounded by its producers but on the same
type. The neighbouring `GetTextExtentExPointW`/ellipsis code (`stswnd.cpp:1025+`)
uses `int` and `AlpDX` sized to byte-length+1, so it does not overflow.

---

## D2 — Change Directory to a typed FILE path of 260+ bytes — **CONFIRMED (driven)**

**Driven.** A normal file `f.txt` in a folder 306 bytes deep; typed its full
306-byte path into Change Directory (CM_ACTIVE_CHANGEDIR=862, wide `WM_SETTEXT`
into field 210, OK). Result: **Debug Assertion Failed — "Buffer is too small",
`corecrt_internal_string_templates.h:81`** — the compile-time-sized secure `strcpy`
overload catching the overrun.

**Cause.** `src\fileswn3.cpp:2481-2482` in `CFilesWindow::ChangeDir`, the "existing
file, not an archive" branch:

```cpp
char shortenedPath[MAX_PATH];
strcpy(shortenedPath, copy);   // copy is char[SAL_MAX_PATH_UTF8], here 306 bytes
```

`copy` (`fileswn3.cpp:2245`, `char copy[SAL_MAX_PATH_UTF8]`) holds the resolved
full path. The archive check runs first (`PackIsArchive`); for a non-archive file
the `else` branch `strcpy`s the whole path into a 260-byte stack buffer, then
`CutDirectory` + `ChangePathToDisk(..., name)`. **Intended** behaviour: go to the
file's folder and focus the file (`CHPPFR_FILENAMEFOCUSED`). In Debug the secure
`strcpy` template asserts; in Release it is a real stack overrun of up to ~259
bytes past `shortenedPath`.

**Since when.** The `strcpy`/`shortenedPath[MAX_PATH]` is from `3945ecf7` and is in
v0.1.8 verbatim. It became **reachable** when `copy` was widened to
`SAL_MAX_PATH_UTF8` in feature 004 (`d855eec6`, shipped **0.1.0**); before that
`copy` was `MAX_PATH` and could not overflow it.

**Smallest safe fix.** `shortenedPath` to `char[SAL_MAX_PATH_UTF8]` (or reuse
`copy` in place), and use `lstrcpyn`/bounded copy. `ChangePathToDisk` already
accepts long paths. **Twins.** `uncPath`/`buff` in `CopyUNCPathToClipboard`
(`fileswn9.cpp:1881-1882`, `char[2*MAX_PATH]`) are already guarded by their caller
`CopyFocusedNameToClipboard` (`fileswn9.cpp:2008`, refuses when
`strlen(buff)+2+strlen(itemName) >= 2*MAX_PATH`, feature 097) and by
`CShares::GetUNCPath` (`shares.cpp:256`, `lstrcpyn(buff, path, MAX_PATH)` — cuts,
does not overrun). `ClipboardPastePath` (`fileswn9.cpp:722`, CM_CLIPPASTE=775 /
context-menu paste) reads into `char buff[2*MAX_PATH]` with a **bounded**
`ConvertU2A(..., _countof(buff))`/`lstrcpyn`, so a clipboard path longer than 519
bytes is **silently truncated** (then `ChangeDir`'d — usually "path not found"),
never overrun. The reviewer's "cuts at 519 bytes silently" = this truncation; it
is a correctness nit, not memory-unsafe.

---

## D3 — 7zip `_stprintf(msg[1024], …, item path)` — **CONFIRMED by reading; NOT REACHABLE / NOT REPRODUCED**

**Site.** `src\plugins\7zip\extract.cpp:648-651`, `CExtractCallbackImp::OnDataError()`:

```cpp
TCHAR msg[1024];
_stprintf(msg, LoadStr(PasswordIsDefined ? IDS_ERROR_PROCESSING_FILE_PWD
                                          : IDS_ERROR_PROCESSING_FILE),
          (const char*)ProcessedFileInfo.Name);
```

The plug-in builds **without `UNICODE`** (`7zip.props` defines `Z7_NO_UNICODE`), so
`TCHAR`=`char` and `_stprintf`=`sprintf` — the plain **unbounded** CRT `sprintf`
(verified by disassembly of `extract.obj`; the secure array overload does not take
effect). `ProcessedFileInfo.Name` (`extract.cpp:475` = `aii->NameInArchive`) is the
raw, already-UTF-8 in-archive item path. Format (resolved
`lang\lang.rc2`): *"Error processing file '%s'. … delete or keep?"*. Reached from
`SetOperationResult`'s failure branch → `OnDataError()` whenever `DataErrorMode ==
Ask` (F5 Unpack / Copy out of the archive panel). Feature 087 **widened** which
results reach it (v0.1.8: data error only; now CRC error, unexpected end, damaged
headers too). Present in v0.1.8 and back to `3945ecf7`.

**Why it does not fire.** Driven a 7z (`-mx0`) holding one corrupt item whose
in-archive path is **1,104 bytes** (nested 120-char dirs) and CRC-corrupted it
(7-Zip's own `t` confirms `ERROR: CRC Failed`). Unpacking it through the product
(End, CM_UNPACK=851) produced **no overflow**: the product first showed *"Cannot
add 1 or more directories to the list. The total path is too long."* and the deep
item never appeared in the listing, so extraction had nothing to fail on.

Root reason: every item is first inserted into the core archive directory via
`CSalamanderDirectory::AddFile`/`AddDir` (`src\zip.cpp:6016`), which **refuses any
in-archive path longer than `MAX_PATH-5` (255)**:

```cpp
if (path != NULL && ((pathLen = (int)strlen(path)) > MAX_PATH - 5 || file.NameLen > MAX_PATH - 5))
    { TRACE_E("Too long path or file name!"); return FALSE; }  // 7zclient.cpp sets ListingIncomplete, throws
```

So no item whose in-archive path approaches 1,024 bytes is ever *listed*, hence
never *extracted*, hence `ProcessedFileInfo.Name` at `OnDataError` is bounded to
≈255 (dir) + 255 (leaf) ≤ ~510 bytes < 1024. The `msg[1024]` write is therefore a
genuine unbounded `sprintf` that is in practice unreachable through the extraction
UI because of the upstream MAX_PATH-5 listing gate.

**Smallest safe fix.** Still worth hardening: make it
`_snprintf_s(msg, _countof(msg), _TRUNCATE, …)` (the plug-in already uses that
pattern for `Error`/`SysError`/`text` since feature 087). Low priority — latent,
not a live crash.

**Twins in the 7zip plug-in (not 7za engine).**
- **Reachable:** `7zip.cpp:1438/1455` `char caption[2000]; sprintf(caption, "%s - %s",
  name, LoadStr(IDS_UNISO))` — `name` is the **ISO file's disk path** (uniso
  viewer), **not** bounded by the archive-listing gate → overflows on an ISO at a
  path > ~1,980 bytes. Same `_snprintf_s` fix.
- Bounded/safe: `FStreams.cpp:28` `msg[1024]` + `vsprintf` (callers pass only
  `%d`, no path); `extract.cpp:480`, `7zclient.cpp:1160/1663`, `7zip.cpp:1299`
  `strcpy` into `malloc(U8_MAX_PATH)` from core paths ≤ U8_MAX_PATH (truncate-safe);
  `7zclient.cpp:649` `new TCHAR[len+2]` exact-sized; `dialogs.h:118` `lstrcpyn`.

---

## D4 — external packer `sourceShortName[MAX_PATH]` + `CPanelTmpEnumData::WorkPath` cut — **CONFIRMED by reading; external path NOT reachable in default config here (no WinRAR)**

Not driven: no external packer is available on this machine, so the GUI cannot
reach it.

**`sourceShortName` overflow.** `src\pack2.cpp`, `PackUniversalCompress`:
`char sourceShortName[MAX_PATH]` (≈218); for packers that support long names (RAR,
custom) line ≈230 does `strcpy(sourceShortName, sourceDir)` **unbounded** —
`sourceDir` is the panel path, up to `SAL_MAX_PATH_UTF8` (98,302). A second
unbounded `sprintf(buffer[1000], "%s\\%s", sourceShortName, namecnv)` follows (≈345).
From `3945ecf7`; reachable (paths >260) since feature 004 / 0.1.0.

**Reachability.** The only default external packer is **RAR** (WinRAR console
`rar`); 7-Zip console has **no packer entry** (`CustomPackers[PACK7ZIPINDEX]`
arguments NULL); ZIP/7z are packed by the internal plug-in. WinRAR is absent, so
feature 084's `RefreshAvailability`/`CanPack`/`IsPackerOffered` mark RAR
unavailable and hide/stop every route to `PackUniversalCompress`. So the
**external-packer overflow is not reachable in the default configuration on this
machine**; it is reachable with WinRAR installed, with any user custom packer, or
a packer on a UNC path (treated as available). Downstream the path is refused
anyway at the working-directory step (`currentDir[MAX_PATH]`, `CreateProcess`
lpCurrentDirectory) — but *after* the overrunning `strcpy`.

**`WorkPath` cut — the more consequential half, and it is NOT external-packer-only.**
`char WorkPath[MAX_PATH]` (`fileswnd.h:1684`), filled by `lstrcpyn(..., MAX_PATH)`
at `fileswn7.cpp:1390`, `fileswn8.cpp:627/805`, `fileswna.cpp:550`, `zip.cpp:3485`
— **silently cut at 259 bytes** (possibly mid-UTF-8). Used only in
`_ReadDirectoryTree`/`ReadDirectoryTree` (`fileswn7.cpp:1157/1164/1178`), which on a
too-long path **returns TRUE without reporting** (`fileswn7.cpp:823`). Effect: when
packing a selection that includes **sub-folders** from a source folder ≥260 bytes,
each selected sub-folder is enumerated as empty and its contents are **silently
dropped** from the archive — no error. Selected top-level files still pack (they use
relative names from the panel). This path is taken by the **default internal ZIP/7z
plug-in packers too** (not just RAR), so it is reachable in the default config;
not driven here.

**Smallest safe fix.** (1) At the top of `PackUniversalCompress`, refuse
`strlen(sourceDir) >= MAX_PATH` with `IDS_TOOLONGPATH` before line ≈230 (downstream
already refuses such a path). (2) At the five `WorkPath` fills, refuse (or make
`_ReadDirectoryTree` report an error) when the path ≥ MAX_PATH instead of cutting,
so the ZIP/7z packers stop losing sub-folder contents.

**Twins (`pack*.cpp`):** `pack2.cpp:204-205` `rootPath[260]` = `"\\"`+archiveRoot
(1-byte overflow at exactly 259); `pack1.cpp:421-422` (unpack) `rootPath[260]` from
`GetZIPPath()` (unbounded, possibly reachable for ARJ/LZH via 7-Zip console with a
deep in-archive path); `pack2.cpp:624` (delete) same but gated by a NULL
DeleteCommand. Other `pack3.cpp` command-expansion buffers are bounded by the
feature-097 archive-name check (<260).

---

## Summary

| # | Defect | Verdict | Where | Since |
|---|--------|---------|-------|-------|
| 1 | Deep disk nav crash | **CONFIRMED, driven** (7,475 B, RTCc) | `stswnd.cpp:379-380` `WORD` pixel fields | 3945ecf7 / 0.1.0 |
| 2 | Change Dir to a FILE 260+ B | **CONFIRMED, driven** (assert "Buffer is too small") | `fileswn3.cpp:2481-2482` `strcpy` → `shortenedPath[MAX_PATH]` | reachable since feature 004 / 0.1.0 |
| 3 | 7zip `msg[1024]` item path | **CONFIRMED by reading; NOT REACHABLE** (AddFile MAX_PATH-5 gate; driven: item excluded from listing) | `extract.cpp:650` unbounded `sprintf`; reachable twin `7zip.cpp:1455` (uniso) | v0.1.8 / 3945ecf7 |
| 4 | External packer `sourceShortName` + `WorkPath` cut | **CONFIRMED by reading; external path not reachable here (no WinRAR)**; `WorkPath` cut reachable via internal ZIP/7z (silent sub-folder loss) | `pack2.cpp` `strcpy`; `WorkPath[MAX_PATH]` 5 sites | 3945ecf7, reachable since feature 004 / 0.1.0 |
