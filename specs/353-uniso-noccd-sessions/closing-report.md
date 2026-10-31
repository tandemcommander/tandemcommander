# Closing report - 353-uniso-noccd-sessions
Backlog item: iso-plug-in-a-clonecd-image-without-its-ccd-lists-one - ISO plug-in: a CloneCD image without its .ccd lists one session, then Unpack deletes it
Outcome: closed

## What changed

- `src/common/salisotrack.h`: `SalIsoPvdVolumeSectors` (the volume size of a valid primary volume
  descriptor - type 1, `CD001`, version 1, both copies of the size equal, block size 2048) and
  `SalIsoNoCcdRestMarks` (raw image without `.ccd`: marked when the file holds more than 16 whole sectors
  past the volume, ends within it, or the size is unknown; never for a non-raw image).
- `src/plugins/uniso/img.cpp`: `CCD::Missing` where the `.ccd` cannot be opened; `ReadSessionCCD` passes it
  to `CISOImage::CcdMissing` (`isoimage.h`).
- `src/plugins/uniso/isoimage.cpp`: `Open`'s detection without a track table remembers a raw start (sync at
  sector 0) and, for an `.img` whose `.ccd` is missing, reads the descriptor at the opened layout's sector
  16 and marks `ListingLeftOut` by the rule - a whole unpack then fails and "Delete archive after
  unpacking" keeps the image. The existing "Missing .CCD file" box is unchanged; no UI string.
- `src/saltests/saltests.cpp`: `TestIsoNoCcdRest_353` (39 checks).

## Measurements (before / after, commands)

- Probe `probe/iso353_probe.ps1` (images by `probe/img353.py` from feature 334's `mkimg334.sh` seeds), run
  with `tools\run_on_hidden_desktop.ps1` on the Debug build:
  - before (main at b9272d3e): 10 PASS / 2 FAIL - R-NOCCD2 (two raw sessions) and R-REST17 deleted, b.txt
    lost (`probe/result_before_debug.txt`);
  - after: 12 / 0 (`probe/result_after_debug.txt`); after review 1 with rows R-BIGPVD and C-COOKED17:
    16 / 0 (`probe/result_after_debug_review1.txt`);
  - negative controls: a rule mutant (never marks past the volume) 10 / 2
    (`probe/result_mutant_never_marks.txt`); the build before review 1's fix fails R-BIGPVD
    (`probe/result_review1_before_fix.txt`, 15 / 1).
- Regressions: feature 352's probe 22 / 0 (twice), feature 351's probe 10 / 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED. No UI string, `.rc` / `.rc2` / `.rh` unchanged, so no
  `.slt` refresh and no `build.cmd full` were needed.
- saltests 29,286 -> 29,325 checks, 0 failed; the rule mutant fails 8.
- Probes as above, every registry restore identical (SHA-256 1DA45396...).

## Reviews (findings and what was done)

- Review 1 (refute-first agent): MUST 0. SHOULD 1 - a descriptor claiming a volume larger than the file was
  trusted (image deleted) -> fixed, saltests + probe row R-BIGPVD. NOTE 1 - cooked multi-session images
  (pre-existing, outside FR-003) -> Inbox. NOTE 2 - raw single-session dumps with more than 16 sectors past
  their volume are now kept -> accepted (spec Assumptions), recorded as a limit. NOTE 3 - no row pinned the
  raw start -> row C-COOKED17. NOTE 4 - closing records -> written. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `check-feature-353-with-real-clonecd-dumps-whose-ccd-is` - a real one-session and a real two-session
  CloneCD dump with only the `.img` copied.
- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.

CHANGELOG entry (for the next release's section):

- **Unpack could delete a CloneCD disc image whose `.ccd` file was missing, losing all but its first session** (feature 353).
  - **Before:** a CloneCD image (`.img`) without its `.ccd` file beside it was shown after the message "Missing .CCD file. Displayed image could be incomplete." with only its first session's files; a whole Unpack (Alt+F9) with "Delete archive after unpacking" then deleted the image, and the files of the later sessions were lost.
  - **Now:** when such an image holds more data past the first session than the listing shows (or its first volume's size does not fit the file), a whole Unpack extracts what is listed and keeps the image. A single-session image without its `.ccd`, and a plain `.img` disk image, unpack and are deleted as before.
  - **Limitation:** the later sessions are still not listed without the `.ccd`; a single-session CloneCD image with more than a few sectors after its data (padding, a post-gap, audio tracks) is now also kept. A multi-session image of 2048-byte sectors (`.iso` or plain `.img`) still lists one session and can be deleted (recorded for a later fix). Checked with crafted images only.

## New Inbox items (slug - title)

- `iso-plug-in-a-cooked-multi-session-image-lists-one-session` - ISO plug-in: a cooked multi-session image lists one session, then Unpack deletes it
- `check-feature-353-with-real-clonecd-dumps-whose-ccd-is` - Check feature 353 with real CloneCD dumps whose .ccd is removed (person step)
