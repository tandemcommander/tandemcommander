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

## Implementation

- `src/common/salisotrack.h`: `SAL_ISO_LATER_VOLUME_SECTOR` (16), `SAL_ISO_PVD_BYTES` (132),
  `SalIsoPvdVolumeSectors` (type 1, `CD001`, version 1, both copies of the volume space size equal,
  logical block size 2048 both copies), `SalIsoNoCcdRestMarks` (not raw -> never; unknown volume or
  sector size <= 0 -> marks; whole sectors from the data offset > volume + 16 -> marks).
- `src/plugins/uniso/img.cpp`: `CCD::Missing` set where `_wfopen` of the `.ccd` fails;
  `ReadSessionCCD` copies it to `CISOImage::CcdMissing` (new protected member, `isoimage.h`).
- `src/plugins/uniso/isoimage.cpp`: constructor and `ReadSessionInfo` reset `CcdMissing`; `Open`'s
  plain branch keeps `rawStart = SectorType != stISO` right after `DetectSectorType`, and after
  `DetectTrackFS` of the one track, when `CcdMissing && rawStart`, reads `SAL_ISO_PVD_BYTES` at
  `GetSectorOffset(16)` and calls `ListingLeftOut.SetIncomplete()` when the rule says so.
- Consumers enumerated: `CISOImage::Open` is called by `ListArchive` (copies `ListingLeftOut.Incomplete`
  to `pd->ListingLeftOut`, which `UnpackArchive` / whole unpack checks - feature 328), and by the
  unpack / viewer paths that open the image again (they ignore the mark). `CcdMissing` is read only in
  `Open`. No UI string, no `.rc` / `.rc2` / `.rh` change (`git diff main...HEAD --stat`).

## Measurements after

- `.\build.cmd` -> BUILD SUCCEEDED (warnings C4267 only in untouched uniso files, pre-existing).
- saltests: 29,286 (352's count) -> 29,322 checks, 0 failed (`TestIsoNoCcdRest_353`, 36 checks).
- Rule mutant (`return false` past the volume): saltests 29,322 / 8 failed; the probe on that build
  10 / 2 - R-NOCCD2 and R-REST17 deleted (`probe/result_mutant_never_marks.txt`) - the probe rows
  depend on the mark.
- Probe after (`probe/result_after_debug.txt`): 12 PASS / 0 FAIL - R-NOCCD2 and R-REST17 kept (a.txt
  extracted), C-NOCCD, C-REST2, C-REST16, C-COOKED deleted; only "Missing .CCD file" boxes; registry
  restored identical.
- Regressions: 352's probe 22 / 0 (`probe/regress_352.txt`), 351's probe 10 / 0
  (`probe/regress_351.txt`).
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- clang-format `--dry-run` on the changed line ranges: three spots reformatted with `-i --lines` on
  those ranges only (lambda brace, a comment column, a stream continuation).
