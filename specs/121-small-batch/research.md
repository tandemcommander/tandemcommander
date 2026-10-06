# Research: feature 121 (the small batch)

Measured by code reading and by pure measurements (no GUI run was allowed: other agents run GUI
probes on the hidden desktop at night and the maintainer uses the installed program during the
day). Each item: what the backlog said, what the code does at HEAD (`a75b3d8e`, feature 120), the
decision. "Before" = `build\tandemcommander\Debug_x64_pre121` (copy of the HEAD build).

## R1 - Find window: *Look in* cut at 259 bytes (recorded by 101)

- `find.h`: `LOOKIN_TEXT_LEN MAX_PATH`; `CFindOptionsItem::LookInText[LOOKIN_TEXT_LEN]`.
- `CFindDialog` constructor (`finddlg1.cpp`): the panel's path (`OpenFindDialog(..., GetPath())`,
  `fileswn5.cpp:700`) is copied with every `;` doubled into `LookInText` and **cut at 259 bytes,
  inside a UTF-8 character too** (the loop stops at `end`). 259 bytes = about 130 accented
  characters. The search then runs in the cut path: another folder, or none.
- `HistoryComboBox` sets `CB_LIMITTEXT textLen - 1` (259 UTF-16 units) and reads back with
  `SalGetWindowTextU8(..., 260)` (093: cut at a whole character): a typed path of 130+ accented
  characters is cut the same way.
- Behind the field: `Validate` backs the text up in `char[LOOKIN_TEXT_LEN]` (stack),
  `BuildSerchForData` copies it into `char path[MAX_PATH]`, and `CSearchForData::Set` does an
  **unbounded `strcpy` into `Dir[MAX_PATH]`** - all safe only because the field held MAX_PATH.
  The search thread itself is long-path capable (`CSalPathBuf`, 098 buffers). The Browse menu read
  the field into `WCHAR[1024]`; its `path[MAX_PATH + 200]` takes a chosen folder with every `;`
  doubled - up to 259 extra bytes for a folder of `;`s (200 reserved).
- `CFindOptionsItem::BuildItemName` composes `"named" in "look in"` with `sprintf` into
  `ItemName[MAX_PATH + MAX_PATH + 10]` - safe while both texts were MAX_PATH; it used the
  code-page `LoadStr(IDS_FF_IN)` inside a UTF-8 name (Romanian "în": the whole name then fails the
  UTF-8 probe and is drawn through the code page).
- History (`LoadHistory`) and the registry value (`GetValue(..., LOOKIN_TEXT_LEN)`) take any length;
  a longer stored value is read by an older version as empty (its buffer is too small) - no format
  change.
- Decision: **fix** - the field holds `SAL_MAX_PATH_UTF8` bytes (the program's path limit), its
  limit is `SAL_MAX_PATH_W` units (whose UTF-8 always fits); the panel path is taken whole or not at
  all (`SalFindLookInFromPath`, refused when the doubled text does not fit - never cut); the
  backups, the copy and `CSearchForData::Dir` on the heap; `ItemName` composed bounded, cut at a
  whole character (`SalFindComposeItemName`), "in" as UTF-8. Stack: the find thread already uses
  `SAL_MAX_PATH_UTF8` locals; `CFindOptionsItem def` in `Save` (main thread, 3 MB stack) grows to
  about 100 KB.

## R2 - message box breaks lines inside words (101)

- `CMessageBox` (`msgbox.cpp`) measures the text with `DrawText(DT_WORDBREAK)`. When the result is
  wider than the limit (min(desktop / 1.8, 90 average characters)) - which happens only when one
  "word" alone is wider, in practice a path - it calls `DuplicateStrAndInsertEOLs(W)`: these insert
  a hard `\n` before **every** character that overflows a line, counting the line from the last
  `\n` only. So once one long path is in the text, every paragraph longer than the limit is cut at
  the box's edge inside words (e.g. the equivalent-names notice `IDS_EQUIVNAMESPAIR`: a 135-character
  first paragraph and a 95-character last one).
- Decision: **fix** - breaks only inside a run of non-white-space characters that alone is wider
  than the limit; inside it after the last `\` or `/` that keeps the piece within the limit (when
  the piece is at least a third of it), else before the first character that does not fit; never
  inside a surrogate pair; the rest is left to DrawText (`SalMsgWrapBreaks`, `salmsgwrap.h`, pure).

## R3 - clipboard copy commands fail silently (101)

- `CopyHTextToClipboardW` / `CopyHTextToClipboard` (`salamdr4.cpp`) report an `OpenClipboard`
  failure only in their return value (and the A form only with `showEcho`); `CopyTextToClipboardW`
  and `CopyTextToClipboard` **returned FALSE before their echo** when the clipboard could not be
  opened, so even the echo callers (`gui.cpp:1401`, the Check Version plug-in) said nothing. The
  global memory block is not freed then (small leak, unchanged - ownership is unclear when only
  one of the two formats was stored).
- Callers that ignore the result (every user copy command): panel Copy Full Name / Name / Full
  Path / UNC Name (`fileswn9.cpp`), Find window copy name / full name / path / UNC
  (`finddlg1.cpp`), Save Selection to the clipboard (`fileswn1.cpp`), the directory line and the
  status line copy (`mainwnd1.cpp`, `stswnd.cpp`), the file list copy (`mainwnd4.cpp`), the viewer's
  copy (`viewer3.cpp`), Ctrl+C in a message box (`msgbox.cpp`).
- Existing strings: `IDS_COPYTOCLIPBOARD` "&Copy To Clipboard" (a menu label; the echo used it as
  the title - with the `&`), `IDS_TEXTCOPIED`; the reason is the system's text (`GetErrorText`).
- The plug-in services (`CSalamanderGeneral::CopyTextToClipboard[W]`) keep their contract:
  `showEcho` decides, and the FTP plug-in shows its own message for FALSE (`ctrlcon2.cpp:2098`,
  `:2216`) - a box there would be shown twice.
- Decision: **fix** in the core only - the copy functions leave the reason in `GetLastError()`, the
  echo path no longer returns before its message, and every user copy command reports a failure
  through `CopyTextToClipboardU8Report` / `CopyTextToClipboardWReport` / `ShowClipboardCopyError`:
  the system's text, titled with the menu label without its accelerator (`SalMenuLabelToTitle`).
  The UNC conversion remembers a refusal so the outer level of a SUBST chain does not add "cannot be
  converted to UNC".

## R4 - "name already used" in a UTF-8 error field (103)

- `CFileErrorDlg` shows its error text with `SalSetWindowTextU8` (UTF-8 since feature 010; text
  that is not valid UTF-8 falls back to the code-page call). `worker.cpp` `DoCreateDir` passes
  `LoadStr(IDS_NAMEALREADYUSED)` (code page). The same class: `worker.cpp` compress/encrypt
  "not supported" (`IDS_COMPRNOTSUPPORTED` / `IDS_ENCRYPNOTSUPPORTED`, dialog case 5) and six
  `DialogError` calls in `safefile.cpp` (`IDS_NAMEALREADYUSED[FORDIR]`, `IDS_ERRORCREATINGROOTDIR`;
  `DialogError` feeds the same dialog).
- Measured (script over `translations/*/salamand.slt`, each language in its own code page): every
  enabled translation of 10145 / 10185 is either ASCII or **not** valid UTF-8 in its code page, so
  the fallback draws it right - the backlog's "garbled" does not happen while the system code page
  matches the language. What does happen: `LoadStr` converts through the SYSTEM code page, so a
  language whose letters it lacks loses them (French "déjà utilisé" on a CP1250 system: `à` is not
  in CP1250 - best fit "deja"). `LoadStrU8` is exact in every case.
- Decision: **fix** (one function per site).

## R5 - Disk Map log shows paths garbled (104)

- `GUI.LogWindow.h`: the log list view is created by the code-page `CreateWindowEx` under a
  code-page window class whose procedure does not answer `WM_NOTIFYFORMAT`, so the list view asks
  for `LVN_GETDISPINFOA`, and the window hands it the logged texts as they are: the path column is
  UTF-8 (the tree's names, `SplWToU8`), converted by the list view through the code page -
  mojibake for every name outside ASCII. The text column mixes ASCII literals and `FormatMessageA`
  (code page); the level column is a code-page resource string. The logger's path buffer is
  `2 * MAX_PATH + 1` bytes - a longer path may end in a torn character. No other consumer (no copy).
- Decision: **fix** - the window answers `NFR_UNICODE` (and re-queries after creating the list),
  `LVN_GETDISPINFOW` copies converted text into the list's buffer (`SplDisplayTextToWAlloc`:
  UTF-8 / WTF-8, a torn tail dropped, else code page).

## R6 - plug-in folder picker (104 NIT 3)

- `SplBrowseForFolderU8` (`splfiledlg.h`): callback handles `BFFM_INITIALIZED` only; no
  `BFFM_SELCHANGED` / `BFFM_ENABLEOK` (the core's `DirectoryBrowse` disables OK for an item
  without a file-system path); the picked folder is not resolved as a NetHood folder shortcut (the
  core's `GetTargetDirectory` calls `ResolveNetHoodPath`: desktop.ini naming the folder-shortcut
  class `{0AFACED1-E828-11D1-9187-B532F1E9575D}` + target.lnk -> the link's path). Callers: PictView
  (copy to), CAB (target), Undelete (3). The core compares only as many characters as stand between
  the braces (a prefix match).
- Decision: **fix** - `BFFM_SELCHANGED` -> `BFFM_ENABLEOK` (so the silent FALSE after OK is not
  reachable for a non-file-system item); `ResolveNetHoodFolderW` (the core's rule on UTF-16, whole
  class id), result converted and refused when too long as before.

## R7 - "plugin has rejected to unload. Force?" right after fcremote started the program (102)

- `filecomp.cpp`: `CRemoteComparator::RecieveMessage` (receiver thread) creates a
  `CFilecompThread` in `ThreadQueue`; the thread creates its comparator window (or the Compare Files
  dialog) and only THEN adds it to `MainWindowQueue` (`filecomp.cpp:910`). `Release()`:
  `Terminate` the receiver, `MainWindowQueue.Empty()` -> TRUE in that gap -> nothing is closed ->
  `ThreadQueue.KillAll(force)` waits 1 s (5 s unattended) for a thread nobody asked to end ->
  FALSE -> the core asks "rejected to unload. Force?" (normal exit) or abandons the close
  (installer). The same gap exists for a comparison started from the menu just before the exit.
- Decision: **fix** - `Release()` (not forced) waits in 100 ms slices of the same budget and closes
  every window that appears in the queue meanwhile (a Compare Files dialog in an unattended close
  is refused, 118's rule); no new request can come (the receiver is terminated, the menu runs on
  the main thread, which is in `Release`). The forced path is unchanged.

## R8 - Romanian `IDS_CANTMULTIVOL` (119)

- `translations/romanian/zip.slt` row 1060: "arhiva cu acelasi nume ..." (lower case). The ZIP
  plug-in loads its texts through the code page (CP1250 has no comma-below s/t): the corpus is
  without diacritics. The row is already `human` in `zip.origin`.
- Decision: **fix** - capitalised in the `.slt` and pinned in `ui-overrides.json` (`zip/romanian`,
  `_feature_121`), so a later merge keeps it.

## R9 - Checksum Save write errors (118 R7)

- `CCalculateDialog::SaveHashes` (`checksum/dialogs.cpp`): `fprintf` into a `_wfopen` stream; since
  118 `ferror` / `fclose` decide only whether the list counts as saved - nothing is said. A small
  list fails only at `fclose` (the buffered tail). The CRT keeps the failing `WriteFile`'s code in
  `_doserrno`. Existing strings: `IDS_ERRORCREATINGFILE` "Error creating file." (used for the
  open), `IDS_WRITEERROR` "Write error" (a title).
- Decision: **fix** - `Error(..., IDS_SAVE_TITLE, IDS_ERRORCREATINGFILE)` with the system's reason
  (`_doserrno` reset after the open, so an older code is never shown). The truncated file stays (as
  before; deleting it was not asked for).

## R10 - FTP small leftovers (116 research 5)

- (a) `fs2.cpp` `ChangePath` and `fs5.cpp` (upload target) copy the typed user part into
  `newUserPart[FTP_USERPART_SIZE + 1]` with `lstrcpyn(..., 610)`, split it, and copy the user name
  (`USER_MAX_SIZE` 101), the host (`HOST_MAX_SIZE` 201) and - in `SetConnectionParameters` - the
  password (`PASSWORD_MAX_SIZE` 301) with `lstrcpyn`: each is **cut silently**, inside a UTF-8
  character too. A cut password fails the login; a cut user name or host is ANOTHER account or
  server and the password goes there; a cut user part can end inside the password. The plug-in has
  `IDS_TOOLONGPATH` "Unable to finish operation because of too long path." (the user part is part of
  the path). Decision: **fix** - refused before anything is set (`SalFtpTypedLoginTooLong`,
  `salftpsecret.h`). A server path that makes the user part longer than 609 bytes is refused too
  (it was cut; the stored path is cut at `FTP_MAX_PATH` anyway - recorded).
- (b) `StartControlConnection` (`ctrlcon1.cpp`): one exit (`return ret`); `proxySendCmdBuf`
  (`PASS <password>`; later commands overwrite only its start) and the stack `CProxyScriptParams`
  (copies of password, account, proxy password; plain struct) are not wiped. Decision: **fix**
  (`SecureZeroMemory` of both before the return, the 116 worker pattern).
- (c) `ctrlcon1.cpp`: the wait-window text copies the log form of the command into
  `tmpCmdBuf[FTPCOMMAND_MAX_SIZE]` with `lstrcpyn` (cut inside a character possible for a long user
  name); `connectingToAs[200]` takes the host (200) and the user (100) through `_snprintf_s`
  `_TRUNCATE`; the worker's log copy (`operats2.cpp`) `lstrcpyn`s into the caller's 351 bytes.
  Decision: **fix** - `SplU8CopyTrunc` (cut at a whole character, `splunicode.h`) for the two
  copies, `connectingToAs` sized for the text + any host and user.
- Not taken: a custom proxy-script line over 1,000 bytes cut without CRLF (116 record; the
  built-in scripts cannot reach it) - unchanged.

## R11 - windows that still block an installer update (118 R6)

- RegEdit: `CFindDialog` (own thread, `WindowQueue`); `SearchInProgress`; `WM_CLOSE` while searching
  stops the search and closes when it finishes. `Release()`: `WindowQueue.CloseAllWindows(force)`.
  Never declared: the core declines an update for it. The core's own Find window closes for an
  update while it does not search (080 D5).
- FTP: `CWelcomeMsgDlg` (welcome message, server reply, raw listing; read-only edit, *Save As* for a
  listing) on the main thread in `ModelessDlgs`; `CLogsDlg` on its own thread (read-only edit, a
  combo, Save / Save All). `Release()` (unattended: refuses while an FTP operation exists, else
  `ReleaseFS`) destroys the modeless dialogs and closes the Logs window (`CloseLogsDlg`). Neither
  holds anything to lose; their Save dialogs are windows of their own (undeclared, decline).
- FTP and RegEdit refuse to load in a core below 107 - no version guard needed.
- Decision: **fix** - RegEdit Find declared at `WM_INITDIALOG`, withdrawn at the start of a search,
  declared again when it finishes; FTP Logs and the welcome/reply window declared at
  `WM_INITDIALOG`.

## R12 - plug-in Save dialogs open in another program's folder (found by 117's GUI run)

- Added by the coordinator during the work. 117's probe saw Checksum's Save dialog open in
  `C:\Program Files\Notepad++` although the plug-in passes the panel folder as `lpstrInitialDir`
  and a bare proposed name ("rt") as `lpstrFile`. Windows documents that it may prefer a remembered
  folder over `lpstrInitialDir` (Windows 7+), while a path in `lpstrFile` always decides.
- The same pattern (bare name + initial folder): Checksum `CCalculateDialog::GetSaveFileName`
  (own W dialog), PictView `SaveAsDialogU8` (own W dialog with the hook), and the shared
  `SplGetFileNameU8` - FTP's callers pass a folder (`ctrlcon2.cpp`, `dialogs2.cpp`, `dialogs3.cpp`
  x2, `dialogs4.cpp`); the Renamer and the Database Viewer pass none (unchanged by the fix).
  Not examined further: the disabled mmviewer (`SafeGet*FileName`), the core's own dialogs.
- First decision: put the folder into `lpstrFile` (`NameIntoInitialDir`). **Measured afterwards
  (GUI run, fix-log "Item 12") and reverted**: it did not help - see the fix-log for the rule
  Windows really applies (`ComDlg32\FirstFolder` per program path).

## Not taken (large, as instructed)

Print preview empty since 006, the disk-cache structural items, the B-2 systemic work - untouched.
