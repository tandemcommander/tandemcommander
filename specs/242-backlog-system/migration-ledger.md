# Migration ledger (feature 242)

Every entry of the old sources (`specs/NEXT-WORK.md` at `7993914c` = NW, the
five `specs/*/REMAINING-WORK.md` = RW068…RW080) with its destination in
`backlog/`. Rules and destination forms: `ledger/README.md`. The parts below
are the per-agent ledgers, concatenated unchanged; *consolidation* records
the merges made afterwards (a removed item's rows say `merged:<kept>`).
`see …` rows point to the row of another part that carries the destination;
`release-checklist` rows are in `backlog/RELEASE.md`.

| Destination kind | Rows |
|---|---|
| done | 308 |
| item | 147 |
| merged | 89 |
| not migrated | 36 |
| release-checklist | 17 |
| see | 99 |
| **total** | **696** |

## Part: b-person-steps

Person steps become `person-step` items grouped by feature or topic; release
procedure steps go to `release-checklist` (written into `backlog/RELEASE.md`
by another task). The facts that exist only in §R / §3 / §4 (reference trees,
084 commands, 069 V-rows, 081 pixel diff, 88-byte leak rule, 080 P1 steps)
were taken from `numbered-1.md`, *Facts for the part migrating NW §B*, into the
items' steps and notes.

| Source | Destination |
|---|---|
| NW header "Written: 2026-09-02 · Baseline: `main` at `f4cefa1` (0.1.7, build 191)" (L3) | not migrated: history of NEXT-WORK.md |
| NW header "Revised: 2026-09-20 — release status corrected: 0.1.7 is the last published version" (L4) | not migrated: history of NEXT-WORK.md |
| NW header "Revised again: 2026-09-20 — the tree is prepared for the 0.1.8 release" (L8) | not migrated: history of NEXT-WORK.md |
| NW header "Revised 2026-09-24 — 0.1.8 is published (tag `v0.1.8`…)" (L11) | not migrated: history of NEXT-WORK.md |
| NW header "Revised 2026-10-01 — item 7 … is done as feature 085; F9 … feature 090 …" (L17) | not migrated: history of NEXT-WORK.md |
| NW header "Revised 2026-10-06 — features 089–121 are done …" (L23) | not migrated: history of NEXT-WORK.md |
| NW header "Revised 2026-10-07 — the tree is prepared for the 0.1.9 release (build 193)" (L30) | not migrated: history of NEXT-WORK.md (0.1.9 is tagged `v0.1.9`) |
| NW header 2026-10-07 "keep the `Publish to winget` workflow disabled when the release is published, and later run `tools\winget\publish.ps1 -Version 0.1.9 -Submit`" (L41) | release-checklist |
| NW header 2026-10-07 "If the release happens on another day, change the date in the changelog heading and in `PRIVACY.md`" (L44) | release-checklist |
| NW header "Revised 2026-10-14 — the tree is prepared for the 0.1.10 release (build 194 …)" (L47) | not migrated: history of NEXT-WORK.md |
| NW header 2026-10-14 "The branch `release-0.1.10` - also on `origin` - is an earlier state … must not be tagged" (L49) | release-checklist |
| NW header 2026-10-14 "Owed to the maintainer, as for 0.1.9: merge the branches, `build.cmd full release sign setup`, tag `v0.1.10`, the GitHub release with the installer attached …, the feature-123 checks below, winget when #426090 allows" (L57) | release-checklist |
| NW header 2026-10-14 "If the release happens on another day, change the date in the changelog heading and in `PRIVACY.md`" (L61) | release-checklist |
| NW header "Closing pass on this state (2026-10-14, commit `4c852fe9`): `build.cmd full` … all 0 FAIL" (L63) | release-checklist — `backlog/RELEASE.md` *Preparing the tree* 5 (the closing pass) (corrected after review N11: was not migrated: history) |
| NW header closing pass "133: 74 / 2 - both in RENCASE, the known intermittent 'SSH handshake failed …' with the leak boxes at exit (item 5)" (L67) | see NW §D "~~SFTP: a memory leak after a failed SSH handshake~~ … Seen a second time on 2026-10-13" (L757–768; done (feature 217)); fact also in the log of item:sftp-test-container-rows-133; whether 217 joins 0.1.10: item:post-142-fixes-joining-0-1-10-decision (corrected after review N5 / S6: the label said NW §A item 5) |
| NW header closing pass "Two 111 rows (WebDAV rename) were NOT DRIVEN because the WebClient service was not running" (L69) | merged:pictview-own-photos-pipette-histogram-print |
| NW header "Before 0.1.10 - steps owed to a person" 1 "~~PictView Update Thumbnail on real camera files~~ - done by feature 135 … a look at a few own photos in the program is all that is left" (L76) | item:pictview-own-photos-pipette-histogram-print (the update itself: done (feature 135)); listed first in `backlog/RELEASE.md` *Current release: 0.1.10*, row 1 of *Person steps* (corrected after review M1: the release gate had been lost) |
| NW header Before 0.1.10 1 "Names outside the system code page on a volume without short names: done by feature 142" (L78) | done (feature 142) |
| NW header Before 0.1.10 1 "Left by 142: a refused file still reads 'Unable to create a file with the new thumbnail. Disk full?'" (L80) | see NW §A item 7 "a refused file gets 'Unable to create a file with the new thumbnail. Disk full? ...'" (L258) |
| NW header Before 0.1.10 1 "the update changes the picture's modification time and splits it from other hard links (`ReplaceFileW`)" (L82) | item:pictview-update-thumbnail-142-leftovers |
| NW header Before 0.1.10 1 "a failed save of the thumbnail image is an OK-only box per file (`IDS_SAVEERROR`)" (L84) | merged:pictview-update-thumbnail-142-leftovers |
| NW header Before 0.1.10 1 "`EXIFGetOrientationInfo` has no wide twin" (L85) | merged:pictview-update-thumbnail-142-leftovers |
| NW header Before 0.1.10 1 "the Exif information window is opened only for a flag the built-in engine never sets" (L85) | see NW §A item 7 "the viewer's Exif dialog and auto-rotation are dead … (the built-in engine never reports `PVFF_EXIF`)" (L256) |
| NW header Before 0.1.10 2 "SFTP against the test container: upload into a read-only directory, the stale-reason row, Quick Rename to a long name" (L88) | item:sftp-test-container-rows-133; `backlog/RELEASE.md` *Current release: 0.1.10* (corrected after review M1) |
| NW header Before 0.1.10 3 "The rows of 131 that need a volume or a special file: ZIP favourites …, Undelete, Renamer …, Registry Editor Find with `(`, DiskMap on a deep folder, the PE Viewer dump" (L91) | item:plugin-batch-131-rows-needing-volume-or-file; `backlog/RELEASE.md` *Current release: 0.1.10* (corrected after review M1) |
| NW header Before 0.1.10 4 "The rows 124–130 recorded as NOT DRIVEN in their fix logs (real keyboard)" (L95) | item:real-keyboard-ime-pass-093-124-130; `backlog/RELEASE.md` *Current release: 0.1.10* (corrected after review M1) |
| NW header "This file is the single entry point … It consolidates the per-feature handoffs …" (L97) | not migrated: explanation, superseded by backlog/ |
| NW header "Ordering criterion: what it costs users × what it costs us. Nothing here is a blocker …" (L105) | not migrated: explanation, superseded by backlog/ (the criterion is in the tandem-backlog triage guidance) |
| NW "Open items at a glance (2026-10-06)" intro "The numbered sections further down are the evidence trail … 'Queue 104' means …" (L110–115) | not migrated: explanation, superseded by backlog/ |
| NW §B "On-screen sweeps (item 3)": "084 archivers (probes ready)" (L419) | item:onscreen-sweep-084-archivers |
| NW §B On-screen sweeps "069 §4 (W1–W20, V-01…V-24)" (L419) | item:onscreen-sweep-069-encoding-w-and-v-rows |
| NW §B On-screen sweeps "075 S1–S5 + G6" (L420) | item:onscreen-pass-075-small-hardening |
| NW §B On-screen sweeps "070 §3 (codeview)" (L420) | item:onscreen-pass-codeview-070-074 |
| NW §B On-screen sweeps "074" (L420) | merged:onscreen-pass-codeview-070-074 |
| NW §B On-screen sweeps "081 §A–D" (L420) | item:onscreen-pass-081-mdview-shared-host |
| NW §B On-screen sweeps "078 panel tabs on the Release build" (L421) | item:panel-tabs-078-release-pass-and-leak-watch |
| NW §B On-screen sweeps "the 078/079 88-byte leak watch" (L421) | merged:panel-tabs-078-release-pass-and-leak-watch |
| NW §B "The features' own quickstart.md person steps": "085 G1–G6" (L422) | item:privacy-085-gui-checks-g1-g6 |
| NW §B quickstart "086 (an encrypted ZIP round trip)" (L422) | item:zip-sftp-passwords-real-keyboard-086-094 |
| NW §B quickstart "087 (RAR on a fresh and an upgraded configuration, the password prompt, the links message, an update over 0.1.8)" (L423) | item:rar-and-7zip-checks-087-089 |
| NW §B quickstart "088 (a real update with a viewer open, PictView with a pasted image, sign-out and shutdown; `viewers_probe` once more on the visible desktop)" (L425) | item:update-close-real-installer-signout-080-088-118 |
| NW §B quickstart "089 (associations after an update, packing into RAR with WinRAR)" (L427) | merged:rar-and-7zip-checks-087-089 |
| NW §B quickstart "090 (one anonymous FTP login against a server log)" (L428) | item:ftp-real-server-checks-090-116-121 |
| NW §B quickstart "092" (L429) | item:name-identity-checks-092 |
| NW §B quickstart "094" (L429) | merged:zip-sftp-passwords-real-keyboard-086-094 |
| NW §B quickstart "116 (the proxy server dialog, a Master Password, a real FTP server)" (L429) | merged:ftp-real-server-checks-090-116-121 |
| NW §B quickstart "118 (a real installer update, Disk Map's tooltip during the request)" (L430) | merged:update-close-real-installer-signout-080-088-118 |
| NW §B quickstart "121 (the folder picker's tree-view pick, …)" (L431) | merged:clipboard-drag-mouse-routes-099-101-107-119-121 |
| NW §B quickstart "121 (… FTP's welcome-message window)" (L431) | merged:ftp-real-server-checks-090-116-121 |
| NW §B quickstart "152 (one PictView print … compared with its preview: plain, mirrored, a selection)" (L432) | merged:pictview-own-photos-pipette-histogram-print |
| NW §B quickstart "153 (the Archive Update dialog with a marked line: readable, scrolls; English and one translated language)" (L434) | item:dialog-texts-on-screen-153-155 |
| NW §B quickstart "155 (one refusal of each kind on screen in a translated language)" (L435) | merged:dialog-texts-on-screen-153-155 |
| NW §B quickstart "123 (new version check): design acceptance …, real keyboard and mouse …, a screen reader, a real browser download, a real installer update with the notification open" (L436) | item:new-version-check-123-person-steps |
| NW §B "At the next release, because of feature 123": "publish the release with its installer attached and keep the asset name `tandemcommander-<version>-x64-setup.exe`" (L442) | release-checklist |
| NW §B At the next release "check the 'newer version' notification once with the previous Release build against the real endpoint" (L445) | release-checklist |
| NW §B At the next release "run one antivirus scan of the Release build (the core now makes an outbound connection at start-up)" (L446) | release-checklist |
| NW §B "By hand": "paste and drag & drop routes of 099 (also Explorer as the drag source)" (L449) | item:clipboard-drag-mouse-routes-099-101-107-119-121 |
| NW §B By hand "107 step 5" (L450) | merged:clipboard-drag-mouse-routes-099-101-107-119-121 |
| NW §B By hand "119 step 2b" (L450) | merged:clipboard-drag-mouse-routes-099-101-107-119-121 |
| NW §B By hand "101's paste rows" (L450) | merged:clipboard-drag-mouse-routes-099-101-107-119-121 |
| NW §B By hand "the real-keyboard / IME pass of 093 (menu mnemonics first, a mouse drag onto the command line)" (L450) | merged:real-keyboard-ime-pass-093-124-130 |
| NW §B By hand "PictView's pipette and histogram rows on an unlocked visible desktop (120)" (L452) | merged:pictview-own-photos-pipette-histogram-print |
| NW §B "Environment or hardware": "a clean machine without the Visual C++ runtime (077; item 0, point 1)" (L453) | item:clean-machine-start-077 |
| NW §B Environment "the elevated machine-wide update with the program open, a real `winget upgrade`, real sign-out/shutdown and a servicing restart (`080/REMAINING-WORK.md` P1)" (L454) | merged:update-close-real-installer-signout-080-088-118 |
| NW §B Environment "a real macOS or Samba share (103, 107)" (L456) | item:shares-snapshots-fat-same-folder-guards |
| NW §B Environment "a case-sensitive share (092)" (L457) | merged:shares-snapshots-fat-same-folder-guards |
| NW §B Environment "volume mount points (114, admin)" (L457) | item:undelete-mount-points-and-efs-114-115 |
| NW §B Environment "snapshots and FAT volumes (107, admin)" (L458) | merged:shares-snapshots-fat-same-folder-guards |
| NW §B Environment "real EFS backups (115, needs an EFS certificate)" (L458) | merged:undelete-mount-points-and-efs-114-115 |
| NW §B Environment "a SOCKS 5 proxy (116)" (L459) | merged:ftp-real-server-checks-090-116-121 |
| NW §B Environment "a real OpenSSH server with a key passphrase and a double-byte or UTF-8 code-page system (094)" (L459) | merged:zip-sftp-passwords-real-keyboard-086-094 |
| NW §B "Release and catalogue housekeeping (item 6)": "the state of `microsoft/winget-pkgs#426090`" (L462) | merged:winget-submit-release-after-pr-426090 (blocked) |
| NW §B Release housekeeping "the 0.1.8 submission" (L463) | release-checklist (submitting a release to winget once #426090 has settled) |
| NW §B Release housekeeping "P2 (`--scope user`)" (L463) | merged:winget-submit-release-after-pr-426090 |
| NW §B Release housekeeping "P3 (`checkver`)" (L464) | merged:winget-submit-release-after-pr-426090 |
| NW §B Release housekeeping "a real run of the Node 24 workflows (091)" (L464) | item:github-repo-housekeeping-091-083 |
| NW §B Release housekeeping "GitHub private vulnerability reporting and the second `PRIVACY.md` contact line (083)" (L464) | merged:github-repo-housekeeping-091-083 |
| NW §B Release housekeeping "antivirus reputation steps (item 0, point 4)" — one-time part: Avast Whitelisting Program registration, an "antivirus warning?" FAQ page (L466) | item:antivirus-reputation-avast-faq |
| NW §B Release housekeeping "antivirus reputation steps (item 0, point 4)" — per-release part: false-positive submission of each release, SHA-256 + VirusTotal link in the release notes, the same certificate at renewal (2027-08-03) (L466) | release-checklist |

## Part: a-code-work

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

## Part: c-decided

Source: `NEXT-WORK.7993914c.md` L468–504 (§C *Decided — not to do*) and
L2206–2218 (*Recorded, deliberately not on the list*).

| Source | Destination |
|---|---|
| NW §C "B-2 systemic comparison (panel sort, `CSalamanderDirectory`, the comparison services…" (L470) | item:b2-systemic-name-comparison-not-implemented |
| NW §C "Save dialogs' initial folder (117, 121): Windows' per-program first-folder rule…" (L475) | item:save-dialogs-initial-folder-left-to-windows |
| NW §C "259-byte limits kept: external archivers, plug-ins built for an interface older than 107…" (L478) | item:259-byte-limits-kept |
| NW §C "FTP user name, address and initial path not widened…" (L482) | item:ftp-user-address-path-not-widened |
| NW §C "Update close: the Batch Renamer always declines; a Checksum Calculate window…" (L484) | item:update-close-declining-windows-kept |
| NW §C "Formats and old forms: the GIF comment stays ASCII or UTF-8 (120)" (L488) | item:pictview-gif-comment-stays-ascii-or-utf8 |
| NW §C "Formats and old forms: … OEM checksum lists are not guessed (117)" (L489) | item:checksum-oem-lists-not-guessed |
| NW §C "Formats and old forms: … the ZIP comment is code page by format; the ZIP self-extractor routes and the SFX password prompt stay code page" (L489–491) | item:zip-comment-and-sfx-stay-code-page |
| NW §C "Formats and old forms: … a 7z archive mixing the two password forms stays mixed (093)" (L491) | item:7zip-mixed-password-forms-stay-mixed |
| NW §C "Copies and identity: a folder copied into itself or its own subfolder makes a snapshot copy" (L493) | item:folder-copy-into-itself-makes-snapshot |
| NW §C "Copies and identity: … the identity limits on file systems without ids (WebDAV twins, NAS shares…)" (L494) | item:identity-limits-without-file-ids |
| NW §C "SFTP does not split `sftp:user:password@host` (unreachable; item 7)" (L497) | item:sftp-address-password-not-split |
| NW §C "Open question for the maintainer, not a task: is the missing copy hook (drag out of archives into Explorer) intended?" (L497–499) | item:copy-hook-for-drag-out-of-archives |
| NW §C "Help footers, 069's nine sites, 073 parked — Recorded, deliberately not on the list" (L500) | not migrated: pointer to *Recorded, deliberately not on the list* (L2206), whose three entries are the rows below |
| NW *Recorded, deliberately not on the list* "Help footers. 236 of 237 manual pages still carry the 2023 Open Salamander footer" (L2208) | item:help-pages-carry-2023-open-salamander-footer |
| NW *Recorded, deliberately not on the list* "The nine sites 069 chose not to convert, each with a written reason" (L2211) | item:encoding-sites-069-chose-not-to-convert (corrected after review S4: parked, not rejected; site 4 dropped — done by 128) |
| NW *Recorded, deliberately not on the list* "073 (Command Shell environment) is parked as not reproduced" (L2217) | item:command-shell-environment-not-reproduced |

## Part: d-github

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

## Part: numbered-1

These sections are the older evidence trail. Every entry that is still open
is also listed in *Open items at a glance* (lines 110–868), so this part
creates **no items**; open entries point to the bullet of that section
that carries them. Facts that exist only here and that the items of those
bullets should carry are listed after the table.

| Source | Destination |
|---|---|
| NW §R "Tag `v0.1.8` (commit `4899f0d`) and the GitHub release (published 2026-09-20 …" (L871) | done (released 0.1.8) |
| NW §R preface "Step 2, the review of the `v0.1.7..v0.1.8` delta (64 commits) … no findings" (L874) | done (released 0.1.8) |
| NW §R preface "step 3, the human steps (clean-machine start, the panel tabs on the Release build, the elevated machine-wide update)" (L878) | see NW §B "Environment or hardware" (clean machine, elevated update) and NW §B "On-screen sweeps" (078 panel tabs on the Release build) |
| NW §R preface "step 4, the winget manifest for 0.1.8 → item 6 … #426090 (0.1.7) is still open" (L880) | see NW §B "Release and catalogue housekeeping" ("the 0.1.8 submission") |
| NW §R preface "Whether the `Publish to winget` workflow was switched off before publishing could not be checked … look at the Actions tab before relying on it" (L882) | release-checklist |
| NW §R original "Features 075, 077, 078, 079, 080 and 081 are all in `main`. The version was bumped to 0.1.8 / build 192" (L891) | done (released 0.1.8) |
| NW §R gate 1 "Done 2026-09-20 — the changelog heading reads `## [0.1.8] — 2026-09-20`" (L900) | done (released 0.1.8) |
| NW §R gate 1 knowledge: "`tools/winget/publish.ps1` reads the date from that heading and the release summary from the lead paragraph" (≤ 900 characters); "If the release is published on another day, the date moves" (L902, L907) | release-checklist |
| NW §R gate 2 "Pre-release review of the `v0.1.7..HEAD` delta (the 056 pattern)" (L910) | done (released 0.1.8) — done by the maintainer, no findings, recorded 2026-09-24 |
| NW §R gate 2 as procedure: a review of the `<previous tag>..HEAD` delta before a release (the 056 pattern) | release-checklist |
| NW §R gate 3 "The owed human steps that gate a release … clean-machine start … panel tabs on the Release build" (L913) | see NW §B "Environment or hardware" and NW §B "On-screen sweeps" |
| NW §R gate 4 "`build.cmd full release sign setup`, tag `v0.1.8`, GitHub release" (L917) | done (released 0.1.8) |
| NW §R gate 4 "Before publishing, switch the `Publish to winget` workflow off by hand … once #426090 has settled: *Enable workflow*, then *Run workflow* … or `tools\winget\publish.ps1 -Version 0.1.8 -Submit`" (L919) | release-checklist (the procedure; the 0.1.8 submission itself: see NW §B "Release and catalogue housekeeping") |
| NW §R "Item 2 (Restart Manager) was implemented as feature 080 inside 0.1.8 … Its owed human step 1 — the elevated, machine-wide update" (L927) | see NW §B "Environment or hardware" (the step); feature 080 itself done (feature 080) |
| NW §0 "Antivirus findings — DONE (feature 077) … Visual C++ runtime now ships … no longer patches kernel32" (L937) | done (feature 077) |
| NW §0 point 1 "Clean-machine start (owed human step)" (L951) | see NW §B "Environment or hardware" ("a clean machine without the Visual C++ runtime (077; item 0, point 1)") |
| NW §0 point 2 "~~Minidumps have never worked~~ — closed by feature 079" (L955) | done (feature 079) |
| NW §0 point 3 "~~Old bug report blocks start-up~~ — closed by feature 079" (L961) | done (feature 079) |
| NW §0 point 4 "Reputation work (076 section 6): Avast Whitelisting Program registration and false-positive submission of each release … an 'antivirus warning?' FAQ page" (L963) | see NW §B "Release and catalogue housekeeping" ("antivirus reputation steps (item 0, point 4)") |
| NW §0 point 4 "SHA-256 + VirusTotal link in the release notes … keep the same certificate at renewal (2027-08-03)" (L965) | release-checklist |
| NW §0 point 5 "Cosmetics (076 section 3.4): a version resource for `sqlite.dll` … `/guard:cf` … `ZwQueryInformationProcess`" (L967) | done (feature 167) |
| NW §0 "Ship gate for 077: the version bump came with feature 078" (L973) | done (released 0.1.8) |
| NW §1 "Small hardening batch — DONE (feature 075) … six commits, one per defect" (L977) | done (feature 075) |
| NW §1 "The independent review earned its place again: D5's first version …" (L984) | not migrated: a lesson already in `CLAUDE.md` *Working method* (refute-first review, 075 named) |
| NW §1 "the GUI half is still owed … scenarios S1–S5 … as does gate G6" (L988) | see NW §B "On-screen sweeps" ("075 S1–S5 + G6") |
| NW §1 original table: `codetbl.cpp:873` `>` vs `>=`, `viewer3.cpp:3291` `GetCodeType`, `zip.cpp:3292` `GetConversionTable`, `filecomp/controls.cpp:24,39` `strcpy`, `viewer3.cpp:30,35` caption `lstrcpyn` (L1006) | done (feature 075) |
| NW §1 original "Fold in one unrelated one-liner: `src/plugins/codeview/test/run_tests.cmd` reports `RESULT: FAILURES`" (L1014) | done (feature 075, D6 — `--experimental-detect-module`) |
| NW §2 "Restart Manager — DONE (feature 080) … The diagnosis below was wrong in its cause" (L1025) | done (feature 080) |
| NW §2 "five human steps (elevated machine-wide update, a real `winget upgrade`, the interactive installer, real sign-out/shutdown, a servicing restart)" (L1041) | see NW §B "Environment or hardware" (`080/REMAINING-WORK.md` P1; the interactive installer step is named only in RW080 P1) |
| NW §2 "one feature-sized follow-up — a plug-in-visible 'unattended close'" (L1042) | done (feature 088) |
| NW §2 original "The one item that will fail for real users … `winget upgrade` … exit 5" (L1052) | done (feature 080) |
| NW §3 "The reference trees are gone (checked 2026-09-24) … 069 → `64dcbb5` … 081 → `6b4d7af`" (L1081) | see NW §B "On-screen sweeps" (fact for its items: below) |
| NW §3 "Clean-machine start — item 0, point 1" (L1092) | see NW §B "Environment or hardware" |
| NW §3 "The elevated machine-wide update with the program open — `080/REMAINING-WORK.md` P1 step 1 (and its steps 3–5)" (L1094) | see NW §B "Environment or hardware" |
| NW §3 "A manual pass over the panel tabs on the Release build — 078" (L1096) | see NW §B "On-screen sweeps" ("078 panel tabs on the Release build") |
| NW §3 "084 (working archivers). The probes are ready but were not run" (L1101) | see NW §B "On-screen sweeps" ("084 archivers (probes ready)"; commands below) |
| NW §3 "069 §4 — the 068 sweep W1–W20 in the Czech UI and then the Hungarian UI … V-01…V-24" (L1114) | see NW §B "On-screen sweeps" ("069 §4 (W1–W20, V-01…V-24)") |
| NW §3 "075 — scenarios S1–S5 and gate G6" (L1120) | see NW §B "On-screen sweeps" |
| NW §3 "070 §3 — the codeview quickstart scenarios plus the runtime halves of the corpus checks" (L1121) | see NW §B "On-screen sweeps" ("070 §3 (codeview)") |
| NW §3 "074 — the human steps listed at the end of its `fix-log.md`" (L1124) | see NW §B "On-screen sweeps" ("074") |
| NW §3 "081 §A–D — the Markdown Viewer's regression pass after it moved onto the shared WebView2 host" (L1125) | see NW §B "On-screen sweeps" ("081 §A–D") |
| NW §3 "078/079's 88-byte Debug-CRT leak at exit … If the report never appears again under a DBWIN listener, record it as explained" (L1136) | see NW §B "On-screen sweeps" ("the 078/079 88-byte leak watch") |
| NW §3 "The person steps of features 085–121 … are listed together in *Open items at a glance*, B" (L1140) | see NW §B "The features' own `quickstart.md` person steps" (also NW §B "By hand", "Environment or hardware") |
| NW §3 "A sweep failure is a finding: back through fix → independent review → gates" (L1145) | not migrated: a working rule already in `CLAUDE.md` *Working method* |
| NW §4 "Architectural debt — DONE (feature 088) … plug-in interface 107 adds `IsUnattendedClose` and `SetWindowClosesUnattended`" (L1147) | done (feature 088) |
| NW §4 "~~Left: windows of the non-viewer plug-ins (File Comparator, Batch Renamer, Disk Map, Checksum) still decline an update.~~ Fixed by feature 118" (L1156) | done (feature 118) |
| NW §4 "the Registry Editor's Find window and FTP's Logs / Welcome Message windows still declined - declared by feature 121" (L1163) | done (feature 121); their *Save* dialogs declining: see NW §C "Update close" |
| NW §4 "Owed (joins item 3): `088-plugin-interface-107/quickstart.md`" (L1168) | see NW §B "The features' own `quickstart.md` person steps" ("088 (a real update with a viewer open, …)") |
| NW §4 "Note (105 review, 2026-10-04): its `viewers_probe.ps1` fails 3 rows (Code Viewer / Markdown Viewer close, `ERROR_FAIL_SHUTDOWN`) on the hidden desktop" (L1169) | done (feature 168) — NW §A.18: 088's Code/Markdown rows pass on the hidden desktop now; the remaining visible-desktop re-run: see NW §B "The features' own `quickstart.md` person steps" (088) |
| NW §4 original "A plug-in-visible 'unattended close' (`080/REMAINING-WORK.md` P2)" (L1180) | done (feature 088) |
| NW §4 original "~~mdview onto the shared `src/common/webhost/`~~ — DONE (feature 081)" (L1190) | done (feature 081); its on-screen pass: see NW §B "On-screen sweeps" ("081 §A–D") |
| NW §4 original "`GetNextFileNameForViewer`'s buffer contract … 'at least MAX_PATH' (`spl_gen.h:2703`)" (L1199) | done (feature 088) — `SAL_MAX_PATH_UTF8` in `spl_base.h`, comment corrected (088 fix-log) |

## Facts for the part migrating NW §B (they exist only in §R / §3 / §4)

- **Reference trees are gone** (checked 2026-09-24): `build\tandemcommander\`
  holds only `Release_x64` and `translator`; `Release_x64_prefix069\` and
  `Debug_x64_prefix081\` do not exist. Only side-by-side rows need a
  reference; rebuild it from git in a separate worktree, and only for a row
  that needs it: **069** → `64dcbb5` (commit before 069's first), Release
  x64; **081** → `6b4d7af` (commit before 081's first), Debug x64.
- **084 sweep** (not run at the maintainer's request, 2026-10-01): close the
  own Tandem Commander, then
  `specs/084-archiver-cleanup/probe/make_cfg_fixtures.ps1 -Exe "C:\Program Files\Tandem Commander\tandemcommander.exe" -OutDir specs\084-archiver-cleanup\probe\fixtures\cfg`;
  then `gui_probe.ps1 -Exe <Debug build>` (Autoconfiguration, ARJ/Unicode
  browse and extract through 7-Zip, hiding, Cancel, the 0.1.8 → 106
  migration; both back up and restore `HKCU\Software\Tandem Commander`);
  then the visual pass of the Pack/Unpack dialogs and the archiver
  configuration pages in English and Czech, and RAR packing with WinRAR 7.x
  (084 `quickstart.md` §4, §6).
- **069 §4**: Czech UI first, then Hungarian; then V-01…V-24 of its
  `quickstart.md`, starting with V-01 (command line), V-09 (help and
  `config.reg` under an accented install path), V-11 (cloud entries).
- **070 §3**: the corpora are already written (hostile content, request log,
  key sweep, copy fidelity, encoding matrix, performance budgets).
- **081 §A–D** (`specs/081-mdview-shared-webhost/quickstart.md`): the
  machine-checkable half is done; a person owes the network monitor over the
  hostile corpus, the *Keep the rendering engine ready* toggle, plug-in
  unload/reload through the Plugins Manager, the dark menus, and an eye over
  rows A1–A10 against the pre-migration build — a confirmation only:
  `render_diff.ps1` found 0 of 729,144 pixels different.
- **88-byte Debug-CRT leak**: 081 found and fixed a leak of exactly that size
  in `CTcWebKeeper`. If the report never appears again under a DBWIN
  listener, record it as explained; if it does, it was something else.
- **078 panel tabs**: verified by a GUI driver against the Debug build only.
- **080 P1**: five steps — elevated machine-wide update with the program
  open, a real `winget upgrade`, the interactive installer, real
  sign-out/shutdown, a servicing restart.
- **Release checklist**: whether the `Publish to winget` workflow was
  actually disabled before 0.1.8 was published was never checked (no `gh` in
  that session) — look at the Actions tab before relying on it; after
  #426090 settles: *Enable workflow*, *Run workflow* with `version`,
  `submit: true`, or `tools\winget\publish.ps1 -Version <v> -Submit`
  locally (a `release: published` event is not replayed).

## Part: numbered-2

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

## Part: remaining-work

Sources (at `7993914c`): `specs/068-encoding-regression-review/REMAINING-WORK.md`
(RW068, 459 lines), `specs/069-finish-encoding-fixes/REMAINING-WORK.md` (RW069,
189), `specs/070-source-viewer-plugin/REMAINING-WORK.md` (RW070, 178),
`specs/072-winget-distribution/REMAINING-WORK.md` (RW072, 308),
`specs/080-restart-manager-upgrade/REMAINING-WORK.md` (RW080, 114).

Dispositions of RW068 §1 and §3 come from
`specs/069-finish-encoding-fixes/closing-report.md` (per-item table, L22–59:
31 fixed, 3 verify-closed by 068's own fixes X02/X03/X06/X07). Sites named as
open were re-checked at `7993914c` where the row says so.

## RW068 — feature 068 handoff (2026-08-24)

| Source | Destination |
|---|---|
| RW068 §0 "What was finished (so this is not re-done)" — 9 fixes X01–X09 (L9) | done (feature 068) |
| RW068 §1.A F-P6-04 "Ctrl+Enter / Ctrl+Space push raw UTF-8 bytes into the ANSI command line" (L32) | done (feature 069) |
| RW068 §1.B F-P4-01 "the viewer's default character-set conversion is silently lost on every restart" (L43) | done (feature 069) — the "no encoding at rest" invariant of the table names: see RW069 §1 B-5 |
| RW068 §1.B F-P4-02 "a non-ASCII coding name poisons the whole viewer window caption" (L52) | done (feature 069) |
| RW068 §1.B F-P1-08 "`SHGetFolderPath` (A) results are fed to the strict UTF-8 facade" (L61) | done (feature 069) |
| RW068 §1.B F-P1-10 "Install-directory paths obtained with `GetModuleFileName` (A)" (L70) | done (feature 069) — the wider install-path chain later by features 170–172 |
| RW068 §1.B F-P1-19 "Compare Directories cannot read files or subdirectories with non-ASCII names" (L79) | done (feature 069) |
| RW068 §1.B F-P1-20 "Writing an edited file back into an archive uses the ANSI `SHFileOperation`" (L88) | done (feature 069) — the reporting half: see RW069 §2 item 6 |
| RW068 §1.B F-P6-01 "mdview's keeper window class is never unregistered" (L97) | done (feature 069) |
| RW068 §1.B F-P1-03 "Startup cleanup of leftover `SAL*.tmp` directories misses them" (L106) | done (feature 068) — verify-closed by X06/X07 (069 closing-report L86) |
| RW068 §1.C F-P1-09 "OneDrive / Dropbox root paths are stored as CP_ACP" (L117) | done (feature 069) |
| RW068 §1.C F-P4-05 "the OneDrive folder path is obtained in CP_ACP" (L126) | done (feature 069) |
| RW068 §1.C F-P1-12 "`MyGetVolumeInformation`/`MyGetDiskFreeSpace` degrade silently" (L135) | done (feature 069) |
| RW068 §1.C F-P1-13 "`subst` targets are resolved through the ANSI `QueryDosDevice`" (L144) | done (feature 069) |
| RW068 §1.C F-P1-14 "Volume labels, drive display names and mapped-drive UNC paths are acquired in CP_ACP" (L153) | done (feature 069) |
| RW068 §1.C F-P1-27 "Shell/network strings degraded to CP_ACP at intake" (L162) | done (feature 069) — producer half; the `shellib.cpp` STRRET half: see RW069 §2 item 3 |
| RW068 §1.D F-P1-05 "External-archiver list files are written in the wrong encoding" (L173) | done (feature 069) — list file and unpack halves; the archive *listing* half: see RW069 §0b |
| RW068 §1.D F-P1-06 "The external-packer subsystem uses ANSI file APIs on UTF-8 temp/archive paths" (L182) | done (feature 069) |
| RW068 §1.D F-P1-07 "`salspawn.exe` path taken with `GetModuleFileName` (A)" (L191) | done (feature 069) — `salspawn` itself left the product in feature 084 |
| RW068 §1.E F-P2-04 "The safe-wait window … mixes template + path" (L202) | done (feature 069) |
| RW068 §1.E F-P2-07 "Drive Information: the 'type' line mixes ANSI templates with UNC / SUBST / link-target paths" (L211) | done (feature 069) |
| RW068 §1.E F-P2-09 "Plugin Manager: only the Name column was converted" (L220) | done (feature 069) |
| RW068 §1.E F-P2-10 "Plugin Manager: the 'Change Drive menu' checkbox mixes an ANSI template" (L229) | done (feature 068) — verify-closed, X02 = F-P6-02 (069 closing-report L87) |
| RW068 §1.E F-P2-11 "Plugin 'Keyboard Shortcuts' dialog lists command names through the ANSI list-view call" (L238) | done (feature 069) |
| RW068 §1.E F-P2-13 "'Save Configuration' export-exists box mixes an ANSI template" (L247) | done (feature 069) |
| RW068 §1.E F-P3-07 "status-bar tooltip truncates a UTF-8 path mid-sequence" (L256) | done (feature 069) |
| RW068 §1.F F-P4-03 "custom packer/unpacker titles have no defined encoding at rest" (L267) | done (feature 069) |
| RW068 §1.F F-P4-07 "configuration fields documented as UTF-8 are seeded from ANSI `LoadStr`" (L274) | done (feature 069) — ru/uk truncation noted for a language re-enable (069 closing-report L397) |
| RW068 §1.G F-P1-21 "Assorted ANSI file APIs on UTF-8 paths outside the main copy/move engine" (L285) | done (feature 069) — group 3 (DROPFAKE) and group 8 (dead code): see RW069 §2 items 2 and 8 |
| RW068 §1.G F-P1-22 "User-menu icons are loaded with the ANSI `ExtractIconEx`" (L292) | done (feature 069) |
| RW068 §1.G F-P1-23 "Environment-variable expansion mixes ACP values into UTF-8 paths" (L301) | done (feature 069) — `icncache.cpp`: see RW069 §2 item 1 |
| RW068 §1.G F-P1-24 "Common file/folder dialogs return CP_ACP paths into UTF-8 fields" (L310) | done (feature 069) — the code-page dialogs themselves replaced by features 170 and 172 |
| RW068 §1.G F-P1-25 "UTF-8 names widened through CP_ACP before being handed to the shell/OLE" (L319) | done (feature 069) — jump-list half by 068 (X03) |
| RW068 §1.G F-P1-26 "Dropped files are read through CP_ACP even when the payload is wide" (L328) | done (feature 069) |
| RW068 §1.H F-P5-06 "the FS plugin interface states no encoding for any path method" (L339) | done (feature 069) |
| RW068 §2 B-1 "ANSI dialog windows — only 2 of 90 dialog constructions set `unicodeWnd`" (L354) | done (feature 093) — measured not lossy as a class; the real losses fixed by 093 and 154; leftovers: see NW §5 "B-1 (text typed into windows) - DONE where it was real" |
| RW068 §2 B-2 "ACP byte tables behind all name comparison" (L355) | see NW §C "B-2 systemic comparison" (core identity done by feature 092) |
| RW068 §2 B-3 "`GetErrorText` returns UTF-8 but the SDK never says so" (L356) | see NW §A.19 "B-4 `AlterFileName` / *Change Case*" (its *Was:* list keeps "B-3 the undocumented UTF-8 `GetErrorText`"); the per-plug-in compositions were done by features 130 and 134 |
| RW068 §2 B-4 "`AlterFileName` byte-folds UTF-8 names" (L357) | done (feature 169) |
| RW068 §2 B-5 "Plugin-facing services are ANSI and frozen" (L358) | see NW §A.19 "B-4 `AlterFileName` / *Change Case*" (its *Was:* list keeps "B-5 the frozen plug-in-facing ANSI services") |
| RW068 §3 D01 "The Trace Server cannot be built" (L364) | done (feature 069) |
| RW068 §3 D02 "`zip/common.cpp:2469` `GetInfo` … stray `Â`" (L365) | done (feature 069) |
| RW068 §3 D03 "`filecomp/controls.cpp:88-91` Path bar drops its text" (L366) | done (feature 069) |
| RW068 §3 D04 "`filecomp/worker2.cpp:85-100` A fourth filecomp title site" (L367) | done (feature 069) |
| RW068 §3 D05 "The Spec Kit git auto-commit hook cannot parse on a CP1250/CP1252 machine" (L368) | done (feature 069) |
| RW068 §4 "Still owed: the on-screen sweep (maintainer)" — F1–F3 start and W1–W20 in cs/hu, English spot-check (L370–395) | see NW §3 "069 §4" → item:onscreen-sweep-069-encoding-w-and-v-rows, which now carries 068's F1–F8 (`review-report.md` §10.1) and the English spot-check of W1–W6 / W13 (G7, `review-report.md` L518) as steps (corrected after review M4: the pointer had dropped F1–F8 and G7) |
| RW068 §4 "Caveat for F8 (filecomp title): verify on a text comparison … deferred item D04" (L397) | not migrated: D04 was fixed by feature 069, the caveat no longer applies |
| RW068 §5 "How to do the remaining fixes (the protocol that caught 3 regressions)" (L401) | not migrated: process guidance, superseded by the binding `specs/069-finish-encoding-fixes/contracts/fix-protocol.md` (NW *Protocol*) |
| RW068 §6 "Facts a fresh session needs" (L431) | not migrated: reference facts, not work (kept in the 068 folder and in `architecture/`) |
| RW068 §7 "`tasks.md` T036 stays open by design — it fires only if the sweep finds a failure" (L454) | see NW §3 "069 §4 — the 068 sweep W1–W20" (a failure of that sweep is the trigger) |
| RW068 §7 "`consolidate.py` regenerates … `coverage_check.py` re-runs the queue accounting" (L456) | not migrated: tooling note of the 068 review |
| RW068 §7 "the 34 items in section 1 are confirmed user-visible defects and should not be quietly lost" (L458) | done (feature 069) — all 34 dispositioned in its closing report |

## RW069 — feature 069 handoff (2026-08-24)

| Source | Destination |
|---|---|
| RW069 §0 "What 069 finished (so it is not re-done)" — 31 fixed + D01–D05 (L11) | done (feature 069) |
| RW069 §0b "F-P1-05, the archive *listing* display encoding (`pack1.cpp`, both sites)" (L33) | see NW §5 "Not part of this: **F-P1-05, the archive listing display encoding**" (also in NW §A.19's *Was:* list) |
| RW069 §1 B-1 "ANSI dialog windows — 88 of 90 dialog constructions" (L44) | done (feature 093) — leftovers: see NW §5 "B-1 (text typed into windows) - DONE where it was real" |
| RW069 §1 B-2 "Code-page byte tables behind all name comparison" (L45) | see NW §C "B-2 systemic comparison" (core identity done by feature 092) |
| RW069 §1 B-3 "`GetErrorText` returns UTF-8, undocumented" (L46) | see NW §A.19 "B-4 `AlterFileName` / *Change Case*" (*Was:* list, "B-3 the undocumented UTF-8 `GetErrorText`") |
| RW069 §1 B-4 "`AlterFileName` byte-folds names" (L47) | done (feature 169) |
| RW069 §1 B-5 "Plugin-facing services are ANSI and frozen" — incl. the `CCodeTablesData::Name` invariant (L48) | see NW §A.19 "B-4 `AlterFileName` / *Change Case*" (*Was:* list, "B-5 the frozen plug-in-facing ANSI services") |
| RW069 §2.1 "`icncache.cpp:796` (F-P1-23, the file-type icon location)" (L57) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" — still ANSI `ExpandEnvironmentStrings` at `icncache.cpp:796` at 7993914c |
| RW069 §2.2 "`shellsup.cpp:1025` and `:1440` (DROPFAKE / CLIPFAKE). Reverted on review" (L63) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" |
| RW069 §2.3 "`shellib.cpp`, six `IShellFolder`/`STRRET` sites (F-P1-27's second half)" (L72) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" (related: NW §D "A shell calls that return paths (128)") |
| RW069 §2.4 "`fileswn0.cpp:333` / `fileswn2.cpp:157` keep the ANSI `IShellLink`" (L76) | done (feature 128) — both sites use `IShellLinkW` at 7993914c (`fileswn0.cpp:334`, `fileswn2.cpp:168`) |
| RW069 §2.5 "`execute.cpp:1213` (`$(DOSPath)` for a user-menu item) … is still ANSI" (L81) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" — now `MFLFileDataExpDOSPath`, `execute.cpp` ~1224, `GetShortPathName` (A) at 7993914c |
| RW069 §2.6 "Reporting a failed archive-edit copy … no translated string" (L83) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" — still traced only (`salamdr3.cpp` ~3703 at 7993914c) |
| RW069 §2.7 "`IDS_VIEWERTITLE` at nine sites (`viewer2.cpp` ×8, `viewer3.cpp:1670`)" (L87) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" |
| RW069 §2.8 "`worker.cpp:7058` — F-P1-21's 'link operation' site is inside a `/* … */` design sketch" (L92) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" (dead code) |
| RW069 §2.9 "`mainwnd3.cpp` FMExt `szName` — inside `#if (_MSC_VER < 1700)`" (L94) | see NW "Recorded, deliberately not on the list" "The nine sites 069 chose not to convert" (dead code) |
| RW069 §3.1 "`src/codetbl.cpp:873` — one-byte buffer overflow" (L125) | done (feature 075) |
| RW069 §3.2 "`src/viewer3.cpp:3291` — `GetCodeType`'s return value ignored" (L131) | done (feature 075) |
| RW069 §3.3 "`src/zip.cpp:3292` — `GetConversionTable` does not NULL-check" (L133) | done (feature 075) |
| RW069 §3.4 "`src/viewer3.cpp:30/35` — `lstrcpyn(caption, FileName, MAX_PATH)` can cut a path" (L135) | done (feature 075) |
| RW069 §3.5 "`src/plugins/filecomp/controls.cpp:24,39` — unbounded `strcpy(Text, text)`" (L139) | done (feature 075) |
| RW069 §3.6 "`src/editwnd.cpp:577` — `EM_SETSEL` receives UTF-8 byte offsets" (L141) | done (feature 093) — `SalU8OffsetToW` before `EM_SETSEL` (`editwnd.cpp` ~637–644; 093 fix-log) |
| RW069 §4 "Still owed: the on-screen sweep (maintainer)" — W1–W20 cs/hu, V-01…V-24, G7 (L147) | see NW §3 "069 §4" → item:onscreen-sweep-069-encoding-w-and-v-rows, which now carries gate G7 (W1–W6 and W13 in English against a pre-fix reference) as a step (corrected after review M4: the pointer had dropped G7) |
| RW069 §5 "How to continue (the protocol that caught four regressions)" (L170) | not migrated: process guidance; the binding protocol is `specs/069-finish-encoding-fixes/contracts/fix-protocol.md` (NW *Protocol*) |

## RW070 — feature 070 handoff (2026-08-26, updated 2026-08-27)

| Source | Destination |
|---|---|
| RW070 "Update 2026-08-27: the plugin has now been run. Three defects found on first use" — and §4 translations done (L7) | done (feature 070) — `fix-log.md` defects 1–3 |
| RW070 "Update 2026-08-27 (second round): five more defects from real use are fixed" (L15) | done (feature 070) — `fix-log.md` defects 4–8 |
| RW070 "Read `stabilization-review.md` first" (L28) | not migrated: pointer to the current record |
| RW070 "Update 2026-08-27 (third round — systematic review): … 37 unique defects confirmed, 35 fixed" (L31) | done (feature 070) — the two left: §2 (row below) and F16; the ten rows of `stabilization-review.md` §8 *What still needs a human at the keyboard*: steps of item:onscreen-pass-codeview-070-074 (corrected after review M3: §8 was not named and its rows were in no item) |
| RW070 "Two things it did NOT cover remain open: … the code-table gap (FR-024), now recorded as F16" (L42–44) | item:codeview-code-tables-for-single-byte-files |
| RW070 §1 "The plugin has never been run" (L52) | done (feature 070) — run and reviewed (`stabilization-review.md`); shipped in 0.1.6 |
| RW070 §1 risk "ESM import of the language modules through the interceptor" (L63) | done (feature 070) — works since the first run (shipped 0.1.6) |
| RW070 §1 risk "Worker module loading under the CSP" (L64) | done (feature 070) — as above |
| RW070 §1 risk "The `text` resource fetch" (L65) | done (feature 070) — as above |
| RW070 §1 risk "Line-height measurement before the font loads" (L66) | done (feature 070) — real defect, fixed (`fix-log.md` defect 4) |
| RW070 §1 risk "Status bar as a plain `STATIC`" (L67) | done (feature 070) — real defect, fixed (`fix-log.md` defect 6) |
| RW070 §2 "mdview is not yet on the shared host (T006/T007) — DONE (feature 081)" (L69) | done (feature 081) |
| RW070 §2 "The manual GUI regression pass this entry was waiting for is still owed" (L83) | see NW §3 "081 §A–D — the Markdown Viewer's regression pass" |
| RW070 §3 "Verification tasks that need the GUI" T019 … T057 (L102) | see NW §3 "070 §3 — the codeview quickstart scenarios plus the runtime halves of the corpus checks" |
| RW070 §4 "Translations (T055) — needs credentials" (L113) | done (feature 070) — DeepL only (update of 2026-08-27, L10) |
| RW070 §4 "Also still to do: `_DOMAINS[\"codeview\"]` … pinning the plugin name plus the 12 scheme names" (L124) | done (feature 070) — `tools/translate/uicontext.py:65` and `translations/ui-overrides.json:108` at 7993914c |
| RW070 §5 "Ship gate (T059) — `CHANGELOG.md` entry plus the version/build bump" (L130) | done (feature 070) — released in 0.1.6, build 190 (`CHANGELOG.md` L1896) |
| RW070 "Defects found during implementation, already fixed" — `*.txt`/`*.log` claimed twice, `*.pat`, T013 spike (L137–148) | done (feature 070) |
| RW070 "A defect in the plugin API that outlives this feature" — `GetNextFileNameForViewer` buffer "at least MAX_PATH" (L150) | done (feature 088) |
| RW070 "Known limitations to state in the changelog when this ships" — excluded grammars, plain band, "Restore default file types" (L167) | item:codeview-limitations-not-stated-for-users |

## RW072 — feature 072 handoff (2026-08-29, P0 2026-09-30)

| Source | Destination |
|---|---|
| RW072 "Gate: is #426090 merged? Check this first" (L14) | see NW §6 "Cheap winget housekeeping, once PR #426090 has settled" |
| RW072 §P0 "Audit of #426090 (2026-09-30): what moderation is likely to ask next — NOT ACTED ON" (L37) | item:winget-manifest-fixes-from-072-audit (consolidation; was: see NW §6) |
| RW072 §P0.1 "0.1.7 does not start without the Visual C++ runtime — highest risk" (L56) | item:winget-repoint-pr-426090-decision (corrected after review M2: was merged:winget-submit-release-after-pr-426090 — the audit acts on the open PR, a maintainer decision) |
| RW072 §P0.2 "Moderators ask for the current release" (L66) | item:winget-repoint-pr-426090-decision (corrected after review M2: was merged:winget-submit-release-after-pr-426090) |
| RW072 §P0.3 "`PrivacyUrl` may be required (uncertain)" (L73) | item:winget-manifest-fixes-from-072-audit — as a check (the URL answers 200 on `main`), the template line exists since 083 (corrected after review M2 / N10: was listed as a template change) |
| RW072 §P0.4 "`Policy-Test-1.2` is not about the new code-signing certificate" — waiver (L91) | item:winget-repoint-pr-426090-decision (*Notes*: the waiver) (corrected after review M2: was merged:winget-submit-release-after-pr-426090) |
| RW072 §P0.5 "`Validation-Guide` is added by the policy bot … asks nothing of the author" (L102) | not migrated: an explanation, no action |
| RW072 §P0.6 "`AppsAndFeaturesEntries.DisplayName` does not match the installer" (L105) | item:winget-manifest-fixes-from-072-audit (consolidation; was: see NW §6) |
| RW072 §P0.7 "`ProductCode` should also be at installer level" (L116) | item:winget-manifest-fixes-from-072-audit (consolidation; was: see NW §6) |
| RW072 §P0 "Verified as fine" — upgrade without `DisplayVersion`, the moderation bot, the CLA trailer (L121–135) | not migrated: verified facts; the per-user caveat in it: see NW §6 "P2 — `--scope user`" |
| RW072 §P0 "Recommended plan" 1 "Re-point #426090 to 0.1.8" (L139) | item:winget-repoint-pr-426090-decision (option A) (corrected after review M2: was merged:winget-submit-release-after-pr-426090, under a block on the PR — the plan inverted) |
| RW072 §P0 "Recommended plan" 2 "Template fixes (6, 7) … together with step 1" (L147) | item:winget-manifest-fixes-from-072-audit — depends on item:winget-repoint-pr-426090-decision, templates change in the same push as the re-pointed PR (corrected after review M2: was blocked until #426090 settled) |
| RW072 §P0 "Recommended plan" 3 "`PrivacyUrl` (3) — ready since feature 083" (L149) | item:winget-manifest-fixes-from-072-audit — a check in the same push (corrected after review M2 / N10) |
| RW072 §P0 "Recommended plan" 4 "Run the 0.1.8 workflow from `main`, never from tag `v0.1.8`" (L152) | merged:winget-submit-release-after-pr-426090 (*Notes*; also in item:winget-repoint-pr-426090-decision) (corrected after review M2) |
| RW072 §P0 "Repository record fixes" — `CLAUDE.md` 072 entry claims `publish.ps1` refuses without `PrivilegesRequiredOverridesAllowed` (L157) | item:winget-records-stale-claims-from-072-audit (consolidation; was: see NW §6) |
| RW072 §P0 "Repository record fixes" — `templates/installer.yaml.in:13-21` still gives the refuted "pipeline runs elevated" reason (L160) | item:winget-manifest-fixes-from-072-audit (consolidation; was: see NW §6) |
| RW072 §P0 "Repository record fixes" — `fix-log.md` ~128–131 check-09 claim (L162) | item:winget-records-stale-claims-from-072-audit (consolidation; was: see NW §6) |
| RW072 §P0 "Repository record fixes" — `publish.ps1:194` vs `:203` placeholders substituted before comment lines are stripped (L163) | item:winget-records-stale-claims-from-072-audit (corrected after review S2: the item now states the source's effect — a release-notes line starting with `#` is dropped) |
| RW072 §P0 "Repository record fixes" — "This file's Gate … should mention the 2026-09-30 `DisplayVersion` exception" (L167) | not migrated: a correction of this handoff file itself, which the backlog replaces |
| RW072 §P1 "Upgrading over a running instance aborts the install — CLOSED (feature 080)" (L172) | done (feature 080) |
| RW072 §P2 "Per-user installation is untested, not impossible" (L218) | see NW §6 "P2 — `--scope user` has never actually been tested" |
| RW072 §P3 "`checkver` points at upstream and there is no update feed" (L261) | see NW §6 "P3 — `checkver` still points at Open Salamander's site" (feature 123 since added an own new-version check) |
| RW072 §P4 "Node.js 20 deprecation warning in every workflow run — DONE (feature 091)" (L277) | done (feature 091) — its real run: see NW §B "a real run of the Node 24 workflows (091)" |
| RW072 §P4 "Left: `ilammy/msvc-dev-cmd@v1` (no Node 24 release exists)" (L281) | item:ci-msvc-dev-cmd-action-has-no-node-24-release |
| RW072 "Not remaining" — the version boundary for scope switches must not come back (L299) | not migrated: a recorded decision against re-introducing code (also `specs/FEATURE-HISTORY.md` 072) |
| RW072 "Not remaining" — "If P2 reinstates the entry, reinstate the assertion with it" (L303) | see NW §6 "P2 — `--scope user`" (a condition of that work) |
| RW072 "Not remaining" — "Manifest schema 1.10.0 is accepted by the catalogue" (L307) | not migrated: a verified fact |

## RW080 — feature 080 handoff (2026-09-20)

| Source | Destination |
|---|---|
| RW080 §P1.1 "Machine-wide update with an elevated installer" (L14) | see NW §B "Environment or hardware" ("the elevated machine-wide update with the program open … (`080/REMAINING-WORK.md` P1)") |
| RW080 §P1.2 "A real `winget upgrade`, once the package is in the catalogue" (L21) | see NW §B "Environment or hardware" ("a real `winget upgrade`") |
| RW080 §P1.3 "The interactive installer. Run Setup by hand over a running program" (L24) | see NW §3 "The elevated machine-wide update … (and its steps 3–5 whenever convenient)" |
| RW080 §P1.4 "Real sign-out, shutdown and forced shutdown" (L28) | see NW §B "Environment or hardware" ("real sign-out/shutdown") |
| RW080 §P1.5 "A servicing restart (*Update and restart*) with the program open" (L36) | see NW §B "Environment or hardware" ("and a servicing restart") |
| RW080 §P2 "Plug-in windows decline the update; plug-in viewers should not have to — DONE (feature 088)" (L42) | done (feature 088) — the non-viewer plug-ins by 118 and 121 |
| RW080 §P2 "whether an FTP operation can exist without a window and without a file system in a panel was not established" (L73–78) | done (feature 088) — "FTP no longer asks during an unattended close" (L46) |
| RW080 §P3 "An execute stage that outlives the requester's 30 s is not stopped" (L82) | item:update-close-accepted-limitations-of-080 |
| RW080 §P3 "A forced close (`/FORCECLOSEAPPLICATIONS`) … killing it after 30 s — without saving the configuration" (L86) | merged:update-close-accepted-limitations-of-080 |
| RW080 §P3 "The first update from 0.1.7 does not bring the program back" (L90) | merged:update-close-accepted-limitations-of-080 |
| RW080 §P3 "One genuine `WM_CLOSE` within 35 s after an installer's instruction is ignored" (L92) | merged:update-close-accepted-limitations-of-080 |
| RW080 §P4 "Restart after a reboot or sign-out — Excluded with `RESTART_NO_REBOOT`" (L96) | item:restart-after-reboot-or-sign-out |
| RW080 "Found on the way" — "File Comparator writes an uninitialised byte into its stored configuration" (L105) | item:filecomp-stores-uninitialised-configuration-byte |
| RW080 "Found on the way" — "The shipped product contains no help files … *Help → Contents* ends in a *Help Error* box" (L110) | item:help-contents-fails-no-manual-shipped |
| RW080 "Found on the way" — "`072/quickstart.md` §2b used `Start-Process -Wait` … Corrected" (L113) | done (feature 080) |

## Counts

Rows: RW068 52, RW069 24, RW070 20, RW072 27, RW080 15 — 138 in all.
Items: 7 — next 4, decisions 2, rejected 1 (person 0, parked 0).

## Part: consolidation

Done by `consolidate.py` after the seven parts: duplicates across parts
merged (the removed item's texts are in the kept item's *Notes*), the
circular pointers of the 072 audit resolved, one measured finding added.

| Source | Destination |
|---|---|
| a-code-work `shellext-copy-hook-cuts-archive-target` (parked) — same topic as c-decided's open question | merged:copy-hook-for-drag-out-of-archives |
| d-github `sftp-container-person-rows` — same rows as §B "Before 0.1.10" step 2 | merged:sftp-test-container-rows-133 |
| d-github `plugin-defect-batch-131-rows` — same rows as §B "Before 0.1.10" step 3 | merged:plugin-batch-131-rows-needing-volume-or-file |
| a-code-work `ftp-server-person-checks-infoline-short-names` — FTP server checks of 157 / 205 | merged:ftp-real-server-checks-090-116-121 |
| d-github `ftp-server-person-rows` — FTP server rows of 134 / 136 / 233 | merged:ftp-real-server-checks-090-116-121 |
| a-code-work `pictview-print-fit-and-own-photos-check` — overlaps §B PictView by hand | merged:pictview-own-photos-pipette-histogram-print |
| a-code-work `pictview-thumbnail-refusal-message` — the 142 leftover "Disk full?" text | merged:pictview-update-thumbnail-142-leftovers |
| b-person-steps `winget-pr-426090-follow-up` — split more finely by numbered-2 (P2 item, P3 decision, submission step) | merged:winget-submit-release-after-pr-426090 |
| NW §6 "Read 072/REMAINING-WORK.md § P0" ↔ RW072 §P0 — each part pointed at the other, no item | item:winget-manifest-fixes-from-072-audit, item:winget-records-stale-claims-from-072-audit, item:winget-repoint-pr-426090-decision (corrected after review M2: the re-point steps of winget-submit-release-after-pr-426090 moved into the decision) |
| feature 242 measurement: `ai-main` named in CLAUDE.md does not exist | item:claude-md-names-missing-ai-main-branch |
| review.md M2 — RW072 §P0 *Recommended plan* 1–3 and NW §6 L2012–2020: re-point the open #426090 to the current release, a maintainer decision buried in a blocked person step | item:winget-repoint-pr-426090-decision |
| review.md S6 — NW §D L786–788 "the maintainer decides whether 197 joins 0.1.10" and NW L67–68 (the exit hang fixed by 217 after the 0.1.10 state) | item:post-142-fixes-joining-0-1-10-decision |
| review.md S1 — owed person steps of the fix-logs of 194 (~L39), 228 (L8–24), 230 (L8–15), 240 (L14), never carried by NEXT-WORK | item:drag-drop-paste-routes-194-228-230-240-by-hand |
| review.md N9 — recorded leftovers of `specs/146-archive-ops-repointed/fix-log.md` L44–47 and `specs/145-pending-edits-repointed/fix-log.md` L47–50, never carried by NEXT-WORK | item:archive-ops-repointed-name-recorded-gaps |
