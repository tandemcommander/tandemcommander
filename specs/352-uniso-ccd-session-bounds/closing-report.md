# Closing report - 352-uniso-ccd-session-bounds
Backlog item: iso-plug-in-a-clonecd-session-number-from-the-ccd-writes - ISO plug-in: a CloneCD session number from the .ccd writes outside the reader arrays
Outcome: closed

## What changed

- `src/common/salisotrack.h`: pure rules `SalIsoCcdReadInt` (a `.ccd` row's number as `sscanf` read a
  valid one; no number or outside 32 bits fails), `CSalIsoCcdFields` (each needed row once and parsed),
  `SalIsoCcdSessionIndex` (an entry's session in 1..sections), `SalIsoCcdSplitSection`,
  `SalIsoCcdLayoutTrusted` (sections and splits agree).
- `src/plugins/uniso/img.cpp`: the `[TRACK n]` / `[Entry n]` / `[Session n]` parsers use them (and skip
  a row of `=` only instead of `strcmp(NULL)`); `CCDEntry::Session` is `int`; `CCD::Refused`;
  `ReadSessionCCD` checks every entry's session before building anything (refused otherwise), loops
  over the splits, takes a split's offsets only from an existing section, and marks `ListingLeftOut`
  incomplete for a refused `.ccd` (after the existing box and plain detection) and for sections /
  splits that disagree. A missing `.ccd` is unchanged. No UI string - no `.slt` refresh.
- `src/saltests/saltests.cpp`: `TestIsoCcdBounds_352` (60 checks).
- Probe `probe/iso352_probe.ps1`, images `probe/img352.py`.

## Measurements (before / after, commands)

- Probe on the hidden desktop (`tools\run_on_hidden_desktop.ps1` ... `iso352_probe.ps1 -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe`): main 2f260c23 **8 / 10** (R-S0 CRT heap
  corruption at `img.cpp(438)`, R-S200 the image deleted, R-S257 RTC #1, R-ABS TRACE_C index out of
  range, R-MODEX unknown format, R-DUP RTC #3 `plba` uninitialised) -> fix **22 / 0** (22 rows, C-NOCCD
  and R-TWOSEC added). Files: `probe/result_before_debug.txt`, `probe/result_after_debug.txt`,
  `probe/result_after_debug_review1.txt`.
- Mutants: the rule without the upper session bound - saltests 4 failed; `img.cpp` without the layout
  mark - R-TWOSEC FAIL (image deleted, `probe/result_mutant_no_layout_mark.txt`); the reviewer's: main's
  uniso.spl 10 / 10, without both marks 15 / 5.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- `saltests.exe` -> 29,286 checks, 0 failed (29,226 at 351).
- Probes: 352 22 / 0; 351 10 / 0 (`probe/regress_351.txt`); 334 23 / 1 - S-RAW as recorded since 335 /
  by 351 (`probe/regress_334.txt`). Registry restored and identical in every run.

## Reviews (findings and what was done)

- Review 1 (refute-first agent): MUST 0. SHOULD 1 - no probe row proved the layout mark (R-ABS / R-SPLIT
  are kept by 334's / 338's rules too) -> row R-TWOSEC added, proven by a mutant. NOTE 1 - R-SPLIT
  extracts nothing (offset 0 for a split without a section; main extracted session 1 only by a garbage
  offset) -> recorded as a limit. NOTE 2 - real multi-session dumps are now always kept without a
  message -> note added to `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`. NOTE 3 -
  comment accuracy -> corrected. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `check-feature-352-with-real-clonecd-dumps-one-and-two` - a real single-session and a real
  two-session CloneCD dump (the stricter parser must accept real `.ccd` files; the two-session dump is
  kept by a whole unpack).
- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.

CHANGELOG entry (for the next release's section):

- **A damaged CloneCD `.ccd` file could corrupt memory, and Unpack could then delete the disc image** (feature 352).
  - **Before:** the ISO plug-in used the session number of each table-of-contents entry in a CloneCD `.ccd` file unchecked - a damaged or crafted `.ccd` naming a session it does not have wrote outside the plug-in's memory; in one measured case a whole Unpack (Alt+F9) with "Delete archive after unpacking" then went on and deleted the image. A `.ccd` whose session list did not match its tracks, or one of whose values was not a number, was read past its tables or with random values.
  - **Now:** such a `.ccd` is refused with the existing message "Bad format of .CCD file. Displayed image could be incomplete." - the image is still shown as far as it can be read without it, and a whole Unpack keeps the image. A `.ccd` whose sessions and tracks do not match opens within bounds, and a whole Unpack keeps the image.
  - **Limitation:** a real multi-session CloneCD image (its tracks numbered across the disc) is now always kept by a whole Unpack with "Delete archive after unpacking", without a message, until its sessions are read correctly (recorded for a later fix); an image whose `.ccd` is missing is handled as before. Checked with crafted images only.

## New Inbox items (slug - title)

- `iso-plug-in-a-clonecd-image-without-its-ccd-lists-one` - ISO plug-in: a CloneCD image without its .ccd lists one session, then Unpack deletes it
- `check-feature-352-with-real-clonecd-dumps-one-and-two` - Check feature 352 with real CloneCD dumps (one and two sessions) (person step)
