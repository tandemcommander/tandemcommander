# Ledger part b-person-steps — NEXT-WORK header and §B (lines 1–116, 417–467 at 7993914c)

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
