# Research - 351 uniso track defaults

## R1 - Which type marks a CloneCD data track "to be detected"?

- **Decision**: `fsISO9660`.
- **Rationale**: `CISOImage::Open` runs `DetectTrackFS` for every track whose type is neither
  `fsUnknown` nor `fsAudio`; `DetectTrackFS` always writes the detected type (or `fsUnknown`, which
  `Open` turns into `fsData` + 335 / 336's flags). Any data value works; the Nero reader's
  `SetTrackTypeMode` already gives a data track `fsISO9660`, so both readers hand `Open` the same
  value. Nothing reads `FSType` between the reader and `Open` (grep: `viewer.cpp` reads it only
  after the image opened).
- **Alternatives considered**: `fsData` - also detected, but would differ from the Nero reader for
  no gain; a new "to detect" enum value - an internal enum, but more change than the item needs.

## R2 - How to measure the Release build without touching the 0.2.0 tree?

- **Decision**: build only `src/plugins/uniso/vcxproj/uniso.vcxproj` (Release x64) with MSBuild and
  `OPENSAL_BUILD_DIR` = `%TEMP%\tc351-rel\` (plugin_base.props puts the `.spl` under
  `$(OPENSAL_BUILD_DIR)tandemcommander\Release_x64\plugins\uniso\`); copy
  `build\tandemcommander\Release_x64` (0.2.0, built from `v0.2.0`) to `%TEMP%\tc351-reltree` and put
  the fixed `uniso.spl` in it; run the probe on that copy's `tandemcommander.exe`.
- **Rationale**: the 0.2.0 tree's core and plug-in interface (108) are those of the tree; uniso's
  only project reference is its language module (no string change). A full `build.cmd full
  release` would overwrite the 0.2.0 tree the "before" rows ran on.
- **Alternatives considered**: `build.cmd full release` into the default folder (overwrites the
  measured baseline); a second full Release build under another `OPENSAL_BUILD_DIR` (an hour of
  LTO for one plug-in).

## R3 - A deterministic negative control

- **Decision**: a Debug mutant with the CloneCD data mapping removed (the track keeps the
  constructor's `fsUnknown`) - C-M1 / C-M2 / C-M1M1 must fail every time, as Release did at random.
- **Rationale**: Debug's 0xCD fill hides the defect; once the constructor sets `fsUnknown` the
  CloneCD mapping is what makes the rows pass.

## R4 - Nero tracks no DAOX entry describes

- **Decision**: no reader change; the constructor's `fsUnknown` / zero bounds apply.
- **Rationale**: an unknown track is never detected (`Open`), never listed, and marks the listing
  (`ListTracks` `case fsUnknown` -> `SAL_ISO_TRACK_NOT_TRIED`; the single-session path's left-out
  rule) - 334's `SalIsoTrackMarksListing` marks every unknown track. The item's "not listed with
  garbage bounds" holds. Real Nero images with CUEX index points (350's limit: the reader pairs index
  records into tracks) get such extra tracks - an audio disc, whose listing 334 already marks, and
  also a data disc with index points, whose listing is now always marked (the image kept after a
  whole unpack). That is fail-safe and what the 0.2.0 Release build did most of the time (heap value
  0 = unknown); the pairing itself is Inbox `iso-plug-in-nrg-cuex-index-records-are-paired-into-wrong`
  (review 1, NOTE 3).
