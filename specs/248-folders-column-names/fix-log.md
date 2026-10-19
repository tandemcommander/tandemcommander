# Fix log - 248-folders-column-names

Backlog item `drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine` (GitHub issue #13):
the Desktop view (`fld:`, Folders plug-in) draws the shell's column names as mojibake.

## Measurement before (main at 7f37ec00)

- Machine: cs-CZ UI, ACP 1250. `Shell.Application` `Namespace(0).GetDetailsOf($null, 0..4)`:
  "Název", "Velikost", "Typ položky", "Datum změny", "Datum vytvoření".
- Code: `CPluginDataInterface::GetShellColumns` (`src/plugins/folders/fs1.cpp`) reads the name
  with `StrRetToBufW` and stores it as UTF-8 (`SplWToU8`) in `CShellColumn::Name`; `SetupView`
  copies it into `CColumn::Name`. The core is an MBCS build (no `<CharacterSet>` in
  `src/vcxproj/*.vcxproj`), so the header draws with `TextOutA` / `GetTextExtentPoint32A`.
- Python: the UTF-8 bytes of "Typ položky" / "Datum změny" decoded as cp1250 give
  "Typ poloĹľky" / "Datum zmÄ›ny" - exactly the reported text.
- Core readers of `CColumn::Name` (Grep `(column|col|Column|c)(->|\.)Name\b` and
  `Columns[..].Name` over `src/*.cpp`):
  - `filesbx2.cpp` `CHeaderLine::PaintItem` (~229-268): `TextOut`, `GetTextExtentPoint32` - code page;
  - `filesbx2.cpp` ~344-356 (column width from the name) and ~401: `GetTextExtentPoint32` - code page;
  - `salamdr4.cpp` `InsertColumn` / `SetColumnName`: copy only;
  - `fileswn9.cpp` (view template columns: `LoadStr` - code page), `mainwnd1.cpp` (header context
    menu: `FixedWidth`, `ID`), `filesbx2.cpp` ~708 (sorting by `ID`) - do not read `Name`.
  - All code page; FEATURE-HISTORY 124 recorded "column names (code page in the whole program)".
- Other plug-ins insert column names from `LoadStr` (code page) - Folders is the only one that
  converted to UTF-8 (feature 004).
- GUI probe `probe/folders248_probe.ps1` (OCR of the header line on the hidden desktop): **NOT
  RUN** - it refuses while any tandemcommander.exe runs, and the maintainer's installed
  `C:\Program Files\Tandem Commander\tandemcommander.exe` (pid 10456) was running.
