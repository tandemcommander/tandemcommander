# Closing report - 355-uniso-raw-sessions
Backlog item: iso-plug-in-a-raw-multi-session-image-not-named-img-lists - ISO plug-in: a raw multi-session image not named .img lists one session, then Unpack deletes it
Outcome: closed

## What changed

- `src/common/salisotrack.h`: `SAL_ISO_RAW_REST_READ` (2048) and `SalIsoRawRestDecision`. For a raw image
  it keeps the listing, marks it, or asks for the sectors past the volume to be read:
  - mark: no ISO 9660 descriptor gives the volume's size, the sector size is not positive, the file ends
    within the volume, or more than 512 sectors lie past it;
  - keep: at most 16 whole sectors lie past the volume;
  - check: otherwise.
- `src/plugins/uniso/isoimage.cpp`, `CISOImage::Open`, plain branch: a new block for a file with a raw
  start (`rawStart`) when 353's missing-`.ccd` block does not apply (`!CcdMissing`).
  - It reads the descriptor at the opened layout's sector 16 and applies the rule.
  - For "check", it reads the 2048 user-data bytes of every sector past the volume at the opened layout.
    A short read or a non-zero byte marks `ListingLeftOut` incomplete.
  - A marked listing makes a whole unpack fail, so "Delete archive after unpacking" keeps the image.
- `src/saltests/saltests.cpp`: `TestIsoRawRest_355` (39 checks).
- No UI string, no window, no plug-in ABI change. 353's `.img` rule, 354's cooked rule and the
  track-table branch are unchanged.

## Measurements (before / after, commands)

- Probe `probe/iso355_probe.ps1` (images by `probe/img355.py` from 334's `mkimg334.sh`), run on the hidden
  desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\355-uniso-raw-sessions\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\355-uniso-raw-sessions\probe\iso355_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile ...\result_after_debug.txt"`
  - Before (main 4cc97934): **30 PASS / 10 FAIL**. All 10 R rows were deleted:
    - two sessions named `.iso`, `.bin` and `.mdf`;
    - two sessions as XA sectors;
    - a volume size of 400 sectors, more than the file;
    - a short file;
    - 17 non-zero sectors past the volume;
    - 513 zero sectors past the volume;
    - zero sectors with a non-zero last byte;
    - an audio tail.
  - After: **40 PASS / 0 FAIL**.
- Mutant "the rule never marks": probe 30 / 10, saltests 26 failed.
- Mutant "the zero check never passes": probe 38 / 2 (C-ZERO150 and C-ZERO512 kept).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → TOTAL: 0 finding(s).
- `.\build.cmd` → BUILD SUCCEEDED.
- saltests: 29,363 → **29,402 checks, 0 failed**.
- Regression probes:
  - 354: 28 / 0;
  - 353: 16 / 0;
  - 352: 22 / 0;
  - 334: 23 / 1. S-RAW is kept, its state since feature 335.
- The registry was restored with an identical hash after every probe run.
- No UI strings changed, so no translation refresh was needed.

## Reviews (findings and what was done)

- Review 1 (refute-first agent): no MUST findings.
  - Its negative control, uniso.spl built from main, gave 30 / 10.
  - Its own rows behaved as expected: 2448-byte `.mdf` with one and two sessions, a zero tail with
    non-zero subchannel, an XA post-gap, and 150 zero sectors before session 2.
  - SHOULD S1: images that a layout without the sync pattern opens (ECDC and other formats) still lose a
    later session, on both builds. This is outside the item → Inbox.
  - The NOTEs are recorded: N1, a crafted descriptor size, as in 353 and 354; N2, a false mark only keeps
    the image; N3, the code is sound; N4, the tests hold.
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `check-feature-355-with-real-raw-bin-and-mdf-disc-images-one`: check with real raw `.bin` and `.mdf`
  dumps of a one-session and a two-session data CD.
- The CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.

CHANGELOG entry (for the next release's section):

- **Unpack could delete a raw multi-session disc image not named `.img`, losing all but its first session** (feature 355).
  - **Before:** a raw disc image with a second session after the first showed only the first session's files. Examples: a `.bin` without its `.cue`, an Alcohol 120% `.mdf`, a raw dump named `.iso`. A whole Unpack (Alt+F9) with "Delete archive after unpacking" then deleted the image, and the later session's files were lost.
  - **Now:** a whole Unpack extracts what is listed and keeps the image in these cases:
    - it holds data past the volume it lists (more than a few sectors that are not empty);
    - its volume's size does not fit the file.
  - A raw one-session image unpacks and is deleted as before, also when it ends with an empty post-gap.
  - **Limitation:**
    - No message says why the image was kept.
    - A `.bin` of a data + audio disc without its `.cue` is now kept too, because its audio tracks are not listed.
    - The later sessions are still not listed.
    - Images in some other formats (for example Easy CD Creator images) can still be deleted; this is recorded for a later fix.
    - Checked with crafted images only.

## New Inbox items (slug - title)

- `iso-plug-in-a-multi-session-image-opened-through-another` - ISO plug-in: a multi-session image opened
  through another plain layout lists one session, then Unpack deletes it (review:355)
- `check-feature-355-with-real-raw-bin-and-mdf-disc-images-one` - Check feature 355 with real raw .bin and
  .mdf disc images, one and two sessions (person step)
