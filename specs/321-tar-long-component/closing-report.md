# Closing report - 321-tar-long-component
Backlog item: opening-a-tar-whose-member-name-has-a-300-letter-component - Opening a tar whose member name has a 300-letter component crashes the program
Outcome: closed

## What changed

Second run of the item; the first (feature 307, `origin/307-tar-long-component`, record in `run307/`)
was carried over (SKILL.md 4.6) onto `main` with features 308-320, and its review-2 MUST fixed.

- `src/common/sallistingname.h` (new, header-only) + `CSalamanderDirectory::AddFile` / `AddDir`
  (`src/zip.cpp`): an entry with no folder part (archive roots, every file-system plug-in) is refused
  at 780 bytes (`SAL_FIND_NAME_U8`, the panel's name buffers); with a folder part feature 222's rule
  unchanged.
- `src/fileswn3.cpp`: the two simple-icons extension copies into a 780-byte buffer bounded; an
  extension that does not fit has no association.
- `src/plugins/tar/tar.h` / `untar.cpp`: `SCommonHeader::NameFromGnu` (a GNU `L` long name); the
  refusal of `ReadArchiveHeader` covers `NameFromPax || NameFromGnu` with feature 308's
  pass-dependent `SalPaxNameUsableU8(..., Listing)` - the listing's depth bound only while listing,
  a component over 255 UTF-16 units in every pass, an extraction asked for a refused member reports
  it and fails (so "Delete archive after unpacking" keeps the archive).
- `src/common/salpaxheader.h`: a top-level folder's name is not byte-bounded while listing (0.1.10
  behaviour for GNU; PAX too).
- `src/saltests/saltests.cpp`: `TestListingName321` (32 checks), 306's folder checks corrected.
- Probes: `probe/tar321_probe.ps1` (+ `mktar321.py`), `probe/unp321_probe.ps1` (+ `mkunp321.py`,
  308's probe with GNU long names); 306's and 308's probes: one row each updated to the listed
  top-level folder, GNU-TOOLONG in 306's default run.
- `CHANGELOG.md`: entry under `[0.1.11] — unreleased`; 306's "still crashes" limitation updated.

## Measurements (before / after, commands)

- Before (26c31a9d, `main`): `pax306_probe.ps1 -Only GNU-TOOLONG` - the crash ("Stack memory
  corruption" under `CFilesWindow::CommonRefresh`). `tar321_probe` PASS 12 / FAIL 8 (GNU-TOOLONG,
  CPIO-778, CPIO-TOOLONG crash; GNU-DEEP, GNU-255DIR do not open); `unp321_probe` 9 / 3 (COPY rows:
  the deep GNU archive does not open; UNP-TOOLONG-DEL "(123)" instead of "(206)").
- After: `tar321_probe` 20 / 0, `unp321_probe` 12 / 0 (Unpack and Unpack + Delete of the deep GNU
  tree: 34 of 34; the 300-letter member: ok.txt, "(206)", archive kept).
- Commands: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\321-tar-long-component\probe\<file> -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\321-tar-long-component\probe\<probe>.ps1 -Label <label> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (no UI strings, resources or plug-in lists changed: `full` not needed).
- `saltests.exe` -> `saltests: 27698 checks, 0 failed`.
- Probes: tar321 20 / 0; unp321 12 / 0; regressions pax306 30 / 0, unp308 12 / 0, link309 16 / 0,
  cpio310 52 / 0; registry restored and identical in every run.
- Negative controls: listing rule in every pass -> Unpack 2 of 34 (the first run's defect); GNU flag
  off -> no crash but the archives do not open; + core bound off -> saltests 4 failed and the crash
  returns. Sources restored, rebuilt, re-measured.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST, no SHOULD; re-measured every number. NOTE 1 (a long top-level
  folder is listed but cannot be entered, as 0.1.10) - changelog clause added; NOTE 2 (306's probe
  kept GNU-TOOLONG out of its default run) - added, 30 / 0; NOTE 3 (the "(206)" text for members only
  too deep for the listing, features 306 / 308) and NOTE 4 (recorded limitations) - recorded.

## Owed to a person (with the new person-step items)

- Nothing: every probe row was driven on the hidden desktop.

## New Inbox items (slug - title)

- None. The cpio / rpm per-member refusal is already the backlog item
  `a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot` (recorded by the first run).
