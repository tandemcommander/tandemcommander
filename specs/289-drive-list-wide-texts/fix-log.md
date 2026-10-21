# Fix log - 289-drive-list-wide-texts

Backlog item `drive-list-code-page-texts` - Drive list and folder type names use code-page shell
texts. Autonomous run (`/tandem-backlog-implement`), HEAD0 `cf860604`.

## Measurement before (at cf860604, on `main`)

Machine: ACP 1250 (`HKLM\...\Nls\CodePage\ACP`), Czech display language, not elevated, drives
C: D: E: F: G: all fixed (`Win32_LogicalDisk` DriveType 3) - no removable, no CD.

Sites found at HEAD (searched by name, not line):

| Site | What | Sink |
|---|---|---|
| `icncache.cpp` `ReadDirectoryIconAndTypeAux` | `SHGetFileInfo` (A) `SHGFI_TYPENAME` of the system dir -> `FolderTypeName[80]` | panel *Type* column (`salamdr4.cpp` `InternalGetType` -> `TransferBuffer` -> `fileswn4.cpp`; width `fileswn2.cpp`) - UTF-8 first, code-page fallback |
| `salamdr1.cpp` | `UpDirTypeName = DupStr(LoadStr(IDS_UPDIRTYPENAME))` (code page) | same |
| `drivelst.cpp` `GetDisplayNameFromSystem` | `SHGetFileInfo` (A) `SHGFI_DISPLAYNAME` of a removable root | Change Drive menu (`BuildData`), drive bar tooltip (`GetDriveBarToolTip`) |
| `drivelst.cpp` `ReadCDVolNameThreadFBody` | `GetVolumeInformation` (A) CD label, fallback `GetDisplayNameFromSystem` | menu, tooltip |
| `drivelst.cpp` `BuildData` / `AddToDrives` / `GetDriveBarToolTip` / `ExecuteItem` | `LoadStr` of IDS_FLOPPY350/525/800, IDS_REMOVABLE_DISK, IDS_LOCAL_DISK, IDS_COMPACT_DISK, IDS_MYDOCUMENTS, IDS_GOOGLEDRIVE, IDS_DROPBOX, IDS_ONEDRIVE, IDS_ONEDRIVEPERSONAL, IDS_NETWORKDRIVE; `PrintDiskSize(..., u8 = FALSE)`; mixed with the UTF-8 fixed-drive label (069), network texts (246), OneDrive business names (`SalRegQueryValueExW8`, UTF-8) | menu (`CMenuPopup`, UTF-8 first), tooltip (`tooltip.cpp` `SalU8ToW`, CP_ACP fallback) |

Reachability: Alt+F1 / Alt+F2 (Change Drive menu) -> `CDrivesList::BuildData` for every removable
/ CD / fixed drive; drive bar hover -> `CDriveBar::OnGetToolTip` -> `GetDriveBarToolTip`; every
panel listing with the *Type* column -> `InternalGetType`. Default configuration.

Harness (`%TEMP%\tc_measure_dl\measure.ps1`, PowerShell P/Invoke, input given as a PIDL so only
the output conversion is measured):

```text
ACP = 1250
[name] A bytes: 3F 3F 3F | W as UTF-8: D0 94 D0 BE D0 BC | A decoded equals W: False
[type] A bytes: 53 6C 6F 9E 6B 61 20 73 6F 75 62 6F 72 F9 | W as UTF-8: 53 6C 6F C5 BE 6B 61 20 73 6F 75 62 6F 72 C5 AF | A decoded equals W: True
```

- `SHGetFileInfoA` loses a name outside the code page entirely ("Дом" -> "???"); the wide call is
  exact. Same mechanism for a removable drive's display name; `GetVolumeInformationA` likewise
  (measured by feature 069 for fixed drives).
- The folder type name is stored as cp1250 bytes, not UTF-8; it shows right here only through
  the sinks' code-page fallback.
- All enabled translations of the affected strings (en, cs, de, fr, nl, hu, ro, sk, es) fit cp1250
  (checked from `translations/*/salamand.slt`), so no language choice reproduces the `LoadStr`
  part here either.
- End-to-end (a `????` CD / removable label, a `?` folder type name) needs a CD / removable drive
  labelled outside the code page or a display language outside the code page: **owed to a
  person**. The change is verified here by the bytes stored (valid UTF-8 equal to the wide text)
  and by an unchanged display.

## Decisions

- Clarify (autonomous): buffers grow so nothing is cut; no ANSI retry after a failed wide call
  (069 precedent); hot paths / plug-in items / remembered network chain out of scope.
- Analyze run 1: 0 CRITICAL, 0 HIGH; MEDIUM F1 (the "before" binary needs the seam - T001/T006
  reworded), MEDIUM C1 (SC-002 "same decoded text" had no task - added to T018); LOW A1 (API
  names in the spec's Background) accepted - traceability of the measurement. Run 2: only A1.

## Implementation log

- T001: `.\build.cmd` of the unchanged tree: BUILD SUCCEEDED.
- T002/T003: `src/common/saldrivetext.h` + `TestDriveText289` in saltests.
- T004: seam - `TYPES` after `BUILD`, `ALL` at the end of `BuildData` (whole list), `TIP` for
  every drive type (`ProbeDumpToolTips` over every non-separator drive item).
- T005: `probe/run289.ps1` (English and Czech; rows TYPES / ITEM / ALL / TIP).
- T006 (seam only, no fix; build 18:33, saltests 25,237 checks, 0 failed): hidden-desktop probe
  `probe/result_before.txt`, `results_before.txt`, `decoded_before.txt`: **PASS 3, FAIL 5** -
  TYPES-english / TYPES-czech FAIL (folder type "Složka souborů" in cp1250 bytes; Czech display
  language), ITEM-czech FAIL (3 of 15 lines not UTF-8: `C<TAB>Místní jednotka<TAB>60,8 GB`),
  ALL-czech FAIL (6 of 24: the C: item, "Síť"), TIP-czech FAIL (6 of 44: "Místní jednotka
  (60,8 GB)"); English ITEM / ALL / TIP PASS (ASCII words). Registry restored, SHA-256 identical.
  The negative control fails as it must.
- T007-T015 (the fix): `GetDisplayNameFromSystem` -> `SHGetFileInfoW` + `SalDriveNameTrimLetterSuffixW`
  + `SalWToU8` (failure: empty, as before); CD thread -> `GetVolumeInformationW` into a
  `SAL_DRIVE_TEXT_U8_MAX` buffer, no code-page retry, `strcpy_s` into the equally sized
  `ReadCDVolNameBuffer` (was `lstrcpyn` at `MAX_PATH` - a cut); `FolderTypeName[241]` from
  `SHGetFileInfoW` (system directory via `GetSystemDirectoryW`); `UpDirTypeName` from
  `LoadStrU8`; `volumeName` buffers `DRIVE_MENU_NAME_MAX + 100` with the ampersand doubling bounded
  by `DRIVE_MENU_NAME_MAX`; 29 `LoadStr` -> `LoadStrU8` in the drive list (floppies, removable /
  local / compact disk, Documents, Google Drive, Dropbox, OneDrive (+ Personal, both offsets that
  read the business name back), Network, Another Panel, `AddToDrives`); both free-space texts
  `PrintDiskSize(..., TRUE)`. Static asserts tie the buffer sizes to `saldrivetext.h`.
- T016: left in `drivelst.cpp` / `icncache.cpp`: `LoadStr` of message-box captions and texts (code
  page sinks, not drive-list texts) and feature 069's transitional `GetVolumeInformation` (A)
  fallback for a root that is not valid UTF-8 (cannot happen for "X:\"). Nothing feeds the
  drive list or the type names any more.
- T017: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `.\build.cmd` ->
  BUILD SUCCEEDED (touched files recompiled 18:36:47, no warning); saltests -> `25237 checks,
  0 failed`.
- T018 (fixed build 18:36): `probe/result_after.txt`, `results_after.txt`: **PASS 8, FAIL 0**
  (TYPES / ITEM / ALL / TIP, English and Czech; every line valid UTF-8; registry restored,
  SHA-256 identical). SC-002: `decoded_before.txt` and `decoded_after.txt` (each line decoded
  the way the sinks decode - UTF-8, else cp1250 - free space removed): 210 lines each,
  `diff` -> identical, also in order. The display on this machine is unchanged; only the
  bytes are now UTF-8.
- T019 person step (NOT DRIVEN here - no such hardware / locale): (1) a CD / DVD or ISO and (2) a
  USB stick labelled in Cyrillic or Greek on a cp1250 / cp1252 system: Alt+F1 and the drive bar
  tooltip show the label as Explorer does (was `????`); (3) a Windows display language outside
  the system code page (e.g. Japanese display language, English non-Unicode setting): the *Type*
  column of folders shows the display language's "File folder" (was `?`).

## Review

Review 1 (independent agent, refute-first; it re-ran the fix-log measurement - reproduced -, built,
ran saltests 25,237 / 0 failed and the encoding guard 0; it could not re-run the GUI probe because
an installed `tandemcommander.exe` was running at that moment, and read the committed results):
**no MUST**.

- SHOULD S1 - the CD / removable label paths have no evidence beyond code reading; the reviewer
  suggested mounting an ISO labelled "Диск" (IMAPI2FS + Explorer's *Mount*). Not done: mounting
  puts a new drive into the maintainer's visible session (Explorer, AutoPlay) while the maintainer
  works on the machine; it stays a person step with exact steps (ISO and USB), see *Owed to a
  person*. The code of both paths follows feature 069's measured `GetVolumeInformationU8Menu`.
- NOTE N1 - the seam logs a TIP for every item now (plug-in items, hot paths, other panel); the
  246 / 264 probes key tooltips by the first character - no clash here (keys `/ ' ; , . TAB`
  and digits vs drive letters). Accepted, Debug-only.
- NOTE N2 - the probe header claimed hot paths / plug-in items were never written out (the TIP
  rows do write their tooltips: empty for hot paths, the command name for plug-ins), and the ALL
  filter left out `drvtOtherPanel`, so the changed `IDS_ANOTHERPANEL` was not measured. Fixed:
  header corrected, type 14 checked against "As Other Panel" / "Jako druhý panel". Re-run 18:48
  (`result_after.txt`, `results_after.txt`): PASS 8, FAIL 0; ALL-czech now 27 lines incl. 3
  "Jako druhý panel", all UTF-8. `decoded_after.txt` minus its 8 type-14 lines equals
  `decoded_before.txt` (210 lines; the before run predates the type-14 check).
- NOTE N3 - `consts.h` comment still said `LoadStr(IDS_UPDIRTYPENAME)`: fixed.
- NOTE N4 - subst targets: `MyQueryDosDevice` falls back to the code page when the UTF-8 form
  does not fit `MAX_PATH` bytes, `GetSubstInformation` cuts with `lstrcpyn`, and `ResolveSubsts`
  uses the result; outside this item -> Inbox item
  `a-subst-drive-whose-target-is-long-or-outside-the-code-page` (review:289). The remembered-path
  `min(l, MAX_PATH - 1)` display cut is noted there too.
- NOTE N5 - `result_*.txt` (runner log) vs `results_*.txt` (the script's file) are both kept as
  in earlier features; the closing artifacts follow in the close step.

After the fixes: `.\build.cmd` BUILD SUCCEEDED, saltests 25,237 checks 0 failed, encoding guard
TOTAL 0, probe PASS 8 / FAIL 0. No second review needed (no MUST finding).
