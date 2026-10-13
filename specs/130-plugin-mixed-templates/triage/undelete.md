# Triage: undelete (feature 130)

Read: every `LoadStr(` use (`String<char>::LoadStr`, `String<CHAR>::LoadStr`,
`String<wchar_t>::LoadStr`) in `dialogs.cpp`, `fs1.cpp`, `fs2.cpp`, `restore.cpp`, `undelete.cpp`,
`library/miscstr.cpp`, `library/fat.h`, `library/exfat.h`, `library/ntfs.h`, `library/os.h`
(78 uses), and the helpers `String<char>::Error`, `SysError`, `PartialRestore`. **No source change
was needed.** Not built, not run.

## 1. Encoding of the names where they meet the texts

- The plug-in instantiates its library for `char` (`fs2.cpp:280-286`, `undelete.h:252`); names
  read from NTFS / exFAT / FAT are converted from UTF-16 to **UTF-8 (WTF-8)** in
  `String<char>::CopyFromUnicode` (`library/miscstr.cpp:297-313`); volume labels in
  `library/os.cpp:360`. Paths from the core are UTF-8.
- `String<char>::LoadStr` is `LoadStringA` - **code page** (`library/miscstr.cpp:70`); it is the
  plug-in's own loader with its own rotating buffer, not the core's.
- The error helpers were made UTF-8 by feature 114: `FormatResU8` loads the template from the
  UTF-16 resource and converts it (`library/miscstr.cpp:368-376`), `SysError` appends
  `FormatMessageW` text converted to UTF-8 (`library/miscstr.cpp:398-410`).

## 2. Compositions

| Site | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `library/miscstr.cpp:386-415` `SysError`, `418-430` `Error`, `433-455` `PartialRestore` | any | UTF-8 template (`FormatResU8`), UTF-8 names (`fs2.cpp:1014`, `1031`), `FormatMessageW` -> UTF-8 | `SalMessageBox` / `SalMessageBoxEx` | RIGHT AS IT IS (feature 114) |
| `dialogs.cpp:486-494` | `IDS_VOLENUMERATE` | + `" "` + `FormatMessage` A text - all code page | `SalMessageBox` | RIGHT AS IT IS |
| `dialogs.cpp:75-78` | plural template | a number | `SetDlgItemText` A | RIGHT AS IT IS |
| `fs2.cpp:1486-1492` | `IDS_TEMPDIR` | two drive letters (`%c`, ASCII) | `SplBrowseForFolderU8`, the overload that takes code-page texts (`shared/splfiledlg.h:452-462`) | RIGHT AS IT IS |
| `fs1.cpp:201` | condition text (`sprintf(buf, text)`) | a resource text alone, used as a format | panel column (`TransferBuffer`) | RIGHT AS IT IS as a composition; see section 4 |
| `fs2.cpp:661`, `1352`, `1357`, `1406`, `1552`, `1690`; `restore.cpp:758`, `786`; `undelete.cpp` | a resource text alone (error text, title, wait window) | name separate where there is one | core services | RIGHT AS IT IS |
| `undelete.cpp:287-293` About | name, description, literals | all code page | `SalMessageBox` | RIGHT AS IT IS |
| `dialogs.cpp:836-864` Restore dialog, source line | the label of the dialog read with `GetDlgItemText` A (code page) | `text2` from the core's `GetCommonFSOperSourceDescr`, which itself composes a code-page `LoadStr` text with the UTF-8 file name (`src/zip.cpp:3997-3999`) | `SalamanderGUI->SetSubjectTruncatedText` (the name passed separately) or `SetDlgItemText` A (`dialogs.cpp:864`) | RECORDED - the mixed text is produced by a **core** service (one of the two places feature 127 deferred: "hand a composed text to plug-ins which wrap it in their own code-page sentences"); a fix here alone cannot make the pieces agree. In a translated UI the file name in "Restore file "..." to:" is garbled whenever the core's or the dialog's text has an accented letter |
| `library/fat.h:1558` | `IDS_VDIRECTORY` (`"Directory%06d"`) | a number; code page | the **name** of a virtual directory in the snapshot (a UTF-8 name for the panel) | RECORDED - a resource text used as a file name; inside a template over `CHAR`, not a few-line change. Right while the translation is ASCII |
| `library/ntfs.h:815` | `resID` + a number | code page | `FNName` of a virtual directory | RECORDED - the same |
| `library/fat.h:2298`, `2303` | `IDS_ALLDELETEDFILES`, `IDS_METAFILES` alone | code page (`String<char>::LoadStr`) | the name of a virtual directory | RECORDED - not a composition, the same defect: a translated `{All Deleted Files}` with an accented letter is a name that is not UTF-8 (exFAT loads the wide text, `library/exfat.h:614`, `620`, and is right) |
| `library/os.h:203-253` | `IDS_FLOPPY350` ... `IDS_LOCAL_DISK`, `IDS_COMPACT_DISK` alone | code page, as the volume name when the volume has no label (labels are UTF-8) | the volume list, set wide with a UTF-8-then-code-page conversion (`dialogs.cpp:325-354`) | RIGHT AS IT IS |

Counts: fixed 0, right as it is 8 rows, recorded 4.

## 3. FIXED rows

None.

## 4. Other defects seen (not fixed)

- **Virtual directory names from code-page resource texts** (`library/fat.h:1558`, `2298`, `2303`,
  `library/ntfs.h:815`) - see the table. The shipped translations do have letters outside ASCII:
  id 17 is `{Všechny vymazané soubory}` (Czech), `{Alle gelöschten Dateien}` (German),
  `{Tous les fichiers supprimés}` (French), `{Minden törölt fájl}` (Hungarian),
  `{Všetky vymazané súbory}` (Slovak); id 11 is `Adresář%06d` (Czech), `Répertoire %06d` (French),
  `Adresár%06d` (Slovak) - `translations/<language>/undelete.slt`. So on an NTFS or FAT volume in
  these languages the first directory of the listing has a name that is code-page bytes where the
  rest of the program expects UTF-8 (exFAT is right). How the panel shows it, and whether a path
  through it (`del:C:\{...}\file`) survives the core's UTF-8 path handling, was **not examined** -
  worth a row of its own in NEXT-WORK. Not changed here: it is a name used as such (the paths
  into the directory are compared with it), and the code is a template over the character type.
- `dialogs.cpp:836-864`: see the table; `text1[200]` and `path[MAX_PATH + 300]` bound the sentence
  (`_snprintf_s`, cut possible inside a character, no tail trim); `fileName[MAX_PATH]` for the
  highlighted name (`dialogs.cpp:847`, guarded by the length test at `845`).
- `fs1.cpp:201`: `sprintf(TransferBuffer, String<char>::LoadStr(resID))` - a resource text used as
  the format string (a `%` in a translation would be read as a conversion), and a code-page text
  handed to the panel's column; how the core shows a column text that is not valid UTF-8 was not
  examined.
- `dialogs.cpp:486-492`: `strcpy` + `strcat` + `FormatMessage` A into `buf[1024]`, not bounded
  formally (short texts).
- `dialogs.cpp:879`: `GetWindowText` A into `title[100]` for the folder picker's caption (a
  resource title, code page - consistent with the overload used).
