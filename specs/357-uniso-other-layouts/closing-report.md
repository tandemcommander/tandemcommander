# Closing report - 357-uniso-other-layouts
Backlog item: iso-plug-in-a-multi-session-image-opened-through-another - ISO plug-in: a multi-session image opened through another plain layout lists one session, then Unpack deletes it
Outcome: closed

## What changed

- `src/common/salisotrack.h`: `SAL_ISO_PLAIN_*` (the checks of `CISOImage::Open`'s plain detection) and
  `SalIsoPlainRawRuleApplies(rawStart, ccdMissing, layout)`: a raw start as 355 decided (unless the `.ccd` is
  missing - 353); without one, true for the NRG offset, 2336, NCD, PDI, Easy CD Creator, CIF, C2D and CIF 2332.
- `src/plugins/uniso/isoimage.cpp`, `CISOImage::Open` plain branch: `plainLayout` recorded per check; 355's block
  runs under `SalIsoPlainRawRuleApplies` (was `rawStart && !CcdMissing`). 355's rule and block body unchanged.
- `src/saltests/saltests.cpp`: `TestIsoPlainLayouts_357` (65 checks).
- No UI string, dialog or window; no translation refresh needed.

## Measurements (before / after, commands)

- Seeds: 334's `mkimg334.sh` (WSL, genisoimage); images: `probe/img357.py` in ten layouts, checked against a mirror
  of the detection order.
- `probe/iso357_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`):
  - before (main 8bf3ebd4): `probe/result_before.txt` 44 PASS / 16 FAIL - every R-<layout>-TWO and the
    ECDC / NRG REST17, ZERO513, SHORT rows deleted the image;
  - after: `probe/result_after.txt` 60 PASS / 0 FAIL.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (Debug x64).
- saltests: 29,488 -> 29,553 checks, 0 failed; mutant (rule never applies without a raw start): 16 failed.
- Probes: iso357 60 / 0; regressions 353 16 / 0, 354 28 / 0, 355 40 / 0, 356 56 / 0 (`probe/regress_35N.txt`);
  registry restored and identical every run.

## Reviews (findings and what was done)

- Review 1: no MUST, no SHOULD. Its probe with extra rows 30 / 0; negative control (uniso.spl of HEAD~1) 14 / 6.
  NOTEs: crafted images only (person step below); UDF-only at the NRG offset always marked (decided); the
  header's "MDF always a raw start" comment was wrong - fixed; the short Roxio image that never opens (older,
  nothing at stake) - recorded in `fix-log.md`; other features' old review worktrees - not this feature's.

## Owed to a person (with the new person-step items)

- `check-feature-357-with-real-ecdc-cif-c2d-ncd-and-pdi-disc`: check with real one- and two-session images of
  those formats.
- The CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section (versions are the maintainer's), so it
  is not added there.

CHANGELOG entry (for the next release's section):

- **Unpack could delete an old-format disc image (Easy CD Creator, WinOnCD, Roxio, NTI, CIF, PDI) together with its second session** (feature 357).
  - **Before:** a disc image in one of the older formats the ISO plug-in recognises without a cue sheet - Easy CD Creator, WinOnCD / Roxio `.c2d`, `.cif`, NTI `.ncd`, `.pdi`, Nero images without their footer, 2336- and 2332-byte sector images - showed only the files of its first session. When it held a second session, a whole Unpack (Alt+F9) with "Delete archive after unpacking" deleted the image, and the second session's files were lost.
  - **Now:** a whole Unpack extracts what is listed and keeps the image when data lies past the listed volume (as features 354 and 355 do for cooked and raw images). A one-session image of those formats unpacks and is deleted as before.
  - **Limitation:**
    - No message says why the image was kept.
    - An image of those formats that ends with more than 16 sectors of other data after its volume is now kept too.
    - Only the first session is listed.
    - Checked with crafted images, not with real images of those formats.

## New Inbox items (slug - title)

- `check-feature-357-with-real-ecdc-cif-c2d-ncd-and-pdi-disc` - Check feature 357 with real ECDC, CIF, C2D, NCD
  and PDI disc images, one and two sessions (person step, leftover:357).
