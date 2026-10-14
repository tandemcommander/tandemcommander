# Fix log: 171 - the rest of the install-path chain in the core

Backlog: the part of NEXT-WORK item 19 that feature 170 left (the core places that still build
the program's folder in the code page).

## Measured

`specs/170-install-path-unicode/probe/install_path_probe.ps1 -ShotDir`: a picture of the main
window started from an ASCII folder and from a Cyrillic one (after 170). From the Cyrillic folder
the toolbar showed the old built-in bitmaps instead of the SVG icons (`toolbars\*.svg` - the
path had '?'); from the ASCII folder the SVG icons. After: the same SVG icons from the Cyrillic
folder (`probe/cyrillic_folder_toolbar_after.png`), probe 4 / 0, registry identical.

Read, not driven (the consumers are plain): the conversion tables of the viewer and of Convert
(`codetbl.cpp`: `convert\*` listed and `convert.cfg` / the tables opened with A functions - no
table under such a folder), `utils\sqlite.dll` (`shiconov.cpp`, the Google Drive folder for icon
overlays - `LoadLibrary` A).

Left out after reading: the tips (`dialogs6.cpp`: a commented-out block), SalOpen (`salamdr4.cpp`:
`utils\salopen.exe` is not shipped), the shell extension (not shipped, 083).

## Work

- `src/svg.cpp`: the folder from `SalGetModuleDirU8`, bounded names, `ReadSVGFile` opens with
  `SalCreateFile` (quiet like before: a missing dark variant is normal).
- `src/shiconov.cpp`: `GetSQLitePath` UTF-8, `SalLoadLibrary`.
- `src/codetbl.cpp`: `ReadTable` / the constructor open with `SalCreateFile`, the folder in a
  `SAL_MODULE_PATH_U8` buffer (also `InitAux`'s copy and limit), `PreloadAllConversions` lists
  wide; a folder name of `MAX_PATH` bytes or more is left out (`DirectoryName`).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Left (NEXT-WORK)

The configuration export's file dialog (`mainwnd3.cpp`, an A dialog with the program's folder as
the start), the bug report's module line (`bugreprt.cpp`), `EnumInstalledModules` (a plug-in
service), the plug-ins' own lookups of their files.

## Review

Independent refute-first review (read-only): nothing CRITICAL; buffer sizes, the `PreloadCS`
pairing, handle pairing and the failure paths checked.
- SHOULD-FIX, taken: the conversion tables dialog showed the table's folder through
  `ListView_SetItemText` A - now `SalListViewSetItemTextU8` (`dialogs3.cpp`).
- NIT, taken: two comments (`mainwnd3.cpp`, `codetbl.cpp`).
- Accepted: a CJK install path near 260 characters (more than 3 x MAX_PATH bytes) falls back to the
  defaults; names in `convert.cfg` are read as UTF-8 (the shipped ones are ASCII); a relative table
  name too long for the buffer is cut as before.
- Not changed (not shipped or a separate program): the shell extension's registration, SalOpen,
  `src/translator`.

Final build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.
