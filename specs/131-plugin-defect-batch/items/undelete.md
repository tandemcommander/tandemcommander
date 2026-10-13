# Feature 131 - Undelete plug-in (`src/plugins/undelete`)

Source: `specs/130-plugin-mixed-templates/triage/undelete.md`, section 4 "Other defects seen".
**Nothing was built or run** - this plug-in needs a volume with deleted files and a GUI to
show anything; everything below is from reading. Line numbers are those after the edits.

Changed files (6): `library/miscstr.h`, `library/miscstr.cpp`, `library/fat.h`,
`library/ntfs.h`, `fs1.cpp`, `dialogs.cpp`. BOM and CRLF kept.

| # | Item | Verdict |
|---|---|---|
| 1 | virtual directory names from code-page resource texts (`fat.h:1558`, `2298`, `2303`, `ntfs.h:815`) | FIXED - the names are UTF-8 like every other name of the plug-in (and like exFAT's already were) |
| 2 | `fs1.cpp:201` column text: code page, and the resource text used as a `sprintf` format | FIXED |
| 2b | `fs1.cpp:223-224` column name / description | NOT A DEFECT (the core draws a column header through the code page) |
| 3 | `dialogs.cpp:836-864` wraps `GetCommonFSOperSourceDescr` | NEEDS A CHANGE OUTSIDE MY DIRECTORIES - recorded only |
| 4 | `dialogs.cpp:486-492` `strcpy` + `strcat` into `buf[1024]` | FIXED (bounded; not reachable with a real text) |
| 5 | `dialogs.cpp:879` `GetWindowText` A into `title[100]` | NOT A DEFECT |

---

## 1. Virtual directory names

**The note of 130:** `{All Deleted Files}`, `{Metafiles}` and `Directory%06d` are loaded with
`String<char>::LoadStr` = `LoadStringA` (code page, `library/miscstr.cpp:70`) and used as the
**names** of directories of the snapshot, where every other name is UTF-8. The shipped
translations are accented: `{Všechny vymazané soubory}`, `{Metasoubory}`, `Adresář%06d` (cs),
`{Alle gelöschten Dateien}` (de), `{Tous les fichiers supprimés}`, `{Métafichiers}`,
`Répertoire %06d` (fr), `{Minden törölt fájl}`, `{Metafájlok}` (hu), `{Všetky vymazané súbory}`,
`Adresár%06d` (sk); Dutch and Spanish are ASCII. exFAT loads the wide text and is right.
"How the panel shows it, and whether a path through it survives, was not examined."

### Where the name goes (followed)

The name is `FILE_NAME_I<char>::FNName` of the virtual directory's record. From there:

| Place | Code | What a code-page name does there |
|---|---|---|
| **Panel listing** | `fs2.cpp:462` `fd.Name = DupStr(di->FileName->FNName)` -> core | the core takes names as UTF-8; a name that is not valid UTF-8 is drawn through its byte-wise fallback (`src/fileswn4.cpp:711`, `:727-729`, `:804-805`: "invalid UTF-8 (should not happen): keep the byte-wise call") - so it **looks right** on a system whose code page has the letters. On another code page (a Czech UI on an English Windows) `LoadStringA` already gave `{V?echny vymazan? soubory}` |
| **Entering the directory** | `fs1.cpp:130-134` `SalPathAppend(newPath, file.Name)` -> `ChangePanelPathToPluginFS` -> core -> `ChangePath` | the `del:` path now holds bytes that are not UTF-8; it travels through the core (path line, history, hot paths, window title - **not followed in the core**) and comes back as `userPart` |
| **Parsing the path back** | `fs2.cpp:327-383`: the path is split at `\` and each component compared with `FNName` - `strcmp` first, then `namecmp` (`SalNameOrderCompareCI`, UTF-8 rule) | agrees with the listing only as long as the core returns the very same bytes. A path that went through the registry does **not**: the registry service converts non-UTF-8 text from the code page to UTF-16 on write and gives **UTF-8** on read (`src/salamdr6.cpp:2443-2485`, `2352-2430`), so a remembered path `del:C:\{Všechny vymazané soubory}` of an earlier session no longer equals the code-page `FNName`: `IDS_PATHNOTFOUND` (mode 3) or the path silently shortened to the root |
| **Restoring** (F5 on the virtual directory itself, or on a selection that holds one - e.g. `Adresář000123`, the folder of orphaned FAT clusters, which is where the lost files are) | `fs2.cpp:1445` `list.AddFile` -> `FL_ITEM::Name = DupStr(FNName)` -> `CopyDir` (`fs2.cpp:1092-1141`): `AppendPath(path, targetPath, name)` -> `SafeFileCreate(path, ..., TRUE /*directory*/)` in the core | **the name of the folder created on disk** is built from code-page bytes inside a UTF-8 path. What the core's `SafeFileCreate` does with a path that is not valid UTF-8 was not followed (it fails, or converts through the code page); in neither case is the result guaranteed, and on a code page without the letters the name holds `?` - a character no file name may have, so the folder cannot be created and **nothing under it is restored** |
| Files inside `{All Deleted Files}` | `fat.h:2317` / `ntfs.h:1091...`: the files are the same records, their own names are UTF-8 | unaffected - only the directory's name is the resource text |

Nothing else reads the texts: the virtual directories are found by reference
(`ntfs.h:783-787` `FileRef == ref`), not by name; `IDS_ALLDELETEDFILES` / `IDS_METAFILES` /
`IDS_VDIRECTORY` are loaded only where the names are made (`fat.h:1558`, `2302-2314`,
`ntfs.h:815`, `exfat.h:614`, `620`).

### Decision: UTF-8 in all places - why it is safe

- Listing, parsing and restoring all use the one string `FNName`. Making it UTF-8 changes all
  three together; they cannot disagree with each other.
- It is the state exFAT volumes already have (`exfat.h:614-621` passes
  `String<wchar_t>::LoadStr(...)`, converted like a name read from the volume) and the state of
  every English or Dutch or Spanish user (ASCII). No new path through the code is opened: the
  virtual name becomes an ordinary UTF-8 name like those of the deleted files next to it.
- The restore target gets a valid UTF-8 path, which is what `SafeFileCreate` and the plug-in's
  own `W` calls (`fs2.cpp:954-984`, `1079-1084`) expect.
- A `del:` path remembered by the core comes back as UTF-8 and now equals the listing.

### The fix

- `library/miscstr.h:56-60`, `library/miscstr.cpp:378-395`: new
  `String<CHAR>::NewVirtualDirName(int resID, DWORD number, BOOL useNumber)` (specialised for
  `char`, like the other functions of the class). The text is loaded from the UTF-16 resource
  (`String<wchar_t>::LoadStr`) and converted with `SplWToU8` (WTF-8, the conversion of the names
  read from the volume); only if that fails the code-page text is used, as before. With
  `useNumber` the text is the `printf` format for the number, formatted with a bound
  (`_snprintf_s`, tail trimmed) - it was `vsprintf` into `CHAR name[100]` / `text[100]`.
- `library/fat.h:1557-1565` (`Directory%06d` of an unreferenced cluster), `:2301-2320`
  (`{All Deleted Files}`, `{Metafiles}`): the name from `NewVirtualDirName`; `AddFileOrDir`
  copies it (`fat.h:2131` `NewStr`), the temporary is deleted; low memory is reported as
  before (`IDS_LOWMEM`).
- `library/ntfs.h:814-818` (`GetVirtualDirectory`): `FNName = NewVirtualDirName(resID, ref,
  resID == IDS_VDIRECTORY)`. Before, all three texts were used as a format with the number;
  only `Directory%06d` has a `%`, so the result is the same for every shipped text, and a `%`
  in a translation of `{All Deleted Files}` is no longer read as a conversion.
- exFAT untouched.

The library's templates are instantiated for `char` only (`fs2.cpp:280-286`;
`undelete.vcxproj` is the only project that compiles `library/miscstr.cpp`), so one
specialisation is enough - the same pattern as `NewFromUnicode`, `LoadStr`, `AddNumberSuffix`.

### How a user reaches it (before the fix)

Czech (German, French, Hungarian, Slovak) user interface; *Plugins > Undelete*, an NTFS or FAT
volume.

1. Restore the virtual folder: select `{Všechny vymazané soubory}` in the root (or
   `Adresář000042` on a FAT volume after a scan of the vacant clusters), F5 to `D:\Zachrana\`.
   Expected by the user: `D:\Zachrana\{Všechny vymazané soubory}\...` with the files. Before:
   depends on the core's handling of a non-UTF-8 path - not measured; on a system code page
   without the letters the folder cannot be created at all.
2. Enter `{Všechny vymazané soubory}`, close the program with the panel there, start it again
   (or pick the path from the directory history / a hot path): before, "path not found" or the
   root is shown instead.

### Probe rows

A probe needs a volume it may read raw (an image file works: `ChangePath` accepts the path of
an image, `fs2.cpp:106-113`) - e.g. a small FAT32 / NTFS image with two deleted files, prepared
once and kept in `specs/131-*/probe`.

1. Czech UI, open `del:<image>`: the first panel item's name read from the listing (the probe's
   usual `GetPanelItem` seam / the panel's accessible name) = `{Všechny vymazané soubory}` as
   UTF-8 (`7B 56 C5 A1 ...`), before `7B 56 9A ...`.
2. Change the panel path to `del:<image>\{Všechny vymazané soubory}` given as UTF-8: the panel
   lists the deleted files (before: path not found).
3. Select that folder in the root, F5 to an empty temporary folder: a folder of exactly that
   name exists there (`FindFirstFileW`) and holds the two files with their sizes.
4. FAT image with an orphaned directory cluster: the item `Adresář000NNN` exists, enters and
   restores the same way.
5. Negative control: English UI - all rows identical before and after.

### Unit cases

`NewVirtualDirName` is not pure (it loads a resource). The pure part is "format a UTF-8
template with one number, bounded": `"Adresář%06d"`, 42 -> `Adresář000042` (15 bytes);
a template of 1,100 bytes -> at most 1,055 bytes, valid UTF-8.

### Not sure about

- **Not compiled.** `String<wchar_t>::LoadStr` used from the `char` specialisation (the same
  call is in `FormatResU8`, `miscstr.cpp:371`); the new member is declared in the class
  template and defined only as a `char` specialisation in `miscstr.cpp`, which is how
  `NewFromUnicode` and the others are done - the calls in `fat.h` / `ntfs.h` are instantiated
  in `fs2.cpp` and resolved by the linker.
- What the core did with the code-page `del:` path and with `SafeFileCreate` of a non-UTF-8
  path was **not followed**; the "before" columns above say so. The fix does not depend on it.
- A stored path of an older session holding the code-page form cannot exist as such (the
  registry is UTF-16); nothing to migrate.
- Other things seen in the same functions, not changed: `fs2.cpp:327-331` `temp[MAX_PATH]` -
  a `userPart` longer than 259 bytes is cut by `lstrcpyn` before it is split (the path walk
  then stops at the cut component: "path not found" or a shorter path - a navigation, never a
  restore target); `fs1.cpp:107-130`, `fs2.cpp:1108` further `MAX_PATH`-byte path buffers of
  the plug-in (feature 115 made the restore refuse instead of cut, `fs2.cpp:647-673`).
  `fat.h:2141` `delete fn->FNName` for a `new[]` array (old).

---

## 2. `fs1.cpp` `GetSzText`: the *Condition* column

**The note:** `sprintf(TransferBuffer, String<char>::LoadStr(resID))` - a resource text used
as the format string, and a code-page text handed to the panel's column; "how the core shows a
column text that is not valid UTF-8 was not examined."

**Found:**

- The core takes a column's text as **UTF-8** and falls back to a byte-wise `A` draw when the
  bytes are not valid UTF-8 (`src/fileswn4.cpp:905-908`, `:919-924`, `:970-973`, `:993-996`).
  So `Dobrý` (cs, `44 6F 62 72 FD`) is drawn right through the fallback. It is wrong when the
  code-page bytes **are** valid UTF-8 by chance - Chinese `未知` (GBK `CE B4 D6 AA`) decodes as
  `δ֪` - and on a code page without the letters. With the eight shipped languages no text
  hits this (zh-CN is off in `languages.cfg`), so today the column looks right: a defect by
  contract, visible only for some languages.
- The format-string use is real but not reachable: none of the five texts
  (`IDS_CONDITION_*`) has a `%` in any translation.

**The fix (`fs1.cpp:200-214`):** the text is taken from the UTF-16 resource and converted with
`SplWToU8` straight into `TransferBuffer` (`TRANSFER_BUFFER_MAX` = 1,024, `spl_com.h:435`);
`*TransferLen` is the byte count without the terminator; no `sprintf`. If the conversion fails
the code-page text is copied with a bound.

**Probe row:** Czech UI, detailed view of `del:<image>`: the *Stav* cell of a deleted file
reads `Dobrý` / `Zachovalý` / `Neplatný` / `Ztracený` (screenshot, or the probe's cell-text
seam); unchanged before / after on a cp1250 system - the difference shows only with the
Chinese language module enabled (`未知`, before `δ֪`).

## 2b. `fs1.cpp:223-224` column name and description

`lstrcpy(column.Name, LoadStr(IDS_CONDITION))` - code page. The core draws a column header
with `TextOut` (A) (`src/filesbx2.cpp:229-230`, `:249`) and fills its own columns with
`LoadStr` (`src/fileswn9.cpp:2226-2228`): a header is code-page text by the core's own rule.
Not a defect, not changed. (`lstrcpy` into `COLUMN_NAME_MAX` is unbounded formally; the texts
are one word.)

---

## 3. `dialogs.cpp:836-864` - the Restore dialog's source line

**The note:** the label read with `GetDlgItemText` (A, code page) is a format for `text2` from
the core's `GetCommonFSOperSourceDescr`, which itself composes a code-page `LoadStr` text with
the UTF-8 file name (`src/zip.cpp:3997-3999`); recorded, "it needs the core".

**Found: unchanged, and still needs the core.** `dialogs.cpp:836-865`:

- one item: the name is cut out between the quotes (`:843-850`), the sentence
  `text1(text2 with %s)` is composed in the code page and given to
  `SalamanderGUI->SetSubjectTruncatedText(label, path, fileName, ...)` with the name separate -
  whether that core service reads `path` as UTF-8 or code page was not followed;
- several items: `SetDlgItemText` (A) of code-page text + numbers - right.

The name inside `text2` is UTF-8 inside a code-page sentence; the plug-in cannot make the two
agree without either a UTF-8 variant of the core service or a way to get its template.
Bounds seen: `text1[200]`, `text2[MAX_PATH + 100]` (a name over about 300 bytes is cut by the
core, possibly inside a character), `path[MAX_PATH + 300]` with `_TRUNCATE` and no tail trim,
`fileName[MAX_PATH]` guarded by `:845`. All display only; the restore uses the panel items.

**What the core change would be:** `GetCommonFSOperSourceDescr` returning an all-UTF-8 sentence
(or a `...U8` twin), and this dialog loading its own label wide. Belongs with the two places
feature 127 deferred. **No code changed here.**

**Reach (for the record):** Czech UI, focus a deleted file `žluťoučký.txt`, F5: the line
"Obnovit soubor "..." do:" shows the name garbled when the sentence around it has an accented
letter.

---

## 4. `dialogs.cpp:484-493` - the volume enumeration error

`strcpy(buf, LoadStr(IDS_VOLENUMERATE))` + `strcat(" ")` + `FormatMessage` (A) into
`buf[1024]`: all code page, shown by `SalMessageBox` - right. Formally unbounded (a resource
text of 1,023 bytes or more). Now `lstrcpyn(buf, ..., sizeof(buf) - 1)`, which leaves room for
the space and at least one byte for the system text. No reachable difference.

## 5. `dialogs.cpp:881` - `GetWindowText` (A) into `title[100]`

The dialog's own caption (a resource text) handed to the folder picker's overload that takes
code-page texts (`shared/splfiledlg.h`): consistent. A caption over 99 bytes would be cut -
there is none. Not a defect.
