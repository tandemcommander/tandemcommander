# Fix log: feature 104 - the plug-ins use the names you give them

Branch `104-plugin-unicode-names`, from `103-same-file-delete-guard` (1fc230c9).
Decisions by the author (maintainer away): `spec.md` *Clarifications*. Research and the
measurements behind every decision: `research.md`. Pre-change build:
`build\tandemcommander\Debug_x64_pre104`. Not committed (the coordinator commits after review).

## T001 - what was measured

- **Premises of the backlog entry, checked one by one** (research 0): the eight counted
  subclasses carry no names (except ZIP's path label: display), the `DragQueryFile` calls only
  count, the `CreateFileA` fallbacks are unreachable or correct, `salpvenv.exe` is dormant (not
  built, not shipped, not reachable since 006). Four read-only inventories over the 20 enabled
  plug-ins plus the author's reading found the real sites elsewhere (research 2).
- **Primitive facts** (scratch `m104.cpp`, research 1): a code-page subclass (`SetWindowLongPtrA`)
  turns an Edit, a Static and a combo's Edit into code-page windows; text set into them with
  `SetWindowTextW` is stored **best fit** (`voil<U+00E0> <U+FF21><U+FF22>` -> `voila AB`),
  everything else `?`.
- **In the product, on the build before** (`probe/plugnames_result_pre104.txt`): every predicted
  defect reproduced - the Renamer renamed to `????.txt`/`voila.txt`/`AB.txt` (and asked to
  overwrite the existing decoy), its mask `<U+0416>*.txt` listed 2 files, its manual list showed
  `cl<U+0102><U+02C7>nek.txt`; the Database Viewer opened `voila.csv`; PictView's Copy To field
  came back empty (`?` path) and Save As asked to replace `voila.bmp`; the CAB plug-in took the
  next volumes from `...\voila\`; the ZIP password label showed mojibake; Undelete opened the
  decoy image `voila.ima` ("Unrecognized volume type").
- **Found on the way** (both builds, probe FINDING row): PictView *Save As* onto an existing
  file, "replace?" Yes: the file is **deleted**, then "Unable to save the image ... not supported
  by the built-in image engine" (WIC cannot encode since 006). Data loss - NEXT-WORK.

## T003 - shared code (`src/plugins/shared`)

| File | Change |
|---|---|
| `splfiledlg.h` (new, header-only, BOM + CRLF) | `SplGetFileNameU8(OPENFILENAMEA*, save)`: the A structure's *names* (`lpstrFile`, `lpstrInitialDir`, `lpstrFileTitle`) UTF-8, its *texts* (`lpstrFilter` list, `lpstrTitle`, `lpstrDefExt`) code page; runs `GetOpenFileNameW`/`GetSaveFileNameW` with a 32,768-unit buffer; the core's `FNERR_INVALIDFILENAME` retry; `nFilterIndex`, `Flags`, `nFileOffset`/`nFileExtension` (bytes of the UTF-8 result) returned; hooks, templates, multi-select and custom filters refused (none of the callers uses them; PictView's hooked dialog has its own W code). `SplBrowseForFolderU8` (W and code-page overloads): `SHBrowseForFolderW`, the core's old-style dialog, caption, comment, initial folder (`BFFM_SETSELECTIONW`), centring, `onlyNet`. `SplShowNameTooLong[W]`: the system's text for `ERROR_FILENAME_EXCED_RANGE` in a message box. A result that does not fit the caller's buffer is refused with that message. |
| `splunicode.h` | `SplShortenLongTextW` (pure: over 1,024 units -> first 32 + `...` + last 960, never splitting a surrogate pair) and `SplDrawWindowTextW` (a label's text read and drawn wide; the shortening keeps `DT_PATH_ELLIPSIS` cheap - 102's 28-s lesson) |
| `winliblt.{h,cpp}` `CTransferInfo::EditLine(char*)` | to the window: `SplU8ToWAlloc` (WTF-8; a lone surrogate showed as mojibake), and the buffer's size recorded on the field (`WinLibSetTextLimit`, review B1). From the window: `SplWToU8` (WTF-8); a text whose UTF-8 form does not fit is **refused** - empty buffer, `ErrorOn` (first failure keeps the focus), the system's "too long" message unless `Quiet`; `TooLongRefused` lets the following text fields of the same transfer still be read (otherwise a caller's local buffer stayed uninitialized). Before: a code-page re-read (`WM_GETTEXT` A = best fit, and code-page bytes in a UTF-8 buffer). ASCII text always fits (`EM_LIMITTEXT` = buffer - 1 units): unchanged. The A read remains only for lack of memory. Since review 1 the refusal normally happens earlier, in `ValidateData`, before anything is transferred (T010). |

saltests: `TestPluginFileDlg104` (offsets in bytes for UTF-8 names incl. 2-, 3- and 4-byte
characters, `.cvspass`, a dot in a folder, a trailing dot, slashes; the filter list conversion
incl. the double terminator and a code-page byte; the text shortening at 1,020-1,030 units and
across surrogate pairs) - 13,438 -> 13,487 checks, 0 failed.

## T004 - Renamer (`src/plugins/renamer`)

| Site | Before | Now |
|---|---|---|
| `rendlg.cpp` `Init` | `AttachToWindow` (code page) on the edits of Mask, New name, Search, Replace, manual list | `AttachToWindowKeepKind` (102's opt-in); the classes' own procedures look only at keys and selections, which are the same in both kinds |
| dialog thread loop (`CRenamerDialogThread::Body`), the two drains in `ReloadSourceFiles`/`LoadSubdir`, `CProgressDialog::EmptyMessageLoop` | `PeekMessageA`/`TranslateAcceleratorA`/`IsDialogMessageA`/`DispatchMessageA` | the W calls (093 rule); the accelerator table is VIRTKEY-only |
| `CRenamerDialog::IsMenuBarMessage` | - | a `WM_CHAR`/`WM_SYSCHAR` unit >= 0x80 is converted to the code-page byte the menu bar (core, plug-in interface) expects, exactly (`WC_NO_BEST_FIT_CHARS`); a unit the code page lacks is no menu-bar message |
| `ReloadSourceFiles` mask | `GetDlgItemText` A (`?` = wildcard) | UTF-16 read -> UTF-8; a mask that does not fit selects nothing |
| `HistoryComboBox` | `CB_ADDSTRING` A + `WM_SETTEXT` A of UTF-8 | W (code page for text that is not UTF-8); returns before touching the history when `EditLine` refused the text |
| manual list | filled `WM_SETTEXT` A; read `EM_GETLINE` A (`GetManualModeNewName`, preview) | `SetWindowTextU8`; `GetEditLineU8` (EM_GETLINE W -> UTF-8, the limit in bytes, -1 = the "too small buffer" error) |
| external editor / filter command (`rendlg4.cpp`) | `GetWindowText` A, `EM_REPLACESEL` A, the command line converted with `CP_ACP` | the list as UTF-8 (the bytes those tools received before - the edit held the UTF-8 bytes as code-page characters); the result decoded as UTF-8 (a BOM dropped), else code page (`ReplaceEditSelBytes`); the shell path read wide; the command line converted from UTF-8 (code page for text that is not); the error dialog's command set as UTF-8 |
| editor variables (`editor.cpp`) | `GetWindowsDirectory`/`GetSystemDirectory`/`GetShortPathName`/`GetModuleFileName` A into UTF-8 text | `GetSystemFolderU8` (W), `$(SalDir)` from `GetModuleFileNameW` (32,768 units) |
| Configuration, editor Browse | `GetDlgItemText` A + `SafeGetOpenFileName` | UTF-8 field, `SplGetFileNameU8` |

## T005/T006 - the other plug-ins

| Plug-in | Files | Change |
|---|---|---|
| Database Viewer | `renmain.cpp` | *Open*: `SplGetFileNameU8` |
| FTP | `ctrlcon2.cpp`, `dialogs2.cpp`, `dialogs3.cpp` (x2), `dialogs4.cpp`, `ftp4.cpp`, `dialogs8.cpp`, `precomp.h` | the five file dialogs through `SplGetFileNameU8` (their results went unconverted to the UTF-8 file helpers); `GetMyDocumentsPath` wide; `HistoryComboBox` and the Copy/Move target refuse a text that does not fit (message, field focused, history untouched) instead of a code-page re-read |
| PictView | `dialogs.cpp`, `saveas.cpp`, `renderer.h`, `pictview.cpp`, `precomp.h` | Copy To Browse: `SplBrowseForFolderU8` + the field wide (the core service returns code page); Save As: `GetSaveFileNameW` with the hook and the template (`SaveAsDialogU8`), the hook reads a code-page copy of the filter list (`SAVEAS_INFO::FilterA`; only `nFilterIndex`/`lCustData` are read from the W structure - same offsets), the documents folder wide, the "already exists"/"read-only" questions composed in one encoding (`FormatNameMessageU8`); `exif.dll` located and loaded wide |
| ZIP | `dialogs.cpp` | `TextControlProc` subclassed and painting wide (`SplDrawWindowTextW`), the Password and Low-disk labels set wide; the two change-disk Browse buttons through `SplGetFileNameU8` (were `U8ToDlgA` best fit + code-page dialog) |
| CAB | `dialogs.cpp`, `uncab.{h,cpp}` | next-volume dialog: names and folder set/read wide (`SetDlgItemTextU8OrAcp`, `GetDlgItemTextU8`), Browse `SplBrowseForFolderU8`, a folder over the cabinet path limit refused; the continued-file label subclass and painting wide; `U8ToAcp`/`AcpToU8` and the A browse callback removed |
| Undelete | `dialogs.cpp`, `fs2.cpp` | image field prefill/read wide, image Browse `SplGetFileNameU8`, temp folder Browse and the View temp-folder choice `SplBrowseForFolderU8`, restore target prefill/Browse/read wide (refused when too long) |
| Registry Editor | `finddlg2.cpp`, `editor.cpp`, `utils.cpp`, `dialogs.cpp`, `precomp.h` | Find thread loop wide; the external editor launched as the Renamer's (UTF-8 buffers, `GetShortPathNameU8`, `CreateProcessW`, the folder variables wide); the file-dialog helper refuses a result over `MAX_PATH` bytes (was best fit) and starts empty instead of switching to the code-page dialog; the Browse buttons no longer re-read the field through the code page |
| SFTP | `dialogs.cpp` | `GetDlgItemTextU8` returns -1 (empty) when the text does not fit; the Connect dialog refuses it with the message (was a code-page re-read) |

Disabled plug-ins: no source changed. The shared headers and `winliblt.cpp` are compiled into
some of them, but they are not built by the default build (research 3).

## T007 - probe `probe/plugnames_probe.ps1`

Hidden desktop; the registry exported, restored and SHA-256-verified after every run
(`1AB61430...F769`); fixtures under `%TEMP%\tc104_pn` removed; nothing left running.

**This build** (`probe/plugnames_result.txt`): **39 PASS / 0 FAIL / 6 NOT DRIVEN** (+ 1 INFO).
**Before** (`Debug_x64_pre104`, `probe/plugnames_result_pre104.txt`): **39 PASS / 0 FAIL / 6 NOT DRIVEN** (+ 1 INFO) - every
predicted defect seen (verdicts are "the defect is there").

| Row | This build | Before |
|---|---|---|
| ren-cyr / cjk / emo / lone NEW (typed or set) | exact name, history exact | `????.txt`, `???.txt`, `??ok.txt`, `lone?x.txt` - "Not valid filename." |
| ren-voila / fwab NEW | `voil<U+00E0>.txt`, `<U+FF21><U+FF22>.txt`; decoy untouched, no question | `voila.txt`, `AB.txt` - **"Confirm File Overwrite"** of the decoy (answered No) |
| ren-mask | 1 file | `?*.txt`: 2 files |
| ren-man cz / cjk | list shows the names exactly, renamed exactly | mojibake list, `????-2.txt` refused |
| ren-long (604 bytes into 520) | the system's "too long" message, nothing renamed | code-page re-read -> "Not valid filename." |
| dbv-open | `voil<U+00E0>.csv` | **`voila.csv` opened** |
| pv-copyto | field exact, copied into `voil<U+00E0>` | see the pre-104 result |
| pv-saveas | no question about the decoy; "Unable to save" | **"replace voila.bmp?"** (answered No) |
| pv-saveas FINDING | exist.bmp DELETED, save fails | the same |
| unc-next | field exact, "File not found." | field `...\voila\`, **extracted from the decoy folder's volumes** |
| zip-pwd | label exact, Unicode window | mojibake, code-page window |
| und-image PREFILL / IMAGE | exact / "The file specified was not found." | mojibake / **the decoy image opened** |

NOT DRIVEN, stated in the result: FTP file dialogs (no FTP server on the hidden desktop - the
same helper as dbv-open), ZIP change-disk Browse (needs removable media), Undelete restore and
temp-folder Browse (EFS files; the same helper as pv-copyto), regedt Find typing and external
editor, SFTP field overflow, an installation folder outside the code page.

Probe runs, honestly: the first runs failed on probe defects (the Renamer needs a selection;
the mask must be typed - WM_SETTEXT sends no change notification; `.img` files are entered as
disk images by uniso, so the Undelete fixture uses `.ima`; archives are entered with a posted
Enter and copied with the Copy command after idle; PictView asks about the alpha channel before
its save dialog; a Czech Windows says "too long" in Czech). None was a product failure.

## T008 - gates

- Debug x64 build exit 0, no compiler warning in the touched code (the C4267/C4005 lines of a
  full rebuild are in untouched files: tar, uniso, folders, ftp `fs2.cpp`/`parser2.cpp`,
  undelete `fs2.cpp:459`, dbviewer `dbflib.cpp`).
- Full Release build (`build.cmd full release`): exit 0, BUILD SUCCEEDED, 189 language modules,
  runtime-dependency check passed. It showed one warning in the touched code - C4267 in the
  editor launch ported into `regedt/editor.cpp` (regedt's `TBuffer::Reserve` takes an `int`,
  the renamer's a `size_t`); fixed with the casts regedt had, then `build.cmd release` and the
  Debug build again: exit 0, no warning line. (The probe and the regressions ran on the build
  before that cast and three clang-format hunks - no change in behaviour.)
- saltests **13,487 checks, 0 failed** (13,438 + 49 in `TestPluginFileDlg104`).
- `tools/check_encoding.py --strict` TOTAL 0 (the guard does not scan plug-ins).
- BOM / no BOM as at HEAD and CRLF only in every touched source file (checked byte by byte);
  the new `splfiledlg.h` BOM + CRLF. Three hunks reformatted with clang-format `--lines`; the
  remaining differences clang-format reports in touched files are pre-existing.
- Regression, this build (`probe/regress_*_104.txt`), hidden desktop, registry
  `1AB614304771DBE0` after every run:

| Probe | Result | Baseline |
|---|---|---|
| 102 `filecomp_probe -Expect fixed` | 94 PASS / 0 FAIL / 1 NOT DRIVEN (MISM: needs `-OtherFcremote`, the channel is untouched) | 95 / 0 |
| 103 `samefile_probe -Expect103` | 62 PASS / 0 FAIL | 62 / 0 |
| 099 `linkmove_probe` | 24 PASS / 0 FAIL | 24 / 0 |
| 093 `dialogs_probe` | 139 PASS / 0 LOSSY / 0 FAIL / 1 not driven | same (its Find-menu rows did not flake this time) |
| 094 `zip_gui_probe` (ZIP password dialog touched: its label) | AS EXPECTED 56, DIFFERENT 1 (X1, the self-extractor row that cannot be driven in a Debug tree) | same |
| 094 `sftp_gui_probe` (SFTP Connect dialog touched) | the bytes the server received identical to the 094 result in all 11 rows (paramiko 5.0.0 in a scratch venv; the `tandem-sftp` Docker container is not running here - no Docker on this machine - the 094 probe uses its own local SSH server) | same |


## T010 - independent review 1: REJECT (one BLOCKER), fixes

### B1 - a refused FTP field was stored as EMPTY (a saved password erased)

The reviewer drove it on both builds: a bookmark password of 60 x `č` (120 bytes; the buffer
holds 101). winliblt's `EditLine` refused it (message, field kept) but **emptied the caller's
buffer**, and the FTP Connect dialog's kill-focus handlers (`dialogs1.cpp`, host, initial path,
user, password) never check `ti.IsGood()`: the password handler stored "no password"
(`UpdateEncryptedPassword(NULL, 0)`), the host handler blanked the address; after Close + exit
the bookmark had `Save Password = 1` and no `PasswordS` (the build before stored code-page
bytes); Connect / Enter ran the same handler and connected with an empty password; a bookmark
already holding such a password lost it when the user only tabbed through.

Fix, at the root - **a refused text is refused before anything is stored**:
- winliblt records, per text field, the size of the buffer its text goes to: `EditLine` does it
  when it fills a field (`WinLibSetTextLimit`, a window property under an integer atom - no
  string-atom reference per call, freed with the window); code that fills a field another way
  calls `WinLibSetTextLimit` itself (the Renamer's and the FTP plug-in's history combos, the FTP
  Copy/Move target).
- `CDialog::ValidateData` and `CPropSheetPage::ValidateData` (and regedt's own
  `CDialogEx::ValidateData`) first look for a field whose text does not fit its recorded size as
  UTF-8 (`WinLibFindTooLongText`): **one** message (Windows' text), the field focused, return
  FALSE - nothing validated, nothing transferred, nothing stored.
- FTP Connect dialog: the kill-focus handlers take a field only when it fits
  (`WinLibTextFits`); a field that does not fit is left alone (the bookmark keeps its values, the
  field keeps the text, no message while the focus moves - the first click on Cancel is no
  longer swallowed); Connect and Close (after their own focus round trip) refuse it with the
  message and stay in the dialog - no connection with the old or an empty value. Cancel discards
  as always.
- `EditLine`'s own refusal (empty buffer, `ErrorOn`, message unless `Quiet`) stays as the
  backstop for a field that was never filled through `EditLine`.

Probe rows `ftp-b1` (registry fixture bookmark, local log server `probe/ftplog_server.py` that
logs the bytes of USER/PASS): OK40 (40 x `č`, 80 bytes) stored; LONGPWD and LONGUSER (60 x `č`)
refused on Close, after Cancel + exit the stored password (byte-identical blob) and user name are
unchanged; CONNECT refused, the server receives nothing. On the build before: LONGPWD/LONGUSER
stored the code-page form, CONNECT sent `PASS` with 60 code-page bytes (the log server: `PASS len=60 hex=e8e8...` - U+010D as the cp1250 byte 0xE8, twice, with the login-error retry).

### Audit of every `EditLine(char*)` that reads a field, enabled plug-ins

A refusal must never be stored as an empty value or acted upon. Classes: **P** = a winliblt (or
regedt `CDialogEx`) dialog / property page whose Validate/Transfer pair reads the field and whose
Transfer filled it through `EditLine` (size recorded) - the pre-check refuses before Validate,
nothing is transferred; **V** = read only in Validate into a local buffer (a refusal fails
Validate, Transfer never runs); **K** = read outside the dialog's OK path.

| Plug-in, file | Callers | Class / result |
|---|---|---|
| ftp `dialogs1.cpp` | Configuration General (anonymous password), Defaults (ASCII masks) | P |
| ftp `dialogs1.cpp` Connect | host, initial path, user, password on kill-focus | **K - fixed** (B1, above) |
| ftp `dialogs3.cpp` server type | autodetect condition, parsing rules (Validate, Transfer) | P |
| ftp `dialogs3.cpp:1358` server type, Cancel | the same two, only compared with the stored values ("discard changes?") | K - now `Quiet`; a refused text counts as a change (no message, no storage) |
| ftp `dialogs4.cpp` server-type column | ID, empty value | P |
| ftp `dialogs4.cpp` Copy/Move | target path (own wide read, not `EditLine`) | P - size recorded in its Transfer; its own refusal stays as backstop |
| ftp `dialogs7.cpp` the "solve error" dialogs | new target name / new attributes (Validate + Transfer), read-only path/name fields | P for the editable target name; the read-only path/name fields are **not** "fit by construction" (corrected by the re-review, S1 below): `operats1.cpp` cuts a disk path with `lstrcpyn(MAX_PATH)`, possibly inside a UTF-8 character, and a legacy code-page server name is shown through the code page - both can be longer as UTF-8 than their buffer; they are never read back and are skipped by the pre-check |
| ftp `dialogs8.cpp` | Send FTP command (history combo + secret edit), Connect Advanced (target path, init commands), rename dialog, enter-string dialog, login-error dialog (user, password, account, proxy user/password), proxy server dialog (name, host, user, password, script) | P (the history combo's size recorded in `HistoryComboBox`) |
| pictview `dialogs.cpp` | Rename (path), Copy To (5 lines), Configuration Tools/Advanced (numbers in text) | P |
| regedt `dialogs.cpp`, `finddlg2.cpp` | Configuration (command, arguments, folder), Export (file), Find (times) | P (`CDialogEx::ValidateData` got the same pre-check) |
| renamer `dialogs.cpp` | Configuration (command, arguments, folder), Define class, Command, Add counter (step) | P |
| renamer `rendlg.cpp` | mask, new name, search, replace: OK (IDOK, Validate CMD) | P (history combos' sizes recorded) |
| renamer `rendlg.cpp` `TransferForPreview` | the same, on every change | K - `Quiet`; the preview shows its "transfer error"; only `RenamerOptions` (the live options) are touched - what is saved (`LastOptions`) is set only after a successful OK |
| undelete `dialogs.cpp` | file name (restore), Configuration temp folder | P |
| undelete Connect (image), Restore target | own wide reads (not `EditLine`) | refused in place, the previous value kept (read into a local buffer first - review) |
| dbviewer `dialogs.cpp` CSV separator | one code-page byte | **not `EditLine` any more**: set and read as code-page text (it is a byte of the file's code page; `EditLine` would now refuse `§` in its 2-byte buffer - the build before produced the byte through the fallback) |
| filecomp, codeview, diskmap, folders, uniso, 7zip, checksum, peviewer, tar, portables | no `EditLine(char*)` read of a name, or numbers only | - |

The SFTP field reader (`GetDlgItemTextU8`, -1 when it does not fit): Connect (`ConnectReadFields`
refuses before `ConnectCommitToEntry` copies anything - neither Save nor Connect stores or
connects) and the rename-bookmark dialog (**NIT 4, fixed**: it closed with an empty name and did
nothing; now the message, the field focused, the dialog stays, the old name kept); the key-file
Browse only starts empty.

### NITs

- **NIT 1 (fixed)**: Renamer manual mode with fewer lines than files - `GetEditLineU8` returns
  -2 for a missing line; the preview shows an empty new name as before (it showed "buffer too
  small").
- **NIT 2 (fixed where it was noise)**: the FTP kill-focus message (which swallowed the first
  click) is gone; one OK shows one message (the pre-check stops at the first field); the
  Renamer's Validate no longer follows "too long" with "invalid mask" (the pre-check runs before
  Validate). What stays: a refusal inside a Transfer that has no recorded size (none known in
  the enabled plug-ins) shows the message during the transfer.
- **NIT 3 (recorded)**: `SplBrowseForFolderU8` has no `BFFM_SELCHANGED`/`BFFM_ENABLEOK` (the
  core's dialog disables OK for a selection without a file-system path; here such a pick returns
  FALSE without a message when `SHGetPathFromIDListW` fails) and does not resolve NetHood folder
  shortcuts.
- **NIT 5 (recorded)**: `ReplaceEditSelBytes` is all-or-nothing - one byte that is not UTF-8
  decodes the whole filter/editor output through the code page.

### Gates after the fixes

- Debug build exit 0, no warning in the touched code; saltests **13,487 / 0** (the review fixes
  add no pure helper); `check_encoding.py --strict` TOTAL 0; BOM/CRLF as at HEAD.
- Probe, this build (`probe/plugnames_result.txt`): **47 PASS / 0 FAIL / 6 NOT DRIVEN** (+ 1
  INFO) - the 39 rows before + 8 `ftp-b1` rows (4 + their END rows). Build before
  (`probe/plugnames_result_pre104.txt`): 47 PASS / 0 FAIL / 6 NOT DRIVEN, every row showing the
  old behaviour (`ftp-b1`: no refusal; the long password and user name stored in code-page form;
  Connect sent them).
- Regressions after the fixes (`probe/regress_filecomp_104.txt`, `regress_094zip_104.txt`,
  `regress_094sftp_104.txt`, overwritten): 102 filecomp 94 PASS / 0 FAIL / 1 NOT DRIVEN (MISM);
  094 ZIP AS EXPECTED 56, DIFFERENT 1 (X1, as in 094); 094 SFTP the server's bytes identical to the
  094 result in all 11 rows. Registry `1AB614304771DBE0` after every run.
- Full Release build (`build.cmd full release`): exit 0, BUILD SUCCEEDED, 189 language modules;
  the only warning in a touched file is the pre-existing C4267 at `undelete/fs2.cpp:460` (459 at
  HEAD; the line moved by the added include).

## T011 - re-review: ACCEPT, with one SHOULD-FIX and one NIT to apply

### S1 - the pre-check refused fields the user cannot edit (fixed)

`WinLibFindTooLongText` also checked read-only, disabled and hidden fields. The FTP "solve error"
dialogs (`dialogs7.cpp:206-217`) fill `ES_READONLY` fields through `EditLine` (`DiskPath` 260,
`FtpPath`/`FtpName` 301 bytes); `operats1.cpp` cuts the disk path with `lstrcpyn(MAX_PATH)`,
possibly inside a character, and a server name in a legacy code page is shown through the code
page - either can be longer as UTF-8 than the recorded size, and then every button (Overwrite,
Resume, Skip, ...) said "too long" and focused a field the user cannot change; only Cancel
worked. Fix, two parts:
- the pre-check skips read-only edits (`ES_READONLY`), disabled and invisible controls;
- `EditLine` records the size only when it filled the field with **UTF-8** text; a value that is
  not UTF-8 (a legacy code-page value, a path cut inside a character) gets no limit, so an
  unchanged value of that kind never blocks a dialog - also not in an *editable* field such as
  the solve-error dialog's target name (its Skip does not read the field). When such a field IS
  read back and does not fit, `EditLine`'s own refusal (in Validate: message, nothing stored)
  remains. Checked by code reading: the solve-error dialogs read back only `IDE_SCRD_TGTNAME`
  (editable, and only when the name is transferred); every other `IDE_SCRD_*`/`IDE_SSCD_*`/
  `IDE_SISE_*` field is filled in the `ttDataToWindow` branch only and is `ES_READONLY`
  (`lang.rc`). Not driven (an FTP error dialog with an over-long cut path needs a server
  operation failing at that moment).

### NIT 1 - a long password saved by 0.1.8 or earlier (fixed in code instead of a CHANGELOG hint)

A password that 0.1.8 saved in its code-page form and that is longer than 100 bytes as UTF-8
(more than ~50 accented letters) could no longer be used: the Connect dialog shows it through
the code page and refused it as "too long" on Connect and on Close. Instead of telling users to
re-enter it, the Connect dialog now refuses only a field **the user changed** (`EM_GETMODIFY`;
`CConnectDlg::ConnectFieldFits`, `TooLongCtrlID`): an unchanged value is left as stored and used
as before. Together with the "UTF-8 only" size record above, such a password is not
pre-checked either. Probe row `ftp-b1 LEGACY` (with `-OldExe` = the build before): the build
before stores 60 x `č` in code-page form, this build - the password field only tabbed through -
connects and the server receives `PASS` with the same 60 bytes 0xE8, no "too long". A user who
types a new over-long text is refused as before (LONGPWD, CONNECT).

### NITs 2-4 (recorded)

- Switching to another bookmark discards a typed over-long text without a message (the fields
  are filled anew; nothing was stored).
- The global atom `TandemWinLibTextLimit` is never deleted (one per process and plug-in;
  harmless).
- One full probe run had a `dbv-open` END timeout; four re-runs passed - probe timing.

### Gates after the re-review fixes

- Debug build exit 0, no warning in a touched file; saltests **13,487 / 0**; `check_encoding.py
  --strict` TOTAL 0; BOM/CRLF as at HEAD.
- Probe, this build, with `-OldExe build\tandemcommander\Debug_x64_pre104\tandemcommander.exe`
  (`probe/plugnames_result.txt`): **50 PASS / 0 FAIL / 6 NOT DRIVEN** (+ 1 INFO) - the 47 before
  + LEGACY and the END rows of its two instances. The pre-104 result file is the one of T010 (the
  build before has no LEGACY row: `-Expect before` skips it).
- Full Release build (`build.cmd full release`): exit 0, BUILD SUCCEEDED, 189 language modules,
  no warning in a touched file.
- Registry `1AB614304771DBE0` after every run; nothing left running.

## T012 - targeted check of the S1 / NIT 1 delta: ACCEPT

The reviewer checked every door by which an unmodified field could be stored or used empty or
cut (bookmark switch - `WM_SETTEXT` clears the modify flag; a field modified and restored -
refused, nothing stored; the *Save password* toggle; the host combo's child edit; Enter in a
field; an unmodified legacy password - the stored bytes are used; `EditLine`'s backstop on a
non-UTF-8 value - only local buffers, the history combo's local buffer and the login-error
dialog's proxy-script parameters, used only on IDOK, which the refusal blocks) - none. Probe
rows `ftp-b1` with `-OldExe`: 11 PASS / 0 FAIL (LEGACY: the server receives `PASS` with the same
60 x 0xE8 as the build before). Residual NIT, recorded: in the login-error dialog
(`CLoginErrorDlg`, shown after a failed login) *Retry* with an untouched legacy long code-page
password is refused by the backstop ("too long", the dialog stays); Connect still works, so
only a retry after a transient error ("too many users") is affected.

## Recorded, not changed

- **PictView Save As deletes an existing file and then fails** (every release since 006) -
  NEXT-WORK, first in the new list.
- Undelete `Replace0xE5` on UTF-8 names (a FAT relic): a name whose first byte is 0xE5 (CJK
  U+5000-U+5FFF) is listed with `$` and restored under a garbled name; the volume layer's A
  mount-point functions and `GetVolumePathName` A on UTF-8 paths.
- FTP: the password fields' code-page subclass (`CPasswordEditLine`) and *Show password* read
  (094 left FTP passwords); the login-error dialog's *Retry* refuses an untouched legacy long
  password (T012). What happens now with a password (or user name, address, initial
  path) whose UTF-8 form exceeds the 101-byte buffer, e.g. 60 Czech letters: the field keeps the
  text, nothing is taken when it loses the focus, Connect and Close say "too long" and keep the
  dialog open, the stored value stays (probe rows ftp-b1). The build before stored and sent
  such a password as code-page bytes (60 bytes for 60 letters) - that form is no longer
  produced; widening the buffers is open. The OpenSSL DLL path (FTPS is not shipped).
- checksum: an ANSI list file with accented names reports them "missing" (list-file encoding).
- ZIP: the archive comment field (content, code page by format); every SFX route (unreachable:
  no SFX package shipped); `zip2sfx`, `sfxmake`, `selfextr` (not built/shipped).
- PictView *Regenerate thumbnail* (cannot work since 006) and the wallpaper registry value.
- diskmap's log window (A list view: path mojibake), lukas `utilbase.cpp` code-page system text.
- The folder picker does not resolve a NetHood folder shortcut to its target (the core's
  `ResolveNetHoodPath`); the plug-ins used to get that through `GetTargetDirectory`.
- winliblt's other `CWindow` attachments (`AttachToWindow`) stay code page; they are on list
  views, property-sheet frames and statics (research 2), plus FTP's password edits.

## CLAUDE.md entry

- 104-plugin-unicode-names: **the plug-ins use the names you give them** (NEXT-WORK item 5,
  sub-item 5, the 102 class in the other plug-ins). Measured first; the backlog's list was
  mostly wrong - the eight "code-page subclasses" carry no names (except ZIP's path label,
  display), the `DragQueryFile` A calls only count, the `CreateFileA` fallbacks are unreachable,
  `salpvenv.exe` is not built, shipped or reachable since 006. The real defects, all
  reproduced on the build before (`Debug_x64_pre104`): the **Renamer** attached winliblt's
  code-page `AttachToWindow` to its Mask / New name / Search / Replace edits and manual list
  and ran code-page loops - a new name `voilà.txt` became `voila.txt` (with "overwrite?" for the
  existing one), `Ж*.txt` became the wildcard `?*.txt` (other files selected); and the
  plug-in-facing **`SafeGetOpenFileName` / `SafeGetSaveFileName` / `GetTargetDirectory` are code
  page by contract** (best fit), so the Database Viewer opened `voila.csv`, PictView copied into
  `voila\` and its Save As offered to replace `voila.bmp`, the FTP save dialogs overwrote
  look-alikes and failed for every accented name, the CAB plug-in took the next volumes from
  `voila\`, Undelete opened `voila.ima`.
  - **Helpers** (`src/plugins/shared/splfiledlg.h`, header-only, no interface change):
    `SplGetFileNameU8` (an `OPENFILENAMEA` whose *names* are UTF-8 and *texts* code page, run
    as `Get{Open,Save}FileNameW`, the core's retry kept, offsets in bytes; no hooks) and
    `SplBrowseForFolderU8` (`SHBrowseForFolderW`); `SplShowNameTooLong` = Windows' own text for
    `ERROR_FILENAME_EXCED_RANGE` (no new string). **New plug-in code that asks for a file or
    folder MUST use them, never the core services.** `splunicode.h` `SplDrawWindowTextW` paints
    a path label wide (long text shortened first - 102's `DT_PATH_ELLIPSIS` lesson).
  - **winliblt `EditLine`**: WTF-8 both ways; a text whose UTF-8 form does not fit is
    **refused** - it was re-read through the code page (best fit). The core cuts at a whole
    character (093 D4); plug-in buffers are 260-byte names. **A refusal must never be stored as
    an empty value or acted upon** (review B1: the FTP Connect dialog stored an EMPTY password):
    `EditLine` records each field's buffer size (`WinLibSetTextLimit`) and
    `CDialog`/`CPropSheetPage::ValidateData` refuse a field that does not fit before Validate -
    one message, nothing transferred; code that reads a field outside that path checks
    `WinLibTextFits` (FTP Connect's kill-focus handlers). Audit of every caller in fix-log T010.
    The dbviewer CSV separator (one code-page byte) no longer goes through `EditLine`.
  - Renamer: `AttachToWindowKeepKind`, wide loops, the menu bar still fed code-page characters
    (plug-in-facing `IsMenuBarMessage`), mask/history/manual list/filter/editor UTF-8. PictView
    Save As: `GetSaveFileNameW` with its hook (the hook reads a code-page copy of the filter -
    only `nFilterIndex`/`lCustData` from the W struct). ZIP and CAB labels: Unicode subclass.
    Regedt Find loop wide, its editor launch ported from the Renamer. FTP/SFTP field readers
    refuse instead of re-reading. Disabled plug-ins listed, unchanged.
  - **Found, not fixed** (NEXT-WORK item 5, sub-item 5 queue): **PictView Save As onto an
    existing file deletes it, then fails** (WIC cannot encode, every release since 006 - data
    loss, first); Undelete's FAT `Replace0xE5` garbles CJK names on restore; FTP password
    fields keep a code-page subclass; checksum lists in the code page.
  - Probe `probe/plugnames_probe.ps1` (hidden desktop, decoys, a local FTP log server):
    50 PASS / 0 FAIL / 6 NOT DRIVEN (before: 47 rows showing the old behaviour). saltests
    13,438 -> 13,487. Regressions 093, 094 ZIP + SFTP, 099, 102, 103 as baseline. Review 1:
    REJECT (B1), fixed; re-review ACCEPT (S1: the pre-check skips read-only, disabled and
    hidden fields and only UTF-8 values get a size; NIT 1: an unchanged long password saved by
    0.1.8 keeps working). Records: `specs/104-plugin-unicode-names/fix-log.md`.
