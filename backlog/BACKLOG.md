# Tandem Commander — Backlog

All planned work: bugs, features, improvements, debts, decisions and steps
owed to a person. **The order of rows is the priority**, top first. Only the
maintainer triages and reorders; agents add new items to *Inbox* and nothing
else. Each row links to its item's description `items/<slug>/desc.md`, which
is the only source of the item's data: every column except **#** and the
row's place is written by `python tools/backlog/backlog.py sync` (every
changing command of the tool runs it). Manage the backlog with
`/tandem-backlog`; run one item autonomously with `/tandem-backlog-implement`.
Formats: `specs/242-backlog-system/contracts/`. Runs: `RUNS.md`. Release
procedure: `RELEASE.md`.

Last triaged: 2026-10-19

## In progress

| # | Item | Type | Sev | Area | Feature |
|---|---|---|---|---|---|

## Next

| # | Item | Type | Sev | Area | Who | Effort | Status |
|---|---|---|---|---|---|---|---|
| 1 | [FTP: PWD reply cut at 300 bytes and other long-name leftovers of 215](items/ftp-long-name-and-path-leftovers/desc.md) | bug | 5 | ftp | agent | M | blocked |
| 2 | [ISO plug-in: HFS+ B-tree loader trusts the image; Joliet names cut](items/uniso-hfs-btree-trust-and-joliet-cut/desc.md) | bug | 5 | other-plugins | agent | M | blocked |
| 3 | [Paste fails in a folder whose path contains an exclamation mark](items/vkladanie-zo-schranky-nefunguje-v-adresaroch-s-v-ceste/desc.md) | bug | 5 | file-ops | agent | - | blocked |
| 4 | [Archive listings show names in one encoding only as a whole (F-P1-05)](items/archive-listing-display-encoding/desc.md) | tech-debt | 4 | encoding | agent | L | blocked |
| 5 | [Read the 78 findings of check_encoding.py --plugins one by one](items/check-encoding-plugin-findings/desc.md) | tech-debt | 4 | encoding | agent | L | blocked |
| 6 | [Undelete and ZIP wrap the core's UTF-8 texts in their own code-page sentences](items/undelete-zip-core-texts-in-code-page-sentences/desc.md) | bug | 4 | encoding | agent | M | blocked |
| 7 | [User Menu: messages name the command, System32 fallback, silent batch ends](items/user-menu-messages-and-folder-leftovers/desc.md) | bug | 4 | panels-ui | agent | M | blocked |
| 8 | [Code Viewer reads single-byte files only in the system code page (no CP852 etc.)](items/codeview-code-tables-for-single-byte-files/desc.md) | feature | 4 | other-plugins | agent | L | open |
| 9 | [Importing a configuration file writes every key of a foreign .reg file](items/importing-a-configuration-file-writes-every-key-of-a-foreign/desc.md) | bug | 4 | data-safety | agent | S | open |
| 10 | [Remembered network drive with a non-code-page or long path cannot be reconnected](items/remembered-network-drive-with-a-non-code-page-or-long-path/desc.md) | bug | 4 | encoding | agent | M | open |
| 11 | [Backlog tool tests fail on a fresh checkout: the fixture folder specs/243-example is not in git](items/backlog-fixture-empty-specs-folder-missing/desc.md) | bug | 4 | tooling | agent | S | open |
| 12 | [Plug-in closing: forced Disk Map unload in a shell command, stray comparator box](items/plugin-close-forced-unload-and-stray-box/desc.md) | bug | 3 | other-plugins | agent | M | open |
| 13 | [PictView: the Exif dialog and auto-rotation never work with the built-in engine](items/pictview-exif-dialog-and-auto-rotation/desc.md) | feature | 3 | pictview | agent | L | open |
| 14 | [Archive Update: a changed member can go unmarked or be marked needlessly](items/archive-update-change-detection-limits/desc.md) | bug | 3 | archives | agent | M | open |
| 15 | [Other plug-ins' dialogs: code-page message loops not examined](items/plugin-dialogs-code-page-message-loops/desc.md) | tech-debt | 3 | encoding | agent | ? | open |
| 16 | [A file moved aside to salNNN can stay there silently on the create paths](items/moved-aside-restore-leftovers/desc.md) | bug | 3 | data-safety | agent | M | open |
| 17 | [Renamer: a new name is capped at 259 bytes; a subfolder item refused at 260](items/renamer-long-new-name-limits/desc.md) | bug | 3 | long-paths | agent | M | open |
| 18 | [711 clipped labels in the shipped translations](items/translations-clipped-labels/desc.md) | bug | 3 | translations | both | L | open |
| 19 | [After a menu popup closes by itself, typed characters are swallowed until Esc](items/menubar-loop-swallows-typed-characters/desc.md) | bug | 3 | panels-ui | agent | S | open |
| 20 | [File masks fold accented letters through the code page](items/mask-matcher-code-page-fold/desc.md) | bug | 3 | encoding | agent | M | open |
| 21 | [`..` / Go to root in \\\\server\\share does nothing without the Network plug-in](items/share-root-parent-offers-share-list/desc.md) | improvement | 3 | panels-ui | agent | M | open |
| 22 | [A server's share list that needs a password shows only the Windows error](items/share-list-offers-sign-in/desc.md) | improvement | 3 | panels-ui | agent | M | open |
| 23 | [Folder-shortcut code gets only a MAX_PATH Browse result](items/folder-shortcut-browse-result-max-path/desc.md) | bug | 3 | long-paths | agent | S | open |
| 24 | [Registry Editor: fs3.cpp passes a third of the key-name buffer size](items/regedit-key-name-buffer-size-and-move-rows/desc.md) | bug | 3 | other-plugins | agent | S | open |
| 25 | [SFTP: leaks and waits after a lost or broken connection](items/sftp-leaks-and-waits-after-broken-connection/desc.md) | bug | 3 | sftp | agent | M | open |
| 26 | [FTP: one process-wide name encoding instead of a per-server flag](items/ftp-per-server-encoding-flag/desc.md) | improvement | 3 | ftp | agent | M | open |
| 27 | [ZIP: a code-page .set file that looks like UTF-8 is misread on import](items/zip-set-import-and-favourites-wide/desc.md) | bug | 3 | archives | agent | S | open |
| 28 | [Drive list and folder type names use code-page shell texts](items/drive-list-code-page-texts/desc.md) | bug | 3 | encoding | both | M | open |
| 29 | [winget: offer a per-user install (--scope user), proven in Windows Sandbox first](items/winget-per-user-scope-entry/desc.md) | improvement | 3 | build-release | both | M | blocked |
| 30 | [winget manifest fixes (072 audit): DisplayName, ProductCode; PrivacyUrl check](items/winget-manifest-fixes-from-072-audit/desc.md) | bug | 3 | build-release | agent | S | open |
| 31 | [PictView Update Thumbnail: file time, hard links, per-file box, orientation](items/pictview-update-thumbnail-142-leftovers/desc.md) | improvement | 3 | pictview | agent | M | open |
| 32 | [Quick search: first keystroke over 100,000 non-ASCII names takes about 335 ms](items/quick-search-first-keystroke-over-100-000-non-ascii-names/desc.md) | improvement | 3 | panels-ui | agent | M | open |
| 33 | [translate.merge keeps a stale machine translation when the English text changes](items/translate-merge-keeps-a-stale-machine-translation-when-the/desc.md) | bug | 3 | translations | agent | S | open |
| 34 | [SDK: state that GetErrorText returns UTF-8 (B-3 contract half)](items/geterrortext-utf8-contract/desc.md) | tech-debt | 2 | plugin-api | agent | S | open |
| 35 | [GetSHObjectName converts through CP_ACP and cuts at MAX_PATH (server links)](items/getshobjectname-code-page-cut-server-links/desc.md) | bug | 2 | encoding | agent | S | open |
| 36 | [Unpack short-name walk: process-wide root; external archiver's unpack not driven](items/unpack-root-process-wide-latent/desc.md) | tech-debt | 2 | archives | agent | M | open |
| 37 | [The 092 name comparator reads both names to their ends (2x-16x slower sorts)](items/name-comparator-reads-whole-names/desc.md) | tech-debt | 2 | encoding | agent | M | open |
| 38 | [Translation merge keys by bundle ordinal; removing a bundle needs a re-key](items/translate-merge-bundle-rekey/desc.md) | tech-debt | 2 | translations | agent | M | open |
| 39 | [Bug report's module line from an install folder outside the code page](items/bug-report-module-line-install-path/desc.md) | bug | 2 | encoding | agent | S | open |
| 40 | [Mixed-template guard: no reverse rule, sinks found by variable names](items/mixed-template-guard-reverse-rule/desc.md) | tech-debt | 2 | tooling | agent | S | open |
| 41 | [PE Viewer: version-resource names printed with a narrow %ls (suspected)](items/peviewer-version-names-narrow-ls/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 42 | [FTP: server reply cut inside a character; Logs window caret counts bytes](items/ftp-reply-cut-and-logs-caret-bytes/desc.md) | bug | 2 | ftp | agent | S | open |
| 43 | [SFTP: questions and reasons are untranslated English literals](items/sftp-english-literal-messages/desc.md) | tech-debt | 2 | sftp | agent | M | open |
| 44 | [User Menu through a shell: a UNC panel folder runs the command in C:\\Windows](items/user-menu-unc-folder-pushd/desc.md) | bug | 2 | panels-ui | agent | S | open |
| 45 | [Renamer: two error messages still append a stale system reason](items/renamer-stale-error-reasons/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 46 | [Plug-ins show a literal "%1" in Windows error texts that have inserts](items/plugins-error-text-literal-inserts/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 47 | [Message box shows a plug-in's code-page URL text as UTF-8](items/msgbox-plugin-url-text-code-page/desc.md) | bug | 2 | encoding | agent | S | open |
| 48 | [7-Zip: two-form password passes in Test, F3 view, Delete and Cancel not driven](items/7zip-two-form-password-passes-not-driven/desc.md) | tech-debt | 2 | archives | agent | M | open |
| 49 | [CI: ilammy/msvc-dev-cmd@v1 is a Node 20 action with no Node 24 release](items/ci-msvc-dev-cmd-action-has-no-node-24-release/desc.md) | tech-debt | 2 | build-release | both | S | open |
| 50 | [Stale winget claims in project records and publish.ps1 order (072 audit)](items/winget-records-stale-claims-from-072-audit/desc.md) | tech-debt | 2 | build-release | agent | S | open |
| 51 | [Archive operations through a re-pointed name: four gaps recorded by 145 / 146](items/archive-ops-repointed-name-recorded-gaps/desc.md) | bug | 2 | archives | agent | M | open |
| 52 | [A history entry with invalid text hides the entries saved after it](items/a-history-entry-with-invalid-text-hides-the-entries-saved/desc.md) | bug | 2 | encoding | agent | S | open |
| 53 | [Quick search keys skip canonical reordering of combining marks](items/quick-search-keys-skip-canonical-reordering-of-combining/desc.md) | bug | 2 | encoding | agent | S | open |
| 54 | [Remove the dormant start-up import of older Open Salamander configurations](items/remove-the-dormant-start-up-import-of-older-open-salamander/desc.md) | tech-debt | 2 | data-safety | agent | M | open |
| 55 | [106's packself probe row A-zip-noask-refused is stale since 119](items/packself-probe-stale-row/desc.md) | tech-debt | 1 | tooling | agent | S | open |
| 56 | [Plug-in threads ended by CThreadQueue leave their CCallStack registered](items/plugin-thread-kills-leave-callstack/desc.md) | tech-debt | 1 | plugin-api | agent | M | open |
| 57 | [Code Viewer: its known limitations are not stated anywhere a user can read](items/codeview-limitations-not-stated-for-users/desc.md) | improvement | 1 | help-docs | agent | S | open |
| 58 | [File Comparator stores an uninitialised byte in its saved configuration](items/filecomp-stores-uninitialised-configuration-byte/desc.md) | bug | 1 | other-plugins | agent | S | open |
| 59 | [CLAUDE.md names a branch ai-main that does not exist](items/claude-md-names-missing-ai-main-branch/desc.md) | tech-debt | 1 | help-docs | both | S | open |
| 60 | [Unshipped resources still carry 2023 Open Salamander-only copyright notices](items/unshipped-resources-still-carry-2023-open-salamander-only/desc.md) | tech-debt | 1 | build-release | agent | S | open |
| 61 | [winget README names a publish.ps1 check that does not exist](items/winget-readme-names-a-publish-ps1-check-that-does-not-exist/desc.md) | tech-debt | 1 | build-release | agent | S | open |
| 62 | [The stored main window icon index is checked against the count, not the last index](items/the-stored-main-window-icon-index-is-checked-against-the/desc.md) | bug | 1 | panels-ui | agent | S | open |

## Decisions for the maintainer

| # | Item | Sev | Area | Status |
|---|---|---|---|---|
| 1 | [winget: re-point the open PR #426090 to the current release (072 audit)?](items/winget-repoint-pr-426090-decision/desc.md) | 4 | build-release | open |
| 2 | [Frozen code-page plug-in services: add wide/UTF-8 variants or keep them (B-5)?](items/plugin-ansi-services-interface-decision/desc.md) | 3 | plugin-api | open |
| 3 | [Ship the Network plug-in (nethood) enabled?](items/decide-ship-network-plugin-nethood/desc.md) | 3 | other-plugins | open |
| 4 | [State a deliberate minimum Windows version in the program and installer?](items/decide-windows-version-floor/desc.md) | 2 | build-release | open |
| 5 | [SFTP: a recursive Change Attributes gives one mode to files and folders alike](items/decide-sftp-recursive-change-attributes-modes/desc.md) | 5 | sftp | open |
| 6 | [PE Viewer: write the dump as UTF-8 with a BOM?](items/decide-peviewer-dump-utf8-with-bom/desc.md) | 2 | other-plugins | open |
| 7 | [checkver plug-in still checks Open Salamander's site: redirect it or drop it](items/checkver-update-channel-decision/desc.md) | 2 | other-plugins | open |
| 8 | [Should the program come back after a reboot or sign-in (RESTART_NO_REBOOT)?](items/restart-after-reboot-or-sign-out/desc.md) | 1 | plugin-api | open |
| 9 | [Help > Contents ends in a Help Error box: the product ships no manual](items/help-contents-fails-no-manual-shipped/desc.md) | 4 | help-docs | open |
| 10 | [Is the missing shell copy hook (drag out of archives into Explorer) intended?](items/copy-hook-for-drag-out-of-archives/desc.md) | 3 | archives | open |

## Person steps

| # | Item | Area | Status |
|---|---|---|---|
| 1 | [Drag from a ZIP or SFTP panel during a quick search acts only on the dragged item](items/drag-from-a-zip-or-sftp-panel-during-a-quick-search-acts/desc.md) | data-safety | open |
| 2 | [Drag & drop and paste routes of 194, 228, 230, 240 by hand](items/drag-drop-paste-routes-194-228-230-240-by-hand/desc.md) | data-safety | open |
| 3 | [Check network drive names and disconnected icons with a real SMB server](items/check-network-drive-names-and-disconnected-icons-with-a-real/desc.md) | panels-ui | open |
| 4 | [Judge the quick-search tint on a real screen and try Shift and Alt keys](items/judge-the-quick-search-tint-on-a-real-screen-and-try-shift/desc.md) | panels-ui | open |
| 5 | [Backlog loop: Ctrl+C in Git Bash and the first real usage limit](items/backlog-loop-person-checks/desc.md) | tooling | open |
| 6 | [Disk Map closing with its menu or a shell confirmation open, with a real mouse](items/diskmap-close-real-mouse-rows/desc.md) | other-plugins | open |
| 7 | [Viewer Copy to File onto a file held open, on a FAT stick or a network share](items/viewer-copy-to-file-on-fat-or-share/desc.md) | data-safety | open |
| 8 | [Email files on a tree with an unreadable deep folder, with a mail client](items/email-files-deep-folder-with-mapi-client/desc.md) | long-paths | open |
| 9 | [Plug-in messages of feature 130 not driven (SFTP, Renamer, DiskMap, ...)](items/plugin-mixed-template-rows-130/desc.md) | other-plugins | open |
| 10 | [User Menu from the Find window driven by a person](items/user-menu-find-route-person/desc.md) | panels-ui | open |
| 11 | [Real file server rows: shares, other-script names, refused list, SMB timing](items/real-file-server-person-rows/desc.md) | panels-ui | open |
| 12 | [Delete of a cloud placeholder past 780 characters (OneDrive)](items/cloud-placeholder-deep-path-onedrive/desc.md) | data-safety | open |
| 13 | [UNC "Checking path" wait window: real Esc / Close, then an immediate exit](items/unc-wait-window-esc-and-exit/desc.md) | panels-ui | open |
| 14 | [Clipboard and real-screen rows of 124 and 127 (Registry Editor, messages)](items/clipboard-and-screen-rows-124-127/desc.md) | encoding | open |
| 15 | [Real mouse double-click on a shortcut to an accented folder (GitHub #8)](items/shortcut-accented-folder-double-click/desc.md) | panels-ui | open |
| 16 | [Start the 0.1.10 build on Windows 7 SP1 / Server 2008 R2 SP1 (GitHub #6)](items/windows-7-start-of-release-build/desc.md) | build-release | open |
| 17 | [Accented archive edits and long archive paths: rows the probes could not drive](items/archive-edit-and-long-path-rows-owed-to-person/desc.md) | archives | open |
| 18 | [Submit the current release to winget once PR #426090 has settled](items/winget-submit-release-after-pr-426090/desc.md) | build-release | blocked |
| 19 | [On-screen sweep of 084 archivers: run the ready probes, then a visual pass](items/onscreen-sweep-084-archivers/desc.md) | archives | open |
| 20 | [On-screen sweep of 068/069: F1-F8, W1-W20 in cs and hu, V-01 to V-24, G7](items/onscreen-sweep-069-encoding-w-and-v-rows/desc.md) | encoding | open |
| 21 | [On-screen pass of 075 (small hardening): scenarios S1-S5 and gate G6](items/onscreen-pass-075-small-hardening/desc.md) | viewer | open |
| 22 | [On-screen pass of the Code Viewer: 070 quickstart scenarios and 074 gutter steps](items/onscreen-pass-codeview-070-074/desc.md) | viewer | open |
| 23 | [On-screen pass of 081: Markdown Viewer on the shared WebView2 host, sections A-D](items/onscreen-pass-081-mdview-shared-host/desc.md) | webview | open |
| 24 | [Panel tabs (078) by hand on the Release build, and the 88-byte leak watch](items/panel-tabs-078-release-pass-and-leak-watch/desc.md) | panels-ui | open |
| 25 | [Privacy fixes of 085 on screen: checks G1-G6](items/privacy-085-gui-checks-g1-g6/desc.md) | privacy-security | open |
| 26 | [Encrypted ZIP and SFTP passwords by hand: AES round trip, accented passwords](items/zip-sftp-passwords-real-keyboard-086-094/desc.md) | archives | open |
| 27 | [RAR reading and 7-Zip plug-in by hand: associations, WinRAR (087, 089)](items/rar-and-7zip-checks-087-089/desc.md) | archives | open |
| 28 | [Closing for a real update: elevated installer, sign-out, open plug-in windows](items/update-close-real-installer-signout-080-088-118/desc.md) | plugin-api | open |
| 29 | [FTP against real servers: anonymous login, non-ASCII password, SOCKS 5 proxy](items/ftp-real-server-checks-090-116-121/desc.md) | ftp | open |
| 30 | [Name identity of 092 by hand: accented names that differ only in case](items/name-identity-checks-092/desc.md) | data-safety | open |
| 31 | [New texts on screen in a translation: Archive Update (153), refusals (155)](items/dialog-texts-on-screen-153-155/desc.md) | translations | open |
| 32 | [New version check (123): design, real keyboard and mouse, screen reader](items/new-version-check-123-person-steps/desc.md) | panels-ui | open |
| 33 | [Paste, drag and drop and mouse-only routes by hand (099, 101, 107, 119, 121)](items/clipboard-drag-mouse-routes-099-101-107-119-121/desc.md) | data-safety | open |
| 34 | [Clean-machine start: the installer on Windows without the Visual C++ runtime](items/clean-machine-start-077/desc.md) | build-release | open |
| 35 | [Same-file guards on macOS / Samba and case-sensitive shares, snapshots, FAT](items/shares-snapshots-fat-same-folder-guards/desc.md) | data-safety | open |
| 36 | [Undelete on a mount point with an accented name (admin) and real EFS backups](items/undelete-mount-points-and-efs-114-115/desc.md) | other-plugins | open |
| 37 | [GitHub housekeeping: real run of the Node 24 workflows, vulnerability reporting](items/github-repo-housekeeping-091-083/desc.md) | build-release | open |
| 38 | [Antivirus reputation: Avast Whitelisting registration and a FAQ page](items/antivirus-reputation-avast-faq/desc.md) | build-release | open |

## Inbox

| Item | Type | Sev | Area | Source | Created |
|---|---|---|---|---|---|
| [Desktop view (Folders plug-in) repeats its shell columns after a view-mode switch](items/desktop-view-folders-plug-in-repeats-its-shell-columns-after/desc.md) | bug | 3 | other-plugins | review:248 | 2026-10-19 |
| [Plug-in interface does not say that column names are code-page text](items/plug-in-interface-does-not-say-that-column-names-are-code/desc.md) | tech-debt | 1 | plugin-api | review:248 | 2026-10-19 |
| [Unpack refused at a link names a temporary folder, not the archive folder](items/unpack-refused-at-a-link-names-a-temporary-folder-not-the/desc.md) | improvement | 2 | archives | leftover:249 | 2026-10-19 |
| [A damaged viewer, editor or User Menu entry erases the entries after it](items/a-damaged-viewer-editor-or-user-menu-entry-erases-the/desc.md) | bug | 7 | panels-ui | review:250 | 2026-10-20 |
| [A .gz file whose stored name is too long for Windows: refuse it or use the archive name](items/a-gz-file-whose-stored-name-is-too-long-for-windows-refuse/desc.md) | decision | 3 | archives | review:260 | 2026-10-20 |
| [A ZIP made on Windows that holds names differing only in case is not case-sensitive](items/a-zip-made-on-windows-that-holds-names-differing-only-in/desc.md) | bug | 5 | archives | leftover:252 | 2026-10-20 |
| [Automation: a script folder with non-ASCII letters is shown as mojibake in the configuration](items/automation-script-folder-list-code-page/desc.md) | bug | 2 | other-plugins | measure:255 | 2026-10-20 |
| [Change Attributes on a file symbolic link compresses / re-times the target file](items/change-attributes-on-a-file-symbolic-link-compresses-re/desc.md) | bug | 5 | data-safety | leftover:253 | 2026-10-20 |
| [Check Ctrl+X ghosting and User Menu compare names with case twins](items/check-ctrl-x-ghosting-and-user-menu-compare-names-with-case/desc.md) | person-step | 3 | panels-ui | leftover:261 | 2026-10-20 |
| [The encoding guard does not read header files; plug-in headers convert names leniently](items/check-encoding-skips-header-files/desc.md) | tech-debt | 2 | tooling | review:255 | 2026-10-20 |
| [Check that Change Attributes refuses to encrypt or decrypt a junction (253)](items/check-that-change-attributes-refuses-to-encrypt-or-decrypt-a/desc.md) | person-step | 4 | data-safety | leftover:253 | 2026-10-20 |
| [CheckVer: the log shows a script path with non-ASCII letters garbled](items/checkver-log-script-path-garbled/desc.md) | bug | 1 | other-plugins | review:255 | 2026-10-20 |
| [Command line: a COMSPEC path outside ASCII is read through the code page](items/command-line-comspec-read-wide/desc.md) | bug | 2 | encoding | manual | 2026-10-20 |
| [Compare Directories misses a case-only pair beside a soft-hyphen or NFD name](items/compare-directories-misses-a-case-only-pair-beside-a-soft/desc.md) | bug | 3 | panels-ui | review:261 | 2026-10-20 |
| [Copying from a TAR folder opened in another case extracts nothing](items/copying-from-a-tar-folder-opened-in-another-case-extracts/desc.md) | bug | 5 | archives | review:252 | 2026-10-20 |
| [Create Directory refuses a relative name in a folder whose path is 260+ bytes](items/create-directory-refuses-a-relative-name-in-a-folder-whose/desc.md) | bug | 5 | long-paths | measure:259 | 2026-10-20 |
| [Ctrl+X ghosts a name in the other panel that shows a case twin folder](items/ctrl-x-ghosts-a-name-in-the-other-panel-that-shows-a-case/desc.md) | bug | 2 | panels-ui | review:261 | 2026-10-20 |
| [DB Viewer: a field length of 1000 or more shows a broken thousands separator](items/dbviewer-field-length-separator/desc.md) | bug | 2 | other-plugins | measure:255 | 2026-10-20 |
| [Editing long-named archive members: the rows the feature-260 probe could not drive](items/editing-long-named-archive-members-the-rows-the-feature-260/desc.md) | person-step | 6 | archives | leftover:260 | 2026-10-20 |
| [F3 / F4 refuse archive members whose path inside the archive has 520 bytes or more](items/f3-f4-refuse-archive-members-whose-path-inside-the-archive/desc.md) | improvement | 4 | archives | leftover:260 | 2026-10-20 |
| [Find window: the viewer next / previous file takes the first case-insensitive twin](items/find-window-the-viewer-next-previous-file-takes-the-first/desc.md) | bug | 3 | panels-ui | measure:261 | 2026-10-20 |
| [Focusing an archive member with a very long name shows "Expanded string is too large." twice](items/focusing-an-archive-member-with-a-very-long-name-shows/desc.md) | bug | 4 | panels-ui | measure:260 | 2026-10-20 |
| [FTP: a path whose escaped form does not fit MAX_PATH is left half-escaped](items/ftp-escaped-path-does-not-fit-decision/desc.md) | decision | 2 | ftp | manual | 2026-10-20 |
| [FTP: download and upload refuse local paths and names over 259 bytes](items/ftp-local-long-paths/desc.md) | improvement | 3 | ftp | manual | 2026-10-20 |
| [FTP: a mask ? takes two code-page bytes of a legacy server as one letter](items/ftp-mask-letters-by-server-encoding/desc.md) | bug | 2 | ftp | manual | 2026-10-20 |
| [FTP: a PWD reply or a created folder path that does not fit is cut and used](items/ftp-pwd-and-created-path-cut/desc.md) | bug | 4 | ftp | manual | 2026-10-20 |
| [FTP: a file name with an unpaired surrogate comes back garbled from a UTF-8 server; re-upload may overwrite](items/ftp-wtf8-name-listing-round-trip/desc.md) | bug | 7 | ftp | review:255 | 2026-10-20 |
| [Menu bar hot keys typed after F10 arrive as code-page bytes](items/menubar-loop-wide-mnemonics/desc.md) | bug | 3 | panels-ui | measure:256 | 2026-10-20 |
| [Shell extensions in the panel background menu and the Find window never answer typed hot keys](items/menuchar-owner-routing/desc.md) | bug | 2 | panels-ui | review:256 | 2026-10-20 |
| [Multimedia Viewer: the "cannot open" message shows a non-ASCII file name as mojibake](items/mmviewer-open-error-name-mojibake/desc.md) | bug | 1 | other-plugins | measure:255 | 2026-10-20 |
| [More typed fields cut to their buffer: masks, filter, volume label, hot path label edit](items/more-typed-fields-cut-to-their-buffer-masks-filter-volume/desc.md) | bug | 6 | long-paths | leftover:251 | 2026-10-20 |
| [Paste and drop of our own files keep a code-page fallback for a name on low memory](items/paste-and-drop-of-our-own-files-keep-a-code-page-fallback/desc.md) | bug | 3 | encoding | review:259 | 2026-10-20 |
| [Paste of a case twin from an archive and SFTP twins by hand (252)](items/paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand/desc.md) | person-step | 5 | archives | leftover:252 | 2026-10-20 |
| [Paste of a long name into its own folder: check the copy name and the too long question](items/paste-of-a-long-name-into-its-own-folder-check-the-copy-name/desc.md) | person-step | 5 | long-paths | leftover:259 | 2026-10-20 |
| [The build runs the plug-in encoding scan strictly for the shipped plug-ins](items/plugin-encoding-scan-strict-in-build/desc.md) | tech-debt | 2 | tooling | leftover:255 | 2026-10-20 |
| [Popup menu hot keys by hand: Russian layout, DBCS and UTF-8 systems, TortoiseSVN](items/popup-hot-keys-real-keyboard-256/desc.md) | person-step | 3 | panels-ui | leftover:256 | 2026-10-20 |
| [Registry Editor Find: confirm quoted hex letters with a UTF-8 code page](items/regedit-find-hex-utf8-code-page-check-257/desc.md) | person-step | 3 | other-plugins | leftover:257 | 2026-10-20 |
| [Registry Editor Find: regexp misses text past the code-page length of a value](items/regedit-find-regexp-multibyte-code-page-buffer/desc.md) | bug | 4 | other-plugins | review:257 | 2026-10-20 |
| [Registry Editor Find: Whole words ignores punctuation that the help names](items/regedit-find-whole-words-punctuation/desc.md) | bug | 2 | other-plugins | measure:257 | 2026-10-20 |
| [Renamer: the preview shows a name with an unpaired surrogate as mojibake](items/renamer-wtf8-names-shown-as-mojibake/desc.md) | bug | 2 | other-plugins | measure:255 | 2026-10-20 |
| [Settings import ends the highlighting list at a damaged entry](items/settings-import-ends-the-highlighting-list-at-a-damaged/desc.md) | bug | 3 | panels-ui | measure:250 | 2026-10-20 |
| [SFTP: a Copy posted right after a failed upload and its reconnect may open nothing](items/sftp-a-copy-posted-right-after-a-failed-upload-and-its/desc.md) | bug | 3 | sftp | measure:258 | 2026-10-20 |
| [SFTP: a folder uploaded again into an upload-only folder fails with Cannot create directory](items/sftp-a-folder-uploaded-again-into-an-upload-only-folder/desc.md) | bug | 4 | sftp | leftover:258 | 2026-10-20 |
| [SFTP drop folder on a real upload-only service and an ACL on a replaced file (258)](items/sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on/desc.md) | person-step | 4 | sftp | leftover:258 | 2026-10-20 |
| [Turkish / Azeri locale: index.html and INDEX.HTML never compare as one name](items/turkish-azeri-locale-index-html-and-index-html-never-compare/desc.md) | bug | 2 | panels-ui | leftover:261 | 2026-10-20 |
| [ISO plug-in: HFS+ names with an unpaired surrogate are changed to U+FFFD](items/uniso-hfs-names-lossy-surrogates/desc.md) | bug | 2 | archives | measure:255 | 2026-10-20 |
| [ISO plug-in: a Joliet file name with an unpaired surrogate is garbled, other letters too](items/uniso-joliet-file-names-wtf8-garbled/desc.md) | bug | 3 | archives | review:255 | 2026-10-20 |
| [UnMIME: the extraction progress title shows a non-ASCII mail file name as mojibake](items/unmime-progress-title-name-mojibake/desc.md) | bug | 1 | other-plugins | measure:255 | 2026-10-20 |
| [unrar plug-in: a member name over 259 bytes overflows a stack buffer on F3 / F4](items/unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack/desc.md) | bug | 7 | archives | review:260 | 2026-10-20 |
| [User Menu errors name the command, not the file or folder at fault](items/user-menu-errors-name-the-file-or-folder/desc.md) | bug | 3 | panels-ui | manual | 2026-10-20 |
| [A hidden User Menu batch that stops at its chcp or cd line tells nobody](items/user-menu-hidden-batch-silent-early-end/desc.md) | bug | 3 | panels-ui | manual | 2026-10-20 |
| [User Menu on items in folders of 260 or more bytes: work, or refuse aloud](items/user-menu-long-paths/desc.md) | bug | 4 | long-paths | manual | 2026-10-20 |
| [User Menu: a shortcut command may start in the item folder, not its own Start in](items/user-menu-shortcut-start-in-folder/desc.md) | bug | 3 | panels-ui | manual | 2026-10-20 |

## Parked

| Item | Area | Reason |
|---|---|---|
| [Two @GMT snapshot folders joined by a junction could hide a folder alias](items/gmt-snapshot-folders-joined-by-junction-alias/desc.md) | data-safety | reasoned in feature 107's re-check, not reproducible without snapshots (agent sessions have no admin rights to create them) |
| [Encoding: the sites feature 069 deliberately did not convert](items/encoding-sites-069-chose-not-to-convert/desc.md) | encoding | deliberately not on the list (069 §2): each site waits for its own condition for re-opening, stated in the item (a facade migration, the copy-hook change, a shell-boundary pass, a viewer-title pass, a new string); not a rejection |
| [Help pages still carry the 2023 Open Salamander footer](items/help-pages-carry-2023-open-salamander-footer/desc.md) | help-docs | recorded in NEXT-WORK as deliberately not on the list: cosmetic, a single mechanical pass whenever it is wanted. |
| [A program started from the panel fails, from Explorer works (not reproduced)](items/command-shell-environment-not-reproduced/desc.md) | panels-ui | parked as not reproduced (decision of 2026-08-31, `specs/073-fix-cmdshell-env/spec.md` Clarifications); no product change until `evidence/capture.cmd` captures a live occurrence. |
| [SFTP: a stopped listing shows as the directory; an empty NAME ends it](items/sftp-listing-end-ambiguities/desc.md) | sftp | Kept by feature 133: a listing stopped by the user is shown as the directory (old behaviour, kept); an empty name or NAME packet cannot be told apart from the end through `libssh2_sftp_readdir_ex`. |

## Rejected

| Item | Area | Reason |
|---|---|---|
| [7-Zip: an archive that mixes the two password forms stays mixed](items/7zip-mixed-password-forms-stay-mixed/desc.md) | archives | feature 093, listed under NEXT-WORK §C Decided - not to do: the plug-in cannot re-encrypt, so an archive holding items under both password forms stays mixed. |
| [ZIP: the archive comment and the self-extractor stay code page](items/zip-comment-and-sfx-stay-code-page/desc.md) | archives | features 094 (2026-10-02) and 104/121, listed under NEXT-WORK §C Decided - not to do: the ZIP comment is code page by format; the self-extractor routes and the SFX password prompt stay code page because no SFX package is shipped (the routes are unreachable). |
| [Copying a folder into itself or its own subfolder makes a snapshot copy](items/folder-copy-into-itself-makes-snapshot/desc.md) | data-safety | feature 107, 2026-10-04: recorded under Decisions recorded (spec.md) in specs/107-folder-alias-move/fix-log.md L142-145 and listed under NEXT-WORK §C Decided - not to do: a folder COPY into itself or its own subfolder stays a snapshot copy (by name and through an alias alike, as before); nothing is lost, the script is built before anything is written - only Move into itself is refused. |
| [Same-file checks on file systems without file ids stay approximate](items/identity-limits-without-file-ids/desc.md) | data-safety | features 103 (2026-10-03) and 107 (2026-10-04), listed under NEXT-WORK §C Decided - not to do: where the file system gives no ids, identity is judged by size and times; each limit is recorded with its reason (e.g. a local folder vs. its WebDAV path kept as two file systems to avoid refusing uploads to WebDAV). |
| [B-2: panel sort, archive listings and plug-in services keep the old comparison](items/b2-systemic-name-comparison-not-implemented/desc.md) | encoding | maintainer 2026-10-04: the remaining B-2 systemic work is not implemented - it changes what users see (panel order, archive and plug-in listings) or what plug-ins get, with the highest regression risk for a mostly theoretical gain; every identity decision that could lose data was converted (092) and the losses found since were fixed one by one (103, 107-110, 112, 113, 115, 117, 119). Re-open only with a concrete wrong-file or lost-data scenario. |
| [FTP: user name, address and initial path keep their buffers (refused, never cut)](items/ftp-user-address-path-not-widened/desc.md) | ftp | feature 116, 2026-10-05 (listed under NEXT-WORK §C Decided - not to do): user name, address and initial path are not widened - they are parts of the plug-in's paths; 104's refusal ("too long", the dialog stays open, the stored value stays) remains, nothing is cut. |
| [Long paths: the remaining 259- and 519-byte limits are kept](items/259-byte-limits-kept/desc.md) | long-paths | decided by features 097 (2026-10-03) and 101, listed under NEXT-WORK §C Decided - not to do: the limits sit at interfaces the program does not own or that are shared - external archivers, the plug-in interface of plug-ins older than 107, the listing structure shared with plug-ins, the layout shared between instances; a longer value is refused, never cut. Reasons in `specs/097-archive-long-path/fix-log.md` and `specs/101-small-leftovers/fix-log.md`. |
| [Checksum: an OEM-encoded list's accented names stay "missing"](items/checksum-oem-lists-not-guessed/desc.md) | other-plugins | feature 117 (research E2), listed under NEXT-WORK §C Decided - not to do: OEM is never guessed - no signal tells an OEM list from a code-page list, so a guess would mis-read correct lists. |
| [A plug-in's Save dialog may open the program's last folder, not the panel's](items/save-dialogs-initial-folder-left-to-windows/desc.md) | other-plugins | feature 121, 2026-10-06 (listed under NEXT-WORK §C Decided - not to do): measured as Windows' per-program first-folder rule, by design; putting the folder into `lpstrFile` did not change it; only `IFileDialog::SetFolder` would - a change of API, a feature of its own if wanted. The 121 change was reverted. |
| [PictView: the GIF comment stays ASCII or UTF-8](items/pictview-gif-comment-stays-ascii-or-utf8/desc.md) | pictview | feature 120, 2026-10-06 (listed under NEXT-WORK §C Decided - not to do): GIF89a defines the comment extension as 7-bit ASCII and has no Unicode alternative; the comment stays ASCII or UTF-8. |
| [Closing for an update: four limitations accepted by feature 080](items/update-close-accepted-limitations-of-080/desc.md) | plugin-api | Accepted as known limitations by feature 080 (REMAINING-WORK.md P3, 2026-09-20): each needs an extreme case (a plug-in `Release()` hanging for half a minute), is what a forced close asks for, concerns only the first update from 0.1.7, or is the single `WM_CLOSE` the Restart Manager itself sends. Re-open only with a new reason. |
| [Installer update close: some plug-in windows and every dialog still decline](items/update-close-declining-windows-kept/desc.md) | plugin-api | features 118 and 121, 2026-10-06 (listed under NEXT-WORK §C Decided - not to do): a window that holds something the user would lose declines - the Batch Renamer always (masks, Undo), a Checksum Calculate window until every calculated type is saved; dialogs and message boxes always decline, including FTP's Logs / Welcome *Save* dialogs. |
| [SFTP: a password typed in sftp:user:password@host is not split off](items/sftp-address-password-not-split/desc.md) | sftp | feature 085 (research R1), listed under NEXT-WORK §C Decided - not to do: recorded, not changed - unreachable in practice, because the server rejects such a user name, the session never lists and the path is never recorded; the typed text itself is covered by the history sinks 085 fixed. |

## Legend

The first column of each table is the allowed value; the tool reads the
vocabularies from here. Adding a value = adding a row.

### Types

| Value | Meaning |
|---|---|
| `bug` | the program does something wrong |
| `feature` | a new capability |
| `improvement` | an existing capability made better |
| `tech-debt` | internal work with no direct user-visible change |
| `decision` | a question only the maintainer can answer |
| `person-step` | a check or action that needs a person (real keyboard, clipboard, hardware, a server, a release step) |

### Statuses

| Value | Meaning | Section |
|---|---|---|
| `new` | recorded, not triaged | Inbox |
| `open` | triaged, waiting for work | Next / Decisions / Person steps |
| `blocked` | triaged, cannot proceed now — `reason` says why | Next / Decisions / Person steps |
| `in-progress` | a feature is being implemented — `feature` says which | In progress |
| `parked` | deliberately not now — `reason` says why | Parked |
| `rejected` | decided not to do — re-open only with a new reason | Rejected |

A finished item is removed (git, `specs/FEATURE-HISTORY.md` and the
feature's spec keep the record); there is no `done` status.

### Severity

| Value | Meaning |
|---|---|
| `9`–`10` | data loss or a crash in a common scenario |
| `7`–`8` | data loss in a narrow scenario, or a crash in an unusual one |
| `4`–`6` | a function does not work; a workaround exists |
| `1`–`3` | cosmetic or wording |
| `0` | trivial |

For features and improvements the number expresses importance on the same
scale.

### Areas

| Value | Meaning |
|---|---|
| `build-release` | build, signing, installer, winget, CI, releases |
| `translations` | translation pipeline, language files, layout of translated dialogs |
| `encoding` | UTF-8 / WTF-8 contracts, code-page residue, text in controls and titles |
| `long-paths` | long paths and names, buffers, refusals instead of cuts |
| `file-ops` | copy, move, delete, rename, attributes in the core |
| `data-safety` | same-file guards, safe replace, links — anything that can lose data |
| `panels-ui` | panels, menus, dialogs, keyboard, command line of the core |
| `viewer` | the built-in viewer and the Code / Markdown viewers' core side |
| `archives` | archives in the core, the disk cache, external archivers, ZIP and 7-Zip plug-ins |
| `plugin-api` | the plug-in interface, loading, closing for an update |
| `webview` | the shared WebView2 host |
| `privacy-security` | network communication, credentials, `PRIVACY.md` claims |
| `ftp` | the FTP plug-in |
| `sftp` | the SFTP plug-in |
| `pictview` | the PictView plug-in |
| `other-plugins` | every other plug-in (Registry Editor, Renamer, Undelete, Disk Map, Checksum, …) |
| `help-docs` | the manual, README, architecture and project documents |
| `tooling` | probes, checkers, scripts, the backlog itself |

### Sources

| Value | Meaning |
|---|---|
| `manual` | added by hand |
| `github#N` | GitHub issue N (`issue.md` holds its text) |
| `review:NNN` | found by a review of feature NNN |
| `leftover:NNN` | left open by feature NNN |
| `measure:NNN` | found by measuring during feature NNN |
| `probe:NNN` | found by a probe of feature NNN |
| `next-work` | migrated from `specs/NEXT-WORK.md` with no identifiable origin |

### Who

| Value | Meaning |
|---|---|
| `agent` | an agent can do it alone |
| `person` | needs a person |
| `both` | an agent does most of it; a person finishes or checks |

### Effort

| Value | Meaning |
|---|---|
| `S` | hours |
| `M` | about a day |
| `L` | several days or a feature series |
| `?` | unknown |
