# Implementation notes: feature 142 - source changes

Session 2026-10-14 (implementation agent). No product build, no run of the program, no git
write. The EXIF library was built from the real project into a scratch folder and driven
directly; the two plug-in translation units were checked with `cl /Zs`.

## 1. What changed, per function

### EXIF.DLL

| File | Function | Change |
|---|---|---|
| `exif/exif.def` | - | `EXIFReplaceThumbnailW @7`, `EXIFGetInfoW @8` appended; **the six old exports got their ordinals written out** (`@1`-`@6`, the numbers they had). Measured with `dumpbin`: without that the linker numbers by name and the two new names moved `EXIFGetOrientationInfo` 4 -> 5, `EXIFGetVersion` 5 -> 6, `EXIFReplaceThumbnail` 6 -> 7. After: old six identical to the library built from the commit of 135. |
| `exif/exif.h` | - | typedefs `EXIFGETINFOW` (`const wchar_t* fileName, EXIFENUMPROC, LPARAM` - a file only, no data mode) and `EXIFREPLACETHUMBNAILW` (`const wchar_t*, const wchar_t*, unsigned char*, int`), with the contract. `EXIF_DLL_VERSION` stays 8 (132 / 135 did not raise it either; the plug-in asks for the export, not the version). |
| `exif/exif.c` | `ReplaceThumbnailW` (static, new) | the former body of `EXIFReplaceThumbnail` on wide paths: `jpeg_data_new_from_file_w` / `jpeg_data_save_file_w`. The Exif rewrite (`SalExifReplaceThumbnail`, "no byte moves"), the JFXX branch and every refusal are the same lines as before. New: it leaves right after a load that failed or did not understand the file (before, such data went on and were refused by the writer - same result: FALSE, nothing written) and returns the reason in `*err`. |
| | `EXIFReplaceThumbnailW` (new export) | NULL path -> `ERROR_INVALID_PARAMETER`; else `ReplaceThumbnailW`. **After FALSE `GetLastError()` is the reason**: the Windows error of the file call that failed, `ERROR_INVALID_DATA` for a refused file. |
| | `EXIFReplaceThumbnail` | thin wrapper: `CP_ACP` -> wide (`AnsiPathToWideAlloc`), then `ReplaceThumbnailW`. |
| | `EXIFGetInfoW` (new export) | `ExifDataNewFromFileW` (loader + `exif_loader_write_file_w`) + `EnumExifData`. |
| | `EXIFGetInfo` | data mode unchanged (`exif_data_new_from_data`); file mode: `CP_ACP` -> wide, the same route as `EXIFGetInfoW`. The enumeration moved unchanged into `EnumExifData`. |
| `exif/libjpeg/jpeg-data.c`, `.h` | `jpeg_data_load_file_w`, `jpeg_data_new_from_file_w`, `jpeg_data_save_file_w` (new) | `CreateFileW` / `ReadFile` / `WriteFile` on the path as given (`\\?\` passes straight through - nothing in between looks at the path). Load: sharing as `fopen "rb"` had (read + write), empty or >= 2 GB or a short read = incomplete. Save: `DeleteFileW` + `CREATE_ALWAYS` (as `remove` + `fopen "wb"`), written whole, **flushed** (`FlushFileBuffers`) and closed before success; any failure deletes the file. `unsigned long* err` out. `windows.h` is included before `config.h` (which defines `inline` away). The `char` functions `jpeg_data_load_file` / `jpeg_data_save_file` are untouched (no export uses them now). |
| `exif/libexif/exif-loader.c`, `.h` | `exif_loader_write_file_w` (new) | the `char` one with `_wfopen`. |

Not converted back to ANSI anywhere: from the two wide exports down, every open is wide.

### Plug-in

| File | Where | Change |
|---|---|---|
| `thumbs.cpp` | `UpdateThumbnails`, library call | `GetProcAddress("EXIFReplaceThumbnailW")` first; paths from `SplU8ToWExtAlloc` - the helper `ReadWholeFileU8`, `ReplaceFileU8`, `DeleteFileU8` use, so the library opens the same files. Missing export: the old `U8ToDLLPathAlloc` route, unchanged. |
| | `ThumbWriteFailed` (new) | `DialogError(hProgress, BUTTONS_SKIPCANCEL, name, reason, LoadStr(IDS_ERRORTITLE))`; Skip all -> `FL_SKIP_ALL`, Cancel (and any other answer) -> `FL_CANCEL`; a set `FL_SKIP_ALL` = no dialog. Replaces the OK-only `ShowMessageBox`. |
| | reasons | (1) `SalGetTempFileName` failed - **said nothing before** (its `err` was NULL): now the Windows error text; (2) the wide library call failed with a file error: `GetErrorText(GetLastError())`; (3) the library refused the file (`ERROR_INVALID_DATA` / `_PARAMETER`), the check of 132 / 135 refused its output, the old DLL failed, or a path could not be converted: the former text `IDS_REGENERATE_THUMB_WRITEFILE` with the name (`LoadStrU8`, as before). |
| | replace loop | `FL_SKIP_ALL` **is read now** (it was set and never tested - the dialog came for every file). The read-only question got a "Skip all" of its own, `FL_RO_SKIP_ALL` (in `FL_KEEP`): both wrote the one flag, and honouring it as it was would have let "skip all errors" silently skip read-only files and the reverse. |
| | `srrLeftAtTemp` | the dialog is always shown (it names the file that holds the picture); Cancel now cancels (was ignored). |
| | `ThumbSetReadOnlyAgain` (new) | after `srrDone` of an attempt made with `clearRO`: `SetFileAttributesW(attr | READONLY)` on the same wide path; failure -> `TRACE_E` only. |
| | `InitEXIF` result | was ignored (`GetProcAddress(NULL, ...)`, the "cannot load" box once per file): a failure sets `FL_CANCEL`. |
| `dialogs.cpp` | `CExifDialog::DialogProc`, `WM_INITDIALOG` | `EXIFGetInfoW` with `SplU8ToWExtAlloc(FileName)` when exported, else the old route. The TIFF (data) branch is unchanged. |
| `PRIVACY.md` | *Temporary files* | a paragraph for *Update Thumbnail*; validity line untouched. |

`InitEXIF` / `pictview.cpp`: nothing needed for this feature; not edited.

## 2. Encodings

| File | Encoding | How edited |
|---|---|---|
| `jpeg-data.c`, `jpeg-data.h` | **ISO-8859-1**, CRLF, no BOM (2 bytes >= 0x80 each) | byte-level Python script (anchors must occur once; asserts the count of high bytes and CRLF); still "ISO-8859 text, with CRLF" |
| `exif-loader.c`, `.h` | ASCII, CRLF | editor; verified ASCII + CRLF after |
| `exif.c`, `exif.h`, `thumbs.cpp`, `dialogs.cpp` | UTF-8 with BOM, CRLF | editor; BOM and CRLF verified after |
| `exif.def` | ASCII, CRLF | rewritten by a script |
| `PRIVACY.md` | UTF-8 without BOM, CRLF | editor; verified |

`python tools/check_encoding.py`: `TOTAL: 0`.

## 3. Decisions where the brief left room

- **Win32 file calls, not `_wfopen`,** in the three new `jpeg-data` functions: exact error codes
  for the dialog, and the old code ignored `fclose` (a failed flush was "success").
- **`FlushFileBuffers` before the library reports success** - the rule of 105 ("complete and
  flushed") now holds for this temporary file too. Costs one flush per picture.
- **Ordinals pinned** in `exif.def` (see above) - this edits the six old lines.
- **`EXIFGetInfoW` has no `dataLen`.**
- **Two "Skip all" flags** instead of one.
- **`DialogError` texts**: name UTF-8, reason UTF-8 (`SalSetWindowTextU8` in the core's
  `CFileErrorDlg`), title code page (`LoadStr`) - as the neighbours.
- The temporary name is `pv` + **one to four** hex digits (`%X` of a number that starts below
  0x1000) - `PRIVACY.md` says "up to four characters".

## 4. Verification (scratch; Release x64 and Debug x64 of the real `exif.vcxproj`)

Build: 0 warnings, 0 errors, both configurations. Baseline: the library built from `git archive
HEAD` (the commit of 139 = library of 135).

`verify142.py`, 91 real files (82 with Exif), five calls per file - A code-page export / W
ASCII name / W name `日本語 αβγ 😀 NNN.jpg` in folder `写真 Φωτογραφίες 😀` (`\\?\`) / W path of
437 + characters (`\\?\`) / baseline library:

| What | Release | Debug |
|---|---|---|
| return values that differ among the five | 0 of 91 | 0 of 91 |
| outputs not byte-identical among the five (so: wide = code-page = library of 135) | 0 of 91 | 0 of 91 |
| source file changed / file left after a refusal | 0 / 0 | 0 / 0 |
| walker of 135 on the Unicode-named outputs | same 82, DIFFERENT 0, refused 0, JFXX 9, RULE132 0 | the same |
| `SalJpegRewriteKeepsFile` (`keepcheck.exe`, the header itself) on Unicode + long-path pairs | 182 of 182 `sjkSame` | 182 of 182 |
| Exif information: `EXIFGetInfoW` (Unicode name, long path) = `EXIFGetInfo` new = of 135 | 82 files, 3,613 tags, 0 lists differ | the same |
| reasons after FALSE: missing source 2, missing folder 3, not a JPEG 13, empty 13, size 0 13, NULL 87, source locked 32, read-only target 5; no file left | 8 of 8 | 8 of 8 |

Also: `exif_real_measure.py` of 135 unchanged (code-page export, now a wrapper): same 82,
refused 0, DIFFERENT 0, JFXX 9. `exifdll_measure.py` of 132: 0 losses, `FILL_8` and `EXIF_BIG`
refused - as recorded in 132. The library of 135 does not export the wide names (fallback case
exists). `cl /Zs` of `thumbs.cpp` and `dialogs.cpp`: clean with Debug and with `NDEBUG` defines.

**Not shown here**: the defect itself. The scratch volume keeps 8.3 names (the Unicode file got
`000~1.JPG`), so the old route would have reached these files; `fsutil 8dot3name query` needs
administrator rights. The "before" row needs a volume without short names.

`facts.py` (`ReplaceFileW` as `SalReplaceWithTempW` calls it): read-only target -> error 5;
after clearing -> the file in place is **not read-only** (so item 4 was needed); modification
time = now, creation time kept; the other hard link keeps the old content, link count 1.

## 5. The lows of the review

- **(a) Modification time**: changes to the time of the update (the creation time stays).
  Not changed. Keeping it would be a decision (a sync tool would then miss the change).
- **(b) Hard links**: the picture is split from its other links - they keep the old content.
  And when the read-only attribute was cleared for the replace, the old content loses it
  (the attribute belongs to the file, and only the new file gets it back). Not changed.
- **(c) Missing messages**, as read in the code after this change: no export at all in the
  loaded EXIF.DLL -> silent (the count box at the end tells); `PVSaveImage` failure -> still
  an **OK-only box per file** (`IDS_SAVEERROR`, `thumbs.cpp` near the end of the loop) - the
  same "one box per file" pattern, not converted (the brief named one box); `pvii.Width == 0`
  would divide by zero. The review's own text was not in the repository - I could not match
  its wording to a line.

## 6. Not done

- T002 ("before" row), the probe of 132 with Unicode names, the program itself - nothing was
  run in the product.
- `EXIFGetOrientationInfo` has no wide twin (its caller is `render1.cpp`, another agent's file);
  `EXIFInitTranslations` stays code-page (`InitEXIF`: Exif texts stay English when the
  installation folder is outside the code page and has no short name - recorded in 131).
- Whether the Exif information window is reachable at all: `render1.cpp:4294` opens it only
  for `PVFF_EXIF`, which 132 recorded as never set. FR-002 may need that file.
- No `saltests` checks (no pure rule was added; `src/saltests` is another agent's).
- `GetErrorText(tmpErr)` when `SalGetTempFileName` fails with error 0 would read "completed
  successfully" - not guarded.
- x86 configurations of the library were not built.

## 7. Places to watch in the product build

- `src/plugins/pictview/exif/libjpeg/jpeg-data.c:21-24` - `windows.h` before `config.h`;
  built clean in the real project (x64 Debug + Release), x86 not built.
- `src/plugins/pictview/thumbs.cpp:578-656`, `:694`, `:739`, `:755` and
  `src/plugins/pictview/dialogs.cpp:1633-1654` - checked without the precompiled header only.
- `src/plugins/pictview/exif/exif.def` - `@n` after `EXPORTS name`; linked clean, ordinals
  confirmed with `dumpbin`.

Scratch (scripts, builds, results):
`C:\Users\pavel\AppData\Local\Temp\claude\E--Projects-tandemcommander\3cc3c426-9583-446c-8ee9-724fd59e73d2\scratchpad\impl142`
(`verify142.py`, `verify142_release.txt`, `verify142_debug.txt`, `keepcheck.cpp`, `facts.py`,
`facts_result.txt`, `edit_jpegdata.py`, `write_def.py`, `zs.cmd`).

## 8. After the review (lows; same limits - scratch builds only)

| # | Where | Change |
|---|---|---|
| 1 | `thumbs.cpp` `FL_WRITE_SKIP_ALL` (0x800, in `FL_KEEP`), `ThumbWriteFailed` | "the new thumbnail could not be written" (temporary file, library, refusal of 132 / 135) has a "Skip all" of its own; `FL_SKIP_ALL` is the failed replace only, `FL_RO_SKIP_ALL` the read-only question. Three flags, none answers another. |
| 2 | `thumbs.cpp`, after the wide library call | only `ERROR_INVALID_DATA` means "refused" (the former text); 87 shows its Windows text like any file error. |
| 3 | `PRIVACY.md` | "If the picture has disappeared meanwhile and the new file cannot be given its name, the new file is kept ..." (`srrLeftAtTemp` only; a failed replace with the original intact deletes the new file). The paragraph re-read against the code: file next to the picture, name `pv` + 1-4 hex digits + `.tmp` (`SalGetTempFileName`); in place only after the library's success and `ThumbNewFileKeepsOriginal`; every other way out calls `DeleteFileU8(newFile)` except `srrLeftAtTemp`; a crash can leave it. |
| 4 | `jpeg-data.c` `jpeg_data_save_file_w` | no `DeleteFileW` first: `CREATE_ALWAYS` over the existing file, so the plug-in's temporary file keeps its name. Only after `ERROR_ACCESS_DENIED` the file is deleted and created (what `remove` + `fopen "wb"` did): a hidden or system file cannot be written over but can be deleted. Edited by a byte script again (ISO-8859-1, CRLF kept). |
| 5 | `exif.c` `AnsiPathToWideAlloc` | `MB_ERR_INVALID_CHARS`. Found: the UCRT converts `fopen`'s path with `MB_PRECOMPOSED | MB_ERR_INVALID_CHARS` (`ucrt/inc/corecrt_internal_win32_buffer.h:634`, Windows Kits source 10.0.26100). On this machine (code page 1250) **no single byte is refused** with that flag, so the difference cannot be shown here - it exists on double-byte code pages (a lead byte without its second byte). |
| 6 | `thumbs.cpp`, `SalGetTempFileName` failure | error code 0 -> the former text instead of `GetErrorText(0)`. |

Re-run after 4 and 5 (Release and Debug x64, 0 warnings; identical numbers in both):

| What | Result |
|---|---|
| 91 files x 5 calls: return values / outputs that differ | 0 / 0 |
| walker of 135 | same 82, DIFFERENT 0, refused 0, JFXX 9, RULE132 0 |
| `SalJpegRewriteKeepsFile` | 182 of 182 `sjkSame` |
| Exif information lists that differ | 0 (82 files, 3,613 tags) |
| reasons after FALSE | 8 of 8 as expected |
| existing target - empty normal / hidden / system / hidden + system / read-only / 200 bytes: new code-page export, new wide export, library of 135 | the same outcome in all six (written, attributes 0x20; read-only: FALSE, file as it was) |
| source name with byte 0x81, old export: new / library of 135 | FALSE / FALSE |
| `cl /Zs` `thumbs.cpp`, `dialogs.cpp`; `check_encoding.py` | clean; `TOTAL: 0` |

Owed (text work, needs a new string): a refused file - not understood by the library, or its
output refused by the check of 132 / 135 - still reads "Unable to create a file with the new
thumbnail. Disk full? ...". The line numbers of section 7 moved by a few lines (`thumbs.cpp`
+10 from the flag block on).

Records: `verify142_review_Release.txt`, `verify142_review_Debug.txt`, `edit_jpegdata2.py` in
the scratch folder.
