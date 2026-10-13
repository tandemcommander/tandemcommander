# Triage: tar (feature 130)

Read: every `LoadStr(` and `LoadErr(` use in `tardll.cpp`, `fileio.cpp`, `untar.cpp`, `deb/deb.cpp`,
`rpm/rpmview.cpp`, `gzip/gunzip.cpp`, `bzip/bunzip.cpp` (135 uses). Not built, not run.

## 1. Encoding of the names where they meet the texts

- Names from TAR / CPIO headers and the gzip original name are raw bytes; they are made **UTF-8** at
  the format boundary: `ConvertNameToU8` (`tardll.cpp:144` - valid UTF-8 is kept, anything else is
  converted from the code page), called for `header.Name` at `untar.cpp:1049` and for the stream's
  stored name at `fileio.cpp:173`. The progress lines use `header.Name` after that.
- The archive path (`name`, `fileName`) comes from the core: UTF-8 (`tardll.cpp:486`, `fileio.cpp:31`
  open it with `CreateFileU8`).
- The Windows reason is always `SalamanderGeneral->GetErrorText()`: **UTF-8** (`src/zip.cpp:1589`).
  So every "resource text + reason" of this plug-in was a mixed sentence.

## 2. Compositions

Sinks verified in the core: `ShowMessageBox` -> `SalMessageBox`; `ProgressDialogAddText` ->
`CStaticText::SetText` (UTF-8, else code page); the viewer's caption (UTF-8 when valid, else code
page, `src/viewer3.cpp:39-107`).

| Site | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `tardll.cpp:88-96` `LoadErr()` | any | + `GetErrorText` (UTF-8) when the error is not 0 | `ShowMessageBox` at all 19 callers (`tardll.cpp` x2, `fileio.cpp`, `untar.cpp` x15, `gzip/gunzip.cpp:1188`) | **FIXED** - `LoadStrU8`, bounded, tail trim |
| `fileio.cpp:38`, `49`, `70` | `IDS_GZERR_FOPEN`, `IDS_GZERR_SEEK`, `IDS_ERR_FREAD` | + `GetErrorText` | `ShowMessageBox` | **FIXED** (was `strcpy` + `strcat`) |
| `deb/deb.cpp:22` `ShowError()` | `IDS_GZERR_FOPEN`, `IDS_ERR_FREAD`, `IDS_GZERR_SEEK` (6 callers) | + `GetErrorText` | `ShowMessageBox` | **FIXED** |
| `untar.cpp:761`, `1835` | `IDS_TARERR_FWRITE` | + `IDS_TARERR_WRSIZE` (now `LoadStrU8` too - the reverse rule) or `GetErrorText` | `ShowMessageBox` | **FIXED** |
| `untar.cpp:822`, `1868` | `IDS_TARERR_FWRITE` | + `GetErrorText` | `ShowMessageBox` | **FIXED** |
| `untar.cpp:639`, `1801` | `IDS_SKIPPROGRESS_TEXT` / `IDS_UNPACKPROGRESS_TEXT` | + `header.Name` UTF-8 | `ProgressDialogAddText` | **FIXED** - `LoadStrU8`, tail trim |
| `tardll.cpp:540` | `IDS_RPMERR_TMPFILE` | + `name` (the viewed file's path, UTF-8) | `ShowMessageBox` | **FIXED** - bounded, tail trim (was `strcpy` + `strncat`) |
| `tardll.cpp:587-591` | `IDS_RPM_VIEWTITLE` | `name` UTF-8 (cut at 450 bytes) + `" - "` + the title word | `ViewFileInPluginViewer` caption | **FIXED** - `LoadStrU8`; the cut name gets a tail trim, the appends are bounded |
| `untar.cpp:695-699` | `IDS_TARERR_FWRITE` ... | - | - | RIGHT AS IT IS - inside a comment block (dead code) |
| `tardll.cpp:249-254` About | name, description, literals (`©` is a code-page byte) | all code page | `SalMessageBox` | RIGHT AS IT IS |
| all other uses | a resource text alone (`ShowMessageBox` text or title, `OpenProgressDialog` title, `TestFreeSpace` title, `rpm/rpmview.cpp` boxes) | | | RIGHT AS IT IS |

## 3. How to reach the FIXED sites

- **`fileio.cpp:38` / `LoadErr(IDS_GZERR_FOPEN)` (easiest)**: Czech UI
  (`"Chyba otevírání archivu: "`), a `.tar` / `.tgz` that cannot be opened for reading (held by
  another program without read sharing, or no read permission), Enter on it: the box reads the
  prefix and the Windows reason `(32) ...`. Before: the reason (UTF-8) garbled in every translated UI
  whose reason or prefix has an accented letter. No special file name is needed - the mixture was
  template + reason.
- **`untar.cpp:639` Skip line (easy)**: Czech (`"Přeskakuji "`) or German (`"Überspringe "`); a
  `.tar` with at least two files named with accented letters, F5 Copy **one** of them out: every other
  file of the archive is passed over with the line `Přeskakuji <name>` in the progress dialog
  (`WriteOutData` with `simulate`, called from `untar.cpp:504`). The *Extracting* prefix
  is ASCII in all eight shipped languages (right by accident before).
- **`tardll.cpp:587-591` (easy)**: Czech (`"RPM Prohlížeč"`), F3 on an `.rpm` with an accented
  name: the viewer's title reads `<path> - RPM Prohlížeč`. Before: the path garbled.
- `untar.cpp:761`, `822`, `1835`, `1868`: a write error during extraction (a full target volume).
- `tardll.cpp:540`: the temporary file for the RPM view cannot be created - not reachable on purpose.

## 4. Other defects seen (not fixed)

- `tardll.cpp:88` `LoadErr` returns one static buffer (not safe for two calls in one expression or
  from two threads) - unchanged.
- `tardll.cpp:587`: the viewer caption cuts the *path* at 450 bytes (a message title, not a name used
  as such); the core cuts it again at 259 bytes (`src/viewer3.cpp:52`).
- `rpm/rpmview.cpp` writes the package information into a temporary text file with `fprintf` of
  header strings from the package (encoding of the package) - no resource texts are mixed in; the
  reader's encoding was not examined.
- `untar.cpp:388-389`, `602-603`, `1770-1771`: `strcat` of names into allocated buffers - sizes
  computed by the callers, not re-checked here.
