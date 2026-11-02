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

## Regression (T008) - on the restored build (commit 4533e82e code)

| Probe | Result | Recorded before |
|---|---|---|
| `cpio393_probe` re-run (`result_after.txt`) | 22 / 0 | - |
| 310 `cpio310_probe` (`regress_310.txt`) | 52 / 0 | 52 / 0 |
| 321 `tar321_probe` (`regress_321_tar.txt`) | 20 / 0 | 20 / 0 |
| 321 `unp321_probe` (`regress_321_unp.txt`) | 12 / 0 | 12 / 0 |
| 306 `pax306_probe` (`regress_306.txt`) | 30 / 0 | 30 / 0 |
| 308 `unp308_probe` (`regress_308.txt`) | 12 / 0 | 12 / 0 |
| 309 `link309_probe` (`regress_309.txt`) | 16 / 0 | 16 / 0 |

Behaviour change seen in 321's rows (intended, recorded): CPIO-TOOLONG now opens (was: did not open,
an observing row); CPIO-778 (`.` + 777 letters, one 778-unit component) now opens with the "(206)"
message instead of listing the name - no file system takes such a component (an extraction failed
with "(123)" before), and PAX / GNU names of that kind are refused the same way since 306 / 321. The
row's purpose (no overflow of the simple-icons buffers) is unchanged: a listed name's extension is now
at most 255 UTF-16 units (<= 765 bytes + 4 < 780).

## Review

### Review 1 (independent, refute-first) - no MUST

- Re-ran the probe on HEAD 3f3481b0: 22 / 0. Own negative control (only the `found && !NameRefused`
  guard reverted, tar plug-in built in a worktree): UNP-HARD-REFUSED-DEL fails (0 of 2 files, a "(123)"
  Retry / Skip box) - the guard matters alone and the probe catches it.
- SHOULD-1: FR-006 / SC-005 promised the data for the other names without qualification; with the data
  on the refused FIRST name (data-first layout) the other name is reported ("(2)") and the operation
  fails (feature 310's rule for a data member not asked for) - no loss, archive kept. Done: FR-006,
  SC-005 and the edge case narrowed to what the code does; probe rows COPY-HARD-FIRST and
  UNP-HARD-FIRST-DEL added (expect: a.txt reported during the copy / unpack, ok.txt, archive kept);
  giving the data in that layout too -> Inbox `a-cpio-name-stored-after-its-data-on-a-refused-name-is`
  (review:393).
- NOTE-1: a cpio symbolic link with a refused name (never listed) is now named by "(206)" at opening;
  a whole Unpack fails for it as a refused name instead of feature 310's link report (both fail, both
  keep the archive) - the same as PAX / GNU symlinks. Recorded in the spec's edge cases; probe row
  COPY-SYMLINK-LONG added.
- NOTE-2: 321's `tar321_probe.ps1` header described CPIO-778 / CPIO-TOOLONG with the old behaviour -
  updated (comment only).
- NOTE-3: binary / byte-swapped cpio and F3 of a refused carrier not probed (shared code; read only).
  Accepted.
- NOTE-4 (pre-existing): a carrier whose name normalizes to empty is dropped from its group and the
  other names are written empty with success -> Inbox `a-cpio-hard-link-whose-data-name-normalizes-to-empty-is`
  (review:393, severity 7, not verified by a probe).
- NOTE-5: old worktrees of earlier reviews are still registered (`%TEMP%\rev325` ...) - not this
  feature's; left alone.

Probe after review 1 (`result_after.txt`, label `after-review1`): PASS 28 / FAIL 0 (14 RUN rows),
registry restored, identical.
