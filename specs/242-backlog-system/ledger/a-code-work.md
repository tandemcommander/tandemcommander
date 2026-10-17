# Ledger part a-code-work — NW §A "Code work an agent can do" (L117–L416)

Source: `NEXT-WORK.7993914c.md` lines 117–416, items 1–19 with their lettered
sub-items. One row per entry and per open leftover clause inside an entry.
Items: `a-code-work.items.json` (25: next 18, person 5, decisions 1,
parked 1).

| Source | Destination |
|---|---|
| NW §A.1 "Disk Map's `Release()` has no guard" (L121) | done (feature 143) |
| NW §A.1 "Left by 143: a forced unload ("force?" Yes) during a shell command terminates the map's thread" (L124) | item:plugin-close-forced-unload-and-stray-box |
| NW §A.1 "the real-mouse rows of its `quickstart.md` are owed to a person" (L126) | item:diskmap-close-real-mouse-rows |
| NW §A.2 "Disk cache across a re-pointed drive letter" (L128) | done (feature 144) |
| NW §A.2a "Pending edits packed into a re-pointed name" (L133) | done (feature 145) |
| NW §A.2b "Archive operations through a re-pointed name" (L142) | done (feature 146) — the gaps its review recorded (and 145's): item:archive-ops-repointed-name-recorded-gaps (corrected after review N9) |
| NW §A.3 "Plug-in windows closing" (L149) | done (feature 147) |
| NW §A.3 "the comparator's hex-view stray box recorded there, no crash path" (L151) | merged:plugin-close-forced-unload-and-stray-box |
| NW §A.4 "Undelete numbering" (L155) | done (feature 148) |
| NW §A.5 "Checksum ... a list line whose path does not fit 780 bytes" (L159) | done (feature 149) |
| NW §A.5a "`FocusNameInPanel` cuts a long folder" (L163) | done (feature 150) |
| NW §A.5b "Plugins dialog: the plug-in's path built with an unbounded `strcat`" (L169) | done (feature 151) |
| NW §A.5c "The viewer's Copy to File overwrites by deleting first" (L174) | done (feature 173) |
| NW §A.5c "a person step on a FAT stick or a network share with the target held open" (L176) | item:viewer-copy-to-file-on-fat-or-share |
| NW §A.5d "A failed configuration export deletes the user's existing file" (L184) | done (feature 174) |
| NW §A.5e "The configuration export writes letters outside the code page as '?'" (L190) | done (feature 174) |
| NW §A.5j "More `sprintf` stack overruns of the same kind" (L201) | done (feature 183) |
| NW §A.5j "Email files not driven - no MAPI client" (L211) | item:email-files-deep-folder-with-mapi-client |
| NW §A.5j "Left (its review): `fileswn7.cpp` ~528 `lstrcpyn(path, tgtPath, MAX_PATH)` ... `pack2.cpp` ~323" (L211) | done (feature 184) |
| NW §A.5f "Files > Convert replaces by delete-then-move" (L215) | done (feature 175) |
| NW §A.5g "Quick Rename onto an existing file deletes the target first" (L221) | done (feature 175) |
| NW §A.5h "F6 Move onto an existing file deletes the target first" (L227) | not migrated: closed by measurement in feature 177, no change (a source that cannot be renamed fails the first move before the overwrite branch; the loss needs another program to lock the source exactly between delete and move) |
| NW §A.5i "Pack with "overwrite" deletes the existing archive before packing" (L234) | done (feature 176) |
| NW §A.6 "PictView's print preview is empty in every release since 006" (L241) | done (feature 152) |
| NW §A.6 "owed to a person: one print compared with the preview" (L242) | see NW §B "The features' own `quickstart.md` person steps" (152: one PictView print compared with its preview) |
| NW §A.6a "PictView print: Fit mode still mirrors by a negative stored size; a large print scale wraps" (L244) | done (feature 179) |
| NW §A.6a "owed to a person: one print" (L245) | merged:pictview-own-photos-pipette-histogram-print |
| NW §A.7 "PictView's *Regenerate thumbnail* cannot work since 006" (L250) | done (feature 132) |
| NW §A.7 "owed before the release: Update Thumbnail on real camera files" (L252) | done (feature 135) |
| NW §A.7 "**135 must ship with 132.**" (L255) | release-checklist |
| NW §A.7 "Left: a look at a few own photos in the program" (L255) | merged:pictview-own-photos-pipette-histogram-print |
| NW §A.7 "the viewer's Exif dialog and auto-rotation are dead" (L256) | item:pictview-exif-dialog-and-auto-rotation |
| NW §A.7 "a refused file gets "Unable to create a file with the new thumbnail. Disk full?"" (L258) | merged:pictview-update-thumbnail-142-leftovers |
| NW §A.8 "A per-member warning when an archive member changed in the archive since its F4" (L261) | done (feature 153) |
| NW §A.8 "owed to a person: the dialog with a marked line on screen" (L262) | see NW §B "The features' own `quickstart.md` person steps" (153: the Archive Update dialog with a marked line) |
| NW §A.8 "Left, recorded in its fix-log: a member rewritten with the same size and time ..." (L263) | item:archive-update-change-detection-limits |
| NW §A.9 "B-1 leftovers: the loops that only drain messages during an operation" (L266) | done (feature 154) |
| NW §A.9 "Kept with reasons (154's fix-log): the menus' own loops ..., help mode, the tooltip's loop, discard-only loops" (L267) | not migrated: kept deliberately, each with its reason in specs/154-drain-loops-wide/fix-log.md (code-page mnemonic against code-page menu texts is consistent; help mode / tooltip / discard-only loops deliver no typed text) |
| NW §A.9 "Not examined: other plug-ins' dialogs" (L269) | item:plugin-dialogs-code-page-message-loops |
| NW §A.10 "Clearer refusal texts" (L271) | done (feature 155) |
| NW §A.10a "FTP information line: "bajt? v 3 vybran?ch souborech"" (L274) | done (feature 157) |
| NW §A.10a "owed to a person: one look with an FTP server" (L275) | merged:ftp-real-server-checks-090-116-121 |
| NW §A.10b "Portables information line at the device level" (L276) | done (feature 159) — its owed person step (fix-log L10–11): a step of item:dialog-texts-on-screen-153-155 (corrected after review S1) |
| NW §A.10c "Portables: "N selected device" never takes its plural" (L280) | done (feature 161) |
| NW §A.11 "A case-sensitive folder refuses `a.txt` → existing `A.txt`" (L284) | done (feature 158) |
| NW §A.11 "F5 copy within the same case-sensitive folder is refused "to itself"" (L285) | done (feature 195) |
| NW §A.11 "the Renamer refuses "already exists"" (L287) | done (feature 196) |
| NW §A.11 "the core's Quick Rename (158) takes "different ids" as proof of another file" (L288) | done (feature 198) |
| NW §A.11 "PictView's rename" (L289) | done (feature 200) |
| NW §A.11 "PictView's rename has the 8.3 short-name trap" (L290) | done (feature 202) |
| NW §A.11 "the Renamer has no step that moves an 8.3 short-name clash aside" (L291) | done (feature 199) |
| NW §A.11 "the core's Quick Rename has the same fallback" (L293) | done (feature 201) |
| NW §A.11 "the create paths have the same defect" (L295) | done (feature 203) |
| NW §A.11 "the other entry can be left under `salNNN` with only a trace when both restores fail" (L296) | done (feature 221) |
| NW §A.11 "left: the create paths `SalCreateFileEx` / `SalCreateDirectoryEx` / `SafeFileCreate` have no window ...; PictView's and the Renamer's move-back have no retry" (L297) | item:moved-aside-restore-leftovers |
| NW §A.11 "an archive member `LONGDI~1/a.txt` unpacked next to a folder `longdirname` goes INTO `longdirname`" (L299) | done (feature 204) |
| NW §A.11 "left by its review, latent: the unpack root is process-wide; an external archiver's unpack not driven" (L301) | item:unpack-root-process-wide-latent |
| NW §A.11 "the FTP and SFTP downloads have the same trap" (L303) | done (feature 205) |
| NW §A.11 "owed to a person: the FTP rows with an FTP server" (L304) | merged:ftp-real-server-checks-090-116-121 |
| NW §A.11 "the Renamer's `CheckAndCreateDirectory` renames a folder whose SHORT name ..." (L307) | done (feature 206) |
| NW §A.11 "feature 207 (CRITICAL) - the Renamer's `MoveFile` / "Remove source path" `dir[MAX_PATH]`" (L310) | done (feature 207) |
| NW §A.11 "208 - the Renamer's `ChangeCase` applies code-page byte tables to UTF-8 names" (L312) | done (feature 208) |
| NW §A.11 "210 - the Renamer's other code-page residue" (L314) | done (feature 210) |
| NW §A.11 "left by its review: the regex engine still judges `\b`, `\w`, classes, '.' and quantifiers by single bytes ...; the history dedupe and the preview's sort use the code-page `StrICmp`" (L315) | item:renamer-regex-single-byte-classes |
| NW §A.11 "209 - `ReloadSourceFiles` expands a renamed folder as `Root + Name`" (L318) | done (feature 209) |
| NW §A.11 "also recorded: a new name is capped at 259 bytes (a refusal), an item from a subdirectory is refused at 260 bytes" (L319) | item:renamer-long-new-name-limits |
| NW §A.12 "An archive whose name has 260+ bytes: drop/paste into it" (L323) | done (feature 160) |
| NW §A.12 "Recorded for the day the extension returns: its copy hook is the code-page `ICopyHookA` and cuts the Explorer target at `MAX_PATH`" (L325) | merged:copy-hook-for-drag-out-of-archives |
| NW §A.13 "FTP, small: typed server path cut at `FTP_MAX_PATH`" (L330) | not migrated: closed by measurement in feature 162, no change (not reachable, probe 16 / 0; Find *Look in* has no maximum; the proxy-script line accepted) |
| NW §A.14 "Small identity leftovers" (L339) | done (feature 163) |
| NW §A.15 "ZIP: n × d deletion" (L348) | done (feature 164) |
| NW §A.15 "Found by its review: the ZIP plug-in kept the entry counts in 16 bits" (L349) | done (feature 165) |
| NW §A.15 "Left of this item: the 092 comparator reads both names to their ends" (L359) | item:name-comparator-reads-whole-names |
| NW §A.16 "Translation drift" (L362) | done (feature 166) |
| NW §A.16 "New, found by 166: 711 clipped labels in the 8 shipped translations" (L365) | item:translations-clipped-labels |
| NW §A.16 "Left of the item: the bundle re-key" (L369) | item:translate-merge-bundle-rekey |
| NW §A.17 "077 cosmetics" (L373) | done (feature 167) |
| NW §A.18 "Probe artefacts" (L378) | done (feature 168) |
| NW §A.18 "Recorded by 168 (product, from reading): a `CMenuBar` popup closed by anything but Esc / Alt / a click" (L381) | item:menubar-loop-swallows-typed-characters |
| NW §A.18 "106's `packself_probe.ps1` row A-zip-noask-refused expects the "already exists" question ... stale since 119" (L389) | item:packself-probe-stale-row |
| NW §A.19 "B-4 `AlterFileName` / *Change Case*" (L395) | done (feature 169) |
| NW §A.19 "found by its review: `zip.cpp` ~4041 `lstrcpyn(nameBuf, fileOrDirName, MAX_PATH)`" (L397) | done (feature 178) — its owed person step (fix-log L11): a step of item:ftp-real-server-checks-090-116-121 (corrected after review S1) |
| NW §A.19 "F-P1-05, the archive listing display encoding (must move as a whole, 069 §0b)" (L399) | item:archive-listing-display-encoding |
| NW §A.19 "B-3 the undocumented UTF-8 `GetErrorText`" (L400) | item:geterrortext-utf8-contract |
| NW §A.19 "B-5 the frozen plug-in-facing ANSI services (needs an interface decision)" (L401) | item:plugin-ansi-services-interface-decision |
| NW §A.19 "the install-path chain (start, language, plug-in loading done - feature 170)" (L402) | done (feature 170) |
| NW §A.19 "toolbar SVG icons, `sqlite.dll`, conversion tables done - feature 171" (L403) | done (feature 171) |
| NW §A.19 "the configuration export's dialog and every other code-page file dialog of the core done - feature 172" (L404) | done (feature 172) |
| NW §A.19 "the plug-ins' own lookups of their files read by 172: the shipped ones are wide already ... or not reachable" (L406) | not migrated: read by feature 172 - the shipped plug-ins are wide already (7-Zip, PictView, ZIP), the rest not reachable (FTP's `libeay32.dll` and ZIP's SFX modules not shipped, Portables takes only the file name, the others are off) |
| NW §A.19 "left: bug report line" (L409) | item:bug-report-module-line-install-path |
| NW §A.19 "left: `EnumInstalledModules` (an interface question)" (L409) | merged:plugin-ansi-services-interface-decision |
| NW §A.19 "tips and SalOpen not reachable (a commented-out block, `salopen.exe` not shipped)" (L409) | not migrated: unreachable - the tips are a commented-out block (`dialogs6.cpp`), `utils\salopen.exe` is not shipped (171's fix-log, *Left out after reading*) |
| NW §A.19 "151's review: the plug-in loader builds every plug-in's path with `GetModuleFileName` A + an unbounded `strcat`" (L411) | done (feature 170) |
| NW §A.19 "the mask matcher" (L414) | item:mask-matcher-code-page-fold |

## Notes for the import

- Overlaps with other parts (same entry named twice in the source; dedupe
  when importing): `name-comparator-reads-whole-names` = NW §5 *The
  comparator's cost*; `plugin-dialogs-code-page-message-loops` ⊂ NW §5 *B-1*
  ("other plug-ins' dialogs ... not examined"); `archive-listing-display-encoding`
  = RW069 §0b; `geterrortext-utf8-contract` = RW068 / RW069 §1 B-3;
  `plugin-ansi-services-interface-decision` = RW069 §1 B-5;
  `mask-matcher-code-page-fold` ≈ NW §5 L1935 and RW068 F-P3-06.
- The person steps of 152 and 153 are listed in NW §B and left to that part;
  179's print step is in `pictview-print-fit-and-own-photos-check` with a
  note to do it together with 152's.
