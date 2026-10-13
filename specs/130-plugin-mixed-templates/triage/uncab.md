# Triage: uncab (feature 130)

> **Correction after the triage (2026-10-13, the maintainer's session):** the core's progress
> dialog now sets its title wide from UTF-8 text (`src/zip.cpp`, `CZIPUnpackProgress`,
> `WM_INITDIALOG`; a text that is not valid UTF-8 is read as code page, as before). Where this
> record calls that title "code page only", or describes a second, wide title set by the
> plug-in, it describes the state before that change: the plug-in composes the title as UTF-8
> (`LoadStrU8`) and passes it to `OpenProgressDialog`.

> The two rows `uncab.cpp:501` / `737` are therefore **FIXED**, not recorded.


Read: every `LoadStr(` use in `uncab.cpp` and `dialogs.cpp` (41 uses). Not built, not run.

## 1. Encoding of the names where they meet the texts

- Names inside a cabinet are stored in the code page or, with `_A_NAME_IS_UTF`, in UTF-8; they are
  converted to **UTF-8** at the FDI notification, before listing and before extraction:
  `CabNameToU8` (`uncab.cpp:209`), used at `fdintCOPY_FILE` (`uncab.cpp:1779`, then
  `UnpackFile(name, ...)`), for the next cabinet / disk names (`uncab.cpp:1720-1721`) and
  `CurrentCAB` (`uncab.cpp:1825`).
- The archive name and the target folder come from the core: UTF-8 (`uncab.cpp:492`
  `strcpy(CurrentCAB, arcName)`).
- Windows error texts come from `FormatMessage` (A): **code page**.

## 2. Compositions

Sinks verified in the core: `ShowMessageBox` -> `SalMessageBox` (`src/zip.cpp:472`);
`ProgressDialogAddText` -> `CZIPUnpackProgress::NewLine` -> `CStaticText::SetText` (UTF-8, else code
page; a line is cut at 299 bytes, `src/zip.cpp:248-290`); `OpenProgressDialog` title ->
`SetWindowText` A (**code page only**, `src/zip.cpp:400`); `DialogError` as in `checksum.md`.

| Site | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `uncab.cpp:1150` `UnpackFile` | `IDS_EXTRACTING` ("unpacking: ") | + `fileName` UTF-8 (was `lstrcpy` + `lstrcat`) | `ProgressDialogAddText` | **FIXED** - `LoadStrU8`, bounded, tail trim |
| `uncab.cpp:501`, `737` | `IDS_EXTRPROGTITLE` | `CurrentCAB` UTF-8 | `OpenProgressDialog` title = `SetWindowText` A in the core | RECORDED - the sink is code page only: the archive name in the progress title is garbled already today in every language (also English); a UTF-8 template would garble the template too. Needs the core's title set through `SalSetWindowTextU8` first, then `LoadStrU8` here (also an unbounded `sprintf` into `title[1024]`: `CurrentCAB` is at most `CB_MAX_CABINET_NAME`, so no overrun) |
| `uncab.cpp:827-834` `Error()` | any | no caller passes an argument (all are `Error(IDS_X)`); + `FormatMessage` A text - all code page | `ShowMessageBox` | RIGHT AS IT IS |
| `uncab.cpp:1385`, `1413`, `1445`, `1496`, `1558`, `1638` | `IDS_UNABLECREATE` / `...GETFIELPOS` / `...READ` / `...WRITE` / `...SEEK` | + `FormatMessage` A text - all code page; file name separate | `DialogError` error text | RIGHT AS IT IS |
| `uncab.cpp:1179` | `IDS_TOOLONGNAME` | alone; name separate | `DialogError` | RIGHT AS IT IS |
| `dialogs.cpp:160` | `IDS_NEXTVOLTEXT` | a number | `WM_SETTEXT` A | RIGHT AS IT IS |
| `dialogs.cpp:187-193` | `IDS_BROWSEFOLDERTEXT` | converted code page -> UTF-16, name UTF-8 -> UTF-16, composed wide | `SHBrowseForFolderW` | RIGHT AS IT IS (wide since feature 104) |
| `uncab.cpp` About | plug-in name, description, literals | all code page | `SalMessageBox` | RIGHT AS IT IS |

## 3. How to reach the FIXED site

- **`uncab.cpp:1150` (easy, but French only)**: of the eight shipped languages only French has an
  accented prefix (`translations/french/uncab.slt`, id 1018 `"décompression de: "`); in the others
  the prefix is ASCII and the line was right by accident. French UI, a `.cab` holding a file with an
  accented name, open it in the panel, F5 Copy the file out: the progress dialog's line reads
  `décompression de: <name>`. A large file keeps the dialog open long enough to capture.

## 4. Other defects seen (not fixed)

- `uncab.cpp:501`, `737`: see the table - the cabinet's name in the progress dialog's title goes
  through `SetWindowText` A in the core (`src/zip.cpp:400`): garbled for any non-ASCII archive name.
- `uncab.cpp:827`: `vsprintf` into `buf[1024]`, unbounded (no caller passes arguments today), and the
  function appends the text of whatever `GetLastError()` holds on entry, also a stale one.
- `uncab.cpp:1385` ...: the Windows reason is `FormatMessage` A (code page; characters outside it are
  lost) - `GetErrorText` would be the UTF-8 source, with a `LoadStrU8` prefix.
- Core: `CZIPUnpackProgress::NewLine` cuts a line at 299 bytes without a tail trim
  (`src/zip.cpp:268-286`); a long UTF-8 path cut inside a character makes `CStaticText` show the
  whole line through the code page.
