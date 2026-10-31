# Closing report - 354-uniso-cooked-sessions
Backlog item: iso-plug-in-a-cooked-multi-session-image-lists-one-session - ISO plug-in: a cooked multi-session image lists one session, then Unpack deletes it
Outcome: closed

## What changed

- `src/common/salisotrack.h`: `SalIsoCookedRestDecision` decides what a cooked image's rest past the ISO
  9660 volume at its sector 16 does to the listing. Up to 16 whole sectors keeps the listing. A size that
  cannot be read, a file shorter than the volume, or a rest of more than 512 sectors marks it. Anything
  else is read, and marked unless it is zero bytes only (`SalIsoBytesAllZero`). New constants:
  `SAL_ISO_ZERO_REST_SECTORS` and `SAL_ISO_COOKED_SECTOR`.
- `src/plugins/uniso/isoimage.cpp`, `CISOImage::Open`, the plain branch: a file opened through
  `CheckForISO` at the cooked layout (`cookedIso`) gets the rule; a mark makes a whole unpack fail, so
  "Delete archive after unpacking" keeps the image. Opening an image reads at most 1 MiB extra, and only
  when the rest is 17 to 512 sectors long.
- `src/saltests/saltests.cpp`: `TestIsoCookedRest_354` (38 checks).
- The rule is narrower than the item's literal one, on the measurement its *Notes* asked for: xorriso's
  native images carry 168 zero sectors outside the volume, and these are still deleted (spec
  *Clarifications*).

## Measurements (before / after, commands)

- Probe `probe/iso354_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`, see
  `quickstart.md`):
  - main at 64e207ca: **20 / 8**. R-TWOISO and R-TWOIMG were deleted and b.txt was lost; six other keep
    rows were deleted too.
  - After the fix: **28 / 0**.
- How long the rest past the volume is with common tools (`probe/measure_tails.sh`, `probe/measure2.sh`):
  see `fix-log.md`, *Measurement before*.

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `TOTAL: 0 finding(s)`. `.\build.cmd`: `BUILD SUCCEEDED`. saltests went from 29,325 to
  29,363 checks, 0 failed.
- Mutants:
  - The rule never marks: saltests 19 failed, probe 20 / 8.
  - The rest is never zero: probe 24 / 4.
- Regression probes:
  - 353 16 / 0, 352 22 / 0.
  - 334 23 / 1: S-RAW is kept, its state since feature 335.
  - 328 20 / 0, 329 14 / 0, 330 30 / 0, 332 16 / 0, 333 20 / 0, 338 24 / 0, 339 20 / 0, 349 10 / 0.
- The registry was restored with an identical hash after every probe run.
- No UI strings changed, so no translation refresh was needed.

## Reviews (findings and what was done)

- Review 1 (refute-first agent): no MUST findings.
  - Its negative control, the uniso.spl of HEAD~1, fails R-TWOISO, R-REST17 and R-XESP.
  - Its own image, with an 11,400-sector gap between the sessions, is kept.
  - SHOULD S1: a raw multi-session image whose name is not `.img` is still deleted. This is outside the
    item → Inbox.
  - The NOTEs are recorded: N1, a kept `.iso` gets no message; N2, other kept cases; N3, a dead NULL check
    in the plug-in's own pattern; N4, the history entry, now written.
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `check-feature-354-with-real-cooked-disc-images-multi-session`: check with a real plain `.iso`, an Ubuntu
  ISO with an appended EFI partition, and a `dd` copy of a two-session CD-R.
- The CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.

CHANGELOG entry (for the next release's section):

- **Unpack could delete a multi-session disc image of 2048-byte sectors, losing all but its first session** (feature 354).
  - **Before:** a disc image of 2048-byte sectors (`.iso`, or an `.img` without a `.ccd`) holding a second session after the first - for example a copy of a multi-session CD - showed only the first session's files; a whole Unpack (Alt+F9) with "Delete archive after unpacking" then deleted the image, and the later session's files were lost.
  - **Now:** when such an image holds data past the volume it lists (more than a few sectors, not just zero padding), or its volume's size does not fit the file, a whole Unpack extracts what is listed and keeps the image. A plain one-volume `.iso` - also one padded with zeros, as xorriso writes it - unpacks and is deleted as before.
  - **Limitation:** no message says why the image was kept. Installation images with an appended partition (Ubuntu ISOs since 20.10, for example) are now kept too, because their partition is not listed. The later sessions are still not listed. A UDF-only image, and a raw (2352-byte) multi-session image not named `.img`, can still be deleted (recorded for later fixes). Checked with crafted images only.

## New Inbox items (slug - title)

- `iso-plug-in-a-udf-only-cooked-image-with-more-past-its` - ISO plug-in: a UDF-only cooked image with more past its volume is still deleted by Unpack
- `iso-plug-in-a-raw-multi-session-image-not-named-img-lists` - ISO plug-in: a raw multi-session image not named .img lists one session, then Unpack deletes it
- `check-feature-354-with-real-cooked-disc-images-multi-session` - Check feature 354 with real cooked disc images (multi-session dd copy, Linux ISOs) (person step)
