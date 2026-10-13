# Feature 131 - ZIP plug-in (`src/plugins/zip`)

> **Correction (review):** the record says `StrICmp` folds ASCII case only on UTF-8. It folds
> every byte through the code page's table, continuation bytes too (`VÍR` = `VÝR` on code page
> 1250); favourite names are compared with `SalNameOrderCompareCI` now (`dialogs2.cpp`).


Source: `specs/130-plugin-mixed-templates/triage/zip.md`, section 4 "Other defects seen".
**Nothing of the repository was built or run.** What was run are two small programs of my own,
compiled with `cl` (x64) outside the repository
(`%TEMP%\claude\...\scratchpad\t131\zr_favname.cpp`, `zr_setpath.cpp`; results quoted below).
Line numbers are those of the tree after the edits.

Changed files (9): `common.h`, `common.cpp`, `main.cpp`, `dialogs.cpp`, `dialogs2.cpp`, `add.cpp`,
`del.cpp`, `extract.cpp`, `iosfxset.cpp` (BOM and CRLF kept; `dialogs.cpp` / `dialogs2.cpp` have no
BOM and got ASCII only).

| # | Item | Verdict |
|---|---|---|
| 1 | favourite names: two encodings | FIXED |
| 2 | `main.cpp:350`, the 50-byte buffer | FIXED (real: the favourite was lost) |
| 3 | unbounded prefix copies (`add.cpp`, `del.cpp`, `extract.cpp`) | FIXED (bounded; not reachable with a normal translation) |
| 3b | `lstrcpyn` of the name into the progress line (`add.cpp:1687`, `del.cpp:142`) | FIXED (cut at a whole character; no visible change while the core cuts at 299 bytes) |
| 4 | `.set` file (`iosfxset.cpp`) | FIXED - a real defect follows for paths with letters outside ASCII |
| 5 | `common.cpp` `FormatMessage()` assumes 512 bytes | FIXED (bounded) |
| 6 | `dialogs3.cpp:185` archive comment through `A` calls | NOT A DEFECT that can be decided here - recorded |
| 7 | `prevsfx.cpp:128-146` | NOT A DEFECT (code-page settings, code-page sinks) |
| 8 | `add_del.cpp:391`, `main.cpp:191` the `©` literal | LEFT - cannot be judged without a build |
| 9 | core items (`src/zip.cpp:394`, `:269-287`, `src/salamdr3.cpp:1217`, `:1264`) | NEEDS A CHANGE OUTSIDE MY DIRECTORIES (not touched) |

---

## 1. Favourite settings of the self-extractor: one name, two encodings

**The note of 130:** the name is typed through `GetDlgItemTextA` (code page) and stored / loaded
with the core's registry service (UTF-8); a reloaded name with an accented letter is garbled in
the list box, the rename dialog and the favourites menu, and `CompareMenuItems` compares the two
encodings.

**Found: real.** Evidence before the change:

- typed: `dialogs.cpp:2046` `GetDlgItemText(Dlg, IDC_NAME, buf, MAX_FAVNAME - 1)` - code page, and
  only 48 characters although the edit's limit was 49 (`dialogs.cpp:2035`): the 49th typed
  character was dropped without a word;
- stored: `main.cpp:461` `registry->SetValue(..., REG_SZ, fav->Name, -1)` ->
  `src/regwork.cpp:218` `SalRegSetValueExW8` -> `src/salamdr6.cpp:2443-2485`: text that is valid
  UTF-8 is stored as it is, anything else is converted **from the code page** to UTF-16. So the
  registry holds the right UTF-16 letters for a code-page name;
- loaded: `main.cpp:350` -> `SalRegQueryValueExW8` (`src/salamdr6.cpp:2352-2430`): always
  **UTF-8**;
- shown: `dialogs2.cpp:942` `InsertMenuItem` (A), `:2066` / `:2118` `LB_ADDSTRING` (A),
  `dialogs.cpp:2034` `WM_SETTEXT` (A) - code-page sinks.

**How a user reaches it:** Pack (Alt+F5) into a `.zip` > self-extracting > *Advanced* >
*Favorites > Add*, name `Výchozí čeština`, OK. In that session everything is right. Restart the
program, open the same dialog: the Favorites menu and *Manage* show `VĂ˝chozĂ­ ÄŤeĹˇtina`
(UTF-8 bytes read as cp1250); *Rename* opens with the garbled text, and pressing OK there stores
the garbled text as the name for good. A name typed in the session and one loaded from the
configuration, equal for the user, were not found equal (`IDS_USEDNAME` not shown, two favourites
of one name).

**The fix - the name is UTF-8 from the dialog to the registry and back:**

- `common.h:178-185`: `MAX_FAVNAME` stays 50 and is now only the limit in characters (UTF-16
  units, the edit's `EM_SETLIMITTEXT`); new `MAX_FAVNAME_U8 = 3 * 49 + 1 = 148` is the size of
  `CFavoriteSfx::Name` (3 bytes per UTF-16 unit is the worst case of UTF-8 / WTF-8; a surrogate
  pair is 4 bytes for 2 units).
- `dialogs.cpp:2034-2036` (`CRenFavDialog::OnInit`): the name is put into the edit with
  `SetDlgItemTextU8` (`SetDlgItemTextW`); a text that is not UTF-8 falls back to the old A call.
- `dialogs.cpp:2047-2060` (`OnOK`): `GetDlgItemTextW` into 51 units, then `SplWToU8` into 148
  bytes. 50 or more units, or a failed conversion, is **refused** (the dialog stays open, nothing
  is stored, the old name is untouched); with the edit's limit of 49 units neither can happen -
  the test is there so that a later change of the limit cannot cut or empty a name.
- `dialogs2.cpp:942-964` (`CreateFavoritesMenu`): `InsertMenuItemW` with the name converted by
  `SplU8ToWAlloc`; the old A call only when the conversion fails.
- `dialogs2.cpp:2076-2088` `AddFavoriteNameToListBox`: `SendMessageW(LB_ADDSTRING)`; always
  exactly one item is added, so the list's indexes stay those of `Favorities` (the list box has
  no `LBS_SORT`, `lang/lang.rc:365`); used at `:2099` and `:2151`.
- `dialogs2.cpp:782-783` `CompareMenuItems`: the two work buffers are `MAX_FAVNAME_U8`.
- `dialogs2.cpp:2172-2174`: the remove question keeps `SplLegacyToU8` (a no-op for UTF-8); the
  comment says what is true now.
- `main.cpp:461` is unchanged: UTF-8 goes to the UTF-8 registry service.

**Names stored by older versions - what happens to each:**

| Stored by | In the registry (UTF-16) | Loaded now |
|---|---|---|
| any version, name typed in that session (code-page bytes) - the usual case | the right letters (`SalRegSetValueExW8` converts non-UTF-8 text from the code page) | right, as UTF-8 |
| a name that had been reloaded (UTF-8 in memory) and saved again | the right letters (valid UTF-8 kept) | right |
| a reloaded name that the user confirmed in the old *Rename* dialog while it was shown garbled | the garbled letters (`VĂ˝chozĂ­`) - the damage is in the stored data | as stored (garbled); the user renames it once |
| a code-page name whose bytes happen to be valid UTF-8 (cp1250 `Ă©` = `C3 A9`) | read as UTF-8 at the old save (`é`) | as stored; not repairable, practically never a real name |
| Open Salamander / older builds through `RegSetValueExA` | Windows converted from the code page - right letters | right |

Nothing is rewritten at load; the values are rewritten (as the same letters) at the next save of
the configuration, as always (`main.cpp:453` `ClearKey` + rewrite).

**Probe rows (need typing - NOT DRIVEN on the hidden desktop unless the edit is filled with
`WM_SETTEXT` W by the probe, which is how a probe can do it):**

1. Advanced SFX dialog > Favorites > Add; set `IDC_NAME` to `Výchozí čeština 日本`; OK. Expect:
   the menu item text read with `GetMenuStringW` = the same string; registry value
   `...\ZIP\Favorities\Favorite 1 Name` (REG_SZ) = the same string.
2. Restart; open the dialog. Expect: `GetMenuStringW` of the first favourite = the same string;
   *Manage*: `LB_GETTEXT` W of item 0 = the same string; *Rename*: `GetWindowTextW(IDC_NAME)` =
   the same string; OK without a change -> `IDS_USEDNAME` (see "not sure").
3. Negative control (build before): step 2 gives `VĂ˝chozĂ­ ...`.
4. Pre-seed the registry with `Favorite 1 Name` = 49 x `č` (a name the old dialog could not
   make, the new one can): expect it listed (item 2).

**Pure decision / unit cases:** none new in code; the size rule is
`MAX_FAVNAME_U8 >= 3 * (MAX_FAVNAME - 1) + 1`. Run outside the repository (`zr_favname.exe`):
49 x CJK = 147 bytes, 49 x `€` = 147 bytes, 24 emoji + a lone surrogate = 99 bytes - all fit 148.

**Not sure about:**

- Not compiled. `GetDlgItemTextW` on a control of a dialog created with `DialogBoxParamA`: the
  plug-in already does this in `GetDlgItemTextU8` / `SetDlgItemTextU8` (`common.cpp:352-382`) on
  the same kind of dialogs; the edit is not subclassed (`RenFavDlgProc` only passes theme
  messages).
- `CompareMenuItems` -> `SalamanderGeneral->StrICmp` (`src/common/str.cpp:138`, a byte table of
  the code page). On UTF-8 bytes it folds ASCII case only: `Výchozí` and `VÝCHOZÍ` are two names
  now (before: one, as long as both were code page), and accented names sort behind `z`. Not
  changed - an order / "same name" rule for display names would be a new decision.
- The refusal has no text of its own in the plug-in ("the name is too long" does not exist; the
  nearest are about files and masks). It shows the system text of `ERROR_BUFFER_OVERFLOW`
  ("The file name is too long.") through `GetErrorText` under the caption `IDS_ERROR`. Not
  reachable through the dialog.
- Seen, not changed: *Rename* + OK without changing the name answers "The name has already been
  used." (`dialogs.cpp:2067-2073` compares the name with itself). Old behaviour.

---

## 2. `main.cpp:350` - the 50-byte buffer

**The note:** "the UTF-8 form of a 49-letter name can be 98 bytes - the read then fails and the
favourite is not loaded."

**Found: real, and it is a loss.** `registry->GetValue(favKey, key, REG_SZ, temp.Name, 50)` ->
`SalRegQueryValueExW8`, `src/salamdr6.cpp:2407-2413`: when the UTF-8 form with its terminator
does not fit, `ERROR_MORE_DATA`; `GetValueAux` (`src/regwork.cpp:115-158`) returns FALSE (and,
when it runs outside the registry worker thread, shows "Error Loading Configuration" with the
system text - which of the two paths runs at the plug-in's load was not followed). The favourite
is skipped (`main.cpp:350` is the innermost `if`), the loop goes on with the next one.

- **Which names:** every name whose UTF-8 form has **50 bytes or more**. Measured
  (`zr_favname.exe`): 25 accented Latin or Cyrillic letters (50 bytes) fail, 24 load; 17 CJK
  characters (51 bytes) fail, 16 load; a mixed Latin name fails as soon as *characters +
  accented characters >= 50* - e.g. 45 characters of which 5 are accented (the old dialog
  allowed 48 characters, so such names could be made).
- **What the user loses:** the favourite itself - its name and the whole set of self-extractor
  options (target directory, command, texts, icon, message box). Not only for the session: the
  next `SaveConfiguration` (`main.cpp:451-477`) clears the `Favorities` key and writes only the
  favourites that are in memory, so the one that failed to load is deleted from the registry.
- **Reach:** create a favourite named with 25 or more accented letters (48 are allowed), close
  the program (configuration saved), start it, open the Advanced SFX dialog: the favourite is
  gone; after the next exit it is gone from the registry too.

**The fix:** `main.cpp:350-352` reads into `temp.Name` with `MAX_FAVNAME_U8` (148) bytes. Every
name either dialog could make fits: the old one at most 48 code-page bytes = at most 48 UTF-16
units = at most 144 bytes, the new one 49 units = at most 147 bytes. A value written by hand that
is longer still fails to load as before (and is then dropped at the next save) - not cut.

**Probe row:** write `Favorite 1 Name` = 30 x `ž` (REG_SZ) with valid `Favorite 1 Size` / `Data`
copied from a real favourite and `Number Of Favorities` = 1; start the program, open the dialog:
expect one favourite in the menu with that name (before: "(empty)"), and after closing the
program the three values still present (before: removed).

**Not sure about:** whether an error box appears at load in the old build (see above).

---

## 3. The unbounded prefix copies

**The note:** `extract.cpp:1970` buffer `maxNameLen + 128`, prefix copied without a bound
(`:2005-2006`); `add.cpp:1672-1673`, `del.cpp:115-116` the same into 1,072 bytes. "Fine for any
real translation, not checked by the code."

**Found: as the note says - not reachable with a normal translation.** The prefix is a resource
text of the language module (`IDS_ADDING`, `IDS_REMOVING`, `IDS_DELETING`, `IDS_TESTING`,
`IDS_EXTRACTING`; English "extracting: "). It overruns only when a translation is longer than
127 bytes (`extract.cpp`, heap) or about 1,070 bytes (`add.cpp`, `del.cpp`, stack). No user
input reaches it. The lengths of the shipped translations were not measured one by one.

**The fix (the rule "an unbounded copy becomes a bounded one"):**

- `common.h:174-176` `PROGRESS_PREFIX_SIZE 128` - the room for the prefix with its terminator.
- `extract.cpp:1970` allocates `maxNameLen + PROGRESS_PREFIX_SIZE`; `:2003-2007` copies the
  prefix with `SplU8CopyTrunc(progrTextBuf, PROGRESS_PREFIX_SIZE, sour)` (cut at a whole
  character, only when it is cut); the name behind it (at most `maxNameLen` bytes) always fits:
  127 + `maxNameLen` + 1.
- `add.cpp:1671-1674`, `del.cpp:114-117`: the same call; `progrPrefixLen` from `strlen`.

**3b - `add.cpp:1687-1688`, `del.cpp:142-143`:** the name behind the prefix was copied with
`lstrcpyn` (a byte cut) into what is left of 1,072 bytes; now `SplU8CopyTrunc` (a relative name
over about 1,050 bytes is shortened at a whole character). Shown only - the name used for
packing / deleting is `next->Name` / `curFile->Name`, untouched. **No visible change today:** the
core cuts every progress line byte-wise at 299 bytes anyway (`src/zip.cpp:269-287`, item 9).

**Probe row:** none worth automating (the text is the same for every real input). A unit case if
the copy is ever moved into a function: prefix of 127 / 128 / 200 bytes ending in a 2-byte
character -> result at most 127 bytes and valid UTF-8.

---

## 4. The `.set` file (`iosfxset.cpp`)

**The note:** "written to the exported `.set` file, the reader (`ImportSFXSettings`,
`zip2sfx.exe`) takes the bytes as they are; not touched."

**Who reads the file and in what encoding:**

| Reader | Where | Encoding it assumes |
|---|---|---|
| the plug-in's *Import* | `dialogs2.cpp:1077`, `:1112` -> `ImportSFXSettings` (`iosfxset.cpp:380`) | bytes as they are; the two **paths** (`sfxpackage`, `icon_file`) are then used as **UTF-8** (`chicon.cpp:25-44` `SplU8ToWExtAlloc`, `dialogs2.cpp:1086` compares with `FindDataNameU8` names); the texts (`dlg_text`, `dlg_title`, `button_text`, `vendor`, `link`, `mbox_*`, `target_dir`, `command`, `wait_for`) go to `A` controls and into the stub - **code page** |
| `zip2sfx.exe` (built by `vcxproj/zip2sfx/zip2sfx.vcxproj`, in `salamand.sln`, copied by `!populate_build_dir.cmd`) | `zip2sfx/zip2sfx.cpp:223-290`, `:416` -> the same `ImportSFXSettings` (compiled without `ZIP_DLL`) | everything **code page**: `CreateFile` (A) of `Settings.SfxFile` (`zip2sfx.cpp:302`) and of the icon file (`chicon.cpp:48-57`) |
| a person with a text editor | the comments are written for them (`WriteSFXComment`, `LoadStr` = code page) | code page |

**Writer before the change:** `ExportSFXSettings` wrote every value as it is in memory: the texts
in the code page, the two paths in **UTF-8** (`settings->IconFile` from `PickIconDlg` W ->
`SplWToU8`, `dialogs2.cpp:548`, `:573`; `settings.SfxFile` = the plug-in's directory + `sfx\` +
the package name from `GetModuleFileNameU8`, `dialogs2.cpp:1181-1186`).

**A real defect follows** (a path with accented letters stored in the file and read back wrong):

1. *Export, then `zip2sfx.exe`.* Choose an icon from `C:\Ikony\žluťoučký.ico` (or have the
   program installed in a folder with an accented name), *Export* to `my.set`, run
   `zip2sfx -smy.set archive.zip`. The file holds `icon_file="C:\Ikony\Ĺľlu...ico"` (UTF-8
   bytes); `zip2sfx` opens that byte string through the code page -> "cannot open icon file"
   (`STR_ERROPENICO`) or, for the package path, `STR_ERROPEN`. The exported file was useless for
   the tool it is exported for.
2. *A code-page `.set`, then Import.* A `.set` written by hand, by an older version (before
   interface 104) or for `zip2sfx` with `icon_file="C:\Ikony\žluťoučký.ico"` in the code page:
   the plug-in takes the bytes as UTF-8, `SplU8ToWExtAlloc` fails, `LoadIcons` returns 1 and the
   import ends with the "unable to open the icon file" error (`dialogs2.cpp:1678-1724`).
   The same for an accented package name (`IDS_NOLANGFILE`).

(Export followed by Import in the plug-in itself was right before: UTF-8 out, UTF-8 in.)

**The fix (`iosfxset.cpp`, inside `#ifdef ZIP_DLL` - `zip2sfx.exe` compiles the file without it
and is unchanged):**

- `ExportPath` (`:349-363`), used for `sfxpackage` (`:1066`) and `icon_file` (`:1187`): a path
  with letters outside ASCII is written **in the code page when that loses nothing**
  (`WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS)` and no default character) - the form
  `zip2sfx.exe` and an editor understand and the form of the rest of the file; a path the code
  page cannot hold stays **UTF-8** as before (`zip2sfx.exe` could not open it in any form; the
  plug-in's import still reads it).
- `CanExportPathInCodePage` (`:336-345`, `inline`, pure): the code-page form is not used when its
  bytes are not ASCII and happen to be valid UTF-8 (the import below would read them as UTF-8) -
  then UTF-8 is written, so **export -> import in the plug-in is always the identity**.
- `ImportedPathToU8` (`:320-331`), called right after the two `GetString` calls (`:480`,
  `:579`), before the relative-path join: ASCII untouched; valid UTF-8 kept; anything else
  converted from the code page to UTF-8 (`SplLegacyToU8Alloc`). A converted path that does not
  fit the `MAX_PATH`-byte field is **refused** (the field is emptied - the import then reports
  the missing package / icon), never cut.

**Run outside the repository** (`zr_setpath.exe`, the three functions copied, ACP 1250):

```
plain ASCII                -> written as it is            -> read back equal
C:\ikony\žluťoučký kůň.ico -> code page (9E 6C 75 9D ...) -> read back equal
C:\ic\café.ico             -> code page (... E9 ...)      -> read back equal
C:\ic\日本.ico             -> UTF-8 (E6 97 A5 ...)        -> read back equal
C:\ic\Ã©.ico               -> UTF-8 (not in cp1250)       -> read back equal
C:\ic\Ă©.ico (cp bytes C3 A9 = valid UTF-8) -> UTF-8      -> read back equal
legacy code-page bytes "caf\xE9" -> 63 61 66 C3 A9 (UTF-8)
a path too long after the conversion -> "" (refused)
```

**Probe rows:**

1. Advanced SFX dialog; choose the icon `C:\Ikony\žluťoučký.ico` (the icon picker needs a
   person - or pre-load a favourite whose blob holds that path); *Export* to `t.set`. Expect in
   the file (bytes): `icon_file="C:\Ikony\` + `9E 6C 75 9D 6F 75 E8 6B FD` + `.ico"` on a cp1250
   system (before: `C5 BE 6C 75 C5 A5 ...`).
2. *Import* `t.set`: no error, the icon shown; *Export* again: byte-identical file.
3. *Import* a hand-made file with `icon_file` in the code page: no error (before: "unable to
   open the icon file").
4. `zip2sfx.exe -st.set some.zip` in a console: an `.exe` is made (before: `STR_ERROPENICO`).
   A console program - can be driven without a GUI.

**Unit cases (`CanExportPathInCodePage`, pure but tied to the ACP for its inputs):** ASCII ->
TRUE; `"caf\xE9"` -> TRUE; `"\xC3\xA9"` -> FALSE; a torn sequence `"\xC3"` -> TRUE.

**Not sure about:**

- Not compiled (the logic was compiled and run as a copy; `SplLegacyToU8Alloc` comes from
  `splloadstru8.h`, which `common.h:11` includes).
- A system whose ACP is UTF-8 (65001): `WideCharToMultiByte` with `WC_NO_BEST_FIT_CHARS` and a
  default-character flag fails there -> the path is written as UTF-8, which is the code page.
  Reasoned, not run.
- The texts of the file stay code page (they are code page in memory, `A` controls); a text
  with a letter outside the code page was already `?` when it was typed. Not part of this item.
- Seen, not changed (paths cut silently, all old): `GetString(..., MAX_PATH, ...)`
  (`iosfxset.cpp:178-210`) stops copying at 259 bytes; `HandlePathRelativeToZip2Sfx`
  (`:292-312`) cuts `zip2sfxDir` at `MAX_PATH`; `dialogs2.cpp:1186` `lstrcpyn(settings.SfxFile,
  fullPath, MAX_PATH)` cuts the full package path before the export. All three produce a path
  that is not found (an error message), never a write under a wrong name; they belong to the
  `MAX_PATH`-sized `CSfxSettings` fields (`typecons.h:238-250`), which the stub's format shares.
- `ExportSFXSettings` still formats with `sprintf` into `buf1[2048]` / `buf2[2048]`
  (`ExportString` doubles every quote): the largest field is `SE_MAX_TEXT`; sizes not audited.

---

## 5. `common.cpp:2747-2760` `FormatMessage(buffer, errorID, lastError)`

**The note:** assumes a buffer of at least 512 bytes and copies the resource text with `lstrcpy`;
every caller gives 1,024.

**Found: right for every existing text; formally unbounded,** and with a resource text of 512
bytes or more `512 - lstrlen(buffer)` would become a huge unsigned size for the system call. No
user input reaches it.

**The fix:** `lstrcpyn(buffer, LoadStr(errorID), 512)`, the length taken once, the system text
appended only when at least one byte is left. Code-page text as before (row 16 of 130: all
pieces code page).

**Probe row:** none (no reachable difference).

---

## 6. `dialogs3.cpp:185` - the archive comment through `SetDlgItemTextA` / `GetDlgItemTextA`

**Found:** `PackObject->Comment` is the raw byte string of the archive's end record
(`common.cpp:1092-1112`, `:1157-1178`); it is shown and read back through the code page
(`dialogs3.cpp:185`, `:264`) and written back as the same bytes (`add.cpp:3444-3450`). The ZIP
format gives the archive comment no encoding; the plug-in's rule "the bytes are the system code
page" is consistent in both directions (what is typed is what is stored and shown again on the
same system). A comment written by another program in UTF-8 or OEM is shown garbled, and a
letter outside the code page cannot be typed. **Not changed:** making it UTF-8 would change what
existing archives show and what other tools read; it is a decision about the format, not a fix.

## 7. `prevsfx.cpp:128-146`

Code-page settings into `A` calls - consistent (130 said the same). Not a defect.

## 8. The `©` literal (`add_del.cpp:391`, About `main.cpp:191-196`)

`src/versinfo.rh2:21` holds `©` in a narrow literal; no `/utf-8` / `/execution-charset` in the
plug-in's property sheets. With a BOM source MSVC converts narrow literals to the **code page of
the build machine**, so the byte is `A9` when the build machine is cp125x - and whether the
header has a BOM and what a user on another code page sees was not determined (needs the built
binary). Left as recorded by 130.

## 9. Core items of the note

`src/zip.cpp:394` (title, fixed by the maintainer after 130 - see the correction on top of the
130 note), `src/zip.cpp:269-287` (progress line cut at 299 bytes inside a character),
`src/salamdr3.cpp:1217`, `:1264` (`LoadStr` + UTF-8 path) and the 128-byte `errBuf` cut: all in
the core - not my directories, nothing done.
