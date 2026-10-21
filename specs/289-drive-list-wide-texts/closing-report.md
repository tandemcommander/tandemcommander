# Closing report - 289-drive-list-wide-texts
Backlog item: drive-list-code-page-texts - Drive list and folder type names use code-page shell texts
Outcome: closed

## What changed

- `src/common/saldrivetext.h` (new, header-only): `SAL_DRIVE_TEXT_U8_MAX` (3 * MAX_PATH + 1),
  `SAL_FOLDER_TYPE_U8_MAX` (241), `SalDriveNameTrimLetterSuffixW` (the " (X:)" trim, unchanged
  rule, on UTF-16).
- `src/icncache.cpp`: folder type name from `SHGetFileInfoW` of the wide system directory, UTF-8
  into `FolderTypeName[241]` (whole).
- `src/salamdr1.cpp`: `FolderTypeName[241]`; `UpDirTypeName` from `LoadStrU8`.
- `src/drivelst.cpp`: `GetDisplayNameFromSystem` (removable drives) and the CD label thread use
  `SHGetFileInfoW` / `GetVolumeInformationW` and keep UTF-8, no code-page retry; the CD label is
  handed over whole (`ReadCDVolNameBuffer[781]`, `strcpy_s`, was `lstrcpyn` at MAX_PATH); menu
  and tooltip buffers sized for a UTF-8 name with every '&' doubled; 29 `LoadStr` ->
  `LoadStrU8` (all drive-list words) and `PrintDiskSize(.., TRUE)`; the OneDrive for Business
  name read back with the same encoding. Debug seam: `TYPES`, `ALL`, `TIP` for every item
  (`contracts/probe-seam.md`).
- `src/salamdr5.cpp`, `src/consts.h`: buffer declarations; `src/saltests/saltests.cpp`:
  `TestDriveText289` (11 checks).

## Measurements (before / after, commands)

- Before, at cf860604 (P/Invoke harness, ACP 1250, Czech display language): `SHGetFileInfoA` of a
  folder "Дом" -> `3F 3F 3F`; the folder type name stored as cp1250 bytes.
- Probe (hidden desktop): `powershell -File tools\run_on_hidden_desktop.ps1 -Log
  specs\289-drive-list-wide-texts\probe\result_<label>.txt -CommandLine "powershell -NoProfile
  -ExecutionPolicy Bypass -File specs\289-drive-list-wide-texts\probe\run289.ps1 -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label> -OutFile ...results_<label>.txt
  -DecodedFile ...decoded_<label>.txt"`.
  - before (seam only, no fix): PASS 3, FAIL 5 - TYPES English / Czech, ITEM / ALL / TIP Czech
    (cp1250 "Místní jednotka", "Síť", "Složka souborů").
  - after: PASS 8, FAIL 0 (English and Czech; every line valid UTF-8; As Other Panel checked too).
  - SC-002: the texts decoded as the sinks decode them - before = after (210 lines).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED; the touched files recompiled without a warning.
- saltests -> `saltests: 25237 checks, 0 failed` (25,226 at feature 288).
- Probe `run289`: 3 / 5 -> 8 / 0; registry restored, SHA-256 identical, each run.

## Reviews (findings and what was done)

One independent refute-first review: no MUST. S1 (CD / removable paths only code-read; mount an
ISO) - not done on the maintainer's working session, a person step. N1 seam TIP for every item -
accepted (Debug-only, no key clash). N2 probe header / As Other Panel not measured - fixed and
re-run (8 / 0). N3 stale comment - fixed. N4 subst target cut / code-page fallback - Inbox item.
N5 housekeeping - noted.

## Owed to a person (with the new person-step items)

`check-drive-labels-and-folder-type-names-outside-the-code`: a CD / ISO and a USB stick labelled
in Cyrillic, a CD drive without medium, optionally a display language outside the code page.

## New Inbox items (slug - title)

- `a-subst-drive-whose-target-is-long-or-outside-the-code-page` - A subst drive whose target is
  long or outside the code page resolves to a cut or code-page path (review:289).
- `check-drive-labels-and-folder-type-names-outside-the-code` - Check drive labels and folder type
  names outside the code page on real hardware (289) (person step, leftover:289).
