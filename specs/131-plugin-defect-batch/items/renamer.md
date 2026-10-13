# Feature 131 - Batch Rename plug-in (`src/plugins/renamer`)

Source: `specs/130-plugin-mixed-templates/triage/renamer.md`, section 4 "Other things seen".
**Nothing was built or run**; everything is from reading (the plug-in and, for the sinks, the
core). Line numbers are those after the edits.

Changed files (5): `utils.h`, `utils.cpp`, `rendlg3.cpp`, `renamer.cpp`, `rendlg.cpp` (a
comment). BOM and CRLF kept.

| # | Item | Verdict |
|---|---|---|
| 1 | `utils.cpp` `FileError` appends a stale `GetLastError()` text to logical errors | FIXED |
| 1b | (found on the way) two real system errors shown with the reason of a *later* call | FIXED (`rendlg3.cpp:133`, `:499`) |
| 2 | `rendlg.cpp:1273-1275` `ExpandPluralFilesDirs` into `SetDlgItemText` (A) | NOT A DEFECT (the core gives a plug-in code-page text) |
| 3 | `renamer.cpp:89` `vsprintf` into `buf[1024]` | FIXED (bounded; not reachable with the present texts) |
| 4 | `rendlg2.cpp:194`, `preview.cpp:203-253` new name limited to `MAX_PATH` **bytes** | NOT A DEFECT in the sense of the rules (refused, not cut) - recorded |
| 5 | `preview.cpp:267-272` the *Path* column cut by `lstrcpyn` | UNREACHABLE - nothing changed |
| 6 | `utils.cpp:15-17` histories in the registry, encoding | NOT A DEFECT (UTF-8 both ways); **but found: two histories read with a too small buffer - FIXED** |
| 7 | `dialogs.cpp:823` `IDE_STDERR` through the code page | LEFT - the encoding of a foreign program's output is not known |
| 8 | `utils.cpp` the `A` API fallbacks (`CreateFileA(fileName)` ...) | FIXED (fail closed; not reachable with a valid name) |

---

## 1. `FileError`: a Windows reason behind errors that have none

**The note of 130:** `FileError` takes `GetLastError()` at entry for every caller, also for
those that report a logical error; a stale error code of an earlier call is appended.

**Found: real.** `utils.cpp:42` reads the last error, `:50-59` appended
`SG->GetErrorText(err)` ("(N) text") whenever it was not 0. All 28 callers were read:

| # | Caller | Message | What precedes the call | A system error? |
|---|---|---|---|---|
| 1 | `rendlg.cpp:1332` | `IDS_TOOLONGPATH` | `SG->SalPathAppend` returned FALSE | **no** - logical |
| 2 | `rendlg.cpp:1350` | `IDS_ERRREADDIR` | `FindFirstFileW` failed (then `free`) | yes |
| 3 | `rendlg.cpp:1432` | `IDS_TOOLONGPATH` | `item->NameLen >= MAX_PATH` | **no** |
| 4 | `rendlg.cpp:1448` | `IDS_ERRREADDIR` | `FindNextFileW` failed, not `ERROR_NO_MORE_FILES` | yes |
| 5 | `rendlg2.cpp:266` | `IDS_EXP_SMALLBUFFER` | the new name did not fit | **no** |
| 6 | `rendlg2.cpp:293` | `IDS_DUPLICATENAME` | two new names equal | **no** |
| 7 | `rendlg2.cpp:317` | `IDS_DIRNOTSAMEROOT` | `HasTheSameRootPath` FALSE | **no** |
| 8 | `rendlg2.cpp:339` | `IDS_DIRDIR` / `IDS_FILEDIR` | `SalGetFileAttributes` **succeeded** (a directory is there) | **no** |
| 9 | `rendlg2.cpp:435` | `IDS_DEPENDENCE` | script analysis | **no** |
| 10 | `rendlg2.cpp:555` | `IDS_DEPENDENCE` | an earlier item was skipped | **no** |
| 11 | `rendlg2.cpp:631` | `IDS_DEPENDENCE` | undo, the same | **no** |
| 12 | `rendlg2.cpp:680` | `IDS_DIRCASEERROR` | `SG->SalMoveFile(..., NULL)` failed (the core keeps the last error: `src/zip.cpp:3415-3422`, `src/common/salfileio.cpp:282-322`) | yes |
| 13 | `rendlg2.cpp:702` | `IDS_REMOVEDIR` | `RemoveDirectoryU8` failed | yes |
| 14 | `rendlg3.cpp:56` | `IDS_MOVEERROR` | `SetLastError(err)` right before (feature 103) | yes |
| 15 | `rendlg3.cpp:93` | `IDS_MOVEERROR` | `SetLastError(tmpErr)` right before | yes |
| 16 | `rendlg3.cpp:110` | `IDS_DIRDIR` / `IDS_FILEDIR` | `SalGetFileAttributes` succeeded | **no** |
| 17 | `rendlg3.cpp:126` | `IDS_OVERWRITEERROR` | `DeleteFileU8` failed | yes |
| 18 | `rendlg3.cpp:134` | `IDS_MOVEERROR` | `SalMoveFile(..., &err)` failed - **but** when `err` was "already exists" the identity checks of feature 103 ran in between | yes - the reason was not reliably the move's (item 1b) |
| 19 | `rendlg3.cpp:156` | `IDS_DELETEERROR` | `DeleteFileU8` failed | yes |
| 20 | `rendlg3.cpp:223` | `IDS_DIRCASEERROR` | `SalMoveFile(..., NULL)` failed | yes |
| 21 | `rendlg3.cpp:252` | `IDS_CREATEDIR` | `CreateDirectoryU8` failed | yes |
| 22 | `rendlg3.cpp:307` | `IDS_WRITEERROR` | `WriteFile` failed (or wrote less without an error - then the value is stale, see "not sure") ; on a retry `CreateFileU8` failed | yes |
| 23 | `rendlg3.cpp:366` | `IDS_READERROR` | `ReadFile` failed; on a retry `CreateFileU8` failed | yes |
| 24 | `rendlg3.cpp:451` | `IDS_OPENFILEERROR` | `SetLastError(err)` right before | yes |
| 25 | `rendlg3.cpp:500` | `IDS_OPENFILEERROR` | `CreateFileU8` failed, `err` taken - **then** `SG->SalGetFileAttributes(targetName)` (`:435`) or `SetFileAttributesU8` (`:490`) ran | yes - but the last error was the later call's (item 1b) |
| 26 | `rendlg3.cpp:512` | `IDS_OPENFILEERROR` | `CreateFileU8` (source) failed | yes |
| 27 | `utils.cpp:732` (`ValidateFileName`) | `IDS_NOTVALID_FILENAME` / `_RELATIVEPATH` / `_FULLPATH` (one call, three ids) | a syntax check | **no** |

(The "28" of the 130 note counts the hits of the search, the declaration and definition
included; there are 27 calls, 11 of them logical, with 12 different logical message ids.)

**How a user reaches it:** Ctrl+Shift+R on two files, new name the constant `x.txt` for both,
*Rename*: the error dialog for the second file reads `Duplicate name.` + the text of whatever
call failed last in the thread - typically
`Duplicate name.(2) The system cannot find the file specified.` or `(18) There are no more
files.` (the listing ended with it), in a translated Windows a sentence in the user's language.
The user reads a Windows reason for an error that is the plug-in's own rule. The same for
"Not valid filename." (a new name with `?`), "Expanded string is too large.", the cyclic
dependence and the "directory with the same name already exists" messages.

**The fix:**

- `utils.h:23-43` `FileErrorHasSystemReason(int error)` - `inline`, pure: TRUE for the ten
  messages that report a failed system call (`IDS_ERRREADDIR`, `IDS_OVERWRITEERROR`,
  `IDS_MOVEERROR`, `IDS_DELETEERROR`, `IDS_WRITEERROR`, `IDS_READERROR`, `IDS_OPENFILEERROR`,
  `IDS_DIRCASEERROR`, `IDS_CREATEDIR`, `IDS_REMOVEDIR`), FALSE for everything else. A message
  added later shows no reason until it is put on the list - the rule fails towards "no stale
  text".
- `utils.cpp:50-59`: the reason is appended only when the last error is not 0 **and** the
  message is on the list. A message that does not end with a space (`IDS_ERRREADDIR`,
  "Unable to read directory.") gets one before the reason - it read
  `Unable to read directory.(5) Access is denied.`
- No caller was changed for this; the signature is the same.

Why by message and not by a new parameter: the nine templates that end with `": "` are written
for a reason behind them and the others are whole sentences, so the message itself says which
kind it is; one function carries the rule and can be checked, and 27 call sites stay as they
are (nothing could be compiled here).

## 1b. Real errors with the reason of a later call

Found while reading the callers; both show a **wrong** Windows reason:

- `rendlg3.cpp:496-500` (`NORMAL_ERROR`): the target could not be created; `err =
  GetLastError()` is taken at `:434`, then `SG->SalGetFileAttributes(targetName)` runs (`:435`)
  - for a target that does not exist it fails with "file not found" - and `FileError` read
  that. Reach: rename across volumes (a full path as the new name) into a folder where creating
  is denied or onto a write-protected medium: the dialog said
  `Unable to open file: (2) The system cannot find the file specified.` instead of
  `(5) Access is denied.` / `(19) The media is write protected.` Fixed: `SetLastError(err)`
  before the call (the pattern of `:55`, `:92`, `:450`).
- `rendlg3.cpp:131-136`: after "already exists" for a pair of names that differ only in case,
  the identity checks (`:38-102`) ran before the message. Fixed the same way.

**Probe rows** (Czech or English UI; the dialog is the core's `CFileErrorDlg`, its text line
can be read with `GetWindowTextW`):

1. Two files selected, *New name* = `x.txt` (no variables), *Rename*: the error line is exactly
   `Duplicate name.` (cs: the translated text of id 1217, `IDS_DUPLICATENAME`) - no
   parenthesis, no Windows sentence. Negative control on the build before: the line continues
   with `(N) ...`.
2. One file, *New name* = `a?b.txt`: `Not valid filename.` only.
3. One file held open by another process without sharing, new name `y.txt`: the line is
   `Unable to rename file: (32) <the Windows text>` - the reason is still there.
4. New name = a full path into a folder where the probe's user may not create files (an ACL the
   probe sets on a temporary folder of another volume, or a read-only share):
   `Unable to open file: (5) ...` (before: `(2) ...`).

**Unit cases** (`FileErrorHasSystemReason`, needs only `renamer.rh2`): each of the ten ids ->
TRUE; `IDS_DUPLICATENAME`, `IDS_DEPENDENCE`, `IDS_DIRNOTSAMEROOT`, `IDS_DIRDIR`, `IDS_FILEDIR`,
`IDS_TOOLONGPATH`, `IDS_EXP_SMALLBUFFER`, `IDS_NOTVALID_FILENAME`,
`IDS_NOTVALID_RELATIVEPATH`, `IDS_NOTVALID_FULLPATH` -> FALSE; 0 and an unknown id -> FALSE.

**Not sure about:**

- Not compiled. The ids are defined in `renamer.rh2`, which `precomp.h:41` includes before
  `utils.h` (`:46`); `utils.h` is included nowhere else.
- Row 22: `WriteFile` that succeeds but writes fewer bytes leaves a stale last error, and the
  message is one "with a reason". Not changed (a short write without an error is not something
  I could reproduce by reading).
- Rows 2, 13, 17, 19, 21, 26: a `free()` sits between the failed call and `FileError` (in the
  `...U8` wrappers and at `rendlg.cpp:1346`); `free` does not set the last error when it
  succeeds - assumed, as the code did before.
- `IDS_TOOLONGPATH` ("Unable to read directory because of too long path name") is treated as
  logical; if a caller with a real system error ever uses it, the list must change.

---

## 2. `rendlg.cpp:1272-1279` - the count of files

**The note:** `ExpandPluralFilesDirs` (the core's text) into `SetDlgItemText` (A); "whether its
text can be UTF-8 with accented letters was not checked".

**Found: not a defect.** `CSalamanderGeneral::ExpandPluralFilesDirs` (`src/zip.cpp:3952-3957`)
calls the core's function without its `u8` argument; the default is FALSE
(`src/consts.h:899-906`: "Plugins via CSalamanderGeneral keep the ANSI default -- the API's
output bytes are frozen (feature 067)"), so the template is loaded with `LoadStr`
(`src/salamdr4.cpp:633`) - **code-page text** and numbers. The `A` call is the right sink.
A comment at `rendlg.cpp:1273-1274` says so; no code change.

**Probe row:** Czech UI, 3 files and 2 folders selected, open Batch Rename: the count line
reads the Czech sentence with its accents (`GetDlgItemTextW(IDS_COUNT)`); unchanged.

---

## 3. `renamer.cpp:84-109` `ErrorHelper`

`vsprintf(buf, message, arglist)` into `buf[1024]`. Every caller passes only the id (130 read
them all), so only the length of the resource text matters: not reachable. Made bounded
(`_vsnprintf_s(buf, _TRUNCATE, ...)`, `renamer.cpp:89`); the text is code page (the `FormatMessage`
A text follows it), so no UTF-8 tail trim. `FormatMessage` below it already got `1024 - l`.

## 4. New names limited to `MAX_PATH` bytes

`rendlg2.cpp:194` `char newName[MAX_PATH]`, `preview.h:42` `NewNameCache[MAX_PATH]`: a new
name (full path) whose UTF-8 form has 260 bytes or more is **refused** with "Expanded string is
too large." (`rendlg2.cpp:264-267`, `preview.cpp:204-205`, `:220-223`) - nothing is cut and
nothing is renamed to a shorter name. The limit is counted in bytes, so 86 CJK or 130 accented
Latin characters of path are already too many; lifting it means resizing the plug-in's path
buffers throughout (`CSourceFile`, the script, `MoveFile`'s `dir[MAX_PATH]`,
`CheckAndCreateDirectory`'s `old[MAX_PATH]`). Not a defect by the rules of this feature;
recorded as a limit.

## 5. `preview.cpp:267-272` - the *Path* column

`lstrcpyn(TextBuffer, item->FullName, _countof(TextBuffer))` with `TextBuffer[MAX_PATH]`
(`preview.h:39`) would cut a longer path at a byte. **Unreachable:** an item whose full name has
`MAX_PATH` bytes or more is never put into `SourceFiles` (`rendlg.cpp:1427-1440`: it gets
`IDS_TOOLONGPATH` and is deleted), so every listed `FullName` fits. Nothing changed.

---

## 6. Histories (`utils.cpp:6-36`)

**The note:** "the encoding in the registry is the core's service's; not checked here."

**Encoding - right.** The fields are read as UTF-8 (`ti.EditLine`, winliblt's UTF-8 edit line
of feature 104; `GetWindowTextU8Alloc`), the items are stored with `registry->SetValue(REG_SZ)`
(valid UTF-8 -> UTF-16, `src/salamdr6.cpp:2458-2473`), read back as UTF-8
(`SalRegQueryValueExW8`) and shown wide (`dialogs.cpp:280-296`, feature 104). One encoding from
the field to the registry and back.

**Found on the way - a real defect: two histories were read with a buffer smaller than the
field.** `renamer.cpp:316-320` (before): `SearchHistory` and `CommandHistory` were loaded with
`MAX_PATH` (260) bytes, while the fields accept more: `IDC_SEARCH` `2 * MAX_PATH`
(`rendlg.cpp:1643-1644`), the command line of *Rename using a command* 4,096
(`dialogs.cpp:806`). `LoadHistory` (`utils.cpp:15-16`) stops at the first item that fails to
load.

- **Reach:** type a search text (a long regular expression, or 130 accented letters) or a
  command of 260 bytes or more, run the rename (the text goes to the history), restart. At the
  plug-in's load `GetValue` fails with `ERROR_MORE_DATA` for that item
  (`src/salamdr6.cpp:2407-2413`; outside the registry worker thread the core also shows
  "Error Loading Configuration", `src/regwork.cpp:139-157`); the item **and every older item**
  of that history are not loaded. They stay in the registry until newer items overwrite their
  slots, so the failure repeats at every start.
- **The fix (`renamer.cpp:316-320`):** `SearchHistory` is read with `2 * MAX_PATH`,
  `CommandHistory` with the whole `buffer[4096]` - the sizes the fields store. (`MaskHistory`,
  `NewNameHistory`, `ReplaceHistory` already matched.)
- **Probe row:** write `Search History 0` (the key pattern of `CONFIG_SEARCHHISTORY`) = 300 x
  `a` and `... 1` = `b` into the plug-in's key, start the program, open Batch Rename: the
  *Search for* list holds both items (`CB_GETCOUNT` = 2; before 0), and no error box appears at
  load.

**Not sure about:** an item written by a version before interface 104 (code page, up to
`2 * MAX_PATH - 1` characters) can be longer as UTF-8 than the field's byte size and still
fails to load; not handled (a heap read would be the fix, with the field refusing the long
text anyway).

## 7. `dialogs.cpp:823` - `SetDlgItemText(HWindow, IDE_STDERR, StdError)` (A)

The captured error output of the user's own command, shown through the code page. A console
program writes in the OEM code page, the system code page or UTF-8 - the plug-in cannot know.
Left as it is; choosing a rule (try UTF-8, else OEM) is a decision of its own.

---

## 8. The `A` fallbacks of the `...U8` wrappers (`utils.cpp:109-153`, `:220-226`)

**The note:** when the UTF-8 conversion fails, `CreateFileA(fileName)`, `DeleteFileA`,
`SetFileAttributesA`, `CreateDirectoryA`, `RemoveDirectoryA` were called with the bytes -
"best fit can name another file; reachable only with a name that is not valid WTF-8".

**Found: real in the code, not reachable with the names the plug-in has.** Every caller passes a
name from the core's listing (`CSourceFile::FullName`), a new name read from a wide edit as
UTF-8, an undo entry of those, or the core's temporary file name (`rendlg4.cpp:16`, `:59`): all
valid WTF-8, for which `SplU8ToWExtAlloc` fails only without memory. But the fallback is the
dangerous kind - **`DeleteFileA` of bytes read in the code page with best-fit mapping can delete
another file** (CLAUDE.md, feature 104: `voilà` -> `voila`), and `DeleteFileU8` is what removes
the overwritten target (`rendlg3.cpp:123`) and the source after a copy (`:153`).

**The fix:** `RefuseNameNotU8()` (`utils.cpp:109-115`) sets `ERROR_INVALID_NAME` and returns
FALSE; the five wrappers call the `W` function or refuse - no `A` call with a name is left in
the file. The callers already treat FALSE / `INVALID_HANDLE_VALUE` as a failed operation and
show `FileError` with the reason ("(123) The filename, directory name, or volume label syntax
is incorrect.").

**Probe row:** none - no input reaches it. **Unit case:** not a pure function; a check would
call `DeleteFileU8("\xE9")` (invalid UTF-8) and expect FALSE with `ERROR_INVALID_NAME` and an
existing file `é` in the current directory still there.

**Not sure about:** with no memory the operation is now reported as "invalid name" instead of
being tried through the code page - accepted (the `A` call needs memory too).
