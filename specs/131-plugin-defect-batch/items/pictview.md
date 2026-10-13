# PictView - items of feature 131

Source of the items: `specs/130-plugin-mixed-templates/triage/pictview.md`, section 4.
Changed files: `src/plugins/pictview/thumbs.cpp`, `src/plugins/pictview/pictview.cpp`.

**Nothing here was compiled in the plug-in's project and nothing was run in the program** (the
brief forbids both). What was run: small programs of my own outside the repository
(`specs/131-plugin-defect-batch/probe/pictview-diskmap-peviewer/`: `pv.cpp` = measurement,
`fix.cpp` = checks of the new pure function, which is cut out of the edited file by
`mkexcerpt.sh`, and of a copy of the new `InitEXIF` composition). The first build of the plug-in
is owed.

## 1. `thumbs.cpp:179` - the full name cut at `_MAX_PATH` and left without a terminator

**FIXED.**

- *The note*: `_sntprintf(fileName, _MAX_PATH, "%s%s%s", path, ..., Name)` into
  `path[_MAX_PATH]`; the cut path is opened, replaced and copied.
- *Found*: real. `CEnumFiles` took the panel path into `path[_MAX_PATH]` (a longer one made
  `GetPanelPath` fail, `src/zip.cpp:1081-1083`, and the command answered "no files found") and
  joined it with `CFileData::Name` (up to 255 UTF-16 units = up to 765 bytes) into the caller's
  `path[_MAX_PATH]`. Measured (`pv.cpp`, row 1): `_sntprintf` returns -1, fills all 260 bytes
  and writes **no terminator**. The caller then ran `_tcsrchr(path, '\\')`, the open, and -
  when a later zero byte happened to end a path that still opened - `_tcscpy(newFile, path)`
  into another `_MAX_PATH` array and `ReplaceFileU8(path, newFile)` on it.
- *How a user gets there*: a folder whose path plus a JPEG's name is over 259 **bytes** of
  UTF-8 - no long-path setup needed, e.g. `C:\Users\<name>\Pictures\Dovolená 2024` (about 40
  bytes) and a file name of 110 Cyrillic or 75 CJK letters; select the file, Plugins > PictView
  > Update Thumbnail. Effect before: what follows the 260 bytes on the stack is read as part of
  the name; in the usual case the open fails and the error dialog shows a name with garbage at
  its end; a crash or a stack overwrite by the `_tcscpy` is possible. I did not run it in the
  program.
- *The fix*:
  - `ThumbsMakeFullName` (new `inline`, `thumbs.cpp`): joins path and name with a bound, returns
    FALSE and an **empty** buffer when the result does not fit - nothing is cut.
  - `CEnumFiles::path`, and `path` / `newFile` of `UpdateThumbnails`, are `CSalMaxPathBuffer`
    (`SAL_MAX_PATH_UTF8`, the size `SalGetTempFileName` asks for with a long folder,
    `spl_gen.h:1006-1009`). `GetFile` takes the buffer size.
  - A name that does not fit even that is refused: `UpdateThumbnails` shows the Skip / Cancel
    error dialog with the file name and `IDS_TOOLONGNAME` ("Can't finish operation because of
    too long name." - an existing string) and goes on; nothing is opened, created or replaced
    for it. "Skip all" there shares the flag of "cannot open" (`FL_NON_IMG_SKIP_ALL`).
  - The two path arrays also served as message buffers (`thumbs.cpp:288` unbounded
    `_stprintf`, `515` `wsprintf`, `538` `_stprintf`, `542` `_tcscpy`): these write into a
    separate `msg[1200]` with `_snprintf_s(..., _TRUNCATE, ...)` / `lstrcpyn` now. This also
    closes note 4 of the triage (`thumbs.cpp:288`).
- *Test*:
  - Probe row: a folder + JPEG name of more than 259 bytes together (a name of 120 Cyrillic
    letters); Update Thumbnail, Yes; expected: the progress dialog names the whole file name and
    the command asks its JFXX question (see item 2, *Test*) - no "cannot be processed" dialog
    with a damaged name, no crash. Before: error dialog with garbage at the end of the name /
    crash.
  - EXIF.DLL has an ANSI interface (`thumbs.cpp` `U8ToDLLPathAlloc`): a full name over 259
    bytes **in the code page** goes there as its 8.3 short name; where the volume has no short
    names the row ends with "Unable to create a file with the new thumbnail..." and the file
    untouched. That is a limit of EXIF.DLL, not changed here.
  - Unit cases for `ThumbsMakeFullName` (run in `fix.cpp`, all pass): path with and without a
    trailing backslash; a result of exactly `bufSize - 1` bytes (fits); one byte more (FALSE,
    buffer empty, the old content gone); empty path; NULL buffer / size 0 / NULL path.
- *Not sure*: the refusal branch (a name over `SAL_MAX_PATH_UTF8`) cannot be reached with a
  real panel; it is there so that no cut name can exist. Low memory (`CSalMaxPathBuffer` NULL):
  the command returns without a message.

## 2. `thumbs.cpp:277` - a code-page path handed to the WIC engine

**FIXED** (the note was right; measured at the level of the conversion, not in the program).

- *Found*: `PVW32DLL` is filled only by `InitWicEngine` (`pictview.cpp:1450`); its
  `PVOpenImageEx` is `WicOpenImageEx`, which opens `oi->FileName` with `OpenFromFileU8`
  (`wicengine.cpp:957`, `372-380`: `SplU8ToWExtAlloc`, NULL -> `PVC_CANNOT_OPEN_FILE`).
  `UpdateThumbnails` gave it `U8ToDLLPathAlloc(path)` = the path in the **code page**
  (`pictview.cpp:482-`). Measured (`pv.cpp`, row 2, code page 1250):
  `C:\Fotky\Příliš žluťoučký kůň.jpg` and `C:\Fotky\café.jpg` as code-page bytes ->
  `SplU8ToWExtAlloc` returns NULL; the UTF-8 form gives the exact wide path.
- *How a user gets there*: any JPEG whose path has a letter outside ASCII that the system code
  page **has** (the ordinary case: `Dovolená\foto.jpg` on a Czech system); Update Thumbnail.
  Before: the Skip / Cancel dialog "(code) ... This file cannot be processed. Continue?" for
  every such file; the thumbnail is never updated. (A name **outside** the code page worked
  by accident: `U8ToDLLPathAlloc` falls back to the 8.3 short name, which is ASCII.) The same
  file opens in the viewer and gets a panel thumbnail - those calls pass the UTF-8 name
  (`render1.cpp:316`, `thumbs.cpp` `LoadThumbnail`).
- *The fix*: `oiei.FileName = path;` (UTF-8), the conversion and its `free` removed. The two
  `U8ToDLLPathAlloc` calls for EXIF.DLL (`ReplaceThumbnail`) stay - that interface is ANSI.
- *Test*: probe row (the easiest of this plug-in): `C:\...\Žluťoučký kůň\foto.jpg`, a JPEG;
  Update Thumbnail, Yes. Before: the error dialog "... This file cannot be processed.
  Continue?". After: no such dialog - the command goes on to its next question (today always
  "This file does not contain EXIF data ... create a JFIF JFXX thumbnail instead?", see "Seen
  on the way"); with Yes the file gets the thumbnail and its modification time changes.
  Control: the same file under an ASCII path gets the same questions before and after.
- *Not sure*: with this fix the EXIF.DLL stage is reached for such names for the first time;
  I read it (code-page path without best fit, `usedDefault` checked, the original replaced by
  `SalReplaceWithTempW` only after EXIF.DLL wrote the new file) but did not run it.

## 3. `pictview.cpp:1570-1597` `InitEXIF` - a write to address 1

**FIXED.**

- *Found*: real, on a narrow path. `path[MAX_PATH]` gets `pathW` (the full name of `exif.dll`,
  at most 259 UTF-16 units) through `WideCharToMultiByte(CP_ACP)`; when the result needs more
  than 260 bytes the call fails and `path` is made empty. With EXIF.DLL loaded (it is loaded
  wide, so this does not stop it) and a language whose `IDS_EXIF_LOCALIZATION_FNAME` is not
  empty (English has `en.po`, so every language), `_tcsrchr(path, '\\')` is NULL and
  `_stprintf(NULL + 1, "lang\\exif\\%s", name)` writes to address 1. Measured (`pv.cpp`, row
  3, code page 932 as the example): 226 wide characters -> conversion fails with error 122,
  `_tcsrchr` = NULL, `+ 1` = address 1. Also real without the failure: the append had no
  bound - a plug-in folder of 250 bytes + `lang\exif\` + the name overruns `path`.
- *How a user gets there*: a system with a double-byte code page (Japanese, Chinese, Korean)
  or with "Beta: UTF-8" as the code page; the program installed in a folder whose name has many
  letters outside ASCII (under 260 UTF-16 units, over 259 bytes in the code page); then the
  first call of `InitEXIF`. **Today that is only Update Thumbnail** (`thumbs.cpp`, after the
  new thumbnail was made): the two calls in the viewer (`render1.cpp:1689` auto-rotate,
  `render1.cpp:4291` the EXIF dialog) stand behind `pvii.Flags & PVFF_EXIF`, and the WIC engine
  always reports `Flags = 0` (`wicengine.cpp:909`) - see "Seen on the way". Effect: access
  violation (the program's crash report). For the unbounded append: an installation path of
  more than about 235 bytes on any system - a stack overrun in `InitEXIF`.
- *The fix*: the name of the translation file is composed **wide** beside `exif.dll`
  (`_snwprintf_s(..., _TRUNCATE, L"%.*slang\\exif\\%s", ...)` into `MAX_PATH + 64` units - the
  longest possible result is 292), converted with `SplWToU8Alloc` and `U8ToDLLPathAlloc` (code
  page without best fit, else the 8.3 short name, else NULL) and only a non-NULL result is given
  to `EXIFInitTranslations` (EXIF.DLL opens it with `_tfopen`, `exif/Translation.cpp:208`).
  Without a usable name the EXIF texts stay English - as when the file is missing. The message
  `IDS_LOADEXIF` is composed with a bound too.
- *Test*: probe row needs a non-default installation: install (or copy the program) into a
  folder of ~120 CJK letters with code page 932 or the UTF-8 code page active; select a JPEG,
  Plugins > PictView > Update Thumbnail, Yes (and Yes to the JFXX question); expected: the
  command ends without a crash. Before: crash. Control: default installation - the command
  behaves as before (for an ASCII folder EXIF.DLL gets the same text as before). Unit: the
  composition is checked in `fix.cpp` (the directory part is kept, the result ends with
  `\lang\exif\en.po`, the longest input fits).
- *Not sure*: a side effect that is an improvement but a change: for an installation folder
  outside the code page EXIF.DLL now gets the short name (translations work) where it got `?`
  characters before (no translations).

## 4. `dialogs.cpp:251-265` - the image comment and `SetDlgItemTextA`

**NOT A DEFECT (not reachable); nothing changed.**

- *Found*: the Image Properties dialog gets `Comment` from `CRendererWindow::Comment`, which
  `DuplicateComment` (`render2.cpp:278-290`) fills from `pvii.Comment` / `pvii.CommentSize`.
  The only engine in the plug-in is the WIC one, and its `FillInfo` (`wicengine.cpp:898-927`)
  always sets `CommentSize = 0`, `Comment = NULL`, `Info1` = an ASCII literal
  (`FormatShortName`), and leaves `Info2` zeroed. `PVMessageWrapper.cpp` / `PVEXEWrapper.cpp`,
  which could carry a comment, are in no project of the plug-in (`pictview.vcxproj` compile
  list). So the dialog shows `"JPEG"` / `"PNG"` ..., the engine's ASCII compression text and
  an **empty** comment - the branch with `Comment` never runs.
- *User-visible consequence, recorded, not a text-encoding defect*: the comment of an image
  (JPEG COM, PNG `tEXt`/`iTXt`) is never shown in Image Properties, although Save As writes one
  (`wicengine.cpp:2044-2134`, UTF-8). If reading comments is added to the engine one day, that
  text will be UTF-8 and these three `SetDlgItemTextA` calls must become wide
  (`SplU8ToWAlloc` + `SetDlgItemTextW`).
- *Test*: probe row to confirm the finding: save an image with a comment (`Žluťoučký`), reopen,
  File > Image Properties: the comment field is empty (today's behaviour, before and after).

## Other notes of the triage

- Note 4 (`thumbs.cpp:288`, unbounded `_stprintf` into `newFile[_MAX_PATH]`): **FIXED** with
  item 1 (own buffer, bounded).
- Note 6 (`render1.cpp` `errBuff`): already fixed by feature 130.
- Note 7 (core, `plugins3.cpp:533-534`): **NEEDS A CHANGE OUTSIDE MY DIRECTORIES** - not
  touched.

## Seen on the way, not changed

- **The engine never reports EXIF data** (`wicengine.cpp:909`: `pv.Flags = 0`; `PVFF_EXIF` is
  set nowhere in the plug-in). Read, not run: the viewer's EXIF command is therefore never
  enabled (`pictview.cpp:2369` `vweImgExifAvailable`, `render1.cpp:4291`), auto-rotate through
  EXIF.DLL never runs (`render1.cpp:1689`; the panel thumbnails read the orientation through
  WIC instead, `thumbs.cpp` `WicGetExifOrientation`), and Update Thumbnail asks for **every**
  JPEG "This file does not contain EXIF data ... create a JFIF JFXX thumbnail instead?"
  (`thumbs.cpp`, `!(pvii.Flags & PVFF_EXIF)`), also for one that has EXIF data. A functional
  loss since the engine was replaced (the comment at `thumbs.cpp` "unreachable since feature
  006" knows part of it) - a candidate for `specs/NEXT-WORK.md`; what EXIF.DLL does with a
  file that has EXIF data after "Yes" was not read.
- Update Thumbnail stays limited by EXIF.DLL's ANSI interface (see item 1, *Test*).
- `UpdateThumbnails`, the end of the loop: `PVCloseImage(PVHandle)` is called again with NULL
  after a processed file - harmless (`WicCloseImage` checks for NULL, `wicengine.cpp:1089`).
