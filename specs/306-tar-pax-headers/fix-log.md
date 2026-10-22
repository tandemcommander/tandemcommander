# Fix log - 306-tar-pax-headers

Backlog item `tar-plug-in-ignores-pax-extended-headers`. Autonomous run (`/tandem-backlog-implement`).

## Measurement before (main at 8c6f4d68, Debug x64 build up to date)

Sites at HEAD: `src/plugins/tar/untar.cpp` `CArchive::ReadTarHeader` - `case XHDTYPE: case XGLTYPE:`
under "types we cannot handle" -> `header.Ignored = TRUE`; the data of the `x` / `g` header is skipped
by the callers' `WriteOutData(simulate)`, the next header (the member) keeps its ustar fallback.
Reachable: every route that reads the archive - the listing (`ListArchive`, opening the archive in
a panel), `UnpackArchive` (Copy / F5), `UnpackOneFile` (F3 / F4), `UnpackWholeArchive` (Unpack from a
disk panel), and the .deb / .rpm payloads through the same reader.

Probe `probe/pax306_probe.ps1` (fixtures `probe/mkpax306.py`, Python 3.14 `tarfile`), run on the
hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\pax306_probe.ps1 -Label before -Lib ...\fix_probe_lib.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Result `probe/result_before.txt`: **PASS 13, FAIL 9** (11 RUN rows + 11 END rows):

- PAX-LONG: only the folder `d*100` (the ustar cut) was created.
- PAX-CJK / PAX-TWINS / PAX-DEEP: "(123) invalid name" (the fallback is 100 `?`), nothing created.
- PAX-MTIME: time 1000000000 instead of 1600000000.25.
- PAX-SIZE: "Archive format not recognised or not supported." (the data read as a header).
- PAX-GLOBAL: 1000000000 / 1000000000 instead of 1500000000 / 1400000000.
- GIT-COMMENT, GNU-LONG: PASS (regression rows).
- PAX-TOOLONG: PASS before only because the fallback `?` name is refused by Windows.
- **GNU-TOOLONG**: opening the archive (a GNU long name with a 300-letter CJK component, 904
  bytes) crashed the program: RTC "Stack memory corruption", call stack `CFilesWindow::ChangeDir`
  -> `ChangePathToArchive` -> `CommonRefresh` (END FAIL, a bug report). Outside the item (GNU
  route, core) -> Inbox. Consequence for this feature: applying a PAX path of that length would
  crash the same way, so the refusal of FR-006 is required, not optional.

## Decisions

- Spec Clarifications (three, autonomous: conservative / item).
- Refusal for PAX paths only; GNU long names unchanged (scope).
- speckit-analyze: no CRITICAL / HIGH; E1 (FR-010 check), F1, C1 fixed in tasks.md / spec.md.

## Implementation

Consumers enumerated (Grep `ReadArchiveHeader`, `ReadTarHeader`, `Ignored`, `FileInfo.Size`, `MTime`):
`ListArchive`, `UnpackOneFile`, `DoUnpackArchive` (from `UnpackArchive` and `UnpackWholeArchive`) -
each starts its pass with `ReadArchiveHeader(header, TRUE)`, so the global PAX values are reset
there; `WriteOutData` reads / skips `FileInfo.Size` bytes (the PAX size); `MakeFileInfo` /
`SetFileTime` use `FileInfo.LastWrite` (the PAX time); the .deb route (`deb/`) uses the same
`CArchive`. cpio formats do not reach `ReadTarHeader`; `MTimeFrac` / `NameFromPax` stay 0 for them.

Changes:
- `src/common/salpaxheader.h` (new, header-only): record parser, `size` / `mtime` parsers, `SalPaxApply`,
  precedence (`SalPaxEffective*`), `SalPaxPathHasTooLongComponentU8`.
- `src/plugins/tar/tar.h`: `SCommonHeader::MTimeFrac`, `NameFromPax`; `CArchive::GlobalPax`,
  `ReportRefusedNames`, `RefusedNameShown`.
- `src/plugins/tar/untar.cpp` `ReadTarHeader`: an `x` / `g` header's data (<= 1 MiB, else the header
  error) is read like a GNU long name and applied (`x` -> the member's values, `g` -> `GlobalPax`);
  malformed -> `IDS_TARERR_HEADER`, TAR_ERROR; the member then takes the PAX path (over a GNU long name
  or the ustar name), size (not for links / directories) and mtime (+ 100-ns fraction).
  `XHDTYPE` / `XGLTYPE` removed from the "cannot handle" cases. `ReadArchiveHeader`: `GlobalPax`
  cleared when `probe`; after normalisation a PAX name with a component over 255 UTF-16 units is
  `Ignored` and, in a listing or whole-archive unpack, reported once with
  `GetErrorText(ERROR_FILENAME_EXCED_RANGE)` + the path (heap text, `LoadStrU8` title); the fraction is
  added after the FILETIME conversion. No new UI strings.
- `src/saltests/saltests.cpp`: `TestPaxHeader306`.

Traps met:
- The test's record builder looped forever when the length crossed a digit boundary (98 + 2 digits
  = 100); saltests hung, killed (not a probe), helper rewritten.
- Two wrong tests: `"10 path=a\n"` is exactly 10 bytes (valid); `std::string + "\0" "x"` appends
  nothing. Fixed the tests, not the code.
- A Python edit through a Bash here-document turned `"\n"` into a real newline in the C source
  (trap 123) - caught by grep, rewritten with the editor.
- The probe's `$rows` overwrote the library's `$script:Rows` (PowerShell names ignore case):
  "Collection size fixed" on the first row; renamed `$rowNames`.
- With the PAX branch disabled, `x` / `g` now reach the switch's default ("Unknown block signature")
  instead of the old silent skip - only in the negative control build.

## Measurement after

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- FR-010: `git diff main --stat -- src/plugins/tar/lang src/plugins/tar/tar.rc2 src/plugins/tar/tar.rh2`
  -> empty.
- `build.cmd` -> `BUILD SUCCEEDED` (the only warnings in untar.cpp are the three pre-existing C4267
  `FileInfo.NameLen = strlen(...)` lines).
- `saltests.exe` -> `saltests: 27126 checks, 0 failed`.
- Probe `pax306_probe.ps1 -Label after` -> `probe/result_after.txt`: **PASS 20, FAIL 0** (PAX-TOOLONG now
  has a second member `ok.txt`: the "(206)" message at open, only `ok.txt` extracted).
- Negative control 1, the `x` / `g` branch disabled -> `probe/result_negctl.txt`: PASS 12, FAIL 8
  (every PAX row; GIT-COMMENT and GNU-LONG pass).
- Negative control 2, only the FR-006 refusal disabled, `-Only PAX-TOOLONG` ->
  `probe/result_negctl_refusal.txt`: the program crashes ("Stack memory corruption", the same as
  GNU-TOOLONG) - the refusal is what prevents it.
- Regression probes on the final build: 252 `arc252_probe.ps1` 16 / 0 (`probe/regress_252.txt`), 273
  `arccase273_probe.ps1` 12 / 0 (`probe/regress_273.txt`), 275 `arcmember275_probe.ps1` 17 / 0
  (`probe/regress_275.txt`).
- clang-format applied to the new header and the added saltests lines afterwards (whitespace only);
  rebuilt, saltests 27126 / 0 again.
- Every probe run restored the registry (SHA-256 identical).

Inbox: `opening-a-tar-whose-member-name-has-a-300-letter-component` (measure:306) - the GNU-TOOLONG crash.

## Review

### Review 1 (independent agent, refute-first)

Reproduced: the official probe 20 / 0 on the branch build, saltests 27126 / 0, encoding guard 0,
no string diff; the official probe against the installed 0.1.10 fails the PAX rows (the probe
detects the defect). Own rows all correct: a 255-unit component (757 / 765 bytes) extracts; a bad
record length (first or middle header), an `x` header over 1 MiB and a NUL in a path refused with
the header error, just under 1 MiB accepted; `size=2^63-1` -> premature EOF; size on a directory
ignored; a PAX size smaller than the ustar size reads only the PAX size; invalid mtime ignored;
`mtime=-1.5` -> -1.5; `x` then GNU `L`; `path=` cancelling a global path; `../../` stays inside the
target; a value with an embedded newline; `.tar.gz`; `linkpath` ignored; `x` directly before the
end blocks; whole-archive Unpack (851) with two refused members - one (206) box, the rest extracted.

- **MUST-1 (fixed)**: a PAX path deeper than the panel listing holds made the WHOLE archive
  unopenable - `CSalamanderDirectory::AddFile` / `AddDir` (`src/zip.cpp`, feature 222) refuse a
  folder part or a folder name over `MAX_PATH - 5` bytes, and the plug-in's `ListArchive` then gives
  up the listing ("Internal error: file data structure corrupted."). The ustar fallback (<= 255
  bytes, Python cuts at 100) never reached it: a regression against 0.1.10 for e.g.
  `<90 CJK>/f.txt`, `a*130/b*130/f.txt`, a folder of 255 CJK letters. Fix: `SalPaxNameFitsListingU8`
  (`src/common/salpaxheader.h`) - a component over 255 units, a folder part over 255 bytes or a
  folder member's name over 255 bytes refuses that member alone (the same "(206)" message, once);
  used in `ReadArchiveHeader` instead of the component check. saltests +16 checks.
- **SHOULD-1 (fixed)**: the probe did not cover the listing's limits - rows PAX-PATHPART (a.txt,
  `<90 CJK>/f.txt`, `a*130/b*130/g.txt`, ok.txt -> a.txt + ok.txt, "(206)"), PAX-255DIR (a folder of
  255 CJK letters and a file in it, ok.txt -> ok.txt, "(206)") and PAX-LIMIT (folder part exactly
  255 bytes -> extracted).
- NOTE 1 (accepted, limit): an archive that ends with an `x` header and no end blocks now fails
  with "Premature end of file" (0.1.10 listed the member before it through its missing-end-block
  heuristic) - a damaged archive; the GNU long name route behaves the same.
- NOTE 2 (accepted, FR-006 "once per operation"): only the first refused member is named, later
  ones are skipped without their own box; a masked whole-archive unpack would also report a refused
  member the mask does not select (by reading). No new strings allowed for a count.
- NOTE 3 (accepted): for `L` -> `x` -> member the PAX path wins (spec, GNU tar); Python's tarfile
  takes the GNU name in that order.
- NOTE 4 (accepted): a `g` header with `path=` names every following member the same (POSIX); the
  overwrite question appears, nothing is overwritten unasked.
- NOTE 5 (fixed in the probe): Copy ran even when the archive had not opened (the panel elsewhere);
  every row now reads the panel's path first and copies only from inside the archive.

After the fix: build `BUILD SUCCEEDED`; saltests `27142 checks, 0 failed`; probe (label
after-review1) **PASS 26, FAIL 0**.

### Interruption

The session ended while review 2 ran (the maintainer had the installed program open 12:07-12:09, so
probes refused - "tandemcommander.exe already runs" - and the listing negative control waited).
On continuing: branch `306-tar-pax-headers`, lock still held by this item, no probe backup left in
`%TEMP%` (review 2's runs had restored the registry, identical SHA-256); review 2 resumed.

### Review 2 (independent agent, refute-first; previous findings given)

No MUST. Reproduced: official probe 26 / 0, saltests 27142 / 0; the MUST-1 rule matches
`AddFile` / `AddDir` for `ListArchive(NULL, ...)` and runs on the decoded, normalised name; own rows
B-FOLDLONG (folder part 250 bytes + a 255-letter CJK name, 1016 bytes) and B-FOLDLONG2 (1021 bytes)
list and extract whole - the GNU-TOOLONG crash is not about the total length, the 255-unit
component refusal is enough.

- **SHOULD-1 (fixed)**: a .deb lists its tar parts under `control\` (8 bytes) and `data\` (5)
  (`CDEBArchive::ListArchive`, `src/plugins/tar/deb/deb.cpp`), which the check did not count: a
  data.tar member with a folder part of 251-255 bytes passed it, `AddFile` refused it, and that part's
  listing stopped there ("Internal error: file data structure corrupted.", a partial `data` folder;
  0.1.10 listed the 100-byte fallback). Fix: `SalPaxNameFitsListingU8(name, isDir, prefixLen)`;
  `CArchive::ListingPrefixLen`, set by `CDEBArchive`'s constructor for both parts
  (`SetListingPrefixLen`), so the listing and every extraction pass refuse the same members.
  saltests +7; probe row PAX-DEB (review 2's B-DEB).
- NOTE 1 (fixed): `mtime=910692730085.9` (the last second with a fraction over 0.4775807) passed
  2^63 - 1 after the FILETIME conversion - `SAL_PAX_MTIME_MAX_FRAC`; saltests check the largest
  accepted time converts to exactly 0x7FFFFFFFFFFFFFFF.
- NOTE 2 (fixed): the message boxes of the new PAX code took code-page `LoadStr` texts while
  `ShowMessageBox` is a UTF-8 sink - now `LoadStrU8` (standing rule; the old code of the file keeps
  its `LoadStr`).
- NOTE 3 (accepted, FR-007): a malformed PAX record refuses the whole archive; 0.1.10 opened it under
  the fallback names.
- NOTE 4: the regression probes re-run on the final build (below).
- NOTE 5: CHANGELOG / FEATURE-HISTORY drafts were in the working tree; the CHANGELOG text holds for
  .deb too after SHOULD-1.

Negative control 3, the two listing checks disabled (`prefixLen + folderPart` and the folder-name
check), `-Only PAX-PATHPART,PAX-255DIR,PAX-LIMIT,PAX-DEB` -> `probe/result_negctl_listing.txt`:
PASS 5, FAIL 3 - PATHPART and 255DIR do not open ("Internal error: file data structure
corrupted.", Copy not attempted - the panel check), PAX-DEB lists a partial `data`; PAX-LIMIT (the
boundary) passes.

## Final checks (after review 2, source restored, rebuilt)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; FR-010 diff empty.
- `build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `saltests: 27152 checks, 0 failed`.
- Probe `pax306_probe.ps1 -Label after-review2` -> `probe/result_after.txt`: **PASS 28, FAIL 0**.
- Regression probes: 252 16 / 0, 273 12 / 0, 275 17 / 0 (`probe/regress_*.txt`).
- Every probe run restored the registry (SHA-256 identical).
