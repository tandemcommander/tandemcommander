# Research: feature 127 (GitHub issue #7)

## R1 - Reproduction (0.1.9, Czech, hidden desktop)

`probe/mixed_result_before_v019.txt`:

- **LOG** (exact, `LVM_GETITEMTEXTW`): `Chyba při čtení adresáře: (5) PĹ™Ă­stup byl odepĹ™en.`
- **STATUS** (capture + recognition, 5 captures): `Vyhledávání:` right, the file name garbage.
- **BOX** (window text of the message, exact): `Chyba při čtení adresáře "<path>".` right,
  `(5) PĹ™Ă­stup byl odepĹ™en.`; the recognition of the drawn box agrees.

All three cases of the report confirmed. Mechanism as reported: the composed bytes are not
valid UTF-8, the sink's wide path refuses them and the fallback shows everything as code page.

## R2 - The guard

With the two additions the report proposes (`GetErrorText(` counts as a UTF-8 argument;
`params.Text =` / `log.Text =` count as sinks) `tools/check_encoding.py --rule
mixed-composition` reports **22** places: the report's 21 and `callstk.cpp`
(`InformAboutIconOvrlsHanCrash` - the handler's name is read with `RegEnumKeyExA`, code page
like the template: an allowed exception, marked).

- **Decision**: take the extension. It stays a heuristic (a sink within 14 lines); the four
  `codetbl.cpp` places and the ones of R3 are outside its reach - the inventory script
  `probe/scan_mixed.py` lists every candidate for a person to triage.

## R3 - The whole class in the main program

`probe/scan_mixed.py --core`: 130 compositions with a `LoadStr()` template, **46** with a name
or error-text argument. A separate agent read every sink (read-only) and searched for
compositions without a printf call. Result:

**Fix here**

| Place | What the user sees |
|---|---|
| the report's 21 (`dialogs3`, `fileswn5` x2, `fileswn6` x6, `find` x5, `icncache` x2, `mainwnd4` x3, `salamdr1` x2) | message boxes, Find log |
| `codetbl.cpp` x4 | errors in the viewer's `convert.cfg` |
| `finddlg1.cpp` status base, `find.cpp` duplicates text x2 | Find status line |
| `finddlg1.cpp` x3 (titles with `IDS_FF_NAME` / `IDS_FF_NAMED` + masks) | Find window title with a non-ASCII mask (cs, sk, hu) |
| `fileswn5.cpp` x2 (twins: command + `IDS_TOOLONGNAME`) | viewer / editor command too long |
| `fileswn3.cpp` `IDS_PATHINARCHIVENOTFOUND` | path not found in an archive (fr, hu, sk) |
| `fileswn9.cpp` `IDS_CANNOT_CREATE_UNC_NAME` | UNC name cannot be made (cs, fr, hu, sk) |
| `fileswn6.cpp` `IDS_INFODLGTYPE9/10` + junction target | Properties of a junction / link |
| `fileswn8.cpp` x2 `IDS_COPYDLGTITLE` / `IDS_MOVEDLGTITLE` | the operation's title sentence (its twin a few lines above already uses `LoadStrU8`) |
| `fileswn5.cpp` x2 `IDS_VIEWWITH_EXTERNAL` / `IDS_EDITWITH_EXTERNAL` + command | View With / Edit With menu (the command comes from the configuration, UTF-8) |
| `fileswn6.cpp` `IDS_NEWNAME_COPY` / `IDS_NEWNAME_OF` | **a file name**: the generated "copy" name (sk `Kópia`, hu) |

**Right as they are - do not touch**

| Place | Why |
|---|---|
| `dialogs4.cpp` / `dialogs5.cpp` font description | the face name comes from `LOGFONTA`: code page like the template |
| `plugins2.cpp` x7 start-up progress | plug-in file names are deliberately code page there (feature 069) |
| `drivelst.cpp` OneDrive items | the template is ASCII in every language |
| `drivelst.cpp` reconnect texts | reached only before Windows 7 |
| `callstk.cpp` | see R2 |

## R4 - Needs a change together with plug-ins (recorded in NEXT-WORK, not done)

- `CSalamanderGeneral::GetCommonFSOperSourceDescr` (`zip.cpp`): FTP and Undelete wrap its
  result in their own code-page sentences; a UTF-8 result inside a code-page wrapper would
  garble the word for every item, not only for accented names.
- `salamdr3.cpp` `IDS_NAMEUSEDFORFILE` / `IDS_CREATEDIRFAILED` with a name: the text is used
  only by ZIP, which prefixes its own code-page text.
- Other plug-ins: `scan_mixed.py --plugins` lists 137 candidates (FTP 86, SFTP 17, ZIP 15,
  ...). FTP has its own conventions for server texts (NEXT-WORK B-3 already warns that a naive
  sweep regresses it).

## R5 - `LoadStrU8`

Rotating 10,000-byte buffer of its own; results stay valid, several per expression are fine
(used so already). Unlike `LoadStr` it has **no retry**: when the converted text does not fit
the rest of the buffer (the pointer wraps only when under 200 bytes remain) the conversion
fails and the caller gets `ERROR LOADING STRING`. With more callers and longer templates this
becomes reachable.

- **Decision**: on a failed conversion with the pointer past the start, wrap and convert again.

## R6 - Bounds and cuts

A UTF-8 template is longer than the code-page one (up to 3 bytes a letter). Every unbounded
`sprintf` into an array that is touched becomes `_snprintf_s(..., _TRUNCATE, ...)`; where a
path or name is part of the text the result passes `SalU8TrimIncompleteTail` so that a cut
never leaves half a character (which would make the whole text invalid again). The Find
status line's `CSearchingString::Set` cuts with `SalFindTrimTornTail`; its base grows with
the UTF-8 prefix (`char buf[300]` in the dialog's constructor).

## R7 - Registry Editor

`fs2.cpp` `IDS_ENUMKEY` x2 (Windows error text), `fs3.cpp` `IDS_CONFIRNNONEMPTYDELETE`
(`f->Name`), `IDS_REPLACEVAL` (`fullNameA`), `utils.cpp` the operation error (template +
`SG->GetErrorText`): UTF-8 arguments in code-page templates, sinks are the core's message box
and error dialog. Fixed with the plug-in's `LoadStrU8(resID, buf, size)` (feature 124).
Left: the plug-in's `%ls` messages (`fs5.cpp`, `ErrorHelper`) are consistently code page but
lose letters outside the code page - a separate matter (recorded).

## R8 - Tests

| Row | Check |
|---|---|
| LOG | exact text of the log row (`LVM_GETITEMTEXTW`) |
| STATUS | capture of the status line during a 12 GB sparse-file content search |
| TITLE | the Find window's title with an accented mask (window text, exact) |
| BOX | the Copy error box: window text exact + recognition of the drawing |
| COPYNAME | Slovak: copy a file into its own folder, read the new name from the disk |
| REGDEL | Registry Editor: delete a non-empty key with an accented name - the question's text |
| English | LOG and BOX in English: unchanged texts |
| guard | 22 -> 0; a re-broken line is reported |
