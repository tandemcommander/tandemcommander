# Triage: checksum (feature 130)

> **Correction after the triage (2026-10-13, the maintainer's session):** the core's progress
> dialog now sets its title wide from UTF-8 text (`src/zip.cpp`, `CZIPUnpackProgress`,
> `WM_INITDIALOG`; a text that is not valid UTF-8 is read as code page, as before). Where this
> record calls that title "code page only", or describes a second, wide title set by the
> plug-in, it describes the state before that change: the plug-in composes the title as UTF-8
> (`LoadStrU8`) and passes it to `OpenProgressDialog`.


Read: every `LoadStr(` use in `checksum.cpp`, `dialogs.cpp`, `misc.cpp` (56 uses). Not built, not run.

## 1. Encoding of the names where they meet the texts

- UTF-8. Panel names and paths come from the core (interface 104); the name picked in the Save As
  dialog is converted from UTF-16 with `SplWToU8` (`dialogs.cpp:1127`), the list file of Verify is
  `sourcePath` + `fd->Name` from the panel (`dialogs.cpp:2473-2474`), files are opened through
  `SplU8ToWExtAlloc` + `CreateFileW` (`misc.cpp:103`).
- Windows error texts in this plug-in come from `FormatMessage` (A) - **code page**, not from
  `GetErrorText` (`misc.cpp:56`, `86`, `115`).

## 2. Compositions

Sinks verified in the core: `SalMessageBox` (UTF-8 or code page); `DialogError` - file name through
`CStaticText::SetText` (UTF-8, else code page, `src/gui.cpp:626-629`), error text through
`SalSetWindowTextU8` (UTF-8, else code page, `src/dialogs.cpp:1597`, `src/common/winlib.cpp:1111`),
title through `SetWindowText` A (code page only, `src/dialogs.cpp:1586`).

| Site | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `dialogs.cpp:1129` | `IDS_SAVE_OVERWRITE` | `name` UTF-8 | `SalMessageBox` | **FIXED** - `LoadStrU8`, tail trim |
| `misc.cpp:21-36` `Error()` | any (`error` argument) | variable arguments: a UTF-8 file name at `dialogs.cpp:1686`, `1725` (`IDS_ERROROPENING2`), none elsewhere; + `FormatMessage` A text (code page) | `SalMessageBox` | **FIXED** - template `LoadStrU8`, bounded `_vsnprintf_s`, the Windows text converted with `SplLegacyToU8`; all eleven callers (`dialogs.cpp:1163`, `1234`, `1686`, `1697`, `1716`, `1725`, `1804`, `1852`, `1860`, `1931`, `1939`) now get an all-UTF-8 text |
| `misc.cpp:112-116` `SafeOpenCreateFile` | `IDS_ERROROPENING` | + `": "` + `FormatMessage` A text - all code page; the file name is a separate argument | `DialogError` error text | RIGHT AS IT IS |
| `misc.cpp:56-59`, `86-89` | (title only) | `FormatMessage` A text alone, name separate | `DialogError` | RIGHT AS IT IS |
| `dialogs.cpp:681` | `IDS_ERRORREADINGDIR` | template alone, path separate | `DialogError` | RIGHT AS IT IS |
| `dialogs.cpp:1062` | `idSaveAsFilter` x n | resource texts only | `ResStrToW` -> `GetSaveFileNameW` | RIGHT AS IT IS |
| `dialogs.cpp:2093` | `IDS_RESULT` | three numbers | `SetDlgItemText` A | RIGHT AS IT IS |
| `checksum.cpp:152-157` About | `"%s " VERSINFO_VERSION ... VERSINFO_COPYRIGHT ... "%s"` | two `LoadStr` texts + literals (the `©` of the literal is a code-page byte: the projects are not compiled with `/utf-8`) | `SalMessageBox` | RIGHT AS IT IS |

All other `LoadStr` uses are a resource text alone (captions, column headers, list cells, menu items,
comparisons with a list cell).

## 3. How to reach the FIXED sites

- **`dialogs.cpp:1129` (easiest)**: Czech/German UI, select a file, Plugins > Checksum > Calculate,
  wait, *Save...*, choose the name of an existing file with accented letters (e.g.
  `žluťoučký kůň.md5`), Save: the question "overwrite?" names the file.
- **`misc.cpp` `Error()` with a name (`dialogs.cpp:1686`, easy)**: focus a `.md5` / `.sfv` file with
  an accented name that cannot be opened for reading (held by another program without read sharing,
  or no read permission), Plugins > Checksum > Verify: the box reads the `IDS_ERROROPENING2` sentence
  with the name + the Windows reason. Before the fix the name was garbled whenever the translated
  template or the Windows reason had an accented letter. (`dialogs.cpp:1725` is the same sentence
  after a failed `GetFileSize` - not reachable on purpose.)
- `Error()` without a name (`dialogs.cpp:1163`/`1234`): Save the checksums to a read-only place
  (the Windows reason after the template; it was all code page and right before, UTF-8 now).

## 4. Other defects seen (not fixed)

- `misc.cpp:56`, `86`, `115`: `FormatMessage` A for the reason shown next to a UTF-8 name - right on
  the screen (the sink falls back to the code page for that control), but characters outside the code
  page are lost; `GetErrorText` would be the UTF-8 source.
- `misc.cpp:112-116`: `strcpy` + `strcat` + `FormatMessage` into `error[1024]` - no overrun in
  practice (template is short), not bounded formally.
- `dialogs.cpp:1126`: `name[3 * MAX_PATH]` for the picked name - `SplWToU8` fails for a longer one and
  the question is shown with an empty name (the file dialog's buffer is `2 * MAX_PATH` units, so at
  most 1,560 bytes can be needed against 780).
