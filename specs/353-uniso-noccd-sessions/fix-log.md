# Fix log - 353-uniso-noccd-sessions

Backlog item `iso-plug-in-a-clonecd-image-without-its-ccd-lists-one` - ISO plug-in: a CloneCD image
without its .ccd lists one session, then Unpack deletes it.

## Measurement before (main at b9272d3e)

- Read: `processCCDFile` (`src/plugins/uniso/img.cpp`) returns FALSE when `_wfopen` of the `.ccd` fails,
  after `Warning(IDS_CCD_MISSING)` (once per `DisplayMissingCCDWarning`), without `CCD::Refused`;
  `ReadSessionCCD` returns FALSE; `CISOImage::Open` (`isoimage.cpp`) falls back to `DetectSectorType` +
  `CheckForISO` ... and builds one track spanning the whole file, `DetectTrackFS` reads the volume
  descriptor at sector 16 - session 1 only. Caller chain: Alt+F9 -> core -> `ListArchive` ->
  `CISOImage::Open` -> `ListImage`; `UnpackArchive` fails only when `pd->ListingLeftOut`.
- Seeds measured: genisoimage `s1.iso` 176 sectors, PVD volume space size (bytes 80..83) 176 (the
  150-sector pad is inside the volume); `s2.iso` 176 sectors.
- `.\build.cmd` (Debug x64, up to date at HEAD) -> BUILD SUCCEEDED.
- Probe (new, `probe/iso353_probe.ps1` + `probe/img353.py`, run from a scratch copy before the branch
  existed, same content):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso353_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before ..."`
  -> 10 PASS / 2 FAIL (`probe/result_before_debug.txt`):
  - R-NOCCD2 FAIL: two raw sessions, a.txt extracted, image deleted (b.txt lost) - the defect;
  - R-REST17 FAIL: one session + 17 raw sectors, image deleted;
  - C-NOCCD, C-REST2, C-REST16, C-COOKED PASS (extracted, deleted).
  Registry restored, identical (SHA-256 1DA45396...).
- `BL verify` recorded.

## Decisions

- Rule (spec Clarifications): raw image (DetectSectorType found the sync -> 2352-byte sectors) opened
  without its `.ccd`; listed volume size = PVD volume space size at sector 16; whole sectors of the file
  past the volume > 16 -> listing incomplete; no PVD -> incomplete; cooked .img unchanged.

## Analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM I1 (data-model said 88 bytes, the block-size check needs 132) and
  LOW C1 (FR-005 without a check task) - both fixed in data-model.md / research.md / tasks.md T011.
- Run 2: no findings above LOW; coverage 7 / 7 FR, 4 / 4 SC.
