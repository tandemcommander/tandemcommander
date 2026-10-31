# Fix log - 351 uniso track defaults

Backlog item `iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an` (source review:334).

## Measurement before (main d760ed1a, 2026-10-31)

Sites at HEAD:

- `src/plugins/uniso/isoimage.cpp` `CISOImage::Track::Track()` sets `FileSystem`, `Bootable`, `RawLost`,
  `Form2Stream` only; `SectorSize`, `SectorHeaderSize`, `Mode`, `Start`, `End`, `ExtentOffset`, `FSType`
  are the heap's.
- `src/plugins/uniso/img.cpp` `CISOImage::ReadSessionCCD`: `switch (ccdtrk->Mode)` sets `FSType` only for
  mode 0 (audio); modes 1 / 2 set `Mode` only; another mode sets neither.
- `src/plugins/uniso/nrg.cpp` `readCUEX` makes a `CAudioTrack` per entry with `ExtentOffset` only;
  `readDAOX` fills tracks first..last within the count (331) - a CUEX track no DAOX entry names keeps
  every other field unset.
- Reachability: opening / unpacking a `.img` (with its `.ccd`) or `.nrg` in a panel -> `CISOImage::Open`
  -> `ReadSessionInfo` -> `ReadSessionCCD` / `ReadSessionNRG`; `Open` detects every track whose
  `FSType` is neither `fsUnknown` nor `fsAudio`. uniso is on in the default build.

Probe `probe/iso351_probe.ps1` (written for this item; images by `probe/img351.py` from 334's
`mkimg334.sh` seeds - s1.iso a.txt "A1", s2.iso b.txt "B2"): Unpack (Alt+F9) of the whole image with
"Delete archive after unpacking"; rows C-M1 (CloneCD, one Mode 1 track), C-M2 (one Mode 2 Form 1
track), C-M1M1 (two sessions of one Mode 1 track), N-ONE (NRG control), N-UNDESC (NRG, CUEX two
tracks, DAOX describes track 1 only - want the image kept).

| Build | Command | Result |
|---|---|---|
| 0.2.0 Release (`build\tandemcommander\Release_x64`, from tag `v0.2.0`, 2026-10-25; the sites unchanged since - `git log` of `src/plugins/uniso` after the tag: 349 HFS, 350 CUEX bounds only) | `iso351_probe.ps1 -Repeat 3` on the hidden desktop | **23 / 7** - "Unknown file format or not a valid ISO image", nothing extracted: C-M1 2 of 3 runs, C-M2 2 of 3, C-M1M1 3 of 3; N-ONE and N-UNDESC 3 / 3 PASS (`probe/result_before_release.txt`) |
| Debug at d760ed1a | `iso351_probe.ps1` | **10 / 0** - the 0xCD fill (0xCDCDCDCD is neither unknown nor audio) makes the CloneCD track detected by chance (`probe/result_before_debug.txt`) |

So the item's "would show only in Release (not verified)" is confirmed and worse than the item says:
in the shipped build a CloneCD data image often does not open at all (not only a marked listing).
N-UNDESC keeps the image both ways (a garbage type of unknown / audio / data with a start outside the
file all mark the listing) - its fields are what changes, not the unpack's outcome.

## Decisions

- Every field of `Track` gets a value in the constructor: `FSType = fsUnknown`, `Mode = mNone`, sizes,
  bounds and extent offset 0 (spec Clarifications; conservative - an undescribed track is never
  detected nor listed, and 334 marks the listing).
- CloneCD: `SalIsoCcdTrackKind(mode)` (`src/common/salisotrack.h`): 0 audio, 1 / 2 data, else unknown.
  Data -> `fsISO9660` (the Nero reader's value for a data track; `Open` detects and replaces it,
  research R1).
- Nero: no reader change (research R4).
- Release "after": only `uniso.vcxproj` built Release x64 into `%TEMP%\tc351-rel`, run in a copy of the
  0.2.0 tree (research R2) - the 0.2.0 tree stays as measured.

## Change

- `src/plugins/uniso/isoimage.cpp` `CISOImage::Track::Track()`: `SectorSize`, `SectorHeaderSize`,
  `Start`, `End`, `ExtentOffset` 0, `Mode = mNone`, `FSType = fsUnknown` (besides the existing four).
- `src/common/salisotrack.h` `SalIsoCcdTrackKind(ccdMode)`: 0 audio, 1 / 2 data, else unknown.
- `src/plugins/uniso/img.cpp` `ReadSessionCCD`: the mode switch goes through the rule; a data track
  gets `mMode1` / `mMode2` and `fsISO9660`.
- `src/saltests/saltests.cpp` `TestIsoCcdTrackKind_351` (12 checks).
- Consumers enumerated (grep `FSType`, `new CISOImage::Track`, `new Track`, `new CAudioTrack`): the
  CCD loop (img.cpp), `readCUEX` / `readDAOX` / `readETNF` / `readETN2` / `SetTrackTypeMode`
  (nrg.cpp), the no-track-table path of `Open`, `DetectTrackFS`, `OpenTrack`, `MarkTrack`,
  `ListTracks`, `viewer.cpp` `getTrackTypeStr` / its mode line - every reader that describes a track
  still writes the fields it wrote; only fields no reader wrote change from the heap's value to the
  default.

## Undescribed NRG track (T009, by reading)

`readCUEX` makes a `CAudioTrack` (its base constructor now gives `fsUnknown`, zero bounds) with
`ExtentOffset` only; `readDAOX` overwrites tracks first..last within the count (331). A track no
entry names: `Open` skips detection (`fsUnknown`), the last-readable loop skips it, `ListTracks`
`case fsUnknown` marks it `SAL_ISO_TRACK_NOT_TRIED` (334: an unknown track always marks), the
single-session path marks it left out (`FSType != fsData`). Probe row N-UNDESC: Debug and Release,
image kept, a.txt extracted, no window.

## Measurements after

| What | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 29,214 -> **29,226 checks, 0 failed** |
| rule mutant (every mode data) | same, header mutated, restored from a copy | 7 failed (modes 3, -1, 255, INT_MAX, INT_MIN, 0xCDCDCDCD, the unknown-marks check) |
| Debug after | `iso351_probe.ps1` | **10 / 0** (`probe/result_after_debug.txt`) |
| Debug mutant: CloneCD data type removed (`img.cpp`, restored from a copy) | `iso351_probe.ps1` | **7 / 3** - C-M1, C-M2, C-M1M1 "Unknown file format" every time: the Release symptom, deterministic once the constructor gives `fsUnknown` (`probe/result_mutant_no_ccd_data.txt`) |
| Release after: `uniso.vcxproj` Release x64 built with `OPENSAL_BUILD_DIR=%TEMP%\tc351-rel\`, put into a copy of the 0.2.0 Release tree (`%TEMP%\tc351-reltree`) | `iso351_probe.ps1 -Repeat 3` | **30 / 0** (`probe/result_after_release.txt`) |
| Release control: `main` d760ed1a's `uniso.vcxproj` built the same way (a temporary worktree, removed), in another copy of the 0.2.0 tree | `iso351_probe.ps1 -Repeat 3` | **24 / 6** - C-M1 1 of 3, C-M2 3 of 3, C-M1M1 2 of 3 failed (one run extracted only Session 02 and kept the image) (`probe/result_before_release_main.txt`) |
| regression 334 (Debug) | `iso334_probe.ps1` | 23 / 1 - S-RAW, as recorded since 335 (`probe/regress_334.txt`) |
| regression 335 (Debug) | `iso335_probe.ps1` | 28 / 4 - M-FORM2, S-VCD, C-VCD, C-VCDREAL, as recorded since 336 (`probe/regress_335.txt`) |
| regression 335 (Release tree with the fixed plug-in) | `iso335_probe.ps1` | 28 / 4, the same rows (`probe/regress_335_release.txt`) |
| regression 350 (Debug) | `nrg350_probe.ps1` | 20 / 0 (`probe/regress_350.txt`) |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| format | VS clang-format `--dry-run` with `--lines` of the changed ranges only | no output |

Every probe ran on the hidden desktop; the registry restored and identical after each
(SHA-256 1DA45396...).

No UI string, dialog or menu changed - no `.slt` refresh.

## Review

### Review 1 (refute-first, general-purpose agent, foreground) - no MUST

- Re-measured on Release: the reviewer built `uniso.vcxproj` Release x64 itself from three detached
  worktrees into copies of the 0.2.0 tree, `-Repeat 3`: the fix 30 / 0; main d760ed1a 27 / 3 (C-M2#2,
  C-M1M1#2, C-M1M1#3 - the failures move between runs: 23 / 7, 24 / 6, 27 / 3); a Release mutant (the
  fix's constructor with main's `img.cpp`) 21 / 9 - C-M1, C-M2, C-M1M1 fail in all 3 runs. saltests
  29,226 / 0; registry identical after each run; tree left clean, worktrees removed.
- Callers enumerated (every reader that makes a track, every reader of the fields): each still writes
  what it wrote; an undescribed track takes the fail-safe branch everywhere. No data loss.
- **SHOULD 1** (pre-existing, outside the item): `ReadSessionCCD` indexes `pointMin` / `pointMax` /
  `extents` / `extentsEnd` by an `[Entry]`'s `Session - 1` from the `.ccd` unchecked - `Session=0`
  gave Debug "HEAP CORRUPTION DETECTED", `Session=200` wrote past the array silently and the unpack
  deleted the image; `Session[i]` read past its end when the `.ccd` declares more sessions than
  `INDEX 1=0` splits (by reading). -> Inbox `iso-plug-in-a-clonecd-session-number-from-the-ccd-writes`
  (review:351), with NOTE 1.
- NOTE 1: `processTrackSection` / `processEntrySection` / `processSessionSection` count a row whose
  `sscanf` failed - `ExtentOffset` / `End` from stack garbage for a malformed `.ccd` (the type and
  mode are always defined since 351). -> in the same Inbox item.
- NOTE 2: N-UNDESC passes before the fix too - SC-002 now says it is a regression row; the NRG half
  rests on reading (T009), which the reviewer's reading confirms.
- NOTE 3: research R4 limited the extra CUEX tracks of real index-point images to audio discs; a data
  disc with index points gets them too and its listing is now always marked (fail-safe, as 0.2.0
  Release mostly did) - R4 corrected.
- NOTE 4: CHANGELOG / FEATURE-HISTORY entries come at closing.
