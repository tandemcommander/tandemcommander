# PE Viewer - items of feature 131

Source of the items: `specs/130-plugin-mixed-templates/triage/peviewer.md`, section 4.
Changed files: `src/plugins/peviewer/pefile.cpp`, `src/plugins/peviewer/peviewer.cpp`.

**Nothing here was compiled in the plug-in's project and nothing was run in the program** (the
brief forbids both). Run outside the repository: `pe_ls.cpp`
(`specs/131-plugin-defect-batch/probe/pictview-diskmap-peviewer/`), built with `cl /MD /J`
like the plug-in (`plugin_base.props`: `/J`, `plugin_release.props`: `MultiThreadedDLL`). The
first build of the plug-in is owed.

## 6. `pefile.cpp:1819`, `2317`, `2499` - names printed with a narrow `%ls`

**FIXED** (the names are written whole, in the encoding of the rest of the dump). One limit
stays and is the same as for the values next to them: a letter the system code page does not
have is written as `?` (or its best-fit look-alike) - see "The complete solution" below.

### What `fprintf(file, "%ls")` really does (measured)

The plug-in's situation: the dump goes through `CFileStream::fprintf` -> `vfprintf`
(`pefile.h:101-107`) into a text-mode stream opened with `_wfopen(name, L"w")`
(`peviewer.cpp:412`); nobody in the process calls `setlocale` (searched `src/` - only
non-Windows code of 7-Zip has it), and the plug-in and the core share the DLL runtime, so the
locale is "C". `pe_ls.cpp` reproduces exactly that (it prints `locale: C, ACP: 1250`):

| Insert | Return, `errno` | Bytes in the file |
|---|---|---|
| `CompanyName` | 15, 0 | `    CompanyName` |
| `Société` | 11, 0 | `Soci<E9>t<E9>` - the Latin-1 byte of each letter |
| `Naïve©Ø` | 11, 0 | `Na<EF>ve<A9><D8>` - on code page 1250 the reader shows `ď`, `©`, `Ř`: **other letters** |
| `Názevřetězce` (Czech) | **-1, 42 (`EILSEQ`)**, `ferror` 0 | `    N<E1>zev` - the output of the call ends before the first letter above U+00FF |
| three kanji | -1, 42 | `    ` - nothing of the name |
| `"  %-*s%ls\n"` with `v4.0-ř-tail` | -1, 42 | `  Runtime Version:               v4.0-` - the rest **and the line end** are lost |
| `"    %ls\n"` with `KnihovnaČ, Version=...`, then the next reference | -1, 42; then 34 | `    Knihovna    NextAssembly, Version=1.0.0.0` - one line |

So the note of feature 130 was right in every point, now measured for `vfprintf` on a stream
too: what was already converted is written, the call stops at the letter, later calls work.

### Who reads the dump, and in what encoding

`peviewer.cpp` hands the temporary file to the core's internal viewer
(`ViewFileInPluginViewer(NULL, ...)`, `Mode = 0` = text). The viewer (`src/viewer2.cpp:75-116`,
`1043-1072`) looks at the first 10,000 bytes (`RECOGNIZE_FILE_TYPE_BUFFER_LEN`,
`src/viewer.h:15`): a UTF-8 BOM, or valid UTF-8 with at least one multi-byte character,
switches it to UTF-8; otherwise the file is "legacy" text shown through the system code page
(possibly through a conversion table chosen by the code-page auto-select). The dump has no
BOM and starts with thousands of ASCII bytes (headers, imports, exports; the version resource
comes later), so **the reader takes it as code-page text**, and the rest of the dump is written
so: the translated `IDS_HIDDEN_SECTIONS` (`LoadStr`), the version-resource values
(`W2A` = `WideCharToMultiByte(CP_ACP)`, `pefile.cpp:1735-1747`), resource names
(`dump_res.cpp:13`). UTF-8 written into the middle of such a file would be shown as two or
three wrong letters per character - so `salwideinserts.h` (which produces UTF-8) is **not**
the right tool here, although the plug-in could include it (`..\..\..\common\...` by a relative
path; the project's include directories are only `..\..\shared`).

### How a user gets there

F3 (PE Viewer as the viewer) on an EXE/DLL whose version resource has a `StringFileInfo`
**key** with a letter outside ASCII (a custom key such as `Popis`, `Název produktu`; the
standard keys are ASCII), or on a .NET assembly that references an assembly whose name has
such a letter (`pefile.cpp:2499`), with the version-resource / CLR-metadata parts of the dump
enabled in the plug-in's configuration (their names in the dialog were not looked up). Before:

- key: cut at the first letter above U+00FF, or with wrong letters (U+0080..U+00FF on a code
  page other than 1252); the line then reads `    N<E1>zev:   value`;
- assembly reference / runtime version: the rest of the name and the line end are missing, the
  next line is glued to it.

Nothing is lost on disk - the dump is a temporary file for viewing.

### The fix

`pefile.cpp`: the three inserts are converted with the file's own `W2A` (the conversion the
value on the same line already uses) and printed with `%s`:
`fprintf("    %s", (const char*)W2A(szKey))`, `"  %-*s%s\n"` with `W2A(wzVersion)`,
`"    %s\n"` with `W2A(pszName)`. No `%ls` is left in the plug-in's narrow printf calls (the
remaining one, `pefile.cpp` `StringCchPrintfW(..., L"%ls, Version=...")`, is a wide call -
correct). Measured with the same conversion in `pe_ls.cpp`: `N<E1>zev<F8>et<EC>zce:   value`
(the right code-page-1250 bytes), `Knihovna<C8>, Version=1.0.0.0` and the next reference on its
own line; kanji on code page 1250: `???`; `Naïve©Ø` on 1250: `Naive<A9>O`
(best fit - `W2A` converts with flags 0, as for the values).

### How to test

- Probe row (needs a test file): a small DLL with a version resource holding
  `VALUE "Název řetězce", "hodnota"` and, for the control, `VALUE "CompanyName", "X"`
  (`rc` + `link /noentry /dll`); Czech system; F3. Expected line:
  `    Název řetězce:              hodnota`. Before: `    Název:   ...` (cut after `v`).
  English-only keys: identical before and after.
- .NET row: an assembly referencing `KnihovnaČ.dll`; expected two reference lines; before one.
  Harder to make (needs `csc`); the conversion is the same code as the first row.
- Pure rule to check if the dump ever gets a unit seam: "a wide name of the version resource is
  written through the code page, whole" - cases: ASCII; U+00E9 on 1250/1252 (one byte `E9`);
  U+0159 on 1250 (`F8`); a letter outside the code page (`?`, the line still complete, the
  line end present).

### The complete solution (not done - a decision for the maintainer)

To show letters **outside** the code page exactly (a Japanese `FileDescription` on a Czech
system - note 2 of the triage - and such keys and assembly names), the whole dump has to be
UTF-8 **with a BOM** (without it the viewer's 10,000-byte sample is plain ASCII and the file
stays "legacy"). That means: write `EF BB BF` first in `DumpFileInfo`; convert every chunk
`CFileStream::fprintf` formats from the code page to UTF-8 (one place - all 153 output calls go
through it; raw bytes from the viewed file, e.g. odd section or import names, would be read as
code-page text as today), and give the wide texts (`W2A` users, `dump_res.cpp` `GetName`, the
three inserts) a direct wide -> UTF-8 route. About 50 lines, but it changes the format of the
whole dump (what "Save As" from the viewer writes, the viewer's coding shown in its title) and
cannot be judged without building and looking - so it is described, not done.

### What I am not sure about

- The padding after the key (`pefile.cpp:1823-1829`) counts UTF-16 units (`cchKey`); with a
  double-byte code page a key takes more bytes/cells than units, so the values are not aligned
  for such keys (cosmetic, before and after).
- Best fit in `W2A` (`Ø` -> `O` on 1250) is a display choice already made for the values; I
  kept the keys consistent with it.
- If some other module in the process ever calls `setlocale(LC_ALL, "")`, the old `%ls` would
  have behaved differently (code-page conversion, still stopping at a letter outside it); the
  new code does not depend on the locale.

## Other notes of the triage

- **Note 2** (`pefile.cpp:1830`, `1735-1746`, `dump_res.cpp:13`: values and resource names go
  through `CP_ACP`, a letter outside the code page becomes `?`): **LEFT** - not a defect of the
  code-page dump; it is exactly what "The complete solution" above would remove.
  Seen there: `dump_res.cpp:13-14` `GetName` - when `WideCharToMultiByte` fails (a name longer
  than the 1000-byte buffer) `len` is 0 and the name is printed empty; display only.
- **Note 3** (`peviewer.cpp:432-435`, the core cuts the caption at `MAX_PATH - 1` bytes):
  **NEEDS A CHANGE OUTSIDE MY DIRECTORIES** (`src/viewer3.cpp`); display only, the core trims at
  a whole character. Not touched.
- **Note 4** (`peviewer.cpp:412-414`, the stream is not checked): **FIXED**. Real: when the
  temporary file made by `SalGetTempFileName` cannot be opened for writing (an antivirus or
  another program holding it, a full or read-only TEMP right after the creation) `_wfopen`
  returns NULL and `DumpFileInfo` -> `vfprintf(NULL, ...)` and `fclose(NULL)` follow - the C
  runtime's invalid-parameter handler ends the program. Also, when the conversion of the name
  failed (low memory), the UTF-8 name went to the `A` function `_tfopen`. Now: a NULL stream ->
  the temporary file is deleted, the existing message `IDS_ERR_TMP` ("Creation of temporary
  file has failed.") is shown, the viewed file is unmapped, `ViewFile` returns TRUE (as its
  other `IDS_ERR_TMP` branch does); no `A` call. Probe row: hard to drive on purpose (a file
  lock between two calls); by reading only. Not sure: what the handler does in the shipped
  build was not run - the documented default is termination.
