# Fix log - 394-cpio-empty-name-link

Backlog item `a-cpio-hard-link-whose-data-name-normalizes-to-empty-is` - A cpio hard link whose data
name normalizes to empty is written as an empty file.

## Measurement before (main 32c55a19, Debug x64)

Probe `probe/cpioempty_probe.ps1` (fixtures `probe/mkcpioempty.py`; hidden desktop):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\394-cpio-empty-name-link\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe>\cpioempty_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

Result `probe/result_before.txt`: PASS 11 / FAIL 9 (10 RUN rows + END rows; registry restored,
identical). Every whole Unpack with "Delete archive after unpacking" whose carrier is `.`, `./`
or `` (newc, crc, rpm) wrote `a.txt` with 0 bytes, `ok.txt`, showed nothing and deleted the
archive. The data-first layout did the same (no report). The crc archive with a wrong checksum
on the carrier: also `a.txt` empty, archive deleted, no checksum message. Copy of the listing
(both layouts): `a.txt` empty. Control `UNP-DOTDIR-DEL` (folder `.` + `ok.txt`): PASS.

The F3 row added at analyze (`probe/result_before_view.txt`, `-Only VIEW-EMPTY-DOT`): FAIL - the
viewer opened the cached `a.txt` with content "" (want AAA).

Cause (code at HEAD): `ReadArchiveHeader`, branch "skip invalid names", returns `Ignored` with
no `NameRefused` before time / attribute conversion; `IsCpioGroupMember` keeps only
`!Ignored || NameRefused`; so `DoUnpackArchive`, `UnpackOneFilePass` and
`UnpackOneCpioGroupName` never see the group's data and `WriteOutCpioEmptyNames` writes the
waiting names empty. `WriteOutData` checks the crc sum only for non-`Ignored` members.

## Consumers enumerated (Grep)

- `IsCpioGroupMember`: `UnpackOneFilePass` (data-seen map / waiting single name),
  `DoUnpackArchive` (group writer), `UnpackOneCpioGroupName` (the data member search).
- `header.Ignored` with `simulate = FALSE`: only `WriteOutCpioGroupMember` (WRITE_FOR_WAITING) and
  `UnpackOneCpioGroupName`; `DoUnpackArchive` / `UnpackOneFilePass` pass
  `simulate = Ignored || !found`.
- `found` for an empty-name member: `DoUnpackArchive` uses `names.IsNamePresent(header.Name)` on the
  raw name (`.`) - forced FALSE for `NameEmpty`.

## Implementation

- T002 `SalCpioKeepsGroupMember` in `src/common/salcpiolink.h` (the rule 393 wrote inline, now with
  "unusable name" = refused or empty); T003 saltests `TestCpioKeepsGroupMember394` (8 rule checks,
  7 normalization checks: `.`, `./`, `/`, `..`, `./.`, `` -> nothing; `.a` stays).
- T004 `SCommonHeader::NameEmpty` (`tar.h`), reset in `Initialize`.
- T005 `ReadArchiveHeader`, "skip invalid names": for a cpio format `NameEmpty = TRUE`, MTime ->
  `FileInfo.LastWrite`, `Attr` (ARCHIVE, READONLY from mode) - the early return skipped these, and
  WRITE_FOR_WAITING writes with the carrier's time / attributes.
- T006 `IsCpioGroupMember` = `SalCpioKeepsGroupMember(..., NameRefused || NameEmpty)`.
- T007 `DoUnpackArchive`, `UnpackOneFilePass`: `found = FALSE` for `NameEmpty` (the raw name `.`
  could match a mask; for a non-group member nothing else changes - it is `Ignored`, simulated).
- T008 `WriteOutData`: crc check when `!header.Ignored || !simulate` (data written from an ignored
  carrier is verified; enumerated: only the group paths write from an ignored header).
- T009 data-first rows: no code change - feature 310's `SAL_CPIO_LINK_SKIP` with data marks the
  group LOST, the asked `a.txt` is REPORTed (`(2) ... a.txt -> .`), the operation fails.

## Measurement after (branch, Debug x64)

- Build: `.\build.cmd` -> BUILD SUCCEEDED (the tar plug-in's C4267 warnings at the name split are
  pre-existing, lines moved).
- `saltests.exe` -> `saltests: 30813 checks, 0 failed` (30798 at 393 + 15).
- Probe `probe/result_after.txt` (with the mtime check added after the first after-run): PASS 22 /
  FAIL 0 (11 RUN rows); every written file has the member's time 2001-09-09 01:46:40Z; registry
  restored, identical.
- Negative control `probe/result_negctl.txt` (time conversion of T005 and the crc change of T008
  removed by a temporary edit, rebuilt, then `git checkout HEAD -- untar.cpp` and rebuilt): PASS 15 /
  FAIL 7 - every written `a.txt` has the current time instead of the member's; the bad-checksum
  archive wrote `a.txt` = AAA unverified and was DELETED. The group part itself is controlled by the
  before measurement (`result_before.txt`, 9 FAIL; the only other change is T005-T008).
- Encoding guard: `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- Regression probes (`probe/regress_*.txt`, label regress-394, the branch build): 306 30 / 0,
  308 12 / 0, 309 16 / 0, 310 52 / 0, 321 tar 20 / 0, 321 unpack 12 / 0, 393 28 / 0 - each as
  recorded by feature 393.
- No UI string, dialog or resource changed: no `.slt` refresh needed (stop-rules §2.13 not triggered).

## Review
