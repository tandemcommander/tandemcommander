# Ledger part d-github — NEXT-WORK §D "From the GitHub issues after 0.1.9"

Source: `NEXT-WORK.7993914c.md` lines 505–868. One row per entry, open or
closed; nested "left by …" passages are split into their own rows. Items:
`d-github.items.json` (49: next 32, decisions 4, person 11, parked 2).

## Decisions owed to the maintainer

| Source | Destination |
|---|---|
| NW §D decisions "Ship the Network plug-in (`nethood`)?" GitHub #5 (L509) | item:decide-ship-network-plugin-nethood |
| NW §D decisions "A deliberate Windows floor?" GitHub #6 (L529) | item:decide-windows-version-floor |

## Code work an agent can do

| Source | Destination |
|---|---|
| NW §D code work "The parent of a share's root" (L537) | item:share-root-parent-offers-share-list |
| NW §D code work "A server that wants a name and password" (L540) | item:share-list-offers-sign-in |
| NW §D code work "A shell calls that return paths (128): `GetSHObjectName`" (L542) | item:getshobjectname-code-page-cut-server-links (corrected after review S5: in *Next*, low — was parked on the migration's own judgement) |
| NW §D code work "~~`SHGetFolderPath` A in `drivelst.cpp`~~" (L543) | done (feature 188) |
| NW §D code work "~~`GetOpenFileName` A in `execute.cpp`~~" (L545) | done (features 170, 172) |
| NW §D code work "~~The drop-target code for shortcuts~~" (L546) | done (feature 194) — its owed person step (fix-log ~L39): item:drag-drop-paste-routes-194-228-230-240-by-hand (corrected after review S1) |
| NW §D code work 194 left: "`shellib.cpp`'s folder-shortcut code gets only a Browse result of `MAX_PATH`" (L547) | item:folder-shortcut-browse-result-max-path |
| NW §D code work "~~`tools/check_encoding.py` does not scan `plugins/`~~" (L549) | done (feature 239) |
| NW §D code work 239 left: "its 78 findings" (L550) | item:check-encoding-plugin-findings |
| NW §D "Mixed templates, the rest" (1) "`GetCommonFSOperSourceDescr` … `IDS_NAMEUSEDFORFILE`" (L553) | item:undelete-zip-core-texts-in-code-page-sentences |
| NW §D "Mixed templates, the rest" (2) "the other plug-ins: … 137 candidates" (L556) | done (features 130, 134) |
| NW §D "Mixed templates, the rest" (3) "the guard has no reverse rule" (L558) | item:mixed-template-guard-reverse-rule |
| NW §D "Mixed templates, the rest" (4) "~~`menu2.cpp` `AssignHotKeys`~~" (L560) | done (feature 236) |
| NW §D (4) "~~a popup's key matching compares the typed ANSI byte~~" (L561) | done (feature 237) |
| NW §D (4) 237 left: "the popup's loop is ANSI … `WM_MENUCHAR` … `GetControlHotKey`" (L562) | item:menu-popup-loop-wide-mnemonics |
| NW §D "Mixed templates, the rest" (5) "the Registry Editor's `%ls` messages" (L566) | done (feature 129) |
| NW §D "~~Registry Editor: a malformed `REG_MULTI_SZ`~~" (L568) | done (feature 189) |
| NW §D RegEdit Find 1 "~~The time fields~~" (L572) | done (feature 191) |
| NW §D RegEdit Find 2 "~~A quoted hex pattern~~" (L575) | done (feature 191) |
| NW §D RegEdit Find 3 "~~A plain pattern that does not fit 512 bytes~~" (L577) | done (feature 191) |
| NW §D RegEdit Find 4 "~~\"0x\" before a hexadecimal number~~" (L580) | done (feature 192) |
| NW §D RegEdit Find 5 "~~A DWORD / QWORD value stored shorter~~" (L583) | done (feature 192) |
| NW §D RegEdit Find 6 "Regexp with Whole words tests `text[pos - 1]`" (L586) | item:regedit-find-whole-words-and-quoted-hex-letters |
| NW §D RegEdit Find 7 "a letter that needs 2 bytes … inside `'...'`" (L589) | merged:regedit-find-whole-words-and-quoted-hex-letters |
| NW §D second verification 1 "~~Registry Editor, `%ls` messages~~" (L593) | done (feature 129) |
| NW §D second verification 1, 129 left: "`peviewer/pefile.cpp:1819/2317/2499` … narrow `%ls`" (L595) | item:peviewer-version-names-narrow-ls |
| NW §D second verification 1, 129 left: "`regedt/fs3.cpp:218` passes `MAX_KEYNAME`" (L597) | item:regedit-key-name-buffer-size-and-move-rows |
| NW §D second verification 1, 129 left: "Move of a key and the \"class name differs\" question were not driven" (L598) | merged:regedit-key-name-buffer-size-and-move-rows |
| NW §D second verification 2 "~~Mixed templates in the enabled plug-ins (127)~~" (L599) | done (feature 130) |
| NW §D 130 left: "FTP - the next step, its own feature … decision about the log" (L602) | done (feature 134) |
| NW §D 130 left: "`GetCommonFSOperSourceDescr` (`src/zip.cpp`) still hands FTP and Undelete" (L608) | merged:undelete-zip-core-texts-in-code-page-sentences (FTP part done, feature 134) |
| NW §D 130 left: "Not driven by 130's probe, owed to a person or a later probe" (L610) | item:plugin-mixed-template-rows-130 |
| NW §D 130 left: "~~The FTP client (about 104 sites …)~~" (L615) | done (feature 134) |
| NW §D 134 left: "Copy log, proxy and server-type lists, FTPS certificate text, wait windows" (L618) | merged:ftp-real-server-checks-090-116-121 |
| NW §D 134 left: "a reply cut inside a character … caret arithmetic … `PrintDiskSize` mode 2" (L622) | item:ftp-reply-cut-and-logs-caret-bytes |
| NW §D 130 left: "~~Defects seen on the way~~" (L624) | done (feature 131) |
| NW §D 131 left: "~~PictView, possible loss (EXIF.DLL …)~~" (L626) | done (feature 132, closed by measurement) |
| NW §D 131 left: "~~SFTP: a listing ends silently~~" (L630) | done (feature 133) |
| NW §D 133 left: "~~a move of a directory never removes the directory~~" (L633) | done (feature 138) |
| NW §D 138 left: "the upload direction was not re-examined" (L635) | done (feature 139) |
| NW §D 139 left: "~~after a timeout or transport error the loops went on~~" (L645) | done (feature 140) |
| NW §D 140 left: "**a decision** - a recursive Change Attributes gives one mode" (L648) | item:decide-sftp-recursive-change-attributes-modes |
| NW §D 140 left: "owed to a person: Ctrl+R on a connection that died while idle … refused Change Attributes" (L650) | merged:sftp-test-container-rows-133 |
| NW §D 140 left: "a reply shorter than the protocol allows leaves a request half-done" (L653) | item:sftp-leaks-and-waits-after-broken-connection |
| NW §D 140 left: "~~F3 on a file that cannot be opened shows nothing~~" (L654) | done (feature 220) |
| NW §D 140 left: "one unclosed handle per lost connection stays allocated until exit" (L655) | merged:sftp-leaks-and-waits-after-broken-connection |
| NW §D 139 left: "a replaced server file with other hard links … ACLs … drop directory … `.tcpart-*`" (L656) | item:sftp-replace-keeps-links-acls-drop-dirs |
| NW §D 139 left: "the questions and reasons added are English literals" (L660) | item:sftp-english-literal-messages |
| NW §D 133 left: "a listing stopped by the user … (old behaviour, kept)" (L661) | item:sftp-listing-end-ambiguities (parked) |
| NW §D 133 left: "an empty name or an empty NAME packet … 'end of directory'" (L663) | merged:sftp-listing-end-ambiguities |
| NW §D 133 left: "owed to a person: upload into a read-only directory, the stale-reason row, Quick Rename" (L665) | merged:sftp-test-container-rows-133 |
| NW §D 131 left (via 133): "~~`UploadDirRecursive` holds about 30 KB … no panel refresh~~" (L667) | done (feature 139) |
| NW §D 131 left: "untranslated English literals stay" (L668) | merged:sftp-english-literal-messages |
| NW §D 131 left: "~~FTP: download autorename shortens a name … Quick Rename at 259 bytes~~" (L670) | done (features 137, 141) |
| NW §D 141 left: "~~`CCopyMoveDialog::Transfer` cuts typed text~~" (L675) | done (feature 214) |
| NW §D 214 review left: "Make File List's output file … user menu … viewers / editors … hot path editor … low risk" (L677) | item:dialog-typed-text-cut-to-caller-buffer |
| NW §D 141 left: "~~FTP: a file name of about 494 bytes … `PrepareFTPCommand`~~" (L684) | done (feature 215) |
| NW §D 215 audit left: "~~server paths over 300 bytes cut and acted on~~" (L687) | done (feature 233, measured: refused) |
| NW §D 233 left: "a PWD reply over 300 bytes is cut" (L689) | item:ftp-long-name-and-path-leftovers |
| NW §D 233/235: "a 'tree download left nothing on disk' note was a probe defect … a person's check owed" (L690) | merged:ftp-real-server-checks-090-116-121 |
| NW §D 233: "deep FTP paths are limited to ~260 bytes by the core" (L690) | merged:ftp-long-name-and-path-leftovers (a limit, in notes) |
| NW §D 215 audit left: "~~`FTPU8NameToServer` sends a name … in that code page even to a UTF-8 server~~" (L692) | done (feature 224) |
| NW §D 224 left: "a per-server encoding flag - the maintainer, 2026-10-16: stays in the backlog" (L693) | item:ftp-per-server-encoding-flag |
| NW §D 215 audit left: "VMS / AS/400 / OS/2 helpers that cut; the lock's `StrICmp`; `fs1.cpp:741`; the local side's 259-byte paths" (L699) | merged:ftp-long-name-and-path-leftovers |
| NW §D 215 audit left: "the core's `SalIsValidFileNameComponent` takes a name of more than 256 bytes for invalid - with 222" (L701) | done (feature 222) |
| NW §D 215 audit left: "Paste \"- Copy\" naming says \"cannot copy to itself\"" (L702) | item:core-long-name-wrong-refusals |
| NW §D 215 audit left: "FTP download target name in `fs4.cpp` cut at a byte" (L703) | merged:ftp-long-name-and-path-leftovers |
| NW §D 215 audit left: "Edit New File is limited to paths under 260 bytes" (L704) | merged:core-long-name-wrong-refusals |
| NW §D 215 audit left: "the whole-letter rule of `?` also counts two code-page bytes" (L705) | merged:ftp-long-name-and-path-leftovers |
| NW §D 137 left: "~~`ssl.cpp:666` `name[200]`~~" (L708) | done (feature 216) |
| NW §D 137 left: "~~the core's `SalMakeValidFileNameComponent` cuts at byte 256~~" (L709) | done (feature 222) |
| NW §D 222 review left: "F3 / F4 of such names refused by the disk cache's folder limit; folders over 255 bytes in archives are skipped" (L711) | item:archive-long-names-cache-folders-tar |
| NW §D 222 review left: "~~uniso `hfs.cpp:263-310`, `iso9660.cpp:197` `strncat`~~" (L712) | done (feature 223) |
| NW §D 223 left: "the HFS+ B-tree loader … trusts the image's node numbers …; a fuzzing pass" (L713) | item:uniso-hfs-btree-trust-and-joliet-cut |
| NW §D 222 review left: "Joliet names cut at their UCS-2 byte length" (L715) | merged:uniso-hfs-btree-trust-and-joliet-cut |
| NW §D 222 review left: "tar's gzip name cut at 259 bytes and extracted under it" (L717) | merged:archive-long-names-cache-folders-tar |
| NW §D 222 review left: "~~the User Menu `mainwnd4.cpp:411-433`~~" (L717) | done (feature 225) |
| NW §D 225 left: "~~the User Menu's .bat converts its UTF-8 text with `CharToOem`~~" (L719) | done (feature 226) |
| NW §D 226 reviews left: "~~`%` and `^` in a name change it in the batch file~~" (L720) | done (feature 229) |
| NW §D 229 left: "~~a folder literally named with %VAR%~~" (L721) | done (feature 238) |
| NW §D 238 left: "the refusal message names the command, not the file" (L722) | item:user-menu-messages-and-folder-leftovers |
| NW §D 226 reviews left: "a UNC panel folder or Initial Directory … the maintainer, 2026-10-16: stays in the backlog" (L723) | item:user-menu-unc-folder-pushd |
| NW §D 226 reviews left: "~~the Find window's User Menu route sets no current folder~~" (L728) | done (feature 234) |
| NW §D 234 left: "~~`$(ListOfSelectedNames)` from several Find folders~~" (L729) | done (feature 235) |
| NW §D 234 left: "a missing item folder's message names the command …; a `.lnk` command's own \"Start in\"" (L731) | merged:user-menu-messages-and-folder-leftovers |
| NW §D 234 left: "the Find route driven by a person" (L732) | item:user-menu-find-route-person |
| NW §D 226 reviews left: "a panel folder that cannot be set falls back to System32 …; chcp / `cd` …; OEM code page; `editwnd.cpp:355/482` COMSPEC" (L732) | merged:user-menu-messages-and-folder-leftovers |
| NW §D 226 reviews: "the other A `SetCurrentDirectory` calls on UTF-8 paths are speed hints only" (L735) | not migrated: recorded as harmless (speed hints only), noted in user-menu-messages-and-folder-leftovers |
| NW §D 225 left: "long paths in the User Menu" (L736) | merged:user-menu-messages-and-folder-leftovers |
| NW §D 222 review left: "~~Compare Directories `mainwnd5.cpp:1560/1584` cut disk names~~ … Find window's `CompareName1/2` end empty" (L736) | done (feature 227, measured: not reachable) |
| NW §D 222 review left: "~~`fileswna.cpp:396` cuts `SrcPath`~~" (L738) | done (feature 228) — its owed person step: item:drag-drop-paste-routes-194-228-230-240-by-hand (corrected after review S1) |
| NW §D 228 review left: "~~in `DragDropToArcOrFS` a duplicate case-insensitive match~~" (L739) | done (feature 230) — its owed person step: item:drag-drop-paste-routes-194-228-230-240-by-hand (corrected after review S1) |
| NW §D 230 review left: "~~a disk panel's name-based selection treats a.txt and A.txt … as one~~" (L740) | done (feature 231) |
| NW §D 231 review left: "~~feature 004's tie-break in `CmpNameExtIgnCase`~~" (L742) | done (feature 232) |
| NW §D 232 left: "in Turkish / Azeri locales \"index.html\" / \"INDEX.HTML\" never compare equal (upstream)" (L744) | item:case-sensitive-twins-first-match |
| NW §D 232 left: "Compare Directories may pair the wrong twin in case-sensitive folders" (L745) | merged:case-sensitive-twins-first-match |
| NW §D 232 left: "SFTP should declare its case sensitivity (`SALDIRFLAG_CASESENSITIVE`, `sftp/fs.cpp:778`)" (L746) | item:archive-plugins-declare-case-sensitivity |
| NW §D 231 left: "remembered folder sizes case-insensitive …; viewer's next / previous file …; User Menu's compare names …; Ctrl+X greying" (L748) | merged:case-sensitive-twins-first-match |
| NW §D 231 left: "a timed listing on an SMB share owed" (L751) | item:real-file-server-person-rows |
| NW §D 230 left: "paste from a 7-Zip / TAR archive holding a.txt and A.txt may extract the other one" (L751) | merged:archive-plugins-declare-case-sensitivity |
| NW §D 228 left: "~~a folder name over 255 bytes ends the operation silently~~" (L752) | done (features 240, 241) — 240's owed person step: item:drag-drop-paste-routes-194-228-230-240-by-hand (corrected after review S1) |
| NW §D 222 review left: "the FTP upload's link size from a cut path (`fs5.cpp:1149`)" (L754) | merged:ftp-long-name-and-path-leftovers |
| NW §D 222 review left: "`IsSimpleSelection`'s too-long message and CP_ACP fallback" (L755) | merged:core-long-name-wrong-refusals |
| NW §D "~~SFTP: a memory leak after a failed SSH handshake~~" (L757) | done (feature 217) |
| NW §D 217 left: "~~`Disconnect` tears down with a 1 ms deadline~~" (L759) | done (feature 220) |
| NW §D 220 left: "in libssh2: a partly sent packet …; SFTP handles open on a dead session are not freed" (L760) | merged:sftp-leaks-and-waits-after-broken-connection |
| NW §D 217 left: "a server's SSH_MSG_DISCONNECT while SFTP is up leaks the SFTP structure" (L762) | merged:sftp-leaks-and-waits-after-broken-connection |
| NW §D 217 left: "~1,500 connections to show the 1-in-256 failure gone - owed" (L764) | merged:sftp-leaks-and-waits-after-broken-connection |
| NW §D "Seen a second time on 2026-10-13, on the 0.1.9 build … Two defects to separate" (L764) | done (feature 217; the sighting is in the log of sftp-leaks-and-waits-after-broken-connection) |
| NW §D 131 left: "~~DiskMap: `CZFile::GetFullName` / `GetRelativeName`~~" (L769) | done (feature 211) |
| NW §D 131 left: "PE Viewer: letters outside the code page are `?` in the dump … a decision" (L772) | item:decide-peviewer-dump-utf8-with-bom |
| NW §D 131 left: "ZIP: a code-page `.set` …; wide messages to controls of an `A` dialog (favourites)" (L774) | item:zip-set-import-and-favourites-wide |
| NW §D 131 left: "Renamer: two stale reasons remain" (L777) | item:renamer-stale-error-reasons |
| NW §D 131 left: "Undelete: `dialogs.cpp:836-864` wraps the core's `GetCommonFSOperSourceDescr`" (L778) | merged:undelete-zip-core-texts-in-code-page-sentences |
| NW §D 131 left: "Rows of 131 not driven in the program" (L779) | merged:plugin-batch-131-rows-needing-volume-or-file |
| NW §D second verification 3 "~~The shortcut's own path (128)~~" (L781) | done (feature 181) |
| NW §D 181 left: "`FocusShortcutTarget`'s `errBuf[MAX_PATH + 300]`" (L782) | done (feature 182) |
| NW §D 181 left: "a junction / symlink in a folder of 260+ bytes is not recognised" (L784) | done (feature 197) |
| NW §D 197: "the maintainer decides whether 197 joins 0.1.10" (L787) | item:post-142-fixes-joining-0-1-10-decision; `backlog/RELEASE.md` *Current release* points to it (corrected after review S6: was release-checklist, a prose remark only) |
| NW §D 197 review left: "~~Change Attributes / Change Case with subfolders descend into every junction~~" (L788) | done (feature 213) |
| NW §D 213 left: "the link's own Change Attributes op reaches the target FOLDER" (L790) | item:change-attrs-on-link-reaches-target |
| NW §D 197 review left: "~~`_RemoveTemporaryDir` has no reparse check~~ … driving it owed" (L794) | done (feature 212); the owed driving merged:temp-dir-walks-follow-junctions |
| NW §D 212 left: "the ZIP self-extractor's own `_RemoveTemporaryDir` in `selfextr.cpp:157`" (L795) | item:temp-dir-walks-follow-junctions |
| NW §D 212 left: "the external unpacker's walk `pack1.cpp:632-692`" (L796) | merged:temp-dir-walks-follow-junctions |
| NW §D 197 review left: "~~not driven: a deep directory symbolic link, the delete by Recycle Bin masks~~" (L798) | done (feature 219) |
| NW §D 219 left: "a cloud placeholder past 780 characters - owed to a person with OneDrive" (L800) | item:cloud-placeholder-deep-path-onedrive |
| NW §D 181 left: "`GetSHObjectName(..., MAX_PATH)` cuts and widens through the code page" (L801) | merged:getshobjectname-code-page-cut-server-links |
| NW §D second verification 4 "~~The archivers' messages (127)~~" (L806) | done (feature 186) |
| NW §D second verification 5 "~~`GetErrorText` gives \"System error N …\"~~" (L810) | done (feature 180) |
| NW §D 180 left: "plug-ins with `FORMAT_MESSAGE_IGNORE_INSERTS` show a literal \"%1 ...\"; `sfx7zip/extract.c`" (L812) | item:plugins-error-text-literal-inserts |
| NW §D second verification 6 "The share list (125): the job of a worker … a share name near the path limit" (L815) | done (features 187, 193) |
| NW §D 193 review left: "~~every thread the core ends with `TerminateThread` leaves its `CCallStack`~~" (L820) | done (feature 218) |
| NW §D 218 left: "plug-in threads ended by `plugins/shared/auxtools.cpp` … `CThreadQueue`; duplicated thread handle" (L822) | item:plugin-thread-kills-leave-callstack |
| NW §D second verification 7 "`SHGetFileInfoA` texts read as UTF-8 later … Read 2026-10-15" (L825) | item:drive-list-code-page-texts |
| NW §D second verification 8 "~~`_TRUNCATE` sites of 127 without a tail trim~~" (L836) | done (feature 185) |
| NW §D second verification 9 "~~`msgbox.cpp` copy to the clipboard~~" (L840) | done (feature 185) |
| NW §D 185 left: "the dialog shows a plug-in's code-page URL text as UTF-8" (L840) | item:msgbox-plugin-url-text-code-page |

## Steps owed to a person

| Source | Destination |
|---|---|
| NW §D person "125: Esc and the Close button of the \"Checking path\" wait window" (L846) | item:unc-wait-window-esc-and-exit |
| NW §D person "125: … a real file server with visible shares, … another script, … refuses the list" (L847) | merged:real-file-server-person-rows |
| NW §D person "124: a look at the Registry Editor panel on a real screen in Czech and German" (L849) | item:clipboard-and-screen-rows-124-127 |
| NW §D person "128: a real mouse double-click on a shortcut to an accented folder" (L850) | item:shortcut-accented-folder-double-click |
| NW §D person "127: Slovak, Ctrl+C / Ctrl+V of a file in its own folder … the title of a queued Copy" (L852) | merged:clipboard-and-screen-rows-124-127 |
| NW §D person "126: a start of the 0.1.10 build on Windows 7 SP1 / Server 2008 R2 SP1" (L855) | item:windows-7-start-of-release-build |
| NW §D person "Rows written for the visible desktop, not driven yet … `unc_probe.ps1 -Only W2`" (L857) | merged:unc-wait-window-esc-and-exit |
| NW §D person "Rows written for the visible desktop … `mixed_probe.ps1 -Only COPYNAME,CLIPMSG,CLIPREG`" (L860) | merged:clipboard-and-screen-rows-124-127 |
| NW §D person "Clipboard rows … Registry Editor, *Copy Name* …; Ctrl+C in an error box" (L862) | merged:clipboard-and-screen-rows-124-127 |
| NW §D person "125: Esc in the wait window on a server that does not answer (`\\10.255.255.1\`), then exit at once" (L866) | merged:unc-wait-window-esc-and-exit |

## Notes for the reviewer

- Overlaps with other parts: the SFTP rows of 133 (in
  `sftp-container-person-rows`) and the rows of 131 (in
  `plugin-defect-batch-131-rows`) are also listed in the NEXT-WORK header
  *Before 0.1.10* steps 2 and 3; the header's step 4 ("rows 124–130 NOT
  DRIVEN") partly overlaps `clipboard-and-screen-rows-124-127` and
  `unc-wait-window-esc-and-exit`.
- Unsure: L553 (1) / L608 — after feature 134 the core's
  `GetCommonFSOperSourceDescr` gives UTF-8; what is left for ZIP and the two
  `salamdr3.cpp` texts is not stated (the item says verify first). L668
  "untranslated English literals stay" may record acceptance. L787 (whether
  197 joins 0.1.10) is a release-scope question, routed to the release
  checklist. The recommendations of the four decisions are the migrating
  agent's reading; the source states none.
