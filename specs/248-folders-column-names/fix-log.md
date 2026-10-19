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

## Analyze (speckit-analyze)

- Round 1: 0 CRITICAL, 0 HIGH. C1 MEDIUM - SC-002 named a "cell check" the probe did not have:
  added the CELLS row (the list holds the type text of at least one Desktop item with non-ASCII
  letters). F1 LOW - "replacement mark" (spec) vs "default character `?`" (research): the same
  thing, accepted. Round 2: no findings above LOW.

## Probe before (T002) - unchanged build of 7f37ec00

The maintainer's instance had closed by then, so the probe ran on the hidden desktop.

- First run: the header crop (list top - 24 px) caught the directory line ("fld:") - the header
  line is the top ~20 px of the list window itself; the CELLS crop (first 120 px) showed the
  header garbled ("Typ poloĹľky", "Datum zmÄ›ny" - crop looked at) and only virtual folders with
  empty type cells. Geometry fixed: header = top 22 px of the list, CELLS = the whole list.
- Second run: the CELLS row printed every recognized line of the list - the user's own Desktop
  file names - into the result file meant for the repository. Changed to report only the type
  texts found; the result file was overwritten by the third run.
- Third run, `probe/result_before.txt`: PATH PASS, NAME PASS ("Název" exact), COL1 INFO
  ("Velikost", ASCII), **COL2 FAIL** ("Typ položky": recognized "Typ poloĹlky"), **COL3 FAIL**
  ("Datum změny": recognized "Datum zmÄ»ny"), CELLS PASS (4 of 6 non-ASCII type texts found),
  END PASS (exit 0, no report). Registry restored, SHA-256 identical. The negative control fails
  as it must.

## Fix (T003, T004)

- `src/plugins/folders/fs1.cpp` `GetShellColumns`: `SplWToU8` replaced by
  `WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, colNameW, -1, col.Name, sizeof(col.Name),
  NULL, NULL)`; `<= 0` leaves the name empty (as before). Comment says why.
- `src/plugins/folders/folders.h`: `CShellColumn::Name` documented as code page. (A first version
  put the comment at the end of the line; the trailing-comment alignment of the next line moved -
  rewritten as a comment line above the field, the neighbours untouched.)
- Byte check of the call (PowerShell P/Invoke, same flags):
  - cp1250 "Typ položky" → `54 79 70 20 70 6F 6C 6F 9E 6B 79 00` (ž = 0x9E, 12 bytes);
  - cp1250 "a" U+0101 U+4E2D, no best-fit → `61 3F 3F` (both outside → `?`); with best-fit (flag
    0) → `61 61 3F` (ā shown as "a" - the lookalike FR-004 forbids);
  - cp1250 30 × "x" into 30 bytes → 0, error 122 (insufficient buffer) → empty name. Cannot happen
    in practice: `StrRetToBufW` keeps at most 29 units, 29 bytes + NUL fit in every single-byte
    code page;
  - cp932 14 × U+4E2D (29 bytes) → fits; 15 × (31 bytes) → 0, error 122 → empty, never a half
    double-byte character (FR-005).

## Checks after

- Build: `.\build.cmd` → `BUILD SUCCEEDED` (Debug x64; `folders.spl` rebuilt 22:54:20; rebuilt again
  after the comment move - code unchanged).
- Probe `probe/result_after.txt` (fixed build, before the comment-only move): PATH, NAME, COL2
  ("Typ položky" exact), COL3 ("Datum změny" exact), CELLS, END PASS; COL1 INFO. PASS 6, FAIL 0.
  Registry restored, SHA-256 identical. Crop `fixed_czech_header.png` looked at: "Název / Přípona |
  Velikost | Typ položky | Datum změny".
- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)` (it does not scan `plugins/`).
- `git diff --stat` over `src`: only `src/plugins/folders/fs1.cpp` and `folders.h` (SC-003).
- `saltests`: not run - no change in the core or `src/common/`.
