# Research for feature 102: File Comparator and names outside the code page

Read-only research, 2026-10-03, branch `101-small-leftovers` (HEAD cd5092b6).
Machine ACP = 1250. Scratch probes (not in the repository):
`%TEMP%\fc102probe\probe.cpp`, `wild.cpp`, `drop.cpp` (MSVC 2022, console).

## 0. Headline

1. **The file opening itself is already Unicode** (feature 004): `worker.cpp:225-228` and
   `viewwnd3.cpp:163-165` open with `SplU8ToWExtAlloc` + `CreateFileW` (`\\?\` prefix). A UTF-8
   name that reaches the worker intact is compared correctly, whatever its script.
2. **The losses are upstream**, in four places:
   - the *Compare Files* dialog's own **code-page subclass** of both path combos
     (`dialogs.cpp:174-177`, `SetWindowLongPtr` A + `CallWindowProc` A): measured, it turns the
     combo into a non-Unicode window, so `EditLine`'s wide set and wide read both pass through
     the code page -> `f?.txt` (the 093 lesson exactly);
   - the dialog's history, drop and Browse paths are A calls (UTF-8 bytes in `CB_ADDSTRING` A,
     `DragQueryFile` A, `GetDlgItemText` A + `OPENFILENAME` A via `SG->SafeGetOpenFileName`);
   - **`fcremote.exe`** is a code-page program end to end (`GetCommandLine` A,
     `GetCurrentDirectory` A, `char[MAX_PATH]` message fields) and the plug-in hands its
     code-page bytes to a worker that expects UTF-8;
   - every name buffer is `char[MAX_PATH]` (260 **bytes** of UTF-8 = about 86 CJK characters).
3. **Corrections to the 100 record** ("cannot be started on such files at all"): it *can*,
   today, (a) from the core when *Confirm selection* is off (`filecomp.cpp:648` skips the dialog,
   UTF-8 goes straight to the worker), and (b) by dropping two files onto an open comparator
   window (`mainwnd.cpp:1595-1611`, `DragQueryFileW`, no dialog when 2 files). With the default
   *Confirm selection* on, the dialog breaks it.
4. **New defects found on the way, wider than "outside the code page":**
   - **D-A (every non-ASCII name, every language): the dialog's history drop-down is mojibake**
     and picking an entry fails: `ř` is listed as `Ĺ™` (measured); selecting it puts the
     mojibake into the field -> "file does not exist".
   - **D-B (every non-ASCII name): `fcremote.exe` cannot compare a file whose name has ANY
     non-ASCII character**, also inside the code page (Czech `ů`): the plug-in passes the
     code-page bytes to `SplU8ToWExtAlloc`, which rejects them (measured: NULL) -> "cannot open".
     Broken since feature 004 (the 075 note saw the header side only).
   - **D-C (wrong file compared, silently): best-fit.** `GetCommandLineA` (fcremote) and
     `DragQueryFileA` (dialog drop) best-fit-map: measured `voilà.txt` -> `voila.txt`,
     `ＡＢ.txt` -> `AB.txt`, fullwidth quote `＂` -> `"`. If the best-fit twin exists, the
     comparator **opens and compares that other file** with no error. Also: code-page bytes that
     happen to be valid UTF-8 (`Ă©.txt` in cp1250 = `C3 A9`) are read as UTF-8 by the worker ->
     fcremote opens `é.txt` (measured conversion).
   - **D-D (every non-ASCII name, every language): the text-mode differences list**
     (`mainwnd.cpp:735-774`, `IDS_CHANGEFROM1`... contain `(%s)` file names) is filled with
     `CB_ADDSTRING` A from UTF-8 into a winliblt (code-page subclassed) combo -> mojibake names.
   - **D-E (known, 068 F-P5-09/X09 left it so):** in cs/de/fr/hu/sk the title and messages mix a
     code-page `LoadStr` template with UTF-8 names; the strict conversion fails and the narrow
     fallback shows the names as mojibake (100 fixed the code-page *window*, not this mix).
   - **D-F:** fcremote finds `tandemcommander.exe` with `GetModuleFileName` A +
     `CreateProcess` A (`fcremote.cpp:225-240`): an installation path outside the code page
     (per-user install under a CJK user name) cannot be started ("Unable to launch").
5. **No `FindFirstFile` anywhere in the plug-in**, and the core services it calls
   (`SalGetFileAttributes`, `IsTheSamePath`, lukas `SalGetFullName`) are string or
   `GetFileAttributesW` operations. Measured: `GetFileAttributesW`/`CreateFileW` on `...\f?.txt`
   fail with error 123 (with and without `\\?\`); `FindFirstFileW` would match `fa.txt`. So the
   `?` form can **not** select a different file; it fails with "The filename, directory name, or
   volume label syntax is incorrect". The wrong-file risk is best-fit (D-C), not `?`.

## 1. Data flow, hop by hop

Build: `filecomp.spl` and `fcremote.exe` are compiled with **neither `UNICODE` nor `_MBCS`**
(checked in `build\...\Intermediate\*.tlog\CL.command.1.tlog`), so every `TCHAR`/unsuffixed call
below is the A flavour. fcremote: no CRT (`IgnoreAllDefaultLibraries`, own `memcpy`, `new`).

### 1a. Start from the core (Files menu item / Ctrl+Shift+C)

| # | Site | API | Encoding | Loss for `f日.txt` |
|---|---|---|---|---|
| 1 | `filecomp.cpp:429` `AddMenuItem(... SALHOTKEY('C', CTRL\|SHIFT), MID_COMPAREFILES ...)` | - | - | - |
| 2 | `filecomp.cpp:488-604` `ExecuteMenuItem`: `GetPanelSelectedItem`/`GetPanelFocusedItem` (`CFileData::Name`), `GetPanelPath(..., file1, MAX_PATH)` + `SalPathAppend(..., MAX_PATH)` | core services | UTF-8 (WTF-8) | none for short paths. **Long**: path > 259 bytes -> `GetPanelPath` fails -> `return NULL` (559/593: nothing happens, silently); name does not fit -> `SalPathAppend` returns FALSE (ignored, 561/568/595) and `file1` stays the **folder** -> dialog says "does not exist" / worker "cannot open" (no wrong file) |
| 3 | Selection rules: 2 selected in source; or 1 selected + 1 selected in target (disk) or focused; or focused + same name in target (`StrICmp`) | - | - | - |
| 4 | `filecomp.cpp:604` `new CFilecompThread(file1, file2, FALSE, "")` -> `filecomp.h:81-90` `char Path1[MAX_PATH]`, `strcpy` | - | UTF-8 | (overflow-safe only because the callers are MAX_PATH) |
| 5 | `filecomp.cpp:648` dialog only if a path is empty or `ConfirmSelection` (default TRUE, `filecomp.cpp:180`) | - | - | **without the dialog the flow works today** |

### 1b. The Compare Files dialog (`CCompareFilesDialog`, `dialogs.cpp`)

Modeless in the comparator thread (`filecomp.cpp:650-689`, loop `GetMessage`/`IsDialogMessage`/
`TranslateMessage`/`DispatchMessage` **A**), or modal from the comparator window (`mainwnd.cpp:1245`
CM_COMPARE, `:1642` drop; `DialogBoxParam` A = the system's modal loop). Controls `IDE_PATH1/2`
are `COMBOBOX CBS_DROPDOWN` (`lang/lang.rc:159,162`). winliblt `CDialog::Create/Execute` =
`CreateDialogParam`/`DialogBoxParam` A (`shared/winliblt.cpp:445,452`).

| # | Site | API | Encoding | Loss |
|---|---|---|---|---|
| 6 | `dialogs.cpp:170-171` `SG->InstallWordBreakProc` on the combo's edit | core, W/A-aware since 015 | - | none |
| 7 | **`dialogs.cpp:174-177` `GetWindowLongPtr`/`SetWindowLongPtr(GWLP_WNDPROC, DragDropEditProc)` on both combos, `:153` `CallWindowProc`** | **A subclass** | - | **measured: combo `IsWindowUnicode` 1 -> 0; every text crossing the combo goes through the code page** |
| 8 | `dialogs.cpp:184-198` history: `SendMessage(CB_ADDSTRING, CBHistory[i])` | A | `CBHistory` = UTF-8 (from `EditLine`/registry) | **mojibake for every non-ASCII path** (measured `Petrř` -> `PetrĹ™`); choosing it fills the field with mojibake |
| 9 | `winliblt.cpp:1097-1124` `EditLine` ttDataToWindow (via `CDialog` `WM_INITDIALOG` -> `Transfer`, `dialogs.cpp:105-106`) | `SendMessageW(WM_SETTEXT)` to the combo | UTF-8 -> UTF-16 | **through #7: `f?.txt`** (measured). Also `EM_LIMITTEXT 259` units on a 260-byte buffer |
| 10 | `winliblt.cpp:1127-1143` `EditLine` ttDataFromWindow (`Validate` `dialogs.cpp:83`, `Transfer` `:105-106`) | `GetWindowTextW` -> `WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS)`; fallback `WM_GETTEXT` A | UTF-16 -> UTF-8 | **through #7: `?`** (measured). A UTF-8 form > 259 bytes (or a lone surrogate) -> fallback A read: code-page text, truncated |
| 11 | typing into the field | A message loop (modeless case) | - | IME/typed characters outside the code page arrive as `?` (093 S1 rule); pasting is fine (internal to the edit) but then #10 loses it |
| 12 | `dialogs.cpp:131-151` WM_DROPFILES on the combo: `DragQueryFile` A, `SetWindowText` A | A | best-fit code page | **measured: `voilà` -> `voila`, `ＡＢ` -> `AB`, `日` -> `?`** (D-C: wrong file if the twin exists) |
| 13 | `dialogs.cpp:224-261` Browse: `GetDlgItemText` A, `CB_GETLBTEXT` A (initial dir from history = UTF-8 bytes), `OPENFILENAME` A via `SG->SafeGetOpenFileName` (core `salamdr6.cpp:1703`, `GetOpenFileName` A), `SetDlgItemText` A | A | code page | names outside the code page come back as `?` or best-fit (not measured for comdlg; same conversion family as #12); initial dir from a non-ASCII history entry is a mojibake path |
| 14 | `dialogs.cpp:66-73` `FileExists` -> `SG->SalGetFileAttributes` (`common/salfileio.cpp:376`, `GetFileAttributesW` + `\\?\`) | W | UTF-8 | for `f?.txt`: error 123 -> `FileExists` returns **TRUE** (it treats every error except not-found as "exists") -> the dialog closes OK |
| 15 | `dialogs.cpp:92-95` `wsprintf(IDS_FILEDOESNOTEXIST, buffer)` -> `SalMessageBox` | A format | code-page template + UTF-8 name | D-E mix |
| 16 | `dialogs.cpp:30-53` `AddToHistory`: `IsTheSamePath`, `_tcscpy` into `CBHistory[..][MAX_PATH]` | - | UTF-8 | `f?.txt` is stored; with larger path buffers this becomes an **overflow** (must be bounded) |
| 17 | `dialogs.cpp:269-281` WM_USER_CLEARHISTORY: `WM_GETTEXT`/`WM_SETTEXT` A | A | - | round-trips through the code page |

### 1c. Comparator window and worker

| # | Site | API | Encoding | Loss |
|---|---|---|---|---|
| 18 | `filecomp.cpp:708-726` `new CMainWindow(Path1, Path2, ...)`, `CreateEx` A (winliblt) | A window | pointers into the thread's `Path1/2` | none |
| 19 | `mainwnd.cpp:842-905` `SpawnWorker`, title `IDS_MAINWNDHEADERCOMPUTING` -> `SplU8ToWAlloc`, else `SetWindowTextA` | W + 100's `SplSetWindowTitleW` | mixed | D-E in 5 of 8 languages |
| 20 | `worker.h:261` `TCHAR Name[MAX_PATH]` (Files[2]) | - | UTF-8 | length only |
| 21 | **`worker.cpp:225-228` `SplU8ToWExtAlloc` + `CreateFileW`** | W | UTF-8 -> `\\?\` UTF-16 | **none** (fails cleanly for invalid UTF-8 = fcremote's code-page bytes, D-B) |
| 22 | `worker.cpp:157-172` `CException::Raise`: `vsprintf(LoadStr)` + `FormatMessage` **A** appended | A | code-page template + UTF-8 name + code-page system text | D-E mix in the error box |
| 23 | `viewwnd3.cpp:156-169` hex view `SetData`: `SplU8ToWExtAlloc` + `CreateFileW`; `viewwnd.h:257` `char Path[MAX_PATH]`, `strcpy` | W | UTF-8 | none (length only) |
| 24 | `controls.cpp:17-60, 88-145` header bar `Text[MAX_PATH]` (`StoreHeaderText`, 075), drawn wide with a narrow fallback for code-page bytes (fcremote) | W draw | UTF-8 or code page | none; the narrow fallback exists only for fcremote's code-page bytes |
| 25 | **`mainwnd.cpp:719-794` `ResetComboBox`: `sprintf(IDS_CHANGEFROM1 ... path0)` + `SendMessage(CB_ADDSTRING)` A** into `ComboBox` (`mainwnd.cpp:123-143`, winliblt `CWindow::CreateEx` -> A subclass, `winliblt.cpp:164-226`) | A | UTF-8 names (+ code-page template) | **D-D: mojibake names in the differences list, every language**. Binary mode (`worker2.cpp:58-82`, `IDS_BINREPORT1`) carries no names |
| 26 | `mainwnd.cpp:1229-1249` CM_COMPARE: `char path1[MAX_PATH]`, dialog (#7-#17) | - | UTF-8 | as the dialog |
| 27 | `mainwnd.cpp:1568-1655` WM_DROPFILES on the window: `DragQueryFileW(..., MAX_PATH)` -> `SplWToU8(..., MAX_PATH)` | W | UTF-16 -> UTF-8 | **works**; a name > 259 units is truncated by `DragQueryFileW`, a UTF-8 form > 259 bytes -> empty path -> "not a valid file" with an empty name; `:1611` checks `path1` instead of `path2` (recorded pre-existing) |
| 28 | `mainwnd.cpp:2039-2060, 2128-2160`, `worker2.cpp:88-117` titles (068 X09 + 100) | W | mixed | D-E |

### 1d. Persistence

| # | Site | API | Encoding | Loss |
|---|---|---|---|---|
| 29 | `filecomp.cpp:286-292` load `History %d` (`registry->GetValue(REG_SZ, CBHistory[i], MAX_PATH)`) | core facade (`plugins1.cpp:1603` -> `regwork.cpp` -> `SalRegQueryValueExW8`) | UTF-16 in the registry -> UTF-8 | none; a value > 259 bytes UTF-8 fails and **ends the loop** (later entries dropped) |
| 30 | `filecomp.cpp:370-390` save (`SetValue(REG_SZ, strlen)`) | facade `SalRegSetValueExW8` (`salamdr6.cpp:2443`): UTF-8 (WTF-8), else code-page fallback | UTF-8 | none; fcremote's code-page bytes are saved correctly by the fallback |

Persistence needs no change beyond buffer sizes.

### 1e. fcremote.exe and the remote channel

What it is: `src/plugins/filecomp/fcremote/fcremote.cpp` (361 lines), a tiny CRT-free GUI
program for **external tools** (help `using_cmpfilesfromotherapps.htm`: TortoiseSVN etc.):
`fcremote.exe [-w|--wait] first second`. If no plug-in listens, it starts
`..\..\tandemcommander.exe`, waits up to 5 s on the event `RemoteComparatorStarted`, and retries
(needs *Load plugin on start*). Channel = `CMessageCenter` (`shared/lukas/messages.{h,cpp}`):
named mutexes/events + a 4,094-byte file mapping `"RemoteComparator - Buffer v" Version`
(`Version = "1"`, `messages.cpp:13`); max message 4,082 bytes. Only filecomp and fcremote link it.
Receiver: `CRemoteComparator` thread in the plug-in (`remote.cpp`, created at plug-in load,
`filecomp.cpp:108`).

| # | Site | API | Encoding | Loss |
|---|---|---|---|---|
| 31 | `fcremote.cpp:355-357` `RemoteCompareFiles(..., GetCommandLine())` | **`GetCommandLineA`** | best-fit code page | **measured** in a child process: `"C:\T\voilà.txt"` -> `voila.txt`, `f日` -> `f?`, `a＂x＂.txt` -> `a"x".txt`, emoji -> `??` |
| 32 | `fcremote.cpp:92-125` `MakeArgv` (char, quote stripping, `char argv[4][MAX_PATH]`) | - | code page | a best-fit `"` re-splits/merges arguments (`a＂x＂.txt` -> `ax.txt`) |
| 33 | `fcremote.cpp:221-247` start `tandemcommander.exe`: `GetModuleFileName` A, `CreateProcess` A | A | code page | D-F: install path outside the code page -> "Unable to launch" |
| 34 | `fcremote.cpp:255-268` `CRCMessage` (`remotmsg.h:9-15`: `CurrentDirectory`, `Path1`, `Path2` = `char[MAX_PATH]`, `ReleaseEvent[20]`; 808 bytes) filled with `lstrcpyn` + **`GetCurrentDirectory` A** | A | code page | relative names under a folder outside the code page resolve to `?` |
| 35 | `remote.cpp:106-123` `RecieveMessage`: size check `== sizeof(CRCMessage)` (other sizes ignored silently), `strcpy` to `char[MAX_PATH]`, lukas `SalGetFullName` (`shared/lukas/utilaux.cpp:241`, byte string ops, MAX_PATH limits), `new CFilecompThread(..., TRUE /*no dialog*/, ReleaseEvent)` | - | **code-page bytes treated as UTF-8** | **D-B**: any byte >= 0x80 not forming UTF-8 -> worker `SplU8ToWExtAlloc` NULL -> "cannot open" (measured NULL for cp1250 `Petrů`); valid-UTF-8 coincidences open another name (`Ă©` -> `é`) |
| 36 | `filecomp.cpp:666-667` `AddToHistory` of the code-page bytes | - | code page | saved correctly through the facade fallback, but the in-memory history is mixed-encoding until restart |
| 37 | `fcremote.cpp:283-287` `-w`: `WaitForSingleObject(releaseEvent, INFINITE)` | - | - | if the receiver ignores the message (size mismatch) or dies, fcremote waits forever |

## 2. What fails today for `f日.txt` (and friends)

| Route | Result |
|---|---|
| Core, *Confirm selection* on (default) | dialog shows `C:\...\f?.txt`; OK passes (`FileExists` treats error 123 as existing); comparator window opens with the error "cannot open file ...f?.txt: The filename, directory name, or volume label syntax is incorrect" (in Czech UI the system text is code page, mixed with UTF-8 -> D-E); `f?.txt` lands in the history |
| Core, *Confirm selection* off | **works** (title correct since 100) |
| Drop two files onto the comparator window | **works** (names <= 259 UTF-16 units and <= 259 UTF-8 bytes) |
| Drop one file onto a dialog field | `f?.txt` as above; `voilà.txt` -> `voila.txt`: **compares voila.txt if it exists** (D-C) |
| Browse button | `?`/best-fit from the A common dialog (not measured, same conversion family) |
| History drop-down | every non-ASCII entry is mojibake; picking it -> "file does not exist" (D-A) |
| Typing in the modeless dialog | characters outside the code page arrive as `?` (A loop) |
| `fcremote.exe "C:\T\f日.txt" ...` | `f?.txt` -> error 123 "cannot open" |
| `fcremote.exe "C:\T\Petrů.txt" ...` (inside cp1250!) | "cannot open" (D-B, since 004) |
| `fcremote.exe "C:\T\voilà.txt" ...` | **compares `voila.txt` if it exists**, else "cannot open" (D-C) |
| Path whose UTF-8 form > 259 bytes (about 86 CJK chars) | from the core: nothing happens (`GetPanelPath` fails) or the folder is offered; the dialog's A fallback truncates |
| `?` as wildcard | **cannot happen**: no `FindFirstFile` in the plug-in; `GetFileAttributesW`/`CreateFileW` reject `?` (measured err 123, also with `\\?\`; `FindFirstFileW` *would* have matched `fa.txt`) |

## 3. fcremote: why, and how to make it Unicode

- Purpose: external-diff entry point for other applications (VCS clients), optional wait.
  Not used by the core or any other plug-in. Shipped in `plugins\filecomp\` (build tree has it).
- It is small and CRT-free, so a W port is cheap: `GetCommandLineW`, a WCHAR `MakeArgv`
  (`lstrlenW`, no CRT), `GetFullPathNameW` for each argument (resolves relative names in
  fcremote; drops the `CurrentDirectory` field), `GetModuleFileNameW` + `CreateProcessW`
  (fixes D-F), `wsprintfW` for the event name (or keep A: it is ASCII).
- Wire format: send **UTF-16** (not UTF-8): fcremote then needs no WTF-8 code (it has no CRT
  and `WideCharToMultiByte(CP_UTF8)` maps a lone surrogate to U+FFFD); the plug-in converts with
  `SplWToU8Alloc` (WTF-8, total). Variable-length message: header + flags + `ReleaseEvent[20]` +
  two lengths + packed strings, `Size` = actual size, a magic/kind field. Fits 4,082 bytes up to
  ~2,000 UTF-16 units for both paths together; for full long-path support either enlarge
  `BufferSize` or refuse longer paths with a clear message.
- **Compatibility**: bump `CMessageCenter::Version` "1" -> "2" together with the format. The
  mapping name changes, so an old fcremote with a new plug-in (or the reverse) fails **cleanly**
  ("Cannot send message ... Load plugin on start") instead of being silently ignored and, with
  `-w`, waiting forever (#37). Both files ship together in one installer/winget package, so a mix
  only arises with a copied fcremote. Optionally keep a receiver for the old 808-byte message
  (convert `CP_ACP` -> UTF-16 -> UTF-8): this alone already fixes D-B for code-page names. Also
  wait on the receiver's process handle besides the release event (removes #37's hang class).
- Command line syntax and help unchanged.

## 4. Proposed smallest safe design

Principle: UTF-8 (WTF-8) everywhere inside the plug-in (already the contract), UTF-16 only at
window/OS boundaries, no plug-in interface change (stays 107), no change to the registry format.

### 4a. Sites to change

| Site | Change |
|---|---|
| `dialogs.cpp:174-177, 153` | subclass with `GetWindowLongPtrW`/`SetWindowLongPtrW` + `CallWindowProcW` (keeps the combo Unicode; the 015/093 pattern) |
| `dialogs.cpp:131-151` | `DragQueryFileW` (length query first, heap buffer) + `SetWindowTextW` |
| `dialogs.cpp:184-198` | history: `SendMessageW(CB_ADDSTRING)` with `SplU8ToWAlloc(CBHistory[i])` |
| `dialogs.cpp:269-281` | `WM_GETTEXT`/`WM_SETTEXT` W (heap buffer) |
| `dialogs.cpp:224-261` | Browse: `GetDlgItemTextW`, `CB_GETLBTEXT` W + cut directory wide, `GetOpenFileNameW` called by the plug-in with the same `FNERR_INVALIDFILENAME` retry as the core's `SafeGetOpenFileName` (the plug-in-facing service is A only; a W service would be interface 108), result `SetDlgItemTextW` |
| `dialogs.cpp:78-99` | `Validate`: path buffer enlarged; message composed all-UTF-8 (see `LoadStrU8` below) |
| `dialogs.cpp:27-53`, `dialogs.h:12` | history cells: bound the copy (skip or store heap strings); keep `MAX_HISTORY_ENTRIES`; registry format unchanged |
| `filecomp.cpp:671-689` | comparator thread loop: `GetMessageW`, `IsDialogMessageW`, `TranslateAcceleratorW`, `DispatchMessageW` (093 S1) |
| `shared/winliblt.cpp:1097-1143` `EditLine` | on a UTF-8 overflow do not fall back to the A read: truncate to whole characters (the core's `SalWToU8Truncate` rule) or report; optional `EM_LIMITTEXT` in units derived from the byte size. Shared by all plug-ins: behaviour change only where the A fallback fired (overflow / lone surrogate) - review every caller or make it opt-in |
| `shared/winliblt.*` `CWindow` | opt-in `AttachToWindowKeepKind` / Unicode `CreateEx` (core 093 twin), used only for filecomp's differences `ComboBox`/`CComboBoxEdit` (`mainwnd.cpp:123-150`) |
| `mainwnd.cpp:719-794` | differences list items built wide (template from `SG->LoadStrW`, names `SplU8ToW`), `CB_ADDSTRING` W into the Unicode combo (D-D) |
| plug-in-local `LoadStrU8(id)` (from `SG->LoadStrW` + `SplWToU8`, cached per id) | used in every place that formats a name into a template: titles `mainwnd.cpp:889-904, 2039-2060, 2128-2160`, `worker2.cpp:88-117`, messages `dialogs.cpp:94`, `worker.cpp:164`, `ErrorHelper` users with names (`viewwnd3.cpp:169`, `mainwnd.cpp:1600/1612`) - removes the D-E mix so the existing wide paths always succeed |
| `worker.cpp:157-172` | `FormatMessageW` -> UTF-8 appended (the system text is otherwise code page) |
| `mainwnd.cpp:1575-1612` | heap buffers, `DragQueryFileW` length query, `SplWToU8` with the real size; fix `:1611` path1 -> path2 |
| `filecomp.cpp:497-598` | `CSalMaxPathBuffer` (or `SAL_MAX_PATH_UTF8`) for `file1/file2`, check `SalPathAppend`'s result |
| `filecomp.h:81-92`, `mainwnd.h:54`, `worker.h:261`, `viewwnd.h:257`, `controls.h:18`, `mainwnd.cpp:1231-1232`, `remote.cpp:113-114` | name buffers: heap `SAL_MAX_PATH_UTF8` (thread object, worker, hex view, header) - or at least `3 * MAX_PATH + 1` if full long-path support is out of scope (then CJK paths up to 259 units work) |
| `remotmsg.h`, `remote.cpp:106-142` | new variable-length UTF-16 message (`CRCMessageW`), converted with `SplWToU8Alloc`; optionally accept the old 808-byte one via `CP_ACP` |
| `shared/lukas/messages.cpp:13` | `Version` "1" -> "2" (and `BufferSize` if long paths are in scope) |
| `fcremote/fcremote.cpp` | W command line + WCHAR `MakeArgv`, `GetFullPathNameW`, `GetModuleFileNameW`/`CreateProcessW`, build the W message; wait on {release event, receiver process} |

Left as is: `worker.cpp:225`, `viewwnd3.cpp:163` (already right), persistence (facade),
`controls.cpp` wide header (the narrow fallback for code-page bytes becomes dead but harmless),
`textio.cpp:743` (`CP_ACP` on file *content*, not a name).

### 4b. Test plan

Fixtures (one folder each, plus one folder whose own name is CJK):
- pairs with different content: `Жа.txt`/`Жб.txt` (Cyrillic), `日本1.txt`/`日本2.txt` (CJK),
  `📁a.txt`/`📁b.txt` (surrogate pair), `Petrů1.txt`/`Petrů2.txt` (inside cp1250), a lone
  surrogate name (066 class), each also with **identical** content (expect "files are identical")
  and a binary pair (`.bin`);
- **wrong-file decoys** (must never be opened): `voilà.txt` + `voila.txt`, `ＡＢ.txt` + `AB.txt`,
  `Ă©.txt` + `é.txt`, `f日.txt` + `fa.txt` - decoy content differs, so a wrong open shows a
  different difference count;
- long: a folder chain so that the path is 150 CJK characters (> 259 bytes, < 260 units) and one
  > 260 units (only if full long paths are in scope).

Driving (hidden desktop, as the 093/100 probes; reuse `specs/100-cjk-focus-name/probe/cjk_focus_probe.ps1`
which already starts the comparator with Ctrl+Shift+C):
1. Core route: select the two files in the source panel (or focus + same name in the other panel),
   Ctrl+Shift+C (`MID_COMPAREFILES`); with *Confirm selection* on: read both combos (`WM_GETTEXT`
   W, cross-process) = exact names, `BM_CLICK` OK; with it off: no dialog.
2. Result: comparator window title via `InternalGetWindowText` (100 lesson) =
   `<n1> : <n2> - File Comparator - N Differences` / the identical-files message; header bars;
   the differences drop-down items (`CB_GETLBTEXT` W) contain the exact names; decoy never opened
   (difference count, or Process Monitor-free: a decoy with a unique difference count).
3. Dialog route: CM_COMPARE in the window; set fields with `WM_SETTEXT` W, read back, OK; history
   drop-down after a restart contains the exact names (registry `History %d` read wide); pick an
   entry with `CB_SETCURSEL` + `CBN_SELCHANGE`, OK; `WM_DROPFILES` with a wide `DROPFILES` on a
   field (decoy `voilà`); typed characters (posted `WM_CHAR` per unit, 093 caveat about the
   keyboard layout).
4. fcremote: `CreateProcessW` with each pair (absolute; relative with a CJK current directory),
   with `-w` (process ends when the window closes), and with the plug-in not loaded (starts the
   program); old/new mix: an old fcremote binary against the new plug-in fails cleanly (no hang).
5. Languages: English and Czech UI (titles, differences list, error box for a missing file).
6. Regression: ASCII and cp1250 names unchanged on every route; saltests (no change expected
   unless a pure helper, e.g. the W `MakeArgv` or the message packing, is put in a header and
   tested).

### 4c. Risks

- `winliblt.cpp` is compiled into every plug-in: changes must be opt-in or proven neutral
  (`EditLine` fallback change touches ftp, renamer, undelete, pictview, regedt, checksum,
  dbviewer, uniso... - feature 005 D1 list).
- A W message loop dispatching to winliblt's A windows: fine (system converts per window), but
  accelerators/`IsDialogMessageW` must be verified (093 did the same in the core).
- `GetOpenFileNameW` in the plug-in bypasses the core's `SafeGetOpenFileName` wrapper - replicate
  its retry; dark-theme/centering hooks are not involved (`ComDlgHookProc` unused here).
- Buffer growth: `CFilecompThread` x2, worker `Files[2]`, hex views, headers - heap, not stack
  (`SAL_MAX_PATH_UTF8` is 96 KB); `strcpy` sites must all move together (075's
  `StoreHeaderText` clamps by `dstSize`).
- Protocol version bump: a user who pinned an external tool to a copied old fcremote gets a clean
  error (documented in the changelog).
- Best-fit removal changes behaviour for users who relied on `voilà` -> `voila` by accident (no
  one should; it is the defect).
- History entries saved earlier with `?` stay (harmless; they do not exist).

## 5. Twins noticed (not researched)

- `pictview\salpvenv.exe` (envelope helper EXE, `PVEXEWrapper.cpp:497` `CreateProcess` A,
  `PVMessage.h:169,301` `char FileName[260]` in shared memory) - an A helper process passing
  names; likely dormant since feature 006 (WIC), check whether it is still built/shipped.
- `zip\selfextr` (SFX stub), `zip2sfx`, `sfxmake`: separate code-page programs (100 recorded the
  stub).
- `checksum/misc.cpp:96`, `peviewer/peviewer.cpp:291`, `renamer/utils.cpp:103`: `CreateFileA`
  as the fallback after a failed UTF-8 conversion - same "code-page bytes as legacy" shape as
  D-B's receiving side, harmless for UTF-8 input.
- `dbviewer/renmain.cpp:1559`, `pictview/render1.cpp:2089`: `DragQueryFile` count calls (check
  whether the name reads are W).
- A-subclasses (`SetWindowLongPtr ... GWLP_WNDPROC`): ftp x3, zip x4, 7zip x1 - the dialog
  class of #7; ftp's are in its dialogs (B-1 class).
- 7zip: `7za/CPP/Windows/FileIO.cpp:147`, `FileFind.cpp:296` are the engine's A branches
  (`fs2fas`), compiled out when `g_IsNT` (087 note) - not a defect.
- All plug-ins: `LoadStr` (code page) + UTF-8 name in one `sprintf` (D-E) is the general shape;
  `SG->LoadStrW` exists for a plug-in-local `LoadStrU8`.
