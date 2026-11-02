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

## Probe (T002-T004)

`probe/cpio393_probe.ps1` + `probe/mkcpio393.py` (11 RUN rows, each with an END row = 22 rows).
Command (PowerShell, repository root):
`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\393-cpio-long-name\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\393-cpio-long-name\probe\cpio393_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

- before (af18dc21 code, `result_before.txt`): PASS 14 / FAIL 8. COPY-TOOLONG, COPY-ODC-TOOLONG,
  COPY-RPM-TOOLONG, COPY-DEEP, COPY-NESTDIR, COPY-HARD-REFUSED: "Internal error: file data structure
  corrupted.", the archive does not open. UNP-TOOLONG-DEL / UNP-HARD-REFUSED-DEL: nothing extracted,
  a "(123) invalid name" Retry / Skip box (the archive kept). COPY-255, COPY-DIR100, UNP-DEEP-DEL pass
  (names that fit; the deep whole unpack never lists).

## Implementation (T005-T007), `src/plugins/tar/untar.cpp`

- `ReadArchiveHeader`: the 306 / 321 refusal also for `cpioName` (format newc, crc, odc, binary,
  byte-swapped binary), `isDir` = trailing slash OR cpio mode `CP_IFDIR` (`nameIsDir`).
- `IsCpioGroupMember`: `!Ignored || NameRefused` - a refused name stays in its hard-link group.
- `DoUnpackArchive`: `WriteOutCpioGroupMember(..., found && !header.NameRefused, ...)`.
- Build: `BUILD SUCCEEDED` (the three C4267 warnings are existing `NameLen = strlen(...)` lines whose
  numbers moved).

## After (`result_after.txt`)

PASS 22 / FAIL 0: every TOOLONG row (newc, odc, rpm) shows "(206)" with the path at opening and
copies ok.txt; COPY-DEEP opens with "(206)" and copies the 33 listed-subtree files; COPY-NESTDIR
"(206)" at opening, n/top.txt + ok.txt; COPY-HARD-REFUSED a.txt = AAA; UNP-TOOLONG-DEL ok.txt, "(206)"
box, archive kept; UNP-HARD-REFUSED-DEL a.txt = AAA, ok.txt, "(206)", kept; UNP-DEEP-DEL all 34,
deleted. Registry restored, identical.

## Negative control (T010, `result_negctl.txt`)

Temporary edit (reverted with `git checkout HEAD -- src/plugins/tar/untar.cpp`, rebuilt): `nameIsDir =
header.IsDir`, `IsCpioGroupMember` back to `!Ignored`, `found` passed unchanged to the group. Result
PASS 19 / FAIL 3, exactly the predicted rows: COPY-NESTDIR (the archive does not open again - the
mode-only folder's 300-byte name reaches `AddDir`), COPY-HARD-REFUSED and UNP-HARD-REFUSED-DEL
(`a.txt` written EMPTY). The cpio refusal itself has its negative control in `result_before.txt`.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `saltests.exe` -> `saltests: 30798 checks, 0 failed` (no new rule).
- No UI strings, dialogs or resources changed -> no `.slt` refresh (stop-rules 2.13 not triggered).
