# Fix log - 393-cpio-long-name

Backlog item `a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot`: a cpio / rpm archive with
a member name the panel listing cannot hold fails as a whole.

## Measurement at HEAD (af18dc21, `main`, before the branch)

- `.\build.cmd` (Debug x64): up to date.
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc_measure\cpio_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\321-tar-long-component\probe\tar321_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Only CPIO-TOOLONG -Label before-measure"`
  -> `CPIO-TOOLONG RUN PASS the archive did not open; ... at open: [#32770 'TAR Plugin Error'] [Static id=2477] Internal error: file data structure corrupted.`
  (the row only observes - 321 recorded the same). Registry restored, identical.
- Reachability: the panel opens a `.cpio` / `.rpm` through the TAR plug-in (`AddPanelArchiver`, default
  configuration) -> `CPluginInterfaceForArchiver::ListArchive` -> `CArchive::ListArchive` ->
  `ReadArchiveHeader` -> `ReadNewASCIIHeader` / `ReadOldASCIIHeader` / `ReadBinaryHeader` ->
  `ReadCpioName`; the refusal of 306 / 321 in `ReadArchiveHeader` runs only for
  `NameFromPax || NameFromGnu`; `AddFile` fails (321's 780-byte root bound) -> `IDS_TARERR_FDATA`,
  the listing ends.

## Consumers enumerated (fix protocol)

- `header.NameRefused`: `ListArchive` (hard-link listing guard), `UnpackOneFilePass` (found -> report,
  FALSE), `DoUnpackArchive` (found -> report, refused; link handling skipped).
- `header.Ignored`: `ListArchive` (not listed), `DoUnpackArchive` (`WriteOutData` skip),
  `IsCpioGroupMember` (feature 310 groups) - a refused carrier of a hard-linked file's data would be
  hidden from its group and the other names written empty (research R3) -> T007.
- `ListingPrefixLen`: set only by the .deb reader; 0 for cpio / rpm.
- cpio `IsDir` is set from the mode only after the refusal block (research R2) -> T006.

## Decisions

See research.md R1-R4.
