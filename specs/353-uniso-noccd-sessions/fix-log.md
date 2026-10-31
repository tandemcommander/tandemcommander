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

## Review

- Review 1 (refute-first agent, general-purpose): MUST 0.
  - Its own measurement: build + saltests 29,322 / 0; negative control `uniso.spl` of 268ef8bb (before
    the fix) in a copy of the build tree: R-NOCCD2 deleted (b.txt lost), its X-XA2 (two raw Mode 2 XA
    sessions) deleted, X-POSTGAP150 deleted; the fix: all kept. Callers enumerated (ListArchive ->
    pd->ListingLeftOut -> UnpackArchive / UnpackWholeArchive; UnpackOneFile, ViewFile, CanViewFile open
    and ignore the mark). Standing rules not touched.
  - SHOULD 1: a descriptor claiming a volume larger than the file (its `bigpvd2`: R-NOCCD2's image with
    session 1's size patched to 400 > 352 sectors) was not marked - deleted, b.txt lost. **Fixed**:
    `SalIsoNoCcdRestMarks` also marks `whole < volumeSectors`; checks updated / added (the file ending
    within the volume, the last sector cut, a size of 400 over 352 sectors, an empty volume in an empty
    file - saltests 29,322 -> 29,325); spec FR-002 / edge case and data-model updated. Probe row R-BIGPVD
    added: on the pre-fix build FAIL (deleted, `probe/result_review1_before_fix.txt`, 15 / 1), after PASS.
  - NOTE 1: a cooked (2048-byte) multi-session image (`.img` or `.iso`) lists session 1 and is deleted
    (its X-COOKED2IMG / X-COOKED2ISO) - outside the item (FR-003), pre-existing -> Inbox
    `iso-plug-in-a-cooked-multi-session-image-lists-one-session` (review:353).
  - NOTE 2: every raw single-session dump with more than 16 sectors past its volume (150-sector post-gap,
    data + audio tracks, cdrecord `-pad` 15 + TAO run-out 2 = 17) is now kept by a whole unpack with only
    the "Missing .CCD file" box - accepted by the spec's Assumptions (fails closed, nothing lost); recorded
    as a limit; real dumps owed to a person (`check-feature-353-with-real-clonecd-dumps-whose-ccd-is`).
  - NOTE 3: no row pinned `rawStart` (C-COOKED's file equals its volume). **Fixed**: row C-COOKED17 (a
    cooked `.img` + 17 sectors, expected deleted) - a `rawStart = TRUE` mutant would keep it.
  - NOTE 4: closing records not yet written - done at closing.
- After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests 29,325 / 0; probe
  `probe/result_after_debug_review1.txt` 16 PASS / 0 FAIL (8 RUN rows + 8 END rows); 352's probe 22 / 0
  (`probe/regress_352_review1.txt`); encoding guard TOTAL: 0; clang-format on the changed lines only.
- No MUST finding, so no second review round is required (SKILL.md step 7).
