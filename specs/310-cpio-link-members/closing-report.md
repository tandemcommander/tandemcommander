# Closing report - 310-cpio-link-members
Backlog item: cpio-unpack-drops-links-and-may-delete-archive - Unpacking a cpio or rpm leaves links out silently and may delete the archive
Outcome: closed

## What changed

- `src/common/salcpiolink.h` (new, header-only): `SalCpioIsLinkGroupMember`, `SalCpioLinkDecide` - the
  grouping rule and the per-member decision for hard-linked files of a newc / crc cpio.
- `src/plugins/tar/untar.cpp`, `tar.h`, `precomp.h`:
  - `ReadNewASCIIHeader` reads `c_ino`, `c_nlink`, `c_devmajor`, `c_devminor` silently (`CpioHex8`).
  - `ReadArchiveHeader`: a cpio symlink gets `LinkType = SYMTYPE` and its target (its data, 1..4096
    bytes) as `LinkName`; feature 309's code reports it and fails the operation (archive kept).
  - `DoUnpackArchive`: grouped members through `WriteOutCpioGroupMember` (wait / copy / write for the
    waiting names / report); `WriteOutCpioEmptyNames` at the trailer and the end of data.
  - `UnpackOneFile`: a name stored with size 0 reads on to its data (`UnpackOneCpioGroupName`); data
    that came earlier -> reported, never an empty file.
- `src/saltests/saltests.cpp`: `TestCpioLink310` (+26 checks).
- `CHANGELOG.md` (0.1.11 unreleased) entry; 309's limitation line points to it.

## Measurements (before / after, commands)

- Before (47eb6b83): `cpio310_probe.ps1` (fixtures `mkcpio310.py`) on the hidden desktop -> 13 PASS /
  7 FAIL (`probe/result_before.txt`): hard-linked names empty, the symlink dropped silently, the archive
  deleted.
- After: `probe/result_after.txt` 52 PASS / 0 FAIL (26 rows, including review 1's rpm, padding,
  case-twin, Skip / Yes and data-first rows and three F3 rows).
- Negative control (grouping off, symlink type not set): `probe/result_negctl.txt` 17 PASS / 9 FAIL.
- F3 control row (`probe/result_view_control.txt`): the "monitored handles" debug note is the viewer
  path's, also for a file without links.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd` (Debug x64): BUILD SUCCEEDED (no UI strings, resources or plug-in lists changed - `full`
  not needed).
- `saltests.exe`: 27,237 checks, 0 failed.
- Probes: 310 52 / 0; regressions 309 16 / 0, 308 12 / 0, 306 28 / 0 (`probe/regress_*.txt`).

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD 1 (FR-003 / edge case / Limits over-promised the data-first
  case) - spec and fix-log corrected, row COPY-FIRST-LATER added. SHOULD 2 (probe coverage) - the
  review's 13 rows merged into the shipped probe. NOTEs 3-7: documented / accepted (fix-log *Review*).

## Owed to a person (with the new person-step items)

- Nothing: every probe row was driven on the hidden desktop.

## New Inbox items (slug - title)

- None.
