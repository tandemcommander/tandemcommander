# Triage: uniso (feature 130)

Read: every `LoadStr(` use in `uniso.cpp`, `isoimage.cpp`, `iso9660.cpp`, `udf.cpp`, `hfs.cpp`,
`rawfs.cpp`, `xdvdfs.cpp`, `file.cpp`, `viewer.cpp` (59 uses) and every caller of the helpers
`Error(int, ...)`, `Error(msg, err)`, `Warning`, `SysError`. Not built, not run.

## 1. Encoding of the names where they meet the texts

- Names of items in an image are **UTF-8** at listing: Joliet / UDF / HFS+ names are converted from
  UTF-16 (`iso9660.cpp:269`, `udf.cpp:156`, `hfs.cpp:274`, `314`); the plain ISO9660 / XDVDFS byte
  names are kept when they are valid UTF-8, else converted from the code page (`EnsureU8Name`,
  `uniso.cpp:140`, called at `iso9660.cpp:534`, `573`, `xdvdfs.cpp:229`). The messages use
  `fileData->Name` (the core's `CFileData`, the same UTF-8 name).
- The image path comes from the core: UTF-8 (`isoimage.cpp:830` opens it with `CreateFileU8`).
- `SalamanderGeneral->GetErrorText()` is UTF-8 (`src/zip.cpp:1589`, `src/salamdr2.cpp:193`);
  `file.cpp:40`, `55` use `FormatMessage` A (code page).

## 2. Compositions

Sinks verified in the core: `ShowMessageBox` / `SalMessageBox`; `DialogError` (see `checksum.md`);
the viewer's caption: UTF-8 when valid, else code page, cut at 259 bytes with a tail trim
(`src/viewer3.cpp:39-107`).

| Site | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `uniso.cpp:265-277` `Error(msg, err)` | `"%s\n\n%s"` | `msg` + `GetErrorText` (UTF-8) | `ShowMessageBox` | **FIXED** - `msg` is UTF-8 at every caller (below), `const char*`, bounded, tail trim |
| `hfs.cpp:584`, `589`; `iso9660.cpp:723`, `728`; `rawfs.cpp:195`, `200`; `udf.cpp:1223`, `1228`; `xdvdfs.cpp:409`, `414`; `isoimage.cpp:111`, `1510` | `IDS_CANT_SET_ATTRS` / `IDS_CANT_DELETE_TEMP_FILE` | passed as `msg` to the helper above | | **FIXED** - `LoadStrU8` (12 calls) |
| `isoimage.cpp:837` -> `851` | `IDS_CANT_OPEN_FILE` | `fileName` UTF-8, then `msg` of the helper above | | **FIXED** - `LoadStrU8` (the cut and its tail trim were there, feature 097) |
| `uniso.cpp:246-262` `Error(resID, quiet, ...)` | any | a UTF-8 item name at `hfs.cpp:489` (`IDS_ERR_HFS_FILE_FRAGMENTED`), `hfs.cpp:524` (`IDS_ERR_HFS_SEEK_BLOCK_EXTR`), `udf.cpp:1068` (`IDS_UDF_ICB_AND_FILESIZE_MISMATCH`); numbers or nothing at all other callers (about 150, all read) | `ShowMessageBox` | **FIXED** - `LoadStrU8`, bounded `_vsnprintf_s`, tail trim |
| `uniso.cpp:953` | `"%s - %s"` + `IDS_PLUGINNAME` | `name` UTF-8 path | `ViewFileInPluginViewer` caption | **FIXED** - `LoadStrU8`, tail trim (the plug-in's name is ASCII in English; right by accident before) |
| `uniso.cpp:230-243` `Warning()` | `IDS_CCD_MISSING` | the one caller (`img.cpp:326`) passes no argument | `ShowMessageBox` | RIGHT AS IT IS |
| `uniso.cpp:279-297` `SysError()` | any | + `FormatMessage` A | `ShowMessageBox` | RIGHT AS IT IS - no caller in the plug-in (unreachable) |
| `iso9660.cpp:659`, `rawfs.cpp:136`, `udf.cpp:1161`, `xdvdfs.cpp:346` | `IDS_ERROR_READING_SECTOR` | a number; the name is a separate argument | `DialogError` error text | RIGHT AS IT IS |
| `file.cpp:40-43`, `55-58` | (title only) | `FormatMessage` A text alone; name separate | `DialogError` | RIGHT AS IT IS |
| `viewer.cpp:148`, `166` | `IDS_INFO_LABEL_LABEL`, `IDS_INFO_TRACK_TYPE_SIZE_LABEL` | the volume label: UTF-8 for UDF (`udfiso.cpp:134`, `EnsureU8Name` at `udfiso.cpp:100`, `145`), other file systems not traced | `fprintf` into a temporary file that the core's viewer shows | RECORDED - a text written to a file; the reader (the viewer's encoding detection) was not proved. With a code-page template and a UTF-8 label the file is neither |
| `viewer.cpp:149`, `161`, `162` | `IDS_INFO_CNT_SESSIONS` ... | numbers | the same file | RIGHT AS IT IS |
| `uniso.cpp` About | name, description, literals | all code page | `SalMessageBox` | RIGHT AS IT IS |

## 3. How to reach the FIXED sites

- **`isoimage.cpp:837` (easiest)**: Czech UI (`"Nelze otevřít soubor '%s'."`), an `.iso` with an
  accented name that cannot be opened for reading (held open by another program without sharing, or
  no read permission), Enter on it in the panel: the box reads the sentence with the name, an empty
  line and the Windows reason. Before: name and reason garbled. (A missing file shows nothing:
  `ERROR_FILE_NOT_FOUND` is not reported, `uniso.cpp:268`.)
- **`Error(LoadStrU8(IDS_CANT_SET_ATTRS), err)` (medium)**: extract a file from an image into a
  folder where setting attributes fails (e.g. a share that refuses them): template + Windows reason;
  before the fix the reason (UTF-8) was garbled whenever the template had an accented letter.
- `uniso.cpp:953`: View (F3) on an image with an accented name - the viewer's title
  `<path> - UnISO`; identical before and after unless a translation changes the plug-in's name.
- `hfs.cpp:489`, `524`, `udf.cpp:1068`: need a damaged HFS+ / UDF image - not reachable on purpose.

## 4. Other defects seen (not fixed)

- `viewer.cpp:148-166` (and the literal `fprintf` lines of `iso9660.cpp:745-769`, `udf.cpp:1251-1259`):
  the image information file mixes code-page resource texts with volume identifiers of other
  encodings; the encoding the viewer assumes for it is not fixed anywhere.
- `file.cpp:40`, `55`: `FormatMessage` A for the reason (code page; characters outside it are lost).
- `uniso.cpp:238`, `287`: `vsprintf` into `buf[1024]`, unbounded (`Warning`, the unused `SysError`).
- `isoimage.cpp:833`: `errStr[MAX_PATH]` - the message with a long image path is cut (at a whole
  character); only the message, not a name used as such.
- `iso9660.cpp:659` etc.: `sprintf` into `error[1024]` with a number - fine.
