# Closing report - 394-cpio-empty-name-link
Backlog item: a-cpio-hard-link-whose-data-name-normalizes-to-empty-is - A cpio hard link whose data name normalizes to empty is written as an empty file
Outcome: closed

## What changed

- `src/plugins/tar/untar.cpp`, `ReadArchiveHeader` ("skip invalid names"): a cpio member whose name
  normalizes to nothing gets `NameEmpty` and the time / attributes the normal path converts.
- `IsCpioGroupMember` uses the new pure rule `SalCpioKeepsGroupMember` (`src/common/salcpiolink.h`):
  a member ignored only for an unusable name (refused - 393 - or empty - 394) stays in its
  hard-link group as not asked, so the group's waiting names get its data.
- `DoUnpackArchive`, `UnpackOneFilePass`: a `NameEmpty` member is never asked.
- `WriteOutData`: the crc checksum is verified also when an `Ignored` carrier's data is written.
- `src/plugins/tar/tar.h`: `SCommonHeader::NameEmpty`. `src/saltests/saltests.cpp`:
  `TestCpioKeepsGroupMember394` (15 checks).
- No UI string, dialog, plug-in interface or setting changed (no `.slt` refresh).

## Measurements (before / after, commands)

Probe `specs/394-cpio-empty-name-link/probe/cpioempty_probe.ps1` on the hidden desktop
(`tools\run_on_hidden_desktop.ps1`, Debug x64):

- before (main 32c55a19): PASS 11 / FAIL 9 (`result_before.txt`; the F3 row added at analyze:
  `result_before_view.txt` FAIL, viewer content "") - `a.txt` written empty, archive deleted.
- after: PASS 22 / FAIL 0 (`result_after.txt`), every written file with the member's time.
- negative control (time conversion + crc change removed): PASS 15 / FAIL 7 (`result_negctl.txt`);
  the reviewer's control (T007 removed): 7 rows fail.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- `.\build.cmd` -> BUILD SUCCEEDED
- `saltests.exe` -> 30813 checks, 0 failed
- feature probe 22 / 0; regressions 306 30 / 0, 308 12 / 0, 309 16 / 0, 310 52 / 0, 321 tar
  20 / 0, 321 unpack 12 / 0, 393 28 / 0 (`probe/regress_*.txt`)

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST. SHOULD S1 (a file whose only name normalizes to nothing is
dropped silently - pre-existing, out of scope) -> Inbox. NOTE N3 (a lost space in a saltests
comment) fixed; N1 (existing item `tar-member-name-with-dotdot-extracted-into-wrong-folder` also
covers cpio), N2 (report names the raw member), N4 (repeated conversion), N5 (crc mismatch deletes
an overwritten target - pre-existing for every crc member), N6 recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (no `## [Unreleased]` section exists in `CHANGELOG.md`; versions
  and sections are the maintainer's):

  - **A cpio or rpm file whose data was stored under the name "." was extracted empty** (feature 394).
    - **Before:** when a newc / crc cpio archive or an rpm stored a hard-linked file's data with a
      name such as `.` or `./`, unpacking wrote the file's other names as empty files and reported
      success - with "Delete archive after unpacking" the archive, the only copy of the data, was
      deleted.
    - **Now:** the other names get the data; when the data comes before them in the archive they
      are reported and the archive is kept; data of such a member that fails its crc checksum is
      refused.
    - **Limitation:** a file stored only under such a name (no other name) is still skipped
      without a message (crafted archives only).

No person-step item: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `unpack-silently-drops-a-cpio-file-whose-only-name-normalizes` - Unpack silently drops a cpio
  file whose only name normalizes to empty
