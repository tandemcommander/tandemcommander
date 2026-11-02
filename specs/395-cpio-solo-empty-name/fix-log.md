# Fix log - 395-cpio-solo-empty-name

Backlog item `unpack-silently-drops-a-cpio-file-whose-only-name-normalizes` - Unpack silently drops a
cpio file whose only name normalizes to empty.

## Measurement before (main bb8aa693, Debug x64 - `.\build.cmd` -> BUILD SUCCEEDED, up to date)

New probe `probe/cpiosolo_probe.ps1` (fixtures `probe/mkcpiosolo.py`, copied from 394's probe; odc
writer from 393's, a new ustar writer), run from a work folder before the branch existed:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <work>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <work>\cpiosolo_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result `probe/result_before.txt`: PASS 22 / FAIL 10; registry restored, identical.

- FAIL (the defect, 9 rows): `UNP-SOLO-DOT-DEL`, `-DOTSLASH-`, `-NUL-`, `UNP-CRC-SOLO-DOT-DEL`,
  `UNP-ODC-SOLO-DOT-DEL`, `UNP-RPM-SOLO-DOT-DEL`, `UNP-ORPHAN-DOT-DEL`, `UNP-CRC-ORPHAN-DOT-DEL`,
  `UNP-TAR-SOLO-DOT-DEL` - each extracted only `ok.txt`, showed no window and DELETED the archive.
- FAIL (the probe's own fault): `COPY-SOLO-DOT` counted the core's Copy dialog as a window; the
  row now accepts that dialog and rejects any box with an error code.
- PASS (controls): `UNP-SOLO-DOT-ZERO-DEL`, `UNP-ORPHAN-DOT-ZERO-DEL`, `UNP-DOTDIR-DEL`,
  `UNP-TAR-DOTDIR-DEL`, `UNP-WAIT-DOT-DEL` (a.txt = AAA), `UNP-SOLO-DOT-MASK` (mask `*.txt`).

Decision on tar (the item's Notes): a ustar regular member `.` with data is dropped the same way
(row `UNP-TAR-SOLO-DOT-DEL`) - so it gets the same rule.

Cause (code at HEAD): `ReadArchiveHeader`, "skip invalid names", marks every member whose name
normalizes to nothing `Ignored` (cpio: also `NameEmpty`, 394). `DoUnpackArchive` then passes
`simulate = Ignored || !found` to `WriteOutData` (a single-name member) or, for a newc / crc group
member, `SalCpioLinkDecide` returns `SAL_CPIO_LINK_SKIP` when no name waits (orphan group): the data
is read past, nothing sets `refused`, the operation returns TRUE and the core deletes the archive.
