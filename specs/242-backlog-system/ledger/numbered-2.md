# Ledger part numbered-2

Source: `NEXT-WORK.7993914c.md` lines 1212–2205 (sections 5, 6, 7, 8) and
2219–2226 (*Protocol*). Compared against *Open items at a glance*
(lines 110–868, labels `NW §A.<n>`, `NW §B`, `NW §C`, `NW §D`).

## 5. Encoding: cluster B-2

| Source | Destination |
|---|---|
| NW §5 header "B-2 — core identity DONE (feature 092)" (L1212) | done (feature 092) |
| NW §5 092-left "Delete-then-retry trusts a name rule alone" (L1222) | done (feature 103) |
| NW §5 103-left "a real macOS/Samba share was not driven" (L1236) | see NW §B "Environment or hardware" (a real macOS or Samba share, 103, 107) |
| NW §5 103-left "a copy on a file system without file ids refuses a *different* file" (L1238) | see NW §C "Copies and identity" (identity limits on file systems without ids, 103) |
| NW §5 103-left "a copy onto a symbolic link that points at the source is now refused" (L1239) | item:identity-limits-without-file-ids (*Problem*) (corrected after review N4: was see NW §C "Copies and identity", whose item did not carry it) |
| NW §5 103-left "hard links on file systems that do not share share-mode state" (L1240) | item:identity-limits-without-file-ids (*Problem*) (corrected after review N4: was see NW §C "Copies and identity", whose item did not carry it) |
| NW §5 103-left "the ZIP plug-in can overwrite a selected source with the new archive's file" (L1241) | done (feature 106) |
| NW §5 found-by-106 "a failed multi-volume pack leaves the volumes … / `name.z0N` / 7-Zip packs a selected archive into itself / ZIP *Add* sharing violation" (L1249) | done (feature 119) |
| NW §5 found-by-119 "`translate.merge --module zip` would re-lay out 510 controls" (L1269) | done (feature 166) |
| NW §5 found-by-119 "the Pack dialog's refusal reuses 'Cannot copy a file to itself.'" (L1271) | done (features 119 and 155) |
| NW §5 "a case-sensitive folder still refuses `a.txt` -> existing `A.txt`" (L1276) | done (feature 158) |
| NW §5 found-by-103 "PictView's Rename fails with error 32 for the image it shows" (L1278) | done (feature 111) |
| NW §5 103 second review "renaming or moving a symbolic link onto the file it points at deleted that file" (L1281) | done (feature 103) |
| NW §5 103 second review "moving a FOLDER onto an alias of itself between two roots" (L1283) | done (feature 107) |
| NW §5 found-by-107 "a folder COPY into itself or its own subfolder still makes a snapshot copy" (L1296) | see NW §C "Copies and identity" |
| NW §5 found-by-107 "a refused folder copy says 'Cannot copy a file to itself.'" (L1298) | done (feature 155) |
| NW §5 found-by-107 "a local folder and a WebDAV path of the same folder … not recognised as one" (L1301) | see NW §C "Copies and identity" (recorded with reasons in 107) |
| NW §5 found-by-107 "two DIFFERENT WebDAV servers holding one path … count as one" (L1303) | see NW §C "Copies and identity" (recorded with reasons in 107) |
| NW §5 found-by-107 "a folder reachable through two shares of a NAS that gives each share its own volume serial" (L1306) | see NW §C "Copies and identity" (NAS shares with their own serials) |
| NW §5 found-by-107 "restoring an UNCHANGED file from a snapshot is refused 'to itself'" (L1308) | not migrated: recorded behaviour with nothing to restore (107 fix-log), no work |
| NW §5 found-by-107 "snapshots and FAT volumes could not be driven here (no admin, no FAT volume)" (L1310) | see NW §B "Environment or hardware" (snapshots and FAT volumes, 107, admin) |
| NW §5 found-by-107 "two differently named `@GMT` folders joined by a junction could hide an alias" (L1311) | item:gmt-snapshot-folders-joined-by-junction-alias |
| NW §5 found-by-107 "a merge costs ~1 ms more per folder over SMB" (L1312) | not migrated: accepted cost, recorded in `107-folder-alias-move/fix-log.md` |
| NW §5 found-by-107 "paste and drag & drop cannot be driven on the hidden desktop … `107/quickstart.md` step 5" (L1313) | see NW §B "By hand" (107 step 5) |
| NW §5 found-by-107 "Still open: the Renamer's refusal says 'already exists'" (L1314) | done (features 155 and 196) |
| NW §5 "Decision (maintainer, 2026-10-04): the remaining B-2 systemic work is NOT implemented" (L1317) | see NW §C "B-2 systemic comparison" |
| NW §5 "The panel sort comparator is intransitive with 'Use locale' off" (L1327) | see NW §C "B-2 systemic comparison" |
| NW §5 "`CSalamanderDirectory` (archive and plug-in listings) compares names by the byte fold" (L1331) | see NW §C "B-2 systemic comparison" |
| NW §5 "The services exported to plug-ins (`StrICmp`, `IsTheSamePath`, …) keep the byte fold" (L1334) | see NW §C "B-2 systemic comparison" |
| NW §5 "The disk cache keys an archive by its lower-cased (byte fold) name … `DetachTmpFile` has no caller" (L1338) | done (feature 109) |
| NW §5 "`CFileTimeStamps::AddFile` (`salamdr3.cpp`): `ĥ.txt` and `Ĺ.txt` … collide" (L1342) | done (feature 108) |
| NW §5 queue 108, entry 1 "The disk cache keys an ARCHIVE by its code-page lower-cased name" (L1357) | done (feature 109) |
| NW §5 queue 108, entry 2 "The ZIP plug-in matches names by `CompareStringA` + `NORM_IGNORECASE`" (L1386) | done (feature 110) |
| NW §5 queue 108, entry 2 "Recorded, not fixed: a read error answered *Skip* during `PackFiles`" (L1423) | done (feature 113) |
| NW §5 queue 108, entry 2 "Performance note: that bound and `UpdateCentrDir` walk the central directory once per deleted member" (L1444) | done (feature 164) |
| NW §5 queue 108, entry 2a "a flush marks a copy with a pending edit out of date" (L1453) | done (feature 112) |
| NW §5 queue 108, entry 2a "Left: a per-member warning when the member itself changed in the archive since F4" (L1474) | done (feature 153); its leftovers: see NW §A.8 |
| NW §5 queue 108, entry 2a "Trade-off recorded (review SF1): an UNTOUCHED tracked copy is pinned too" (L1475) | item:archive-update-change-detection-limits (*Notes*, SF1) (corrected after review N4: was see NW §A.8, whose item did not carry it) |
| NW §5 queue 108, entry 3 "`AddFile` returning FALSE on low memory makes `ExecuteFromArchive` release the copy" (L1482) | done (feature 112) |
| NW §5 queue 108, entry 3 "two panels whose archives have the same spelling, equal size AND equal modification time across a re-pointed drive letter" (L1484) | done (feature 144) |
| NW §5 queue 108, entry 3 "the out-of-memory fallback of the cache key can re-create sharing without a check" (L1487) | done (feature 144) |
| NW §5 queue 108, entry 4 "tar extracts case-sensitively under a case-insensitive listing … merged ZIP folder" (L1495) | see NW §C "B-2 systemic comparison" (queue 108, entry 4) |
| NW §5 "`UnselectItemWithName` (`fileswn0.cpp`) uses the linguistic comparison plus a byte-length guard" (L1510) | done (feature 163) |
| NW §5 "`CFindIgnore::Contains`, relative kind" (L1513) | done (feature 163) |
| NW §5 "A guard rule for the old comparison functions on names (092 task T006)" (L1516) | see NW §C "B-2 systemic comparison" |
| NW §5 "The comparator's cost: 2x (ASCII) to 16x (every name accented) the byte fold" (L1519) | see NW §A.15 ("Left of this item: the 092 comparator reads both names to their ends") |
| NW §5 "An unbounded `StrICpy` into `buf[MAX_PATH]` at `fileswn9.cpp`" (L1525) | done (feature 095) |
| NW §5 found-by-095 "An archive whose path is longer than 259 bytes could not be opened" (L1532) | done (feature 097) |
| NW §5 097-left "external archivers and older plug-ins stay at 259 bytes" (L1538) | see NW §C "259-byte limits kept" |
| NW §5 097-left "the inner path stays at 259 bytes" (L1539) | see NW §C "259-byte limits kept" |
| NW §5 097-left "clipboard copy from and drop/paste into an archive with a 260+ byte name are refused" (L1540) | done (feature 160) |
| NW §5 097-left "`-L`/`-R`/`-A` and hot paths stay at 519 bytes" (L1541) | see NW §C "259-byte limits kept" (519 bytes) |
| NW §5 097-left "a real mouse drag was not driven" (L1542) | item:archive-edit-and-long-path-rows-owed-to-person |
| NW §5 "Found by the 097 review — crash in deep folders, Change Directory overrun, UNC-copy overruns, 7zip message buffers, silent loss" (L1543) | done (feature 098) |
| NW §5 queue 098, entry 1 "Moving a folder that contains a junction into an archive deleted the files behind it" (L1549) | done (feature 099) |
| NW §5 queue 098, entry 1 "Not driven: a real drag, the clipboard route, Explorer as the drag source" (L1553) | see NW §B "By hand" (paste and drag & drop routes of 099) |
| NW §5 queue 098, entry 2 "Change Directory to a file whose NAME has a CJK character: the viewer title showed `?`" (L1555) | done (feature 100) |
| NW §5 queue 098, entry 2, found-by-100 "the tray icon tip copies UTF-8 into the ANSI tip structure" (L1557) | done (feature 101) |
| NW §5 queue 098, entry 2, found-by-100 "the File Comparator cannot open files named outside the code page" (L1561) | done (feature 102) |
| NW §5 queue 098, entry 2, found-by-102 "closing the program within ~1 s of `fcremote` starting it asks 'plugin has rejected to unload'" (L1566) | done (feature 121) |
| NW §5 queue 098, entry 2, found-by-102 "the 093 dialogs probe's Find-menu rows fail on the hidden desktop" (L1575) | done (feature 168) |
| NW §5 queue 098, entry 4 "The small leftovers (tray tip, clipboard paste length, silent UNC copy, …)" (L1580) | done (feature 101) |
| NW §5 queue 098, entry 4, found-by-101 "Find's *Look in* cuts at 259 bytes; message box breaks inside words; clipboard copy fails silently" (L1583) | done (feature 121) |
| NW §5 queue 098, entry 4, found-by-101 "packing a tree whose names relative to the packed folder exceed 259 bytes skips those sub-folders" (L1586) | see NW §C "259-byte limits kept" (names relative to a packed folder) |
| NW §5 queue 098, entry 5 "Same class as 102 in other plug-ins" (L1599) | done (feature 104) |
| NW §5 queue 104, entry 1 "PictView *Save As* onto an existing file deletes it and then fails" (L1620) | done (feature 105) |
| NW §5 queue 104, entry 1, found-by-105 "Rename of the shown image fails with 32; alpha question; wallpaper commands" (L1638) | done (feature 111) |
| NW §5 queue 104, entry 1, found-by-111 "(a) pipette and histogram … (b) Rename onto a file a second window shows … (c) GIF comment" (L1662) | done (feature 120) |
| NW §5 queue 104, entry 1, 120 "the pipette and histogram rows are owed to a person on an unlocked visible desktop" (L1675) | see NW §B "By hand" (PictView's pipette and histogram rows, 120) |
| NW §5 queue 104, entry 1, found-by-120 "PictView's print preview is empty in every release since 006" (L1694) | done (feature 152) |
| NW §5 queue 104, entry 2 "Undelete applies a FAT rule (`Replace0xE5`) to UTF-8 names" (L1699) | done (feature 114) |
| NW §5 queue 104, entry 2, 114 "mount points need admin (person step, `quickstart.md`)" (L1718) | see NW §B "Environment or hardware" (volume mount points, 114, admin) |
| NW §5 queue 104, entry 2, found-by-114 "(a) Restore Encrypted Files ignores `SalPathAppend` failures (b) `RemoveDuplicateFiles` (c) `_stricmp`" (L1719) | done (feature 115) |
| NW §5 queue 104, entry 2, 115 "real EFS backups NOT DRIVEN (no user EFS certificate here)" (L1744) | see NW §B "Environment or hardware" (real EFS backups, 115) |
| NW §5 queue 104, entry 2, found-by-115 "numbering can produce a name another listed item has" (L1747) | done (feature 148) |
| NW §5 queue 104, entry 2, found-by-115 "`ViewFile`'s disk-cache key drops a long name" (L1748) | done (feature 163) |
| NW §5 queue 104, entry 3 "FTP password fields keep a code-page subclass (`CPasswordEditLine`)" (L1750) | done (feature 116) |
| NW §5 queue 104, entry 3, 116 "the proxy dialog, a Master Password, a SOCKS 5 proxy and a real keyboard / IME are person steps" (L1780) | see NW §B (116 quickstart steps; "Environment or hardware": a SOCKS 5 proxy) |
| NW §5 queue 104, entry 3, found-by-116 "a password in a typed Change Directory path over 300 bytes is cut; … wipes; log texts cut inside a character" (L1781) | done (feature 121) |
| NW §5 queue 104, entry 3, 121 "except the custom proxy-script line (unchanged, unreachable for the built-in scripts)" (L1795) | done (feature 162, closed by measurement; see NW §A.13) |
| NW §5 queue 104, entry 3, 121 "the stored path is still cut at `FTP_MAX_PATH` - recorded" (L1805) | done (feature 162, closed by measurement; see NW §A.13) |
| NW §5 queue 104, entry 4 "checksum: a checksum list written in the code page with accented names reports those files as missing" (L1807) | done (feature 117) |
| NW §5 queue 104, entry 4, found-by-117 "a list line whose path does not fit 780 bytes aborts the whole Verify" (L1837) | done (feature 149) |
| NW §5 queue 104, entry 4, found-by-117 "an OEM list's accented names stay 'missing'" (L1839) | see NW §C "Formats and old forms" (OEM checksum lists are not guessed) |
| NW §5 queue 104, entry 4 "Checksum's Save dialog opened another program's last folder" (L1841) | see NW §C "Save dialogs' initial folder" |
| NW §5 queue 104, entry 4, 121 coordinator review "the FTP upload target no longer takes a cut typed user name" (L1856) | done (feature 121) |
| NW §5 queue 104, entry 4, 121 coordinator review "a Find Look in path near the program's maximum stops with a trace only" (L1858) | done (feature 162, closed by measurement; see NW §A.13) |
| NW §5 queue 104, entry 4, 121 coordinator review "the same cut-user check in `ChangePath` with an open connection was not examined" (L1860) | done (feature 162, closed by measurement; see NW §A.13) |
| NW §5 queue 104, entry 5 "the plug-in folder picker does not resolve NetHood folder shortcuts; diskmap's log window shows paths garbled" (L1862) | done (feature 121) |
| NW §5 queue 104, entry 5 "the ZIP comment field is code page by format; the ZIP self-extractor routes … stay code page" (L1864) | see NW §C "Formats and old forms" |
| NW §5 queue 104, entry 5 "PictView's *Regenerate thumbnail* cannot work at all since 006" (L1866) | done (feature 132) |
| NW §5 queue 104, entry 5 "Disabled plug-ins (listed in `104/research.md` 3) are unchanged" (L1867) | not migrated: scope note — disabled plug-ins are neither built nor shipped; re-examine when one is enabled (see NW §D "Ship the Network plug-in" for the one under decision) |
| NW §5 queue 104, entry 5, 121 "the folder picker's tree-view pick was not driven - a person step" (L1871) | see NW §B (121, the folder picker's tree-view pick) |
| NW §5 queue 104, entry 6 "checksum's Save ignored write errors" (L1883) | done (feature 121) |
| NW §5 queue 104, entry 6 "the Registry Editor's Find window and FTP's Logs / Welcome Message windows still decline an update" (L1886) | done (feature 121) |
| NW §5 queue 104, entry 6, 121 "their Save dialogs still decline" (L1909) | see NW §C "Update close" |
| NW §5 queue 104, entry 6 "a worker's error box (File Comparator hex view, checksum read errors) can still appear while its window closes" (L1889) | done (feature 147) |
| NW §5 queue 104, entry 6 "Disk Map's `Release()` has no guard like the other three" (L1891) | done (feature 143) |
| NW §5 queue 104, entry 6 "the File Comparator terminates its remote-comparator thread before a window close that may time out" (L1894) | done (feature 147) |
| NW §5 queue 104, entry 6, 121 "FTP's welcome-message window needs a server and was not driven" (L1902) | see NW §B (121, FTP's welcome-message window) |
| NW §5 queue 104, entry 7 "the UTF-8 error field of `CFileErrorDlg` got code-page texts; Romanian `IDS_CANTMULTIVOL`" (L1912) | done (feature 121) |
| NW §5 queue 098, entry 3 "Smaller: the link warning names an unreadable or too-deep folder as a 'Link'; …" (L1922) | done (feature 101) |
| NW §5 "An edited file with a non-ASCII name was not packed back into its archive" (L1929) | done (feature 096) |
| NW §5 096 "Not driven by its probe: the RAR external packer with such a name; a critical shutdown with an edited file" (L1932) | item:archive-edit-and-long-path-rows-owed-to-person |
| NW §5 "The mask matcher, *Change Case* (B-4), the x86-only code and the install-path chain are not part of B-2's identity work" (L1935) | not migrated: the x86-only code (`#ifndef _WIN64`, 8 lines) is not built (092 fix-log L220); the mask matcher and the install-path chain: see NW §A.19 (corrected after review N4: was see NW §A.19, which does not hold the x86-only code) |
| NW §5 B-1 "B-1 (text typed into windows) - DONE where it was real (feature 093)" (L1939) | done (feature 093) |
| NW §5 B-1 left "A real-keyboard pass (owed to a person, `093/quickstart.md`)" (L1950) | see NW §B "By hand" (the real-keyboard / IME pass of 093) |
| NW §5 B-1 left "The main window's title showed `?`" (L1954) | done (feature 100) |
| NW §5 B-1 left "The loops that only drain messages during an operation and the menus' own modal loops" (L1956) | done (feature 154); kept parts see NW §A.9 |
| NW §5 B-1 left "Message boxes, master-password dialogs, other plug-ins' dialogs (FTP, SFTP, ZIP, renamer, ...): untouched" (L1961) | see NW §A.9 ("Not examined: other plug-ins' dialogs") |
| NW §5 B-1 left "The ZIP and SFTP password prompts were examined and fixed by feature 094" (L1964) | done (feature 094) |
| NW §5 B-1, 094-left "the self-extractor's own prompt … stays `?`" (L1968) | see NW §C "Formats and old forms" (the SFX password prompt stays code page) |
| NW §5 B-1, 094-left "the FTP plugin's 101-byte password buffer … and its *Show password* read" (L1971) | done (feature 116) |
| NW §5 B-1, 094-left "a real OpenSSH server and a key passphrase were not driven; a system with a double-byte or UTF-8 code page" (L1975) | see NW §B "Environment or hardware" (094) |
| NW §5 B-1 left "The plug-in copy of the dialog library (`winliblt`) still falls back to a code-page read" (L1977) | done (feature 104) |
| NW §5 B-1 left "7zip plugin: an archive that mixes the two password forms stays mixed" (L1982) | see NW §C "Formats and old forms" (a 7z archive mixing the two password forms stays mixed) |
| NW §5 B-1 left "7zip plugin: a damaged item under a two-form password is decoded up to three times" (L1983) | merged:7zip-two-form-password-passes-not-driven |
| NW §5 B-1 left "7zip plugin: the Test command's second pass, cancel during a retry pass and RAR were not driven" (L1984) | item:7zip-two-form-password-passes-not-driven |
| NW §5 "What the section said before 092: … B-2 … B-1 … B-4 (`AlterFileName`) … last" (L1987) | done (features 092, 093, 169) |
| NW §5 "Not part of this: F-P1-05, the archive listing display encoding (`pack1.cpp`)" (L1998) | see NW §A.19 (F-P1-05, must move as a whole, 069 §0b) |

## 6. Cheap winget housekeeping, once PR #426090 has settled

| Source | Destination |
|---|---|
| NW §6 gate "`072/REMAINING-WORK.md` gates everything on whether the submission is merged; … change nothing under `tools/winget/templates/`" (L2004) | merged:winget-submit-release-after-pr-426090 |
| NW §6 "State on 2026-09-30: #426090 (0.1.7) is still open; the moderator asked to drop `DisplayVersion`" (L2006) | merged:winget-submit-release-after-pr-426090 |
| NW §6 "Read `072/REMAINING-WORK.md` § P0 before anything else here. An audit on 2026-09-30 … Recommended: re-point #426090 to 0.1.8" (L2012) | item:winget-repoint-pr-426090-decision (the re-point recommendation) with item:winget-manifest-fixes-from-072-audit and item:winget-records-stale-claims-from-072-audit (corrected after review M2: was item:winget-manifest-fixes-from-072-audit with re-point steps in the blocked submission item) |
| NW §6 "Submit 0.1.8 (was section R, step 4) once #426090 has settled" (L2022) | item:winget-submit-release-after-pr-426090 |
| NW §6 "P4 — `actions/checkout@v4` / `actions/upload-artifact@v4` run on the deprecated Node 20" (L2028) | done (feature 091) |
| NW §6 P4 "static verification only; a real run is owed" (L2030) | see NW §B "Release and catalogue housekeeping" (a real run of the Node 24 workflows, 091) |
| NW §6 P4 found "`pr-comments-guard.yml` has failed at checkout for every labelled fork pull request" (L2031) | done (feature 091; decided 2026-10-02, opted in, commit `492aca7a`) |
| NW §6 "P2 — `--scope user` has never actually been tested" (L2040) | item:winget-per-user-scope-entry |
| NW §6 "P3 — `checkver` still points at Open Salamander's site" (L2044) | item:checkver-update-channel-decision |

## 7. Privacy-relevant defects found by feature 083

| Source | Destination |
|---|---|
| NW §7 header "F1–F7 FIXED (feature 085, 2026-10-01)" (L2050) | done (feature 085) |
| NW §7 left "The GUI steps `085/quickstart.md` G1–G6" (L2068) | see NW §B "The features' own quickstart.md person steps" (085 G1–G6) |
| NW §7 left "F9 — the FTP anonymous-login e-mail default `name@someserver.com`" (L2069) | done (feature 090) |
| NW §7 left "F8 — withdrawn … Open question instead: is the missing copy hook intended?" (L2075) | see NW §C (open question for the maintainer: the missing copy hook, item 7, F8) |
| NW §7 left "the ZIP plugin's AES salt comes from `rand()` seeded with time ^ pid" (L2080) | done (feature 086) |
| NW §7 left, 086 "GUI round trip owed (`086/quickstart.md`)" (L2083) | see NW §B "The features' own quickstart.md person steps" (086, an encrypted ZIP round trip) |
| NW §7 left "SFTP: `sftp:user:password@host` is not split" (L2090) | see NW §C ("SFTP does not split `sftp:user:password@host`") |
| NW §7 original "F1 — highest priority. A password typed as part of an address … saved in plain text" (L2105) | done (feature 085) |
| NW §7 original "F2 — mdview remote-image requests identify as `OpenSalamander-mdview`" (L2113) | done (feature 085) |
| NW §7 original "F3 — probably a Markdown document can make the viewer open the default browser without a click" (L2117) | done (feature 085) |
| NW §7 original "F4 — WebView2 engine crash dumps are sent to Microsoft by default" (L2123) | done (feature 085; decided 2026-10-01: crash upload off) |
| NW §7 original "F5 — `architecture/11-webview2-integration.md:59-60` says the user data folder 'holds cache only'" (L2125) | done (feature 085) |
| NW §7 original "F6 — password-manager salts come from `rand()`" (L2127) | done (feature 085) |
| NW §7 original "F7 — SFTP: cancelling the master-password prompt silently saves the secret scrambled only" (L2129) | done (feature 085) |
| NW §7 original "F8 — withdrawn: the shell-extension registration only runs if `utils\salext*.dll` exists" (L2131) | see NW §C (the copy-hook question, item 7, F8) |
| NW §7 original "F9 — the FTP anonymous-login e-mail default" (L2136) | done (feature 090) |

## 8. Upgrade the vendored 7-Zip — DONE

| Source | Destination |
|---|---|
| NW §8 header "Upgrade the vendored 7-Zip 16.04 → 25.x — DONE as 26.03, with RAR (feature 087)" (L2142) | done (feature 087) |
| NW §8 "Found on the way and fixed: item names were used unchecked; *Unpack and delete*; *Word size*" (L2151) | done (feature 087) |
| NW §8 "Owed (join item 3): the GUI pass of `087-7zip-2603-rar/quickstart.md`" (L2154) | see NW §B "The features' own quickstart.md person steps" (087) |
| NW §8 "Left: a Unicode password prompt belongs to encoding cluster B-1" (L2157) | done (feature 093) |
| NW §8 "The three items below are DONE (feature 089) … (a) strict UTF-8 (b) 7z update matching (c) `rar` association" (L2160) | done (feature 089) |
| NW §8 089 "Owed (item 3): `089-7zip-followups/quickstart.md`" (L2166) | see NW §B "The features' own quickstart.md person steps" (089) |
| NW §8 original entry "Prerequisite of feature 084 stage S7 … CVE-2018-10115, CVE-2025-53816 … decide ARJ/LZH (084 R5)" (L2182) | done (feature 087; ARJ/LZH answered there: they stay with the 7-Zip console) |

## Protocol

| Source | Destination |
|---|---|
| NW Protocol "`specs/069-finish-encoding-fixes/contracts/fix-protocol.md` is binding for any fix in items 1, 4 and 5" (L2219) | not migrated: rule, carried by .claude/skills/tandem-backlog-implement/stop-rules.md |
