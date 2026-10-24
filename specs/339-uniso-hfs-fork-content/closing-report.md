# Closing report - 339-uniso-hfs-fork-content
Backlog item: iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in - ISO plug-in: an HFS+ file whose data is compressed or only in its resource fork extracts empty
Outcome: closed

## What changed

- `src/common/salhfscatalog.h`: `SalHfsFileContentKind(rec, avail)` - where an HFS+ file record keeps its content:
  COMPRESSED (`UF_COMPRESSED` 0x20 in the BSD owner flags, byte 41, when the file mode's type bits are not 0 -
  TN1150's uninitialised BSD information), RESOURCE_ONLY (empty data fork, non-empty resource fork), DATA, SHORT.
- `src/plugins/uniso/hfs.cpp` `CHFS::UnpackFile`: a COMPRESSED / RESOURCE_ONLY file is refused before anything is
  created - an "Error" box (Skip / Skip all / Cancel) with a new text, silent after Skip all; `UNPACK_ERROR` /
  `UNPACK_CANCEL`. Feature 338's tally then fails a whole unpack and "Delete archive after unpacking" keeps the image.
- Two UI strings (`IDS_ERR_HFS_FILE_COMPRESSED` 1062, `IDS_ERR_HFS_FILE_RSRC_ONLY` 1063), translated into the 8
  enabled languages (pins for cs / sk / de / es in `translations/ui-overrides.json`).
- `saltests`: `TestHfsFileContent339`. Probe `probe/iso339_probe.ps1` + `probe/img339.py`.

## Measurements (before / after, commands)

- Before (main 75fc0f43): `iso339_probe` 12 PASS / 6 FAIL - resource-fork-only, compressed (resource fork / inline /
  beside data) `side.txt` written empty (or its data fork), no box, the image deleted (`probe/result_before.txt`).
- After: 20 / 0 (10 RUN rows, H-EXIST added) - one box, `side.txt` not written, the image kept; controls (ordinary,
  file mode 0, resource fork beside data) unchanged (`probe/result_after.txt`).
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\339-uniso-hfs-fork-content\probe\result_after.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\339-uniso-hfs-fork-content\probe\iso339_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd` and `build.cmd full`: BUILD SUCCEEDED.
- `saltests`: 28,740 -> 28,761 checks, 0 failed; mutants of the rule fail 5 / 3 / 4 / 6 / 1 checks.
- Probes: `iso339_probe` 20 / 0; regressions `iso332_probe` 16 / 0, `iso333_probe` 20 / 0.
- Translations: 2 gaps per language, DeepL 1,936 characters, 0 validation failures, `slt --verify` byte-exact.

## Reviews (findings and what was done)

- Review 1: no MUST. Negative control (uniso.spl of the commit before the fix) 12 / 8. SHOULD 1 (the Mac-image
  person check had no item) -> created. NOTEs (box hidden after an earlier "All"; bare file name in the box; an
  unreachable SHORT text; flag + mode 0 + empty forks extracts empty; H-EXIST's real proof; old worktrees)
  accepted and recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- `check-feature-339-with-a-mac-made-hfs-image-holding` - unpack a Mac-made HFS+ image with an HFS+-compressed
  file and a custom icon file; the boxes appear, the image is kept, ordinary files extract.

## New Inbox items (slug - title)

- `iso-plug-in-an-hfs-file-with-data-and-a-resource-fork-loses` - ISO plug-in: HFS+ resource forks beside file
  data are dropped by Unpack (decision).
- `check-feature-339-with-a-mac-made-hfs-image-holding` - Check feature 339 with a Mac-made HFS+ image holding
  compressed files (person step).
