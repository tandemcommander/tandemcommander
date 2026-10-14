# Fix log: 156 - the "N files" texts of a selection in languages with accents

Report (the maintainer, 2026-10-14, version 0.1.9): dragging several files, the Czech drag image
reads "vybrané 2 soubory" with "?" in place of "é".

## Cause (by reading)

`ExpandPluralFilesDirs` builds "N (selected) files and M directories" from the plural templates -
in the code page (`LoadStr`) unless its last parameter asks for UTF-8 (feature 041 added it for the
information line). Three callers pass the code-page text into UTF-8:

- `CFilesWindow::CreateDragImage` (`fileswn9.cpp`): since 043 the drag image draws its text through
  `SalU8ToWDisplayAlloc` (UTF-8) - for one file the name, for a selection this text: every
  accented letter of the code page is not UTF-8 and became "?" (the report).
- `fileswn7.cpp` (Copy / Delete from archive, Pack): the text goes into a `LoadStrU8` template - the
  mixed string is not valid UTF-8, so the dialog shows all of it through the code page: the
  template's own accented letters are garbled.

## Before (measured)

`probe/plural_text_probe.ps1`, Czech UI, five files (the plural "souborů" has an accent):

| row | build before (`probe/result_pre156.txt`) | fix (`probe/result.txt`) |
|-----|-----|-----|
| pack | FAIL: "PĹ™idat 5 souborů do archivu" | PASS "Přidat 5 souborů do archivu" |
| unpack | FAIL: "KopĂ­rovat 5 souborů z archivu do" | PASS |
| delete | PASS (its template has no accented letter) | PASS |
| pack-one, unpack-one (one file: the name branch, UTF-8 already) | PASS | PASS |
| drag | NOT DRIVEN (a mouse drag) | NOT DRIVEN |

## Work

`ExpandPluralFilesDirs(..., TRUE)` at the three sites.

## Review (refute-first agent, 2026-10-14)

No critical finding: the drag image uses the text only for the bitmap (the A fallback only when
an allocation fails); the dialog subjects go into `CTruncatedString` (no cut for several items) and
`CCopyMoveDialog` / `CMessageBox` / `CPackDialog`, no history, no A API; the longest expansion in
the enabled languages is 121 bytes (French) - within `expanded[200]` and the 360-byte subject, so
no UTF-8 sequence is cut (`ExpandPluralString` truncates by bytes, unreachable today).
Found by it, the same class (to `specs/NEXT-WORK.md`, fixed next): the FTP plug-in's information
line in the "size in bytes" branch takes `ExpandPluralBytesFilesDirs` through the plug-in API in
the code page (`zip.cpp`, no u8) while the core draws the line as UTF-8: "bajt? v 3 vybran?ch
souborech". LOW: the e-mail confirmation (`fileswn8.cpp`) is consistently code page, only the
UTF-8 thousands separator of `PrintDiskSize` would be garbled.

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
- Owed to a person (the reporter): drag several files in Czech - "vybrané 2 soubory" whole.
