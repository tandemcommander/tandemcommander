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
