# Fix log - 321-tar-long-component

Backlog item `opening-a-tar-whose-member-name-has-a-300-letter-component` (measure:306). Second run:
the first (feature 307, `origin/307-tar-long-component`, stopped 2026-10-22 after review 2) is the
starting record - its spec, plan, research, fix-log, probe and results are copied into `run307/`.

## Measurement at 26c31a9d (main, before the feature)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tcrun_scratch\result_before_gnu_main.txt
  -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File
  specs\306-tar-pax-headers\probe\pax306_probe.ps1 -Only GNU-TOOLONG -Label before-HEAD -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe"` -> GNU-TOOLONG END FAIL: "A problem has
  occurred, forcing Tandem Commander to close", report "Error Number: 2 / Description: Stack memory
  corruption", innermost call-stack message `CFilesWindow::CommonRefresh`; RUN FAIL (did not open).
  Registry restored, SHA-256 identical. The defect is present at HEAD (`BL verify`).
- Root cause as in `run307/fix-log.md` / `run307/research.md` R1, re-read at HEAD: a root member
  (`header.Path = NULL`) -> `CSalamanderDirectory::AddFile(NULL, ...)` (`src/zip.cpp`) applies feature
  222's bound only under `path != NULL` (`AddDir` likewise, unchanged since 307) -> the 904-byte name
  is listed -> `RefreshListBox` formats it into `char formatedFileName[SAL_FIND_NAME_U8]`.

## Carry-over of 307 (SKILL.md 4.6)

`main` moved 120 commits since 307's base (d92d8278): features 308 (pass-dependent PAX refusal:
`SalPaxNameUsableU8`, `CArchive::Listing`, `SCommonHeader::NameRefused`), 309 (links, `LinkName`; the
GNU long-name branch now writes through `char** longName`), 310 (cpio hard links), 315-320.

`git diff --binary d92d8278 origin/307-tar-long-component -- . ':!backlog' ':!specs' ...` and
`git apply -3`: clean for `sallistingname.h` (new), `salpaxheader.h`, `fileswn3.cpp`, `zip.cpp`;
conflicts in `tar.h`, `untar.cpp`, `saltests.cpp`, `CHANGELOG.md`, resolved by the item's logic:

- `tar.h` / `untar.cpp`: `main`'s code kept; 307's GNU flag re-applied on it as `NameFromGnu`
  (set in the GNU long-name branch when `longName == &header.Name`, reset in `Initialize`), and
  the refusal of `ReadArchiveHeader` is now 308's pass-dependent one for both sources:
  `(NameFromPax || NameFromGnu) && !SalPaxNameUsableU8(..., Listing)` - the depth / folder-name
  bound only while listing, only the over-255-unit component in an extraction, a refused member
  asked for by an extraction reported and the extraction failed (308's `NameRefused` path). This
  is review 2's MUST of the first run.
- `saltests.cpp`: both sides kept (308-319 tests and 307's `TestListingName307`, its include).
- `CHANGELOG.md`: `main`'s side; the entry is written at closing.
- The carried code's comments and the test renamed from feature 307 to 321 (307 never reached
  `main`).
