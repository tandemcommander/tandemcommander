# Closing report - 351-uniso-track-defaults
Backlog item: iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an - ISO plug-in: a track of a CCD or NRG image may keep an uninitialised file-system type
Outcome: closed

## What changed

- `src/plugins/uniso/isoimage.cpp` `CISOImage::Track::Track()`: every field has a value at
  construction - `FSType = fsUnknown`, `Mode = mNone`, `SectorSize`, `SectorHeaderSize`, `Start`, `End`,
  `ExtentOffset` 0 (besides `FileSystem`, `Bootable`, `RawLost`, `Form2Stream` as before).
- `src/common/salisotrack.h` `SalIsoCcdTrackKind(ccdMode)`: 0 audio, 1 / 2 data, anything else unknown.
- `src/plugins/uniso/img.cpp` `CISOImage::ReadSessionCCD`: a CloneCD data track gets `mMode1` /
  `mMode2` and the type `fsISO9660` (`Open` detects its file system and replaces it - the value the
  Nero reader gives a data track); audio as before; another mode stays unknown.
- Nero readers unchanged: a CUEX track no DAOX entry describes is now unknown with zero bounds (the
  constructor) - never detected nor listed, it marks the listing (334).
- `src/saltests/saltests.cpp` `TestIsoCcdTrackKind_351` (12 checks).
- Probe `specs/351-uniso-track-defaults/probe/iso351_probe.ps1` with `img351.py` (5 rows, `-Repeat`).

## Measurements (before / after, commands)

Hidden desktop:
`powershell -File tools\run_on_hidden_desktop.ps1 -Log <log> -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\351-uniso-track-defaults\probe\iso351_probe.ps1 -Exe <exe> -Label <label> [-Repeat 3]"`

| Build | C-M1 / C-M2 / C-M1M1 (CloneCD) | N-ONE / N-UNDESC (NRG) | Rows |
|---|---|---|---|
| 0.2.0 Release tree, `-Repeat 3` (`result_before_release.txt`) | failed 2 / 2 / 3 of 3 runs - "Unknown file format", nothing extracted | pass | 23 / 7 |
| 0.2.0 tree + main d760ed1a's uniso Release, `-Repeat 3` (`result_before_release_main.txt`) | failed 1 / 3 / 2 of 3 | pass | 24 / 6 |
| 0.2.0 tree + the fixed uniso Release, `-Repeat 3` (`result_after_release.txt`) | pass every run | pass | **30 / 0** |
| Debug d760ed1a (`result_before_debug.txt`) | pass (0xCD fill) | pass | 10 / 0 |
| Debug fix (`result_after_debug.txt`) | pass | pass | 10 / 0 |
| Debug mutant: no CloneCD data type (`result_mutant_no_ccd_data.txt`) | fail every one | pass | 7 / 3 |

The Release plug-ins were built with MSBuild from `src/plugins/uniso/vcxproj/uniso.vcxproj` (Release
x64) with `OPENSAL_BUILD_DIR` under `%TEMP%` and copied into copies of
`build\tandemcommander\Release_x64` (the 0.2.0 tree, left unchanged).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`. No UI strings, menus or dialogs changed - no `.slt` refresh, no
  `full` build needed.
- saltests: 29,214 -> `29226 checks, 0 failed`; rule mutant (every mode data) 7 failed.
- Probes: as above; regressions on Debug 334 23 / 1 (S-RAW), 335 28 / 4 (Form 2 rows), 350 20 / 0 - each
  as recorded; 335 on the fixed Release tree 28 / 4, the same rows. Registry restored and identical
  after every run.
- Format: VS clang-format `--dry-run` on the changed line ranges - no output.

## Reviews (findings and what was done)

- Review 1 (refute-first, foreground): no MUST. Its own Release builds: fix 30 / 0, main 27 / 3, a
  Release mutant (the fix's constructor, main's `img.cpp`) 21 / 9. SHOULD 1 - a `.ccd` `[Entry]`
  `Session=` value indexes the CloneCD reader's arrays unchecked (pre-existing; heap corruption in
  Debug, a silent overrun after which the unpack deleted the image) -> Inbox item. NOTE 1 (unparsed
  `.ccd` rows leave stack values) -> the same Inbox item; NOTE 2 (N-UNDESC passes before too) - SC-002
  reworded; NOTE 3 (data NRGs with index points are marked too) - research R4 corrected; NOTE 4
  closing records - done. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.
- No real CloneCD or Nero image was tried (crafted images); real images are already owed by
  `check-feature-334-with-real-nrg-and-ccd-disc-images` - no new person-step item.

CHANGELOG entry (for the next release's section):

- **A CloneCD disc image of a data disc often did not open** (feature 351).
  - **Before:** opening or unpacking a CloneCD image (`.img` with its `.ccd`) of a data CD showed "Unknown file format or not a valid ISO image" and extracted nothing in most tries - at random, depending on the memory's content; a track of a Nero (NRG) image that its track list does not describe could be read at a random position.
  - **Now:** every track starts with defined values: a CloneCD data track is always examined for its file system, so the image opens every time; a Nero track the track list does not describe is treated as unknown - not listed, and a whole unpack keeps the image.
  - **Limitation:** checked with crafted images only; a damaged `.ccd` whose entries name a session that does not exist is still read unchecked (recorded for a later fix).

## New Inbox items (slug - title)

- `iso-plug-in-a-clonecd-session-number-from-the-ccd-writes` - ISO plug-in: a CloneCD session number from the .ccd writes outside the reader arrays
