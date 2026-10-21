# Fix log - 276 the information line shows items with very long names

Backlog item `focusing-an-archive-member-with-a-very-long-name-shows` (source measure:260).

## Measurement before (main at de31d72a, Debug x64 build of that commit)

Cause, by reading:

- `CFilesWindow::ItemFocused` (src/fileswn2.cpp) expands `Configuration.InfoLineContent` with
  `ExpandInfoLineItems` (src/execute.cpp) into `char buff[1000]`; the only caller of
  `ExpandInfoLineItems`.
- The default content (src/dialogs4.cpp) is
  `$(FileName): $(FileSize), $(FileDate), $(FileTime), $(FileAttributes), $(FileDOSName)`;
  `FileDataExpFileDOSName` returns the name itself when `DosName == NULL` - every archive member,
  and disk files without a short name. A 604-byte name needs 2 x 604 + about 50 bytes.
- `DoExpandVarString` (src/salamdr2.cpp) then shows IDS_EXP_SMALLBUFFER "Expanded string is too
  large." (the panel window as parent) and returns FALSE; `ItemFocused` leaves the information
  line unchanged - it keeps describing the previous item.
- "Twice": at a panel's start both panels focus an item - the probe's content rows saw two boxes
  at the start (both panels overflow); a single key press gave one box.

Probe `probe/infoline276_probe.ps1` (new; hidden desktop; the information line captured with
PrintWindow and its rectangle hashed - PIXCTL proves two short items give different hashes):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\276-infoline-long-name\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\276-infoline-long-name\probe\infoline276_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

- `result_before_v1.txt` (first version, before the analyze rows): 13 PASS / 4 FAIL; its ARCMAX
  row tested nothing - a 964-byte member was refused by the ZIP listing ("total path is too long",
  the listing takes at most 255 UTF-16 units, feature 222); the row now uses 251 CJK letters +
  ".txt" (757 bytes / 255 units).
- `result_before.txt`: **16 PASS / 7 FAIL** - ARCCAP (604 bytes), ARCMAX (757), ARCDEEP (604 in an
  84-letter folder) FOCUS + LINE FAIL (one box, line unchanged); WIDTH
  (`$(FileName:3000) $(FileDOSName:3000)`) FAIL; DISK (754-byte file; C: gave it the 8.3 name
  0771~1.TXT, so the second name is short) PASS; ARCSHORT PASS; BADSYNTAX (`$(FileName`) and
  OVERCAP (12 x `$(FileSize:9999)`) one box each - the behaviour FR-006 keeps. Registry restored,
  identical hash.

## Decisions

- Grow, never shorten (spec Clarifications): first attempt in the 1000-byte stack buffer, then a
  heap buffer 2000 ... 64000, 65535 (`salinfolinebuf.h`); attempts before the last pass no parent
  window (no box); the last one passes the panel - a malformed content or a text over the bound
  reports once, as before.
- The plug-in route `GetInfoLineContent` keeps 1000 bytes (plug-in contract, spl_com.h).
- Analyze: no CRITICAL / HIGH. MEDIUM C1 / C2 fixed (probe rows WIDTH, BADSYNTAX, OVERCAP). LOW
  C3 accepted: hot-text positions are computed by the same `DoExpandVarString` (bytes in the
  buffer, WORD-sized - the bound keeps them below 65,536; saltests checks the bound) and the
  information line exposes no text, so the probe cannot click them. LOW C4 accepted: the
  selection summary, the empty-panel text and the plug-in route are not in the diff.

## Implementation

- `src/common/salinfolinebuf.h` (new): `SAL_INFOLINE_FIRST_LEN` 1000, `SAL_INFOLINE_MAX_LEN` 65535,
  `SalInfoLineNextLen` (doubling, capped, 0 at the bound).
- `src/fileswn2.cpp` `CFilesWindow::ItemFocused`: the plug-in route unchanged into the stack
  buffer; the core's expansion first into the stack buffer, then into a heap buffer grown by the
  rule; every attempt but the last with no message parent; `varPlacementsCount` reset per attempt;
  low memory traces and leaves the line alone; the heap buffer freed.
- `src/saltests/saltests.cpp` `TestInfoLineBuf276`: the sequence (7 steps, 8 attempts), the ends,
  the defect's case over 1000 bytes, two 765-byte names and 18 names of 765 bytes under the bound,
  the WORD limit.

## Checks (after)

- Build: `.\build.cmd` -> BUILD SUCCEEDED, no warning in the touched files.
- `saltests.exe` -> `saltests: 24887 checks, 0 failed` (24,873 before + 14 new).
- Negative control: `SAL_INFOLINE_MAX_LEN` set to 1000 -> `saltests: 24873 checks, 6 failed`
  (TestInfoLineBuf276); restored -> 0 failed. (The edit through PowerShell dropped the header's
  BOM; restored before the commit - the encoding guard checks it.)
- Probe `probe/result_after.txt`: **23 PASS / 0 FAIL / 0 NOT DRIVEN** (before 16 / 7): ARCCAP,
  ARCMAX, ARCDEEP no box and the line changes; WIDTH (about 6 KB) no box; BADSYNTAX and OVERCAP
  exactly one box each, as before; DISK, ARCSHORT unchanged PASS. Registry restored, identical.
- Regressions: 260's `cache260_probe.ps1` -> `probe/regress_260.txt` 16 / 0 (its "monitored
  handles" Debug notes were there in 275's run too); 275's `arcmember275_probe.ps1` ->
  `probe/regress_275.txt` 17 / 0 - its EDITCAP / EDITDEEP rows no longer meet the information
  line's box before F4 ("F4: no window").
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.

## US2 - disk names without 8.3 names (T008)

The DISK row (754 bytes, 254 units) passes before and after: the probe volume C: gave the file the
short name 0771~1.TXT, so `$(FileDOSName)` is short. A volume without 8.3 names (`fsutil 8dot3name`
needs an administrator - "Error 5" here) reaches the same `ItemFocused` code with
`DosName == NULL` and is covered by the same fix; not driven. The WIDTH row drives the same
growth with 6 KB from short names.
