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

Last triaged: 2026-10-23

## In progress

| # | Item | Type | Sev | Area | Feature |
|---|---|---|---|---|---|
| 1 | [ISO plug-in: Joliet and ISO 9660 names are not made safe before extraction](items/iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe/desc.md) | bug | 7 | archives | 327 |

## Next

| # | Item | Type | Sev | Area | Who | Effort | Status |
|---|---|---|---|---|---|---|---|
| 1 | [ISO plug-in: an entry the listing refuses ends the listing with Error, a folder lost](items/iso-plug-in-an-entry-the-listing-refuses-ends-the-listing/desc.md) | bug | 6 | archives | agent | M | open |
| 2 | [Drive Information turns a volume label outside the code page into question marks](items/drive-information-turns-a-volume-label-outside-the-code-page/desc.md) | bug | 5 | encoding | both | ? | blocked |
| 3 | [FTP: an upload to a server named another way (localhost vs 127.0.0.1) misses the panel changes](items/ftp-an-upload-to-a-server-named-another-way-localhost-vs-127/desc.md) | bug | 5 | ftp | agent | S | open |
| 4 | [Read the 78 findings of check_encoding.py --plugins one by one](items/check-encoding-plugin-findings/desc.md) | tech-debt | 4 | encoding | agent | L | open |
| 5 | [A path typed in another case into an archive with case twins elsewhere opens its root](items/a-path-typed-in-another-case-into-an-archive-with-case-twins/desc.md) | bug | 4 | archives | agent | S | open |
| 6 | [Copying into an archive folder typed in another case packs into a new folder beside it](items/copying-into-an-archive-folder-typed-in-another-case-packs/desc.md) | bug | 4 | archives | agent | S | open |
| 7 | [FTP: a name a listing rule extends (z/VM, AS/400, VxWorks) mixes UTF-8 with raw server bytes](items/ftp-listing-rule-joins-utf8-with-raw-bytes/desc.md) | bug | 4 | ftp | agent | S | open |
| 8 | [FTP: server folder names compared by the code-page case rule on UTF-8 bytes](items/ftp-server-path-compare-code-page-fold/desc.md) | bug | 4 | ftp | agent | M | open |
| 9 | [My Documents drive opens a cut path when Documents needs more than 259 bytes](items/my-documents-drive-opens-a-cut-path-when-documents-needs/desc.md) | bug | 4 | long-paths | agent | S | open |
| 10 | [Registry Editor View of a text value: cut text and a stray byte on a UTF-8 code page](items/registry-editor-view-of-a-text-value-cut-text-and-a-stray/desc.md) | bug | 4 | other-plugins | both | S | open |
| 11 | [Renamer: Include subdirectories descends into junctions and folder links](items/renamer-include-subdirectories-descends-into-junctions-and/desc.md) | bug | 4 | data-safety | agent | M | open |
| 12 | [User Menu compare names and the Change Icon file are cut to 259 bytes](items/user-menu-compare-names-and-the-change-icon-file-are-cut-to/desc.md) | bug | 4 | long-paths | agent | S | open |
| 13 | [Registry Editor: Move from HKCR into the user's Classes key does nothing](items/registry-editor-move-from-hkcr-to-user-classes-does-nothing/desc.md) | bug | 4 | other-plugins | agent | S | open |
| 14 | [Registry Editor: Copy or Find through a link to an ancestor walks in a loop](items/registry-editor-copy-or-find-through-a-link-to-an-ancestor/desc.md) | bug | 4 | other-plugins | agent | M | open |
| 15 | [Filter dialog cuts a long panel filter to 259 bytes after a refused edit](items/filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a/desc.md) | bug | 4 | long-paths | agent | S | open |
| 16 | [A cpio or rpm archive with a member name the panel cannot hold fails as a whole](items/a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot/desc.md) | bug | 4 | archives | agent | S | open |
| 17 | [A tar member whose name contains .. is extracted into a wrong folder](items/tar-member-name-with-dotdot-extracted-into-wrong-folder/desc.md) | bug | 4 | archives | agent | S | open |
| 18 | [Hex mode in Find turns quoted letters outside the code page into question marks](items/hex-mode-in-find-turns-quoted-letters-outside-the-code-page/desc.md) | bug | 4 | encoding | agent | S | open |
| 19 | [Viewer Find pre-fills a non-ASCII selection as code-page text](items/viewer-find-pre-fills-a-non-ascii-selection-as-code-page/desc.md) | bug | 4 | encoding | agent | S | open |
| 20 | [ZIP cannot update an archive reached through a symbolic link](items/zip-cannot-update-an-archive-reached-through-a-symbolic-link/desc.md) | bug | 4 | archives | agent | M | open |
| 21 | [Renamer: a new name is capped at 259 bytes; a subfolder item refused at 260](items/renamer-long-new-name-limits/desc.md) | bug | 3 | long-paths | agent | M | open |
| 22 | [winget: offer a per-user install (--scope user), proven in Windows Sandbox first](items/winget-per-user-scope-entry/desc.md) | improvement | 3 | build-release | both | M | blocked |
| 23 | [winget manifest fixes (072 audit): DisplayName, ProductCode; PrivacyUrl check](items/winget-manifest-fixes-from-072-audit/desc.md) | bug | 3 | build-release | agent | S | open |
| 24 | [PictView Update Thumbnail: file time, hard links, per-file box, orientation](items/pictview-update-thumbnail-142-leftovers/desc.md) | improvement | 3 | pictview | agent | M | open |
| 25 | [Quick search: first keystroke over 100,000 non-ASCII names takes about 335 ms](items/quick-search-first-keystroke-over-100-000-non-ascii-names/desc.md) | improvement | 3 | panels-ui | agent | M | open |
| 26 | [translate.merge keeps a stale machine translation when the English text changes](items/translate-merge-keeps-a-stale-machine-translation-when-the/desc.md) | bug | 3 | translations | agent | S | open |
| 27 | [Desktop view (Folders plug-in) repeats its shell columns after a view-mode switch](items/desktop-view-folders-plug-in-repeats-its-shell-columns-after/desc.md) | bug | 3 | other-plugins | agent | S | open |
| 28 | [A refused configuration file does not say which key is outside the program root](items/a-refused-configuration-file-does-not-say-which-key-is/desc.md) | improvement | 3 | panels-ui | agent | S | open |
| 29 | [Code Viewer: no Auto-Select of the code page and no explicit Set as default](items/code-viewer-no-auto-select-of-the-code-page-and-no-explicit/desc.md) | improvement | 3 | other-plugins | both | M | open |
| 30 | [Compare Directories misses a case-only pair beside a soft-hyphen or NFD name](items/compare-directories-misses-a-case-only-pair-beside-a-soft/desc.md) | bug | 3 | panels-ui | agent | M | open |
| 31 | [Find window: the viewer next / previous file takes the first case-insensitive twin](items/find-window-the-viewer-next-previous-file-takes-the-first/desc.md) | bug | 3 | panels-ui | agent | S | open |
| 32 | [FTP: download and upload refuse local paths and names over 259 bytes](items/ftp-local-long-paths/desc.md) | improvement | 3 | ftp | agent | L | open |
| 33 | [Logging in to an inaccessible UNC path with a non-ASCII share name uses code-page APIs](items/logging-in-to-an-inaccessible-unc-path-with-a-non-ascii/desc.md) | bug | 3 | encoding | agent | M | open |
| 34 | [Menu bar hot keys typed after F10 arrive as code-page bytes](items/menubar-loop-wide-mnemonics/desc.md) | bug | 3 | panels-ui | agent | S | open |
| 35 | [Paste and drop of our own files keep a code-page fallback for a name on low memory](items/paste-and-drop-of-our-own-files-keep-a-code-page-fallback/desc.md) | bug | 3 | encoding | agent | S | open |
| 36 | [Settings import ends the highlighting list at a damaged entry](items/settings-import-ends-the-highlighting-list-at-a-damaged/desc.md) | bug | 3 | panels-ui | agent | S | open |
| 37 | [SFTP: a Copy posted right after a failed upload and its reconnect may open nothing](items/sftp-a-copy-posted-right-after-a-failed-upload-and-its/desc.md) | bug | 3 | sftp | agent | ? | open |
| 38 | [ISO plug-in: a Joliet file name with an unpaired surrogate is garbled, other letters too](items/uniso-joliet-file-names-wtf8-garbled/desc.md) | bug | 3 | archives | agent | S | open |
| 39 | [User Menu errors name the command, not the file or folder at fault](items/user-menu-errors-name-the-file-or-folder/desc.md) | bug | 3 | panels-ui | agent | M | open |
| 40 | [A hidden User Menu batch that stops at its chcp or cd line tells nobody](items/user-menu-hidden-batch-silent-early-end/desc.md) | bug | 3 | panels-ui | agent | M | open |
| 41 | [User Menu: a shortcut command may start in the item folder, not its own Start in](items/user-menu-shortcut-start-in-folder/desc.md) | bug | 3 | panels-ui | agent | S | open |
| 42 | [Settings import ends the viewers, editors and User Menu lists at a damaged entry](items/settings-import-ends-the-viewers-editors-and-user-menu-lists/desc.md) | bug | 3 | panels-ui | agent | S | open |
| 43 | [Archive Update: an archive rewritten with its old size and time is not checked again](items/archive-update-archive-same-stamp/desc.md) | bug | 3 | archives | agent | S | open |
| 44 | [Archive Update: Copy Selected To refuses an edited member whose target path is over 259 units](items/archive-update-copy-selected-to-refuses-long-targets/desc.md) | improvement | 3 | long-paths | agent | S | open |
| 45 | [The left-aside message names only the salNNN entry, not the entry it was](items/left-aside-message-names-the-entry/desc.md) | improvement | 3 | file-ops | agent | S | open |
| 46 | [A rename via a temporary name can leave the source there silently after a cancel](items/rename-via-temp-left-silently/desc.md) | bug | 3 | file-ops | agent | S | open |
| 47 | [Screen readers get garbled names from the core path labels (CStaticText)](items/screen-readers-get-garbled-names-from-the-core-path-labels/desc.md) | bug | 3 | encoding | both | M | open |
| 48 | [SFTP: run about 1,500 connections to show the key-exchange failure gone](items/sftp-key-exchange-soak-1500-connections/desc.md) | tech-debt | 3 | sftp | agent | S | open |
| 49 | [SFTP: files open when a connection is lost stay allocated until exit](items/sftp-open-handles-of-lost-connection-leak/desc.md) | bug | 3 | sftp | agent | M | open |
| 50 | [SFTP: a stalled upload or a server disconnect leaks the whole session](items/sftp-session-leak-after-partial-send-or-disconnect/desc.md) | bug | 3 | sftp | agent | M | open |
| 51 | [SFTP: a server reply shorter than the protocol allows waits for the timeout](items/sftp-short-reply-waits-for-timeout/desc.md) | bug | 3 | sftp | agent | M | open |
| 52 | [Clipped labels in the Czech translation (74)](items/translations-clipped-labels-cs/desc.md) | bug | 3 | translations | both | M | open |
| 53 | [Clipped labels in the German translation (98)](items/translations-clipped-labels-de/desc.md) | bug | 3 | translations | both | M | open |
| 54 | [Clipped labels in the Spanish translation (89)](items/translations-clipped-labels-es/desc.md) | bug | 3 | translations | both | M | open |
| 55 | [Clipped labels in the French translation (159)](items/translations-clipped-labels-fr/desc.md) | bug | 3 | translations | both | L | open |
| 56 | [Clipped labels in the Hungarian translation (45)](items/translations-clipped-labels-hu/desc.md) | bug | 3 | translations | both | M | open |
| 57 | [Clipped labels in the Dutch translation (78)](items/translations-clipped-labels-nl/desc.md) | bug | 3 | translations | both | M | open |
| 58 | [Clipped labels in the Romanian translation (74)](items/translations-clipped-labels-ro/desc.md) | bug | 3 | translations | both | M | open |
| 59 | [Clipped labels in the Slovak translation (85)](items/translations-clipped-labels-sk/desc.md) | bug | 3 | translations | both | M | open |
| 60 | [Markdown Viewer: a scheme, width or View Source change shows the document from the top](items/markdown-viewer-a-scheme-width-or-view-source-change-shows/desc.md) | improvement | 3 | other-plugins | both | M | open |
| 61 | [ZIP does not say the temporary file is the only copy when the archive vanished](items/zip-does-not-say-the-temporary-file-is-the-only-copy/desc.md) | bug | 3 | archives | agent | S | open |
| 62 | [ISO plug-in: a valid xorriso ISO + HFS+ hybrid opens with Cannot read sector 00000020](items/iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot/desc.md) | bug | 3 | other-plugins | agent | S | open |
| 63 | [The core reads volume names with the code-page API on UTF-8 paths](items/the-core-reads-volume-names-with-the-code-page-api-on-utf-8/desc.md) | bug | 3 | encoding | agent | S | open |
| 64 | [Tar unpack skips FIFO and device members without a word](items/tar-unpack-skips-fifo-and-device-members-without-a-word/desc.md) | bug | 3 | archives | agent | S | open |
| 65 | [SDK: state that GetErrorText returns UTF-8 (B-3 contract half)](items/geterrortext-utf8-contract/desc.md) | tech-debt | 2 | plugin-api | agent | S | open |
| 66 | [GetSHObjectName converts through CP_ACP and cuts at MAX_PATH (server links)](items/getshobjectname-code-page-cut-server-links/desc.md) | bug | 2 | encoding | agent | S | open |
| 67 | [Unpack short-name walk: process-wide root; external archiver's unpack not driven](items/unpack-root-process-wide-latent/desc.md) | tech-debt | 2 | archives | agent | M | open |
| 68 | [The 092 name comparator reads both names to their ends (2x-16x slower sorts)](items/name-comparator-reads-whole-names/desc.md) | tech-debt | 2 | encoding | agent | M | open |
| 69 | [Translation merge keys by bundle ordinal; removing a bundle needs a re-key](items/translate-merge-bundle-rekey/desc.md) | tech-debt | 2 | translations | agent | M | open |
| 70 | [Bug report's module line from an install folder outside the code page](items/bug-report-module-line-install-path/desc.md) | bug | 2 | encoding | agent | S | open |
| 71 | [Mixed-template guard: no reverse rule, sinks found by variable names](items/mixed-template-guard-reverse-rule/desc.md) | tech-debt | 2 | tooling | agent | S | open |
| 72 | [PE Viewer: version-resource names printed with a narrow %ls (suspected)](items/peviewer-version-names-narrow-ls/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 73 | [FTP: server reply cut inside a character; Logs window caret counts bytes](items/ftp-reply-cut-and-logs-caret-bytes/desc.md) | bug | 2 | ftp | agent | S | open |
| 74 | [SFTP: questions and reasons are untranslated English literals](items/sftp-english-literal-messages/desc.md) | tech-debt | 2 | sftp | agent | M | open |
| 75 | [User Menu through a shell: a UNC panel folder runs the command in C:\\Windows](items/user-menu-unc-folder-pushd/desc.md) | bug | 2 | panels-ui | agent | S | open |
| 76 | [Renamer: two error messages still append a stale system reason](items/renamer-stale-error-reasons/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 77 | [Plug-ins show a literal "%1" in Windows error texts that have inserts](items/plugins-error-text-literal-inserts/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 78 | [Message box shows a plug-in's code-page URL text as UTF-8](items/msgbox-plugin-url-text-code-page/desc.md) | bug | 2 | encoding | agent | S | open |
| 79 | [7-Zip: two-form password passes in Test, F3 view, Delete and Cancel not driven](items/7zip-two-form-password-passes-not-driven/desc.md) | tech-debt | 2 | archives | agent | M | open |
| 80 | [CI: ilammy/msvc-dev-cmd@v1 is a Node 20 action with no Node 24 release](items/ci-msvc-dev-cmd-action-has-no-node-24-release/desc.md) | tech-debt | 2 | build-release | both | S | open |
| 81 | [Stale winget claims in project records and publish.ps1 order (072 audit)](items/winget-records-stale-claims-from-072-audit/desc.md) | tech-debt | 2 | build-release | agent | S | open |
| 82 | [Archive operations through a re-pointed name: four gaps recorded by 145 / 146](items/archive-ops-repointed-name-recorded-gaps/desc.md) | bug | 2 | archives | agent | M | open |
| 83 | [A history entry with invalid text hides the entries saved after it](items/a-history-entry-with-invalid-text-hides-the-entries-saved/desc.md) | bug | 2 | encoding | agent | S | open |
| 84 | [Quick search keys skip canonical reordering of combining marks](items/quick-search-keys-skip-canonical-reordering-of-combining/desc.md) | bug | 2 | encoding | agent | S | open |
| 85 | [Remove the dormant start-up import of older Open Salamander configurations](items/remove-the-dormant-start-up-import-of-older-open-salamander/desc.md) | tech-debt | 2 | data-safety | agent | M | open |
| 86 | [Unpack refused at a link names a temporary folder, not the archive folder](items/unpack-refused-at-a-link-names-a-temporary-folder-not-the/desc.md) | improvement | 2 | archives | agent | S | open |
| 87 | [The encoding guard does not read header files; plug-in headers convert names leniently](items/check-encoding-skips-header-files/desc.md) | tech-debt | 2 | tooling | agent | M | open |
| 88 | [Command line: a COMSPEC path outside ASCII is read through the code page](items/command-line-comspec-read-wide/desc.md) | bug | 2 | encoding | agent | S | open |
| 89 | [Ctrl+X ghosts a name in the other panel that shows a case twin folder](items/ctrl-x-ghosts-a-name-in-the-other-panel-that-shows-a-case/desc.md) | bug | 2 | panels-ui | agent | S | open |
| 90 | [DB Viewer: a field length of 1000 or more shows a broken thousands separator](items/dbviewer-field-length-separator/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 91 | [File Comparator hex recompare: error box from the released sibling view](items/file-comparator-hex-recompare-error-box-from-the-released/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 92 | [FTP: a mask ? takes two code-page bytes of a legacy server as one letter](items/ftp-mask-letters-by-server-encoding/desc.md) | bug | 2 | ftp | agent | S | open |
| 93 | [Shell extensions in the panel background menu and the Find window never answer typed hot keys](items/menuchar-owner-routing/desc.md) | bug | 2 | panels-ui | agent | S | open |
| 94 | [PictView: no Exif command and no automatic turn for TIFF and camera raw files](items/pictview-no-exif-command-and-no-automatic-turn-for-tiff-and/desc.md) | improvement | 2 | pictview | agent | M | open |
| 95 | [The build runs the plug-in encoding scan strictly for the shipped plug-ins](items/plugin-encoding-scan-strict-in-build/desc.md) | tech-debt | 2 | tooling | agent | S | open |
| 96 | [Registry Editor Find: Whole words ignores punctuation that the help names](items/regedit-find-whole-words-punctuation/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 97 | [Renamer: the preview shows a name with an unpaired surrogate as mojibake](items/renamer-wtf8-names-shown-as-mojibake/desc.md) | bug | 2 | other-plugins | agent | S | open |
| 98 | [Turkish / Azeri locale: index.html and INDEX.HTML never compare as one name](items/turkish-azeri-locale-index-html-and-index-html-never-compare/desc.md) | bug | 2 | panels-ui | agent | ? | open |
| 99 | [ISO plug-in: HFS+ names with an unpaired surrogate are changed to U+FFFD](items/uniso-hfs-names-lossy-surrogates/desc.md) | bug | 2 | archives | agent | S | open |
| 100 | [The User Menu page names a new submenu end in the code page, not UTF-8](items/the-user-menu-page-names-a-new-submenu-end-in-the-code-page/desc.md) | bug | 2 | encoding | agent | S | open |
| 101 | [Refreshing a changed archive with edited files lists it twice](items/archive-refresh-lists-changed-archive-twice/desc.md) | improvement | 2 | archives | agent | M | open |
| 102 | [Archive Update: a time-zone or daylight-saving change marks an unchanged member](items/archive-update-time-zone-change-mark/desc.md) | bug | 2 | archives | both | S | open |
| 103 | [Renamer: the New name field holds only 519 bytes of a typed pattern](items/renamer-the-new-name-field-holds-only-519-bytes-of-a-typed/desc.md) | improvement | 2 | long-paths | agent | S | open |
| 104 | [SFTP: a folder uploaded again whose files are all there ends with a misleading folder box](items/sftp-a-folder-uploaded-again-whose-files-are-all-there-ends/desc.md) | improvement | 2 | sftp | agent | S | open |
| 105 | [The question whether to create a missing folder cuts a long path inside a letter](items/the-question-whether-to-create-a-missing-folder-cuts-a-long/desc.md) | bug | 2 | long-paths | agent | S | open |
| 106 | [User Menu list commands refused when the first selected item does not fit 259 bytes](items/user-menu-list-commands-refused-when-the-first-selected-item/desc.md) | improvement | 2 | long-paths | agent | M | open |
| 107 | [The manual has no page for the Markdown Viewer](items/the-manual-has-no-page-for-the-markdown-viewer/desc.md) | improvement | 2 | help-docs | agent | S | open |
| 108 | [106's packself probe row A-zip-noask-refused is stale since 119](items/packself-probe-stale-row/desc.md) | tech-debt | 1 | tooling | agent | S | open |
| 109 | [Plug-in threads ended by CThreadQueue leave their CCallStack registered](items/plugin-thread-kills-leave-callstack/desc.md) | tech-debt | 1 | plugin-api | agent | M | open |
| 110 | [Code Viewer: its known limitations are not stated anywhere a user can read](items/codeview-limitations-not-stated-for-users/desc.md) | improvement | 1 | help-docs | agent | S | open |
| 111 | [File Comparator stores an uninitialised byte in its saved configuration](items/filecomp-stores-uninitialised-configuration-byte/desc.md) | bug | 1 | other-plugins | agent | S | open |
| 112 | [CLAUDE.md names a branch ai-main that does not exist](items/claude-md-names-missing-ai-main-branch/desc.md) | tech-debt | 1 | help-docs | both | S | open |
| 113 | [Unshipped resources still carry 2023 Open Salamander-only copyright notices](items/unshipped-resources-still-carry-2023-open-salamander-only/desc.md) | tech-debt | 1 | build-release | agent | S | open |
| 114 | [winget README names a publish.ps1 check that does not exist](items/winget-readme-names-a-publish-ps1-check-that-does-not-exist/desc.md) | tech-debt | 1 | build-release | agent | S | open |
| 115 | [The stored main window icon index is checked against the count, not the last index](items/the-stored-main-window-icon-index-is-checked-against-the/desc.md) | bug | 1 | panels-ui | agent | S | open |
| 116 | [Plug-in interface does not say that column names are code-page text](items/plug-in-interface-does-not-say-that-column-names-are-code/desc.md) | tech-debt | 1 | plugin-api | agent | S | open |
| 117 | [Loop tool tests leave a temporary git folder behind on every test](items/loop-tool-tests-leave-a-temporary-git-folder-behind-on-every/desc.md) | tech-debt | 1 | tooling | agent | S | open |
| 118 | [The 081 Markdown Viewer probe takes a window with an empty title for the viewer](items/the-081-markdown-viewer-probe-takes-a-window-with-an-empty/desc.md) | tech-debt | 1 | tooling | agent | S | open |

## Decisions for the maintainer

| # | Item | Sev | Area | Status |
|---|---|---|---|---|
| 1 | [winget: re-point the open PR #426090 to the current release (072 audit)?](items/winget-repoint-pr-426090-decision/desc.md) | 4 | build-release | open |
| 2 | [Frozen code-page plug-in services: add wide/UTF-8 variants or keep them (B-5)?](items/plugin-ansi-services-interface-decision/desc.md) | 3 | plugin-api | open |
| 3 | [Ship the Network plug-in (nethood) enabled?](items/decide-ship-network-plugin-nethood/desc.md) | 3 | other-plugins | open |
| 4 | [A .gz file whose stored name is too long for Windows: refuse it or use the archive name](items/a-gz-file-whose-stored-name-is-too-long-for-windows-refuse/desc.md) | 3 | archives | open |
| 5 | [Archive Update: how to tell a member rewritten with the same size and time](items/archive-update-same-stamp-member-decision/desc.md) | 3 | archives | open |
| 6 | [FTP: should the plug-in ask a server whether it speaks UTF-8 (FEAT)?](items/ftp-ask-server-utf8-feat-decision/desc.md) | 3 | ftp | open |
| 7 | [State a deliberate minimum Windows version in the program and installer?](items/decide-windows-version-floor/desc.md) | 2 | build-release | open |
| 8 | [SFTP: a recursive Change Attributes gives one mode to files and folders alike](items/decide-sftp-recursive-change-attributes-modes/desc.md) | 5 | sftp | open |
| 9 | [PE Viewer: write the dump as UTF-8 with a BOM?](items/decide-peviewer-dump-utf8-with-bom/desc.md) | 2 | other-plugins | open |
| 10 | [checkver plug-in still checks Open Salamander's site: redirect it or drop it](items/checkver-update-channel-decision/desc.md) | 2 | other-plugins | open |
| 11 | [Forced Disk Map unload in a shell command: cancel the shell window or terminate](items/forced-disk-map-unload-in-a-shell-command-cancel-the-shell/desc.md) | 2 | other-plugins | open |
| 12 | [FTP: a path whose escaped form does not fit MAX_PATH is left half-escaped](items/ftp-escaped-path-does-not-fit-decision/desc.md) | 2 | ftp | open |
| 13 | [Should PRIVACY.md name the sign-in of the share list (285)?](items/should-privacy-md-name-the-sign-in-of-the-share-list-285/desc.md) | 2 | privacy-security | open |
| 14 | [Should the program come back after a reboot or sign-in (RESTART_NO_REBOOT)?](items/restart-after-reboot-or-sign-out/desc.md) | 1 | plugin-api | open |
| 15 | [Help > Contents ends in a Help Error box: the product ships no manual](items/help-contents-fails-no-manual-shipped/desc.md) | 4 | help-docs | open |
| 16 | [Is the missing shell copy hook (drag out of archives into Explorer) intended?](items/copy-hook-for-drag-out-of-archives/desc.md) | 3 | archives | open |

## Person steps

| # | Item | Area | Status |
|---|---|---|---|
| 1 | [Drag from a ZIP or SFTP panel during a quick search acts only on the dragged item](items/drag-from-a-zip-or-sftp-panel-during-a-quick-search-acts/desc.md) | data-safety | open |
| 2 | [Drag & drop and paste routes of 194, 228, 230, 240 by hand](items/drag-drop-paste-routes-194-228-230-240-by-hand/desc.md) | data-safety | open |
| 3 | [Editing long-named archive members: the rows the feature-260 probe could not drive](items/editing-long-named-archive-members-the-rows-the-feature-260/desc.md) | archives | open |
| 4 | [Registry Editor 292: elevated checks of Move through HKEY_CLASSES_ROOT](items/registry-editor-292-elevated-hkcr-checks/desc.md) | data-safety | open |
| 5 | [FTP 303 on real servers: an upload of B.txt beside b.txt asks first](items/ftp-303-on-real-servers-an-upload-of-b-txt-beside-b-txt-asks/desc.md) | ftp | open |
| 6 | [FTP 323 by hand: Send FTP Command during an open upload, then an upload asks before overwriting](items/ftp-323-by-hand-send-ftp-command-during-an-open-upload-then/desc.md) | ftp | open |
| 7 | [Paste of a case twin from an archive and SFTP twins by hand (252)](items/paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand/desc.md) | archives | open |
| 8 | [Paste of a long name into its own folder: check the copy name and the too long question](items/paste-of-a-long-name-into-its-own-folder-check-the-copy-name/desc.md) | long-paths | open |
| 9 | [ISO plug-in: a fuzzing pass over the HFS+, ISO 9660, Joliet and Rock Ridge readers](items/iso-plug-in-a-fuzzing-pass-over-the-hfs-iso-9660-joliet-and/desc.md) | other-plugins | open |
| 10 | [Check network drive names and disconnected icons with a real SMB server](items/check-network-drive-names-and-disconnected-icons-with-a-real/desc.md) | panels-ui | open |
| 11 | [Judge the quick-search tint on a real screen and try Shift and Alt keys](items/judge-the-quick-search-tint-on-a-real-screen-and-try-shift/desc.md) | panels-ui | open |
| 12 | [Backlog loop: Ctrl+C in Git Bash and the first real usage limit](items/backlog-loop-person-checks/desc.md) | tooling | open |
| 13 | [Check that Change Attributes refuses to encrypt or decrypt a junction (253)](items/check-that-change-attributes-refuses-to-encrypt-or-decrypt-a/desc.md) | data-safety | open |
| 14 | [SFTP drop folder on a real upload-only service and an ACL on a replaced file (258)](items/sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on/desc.md) | sftp | open |
| 15 | [Check that Change Attributes refuses to encrypt or decrypt a file symbolic link (272)](items/check-change-attributes-refuses-encrypting-a-file-link/desc.md) | data-safety | open |
| 16 | [Confirm a network location with a long target is refused in Browse](items/confirm-a-network-location-with-a-long-target-is-refused-in/desc.md) | long-paths | open |
| 17 | [FTP 288 on real servers: names to a code-page server, mainframe listings](items/ftp-288-real-server-checks/desc.md) | ftp | open |
| 18 | [SFTP: a folder uploaded again into a real upload-only service (279)](items/sftp-a-folder-uploaded-again-into-a-real-upload-only-service/desc.md) | sftp | open |
| 19 | [User Menu from Find results in folders of 260 or more bytes driven by a person](items/user-menu-from-find-results-in-folders-of-260-or-more-bytes/desc.md) | long-paths | open |
| 20 | [Check a volume label with accented letters written by Drive Information (300)](items/check-a-volume-label-with-accented-letters-written-by-drive/desc.md) | encoding | open |
| 21 | [Check the plug-in folder picker with a long-target network location](items/check-the-plug-in-folder-picker-with-a-long-target-network/desc.md) | other-plugins | open |
| 22 | [Check a drop onto a long-target shortcut and Browse on a long network location](items/check-a-drop-onto-a-long-target-shortcut-and-browse-on-a/desc.md) | long-paths | open |
| 23 | [Check ISO Rock Ridge names in a Shift-JIS image on a Japanese-locale Windows](items/check-iso-rock-ridge-names-in-a-shift-jis-image-on-a/desc.md) | archives | open |
| 24 | [Disk Map closing with its menu or a shell confirmation open, with a real mouse](items/diskmap-close-real-mouse-rows/desc.md) | other-plugins | open |
| 25 | [Viewer Copy to File onto a file held open, on a FAT stick or a network share](items/viewer-copy-to-file-on-fat-or-share/desc.md) | data-safety | open |
| 26 | [Check Ctrl+X ghosting and User Menu compare names with case twins](items/check-ctrl-x-ghosting-and-user-menu-compare-names-with-case/desc.md) | panels-ui | open |
| 27 | [Confirm reconnecting a remembered drive on a password-protected share (feature 264)](items/confirm-reconnecting-a-remembered-drive-on-a-password/desc.md) | encoding | open |
| 28 | [On-screen check of the Code Viewer conversion tables (feature 262)](items/on-screen-check-of-the-code-viewer-conversion-tables-feature/desc.md) | other-plugins | open |
| 29 | [Popup menu hot keys by hand: Russian layout, DBCS and UTF-8 systems, TortoiseSVN](items/popup-hot-keys-real-keyboard-256/desc.md) | panels-ui | open |
| 30 | [Registry Editor Find: confirm quoted hex letters with a UTF-8 code page](items/regedit-find-hex-utf8-code-page-check-257/desc.md) | other-plugins | open |
| 31 | [Check drive labels and folder type names outside the code page on real hardware (289)](items/check-drive-labels-and-folder-type-names-outside-the-code/desc.md) | encoding | open |
| 32 | [FTP 277 on real servers: long PWD paths, AS/400 member names, case-insensitive lock](items/ftp-277-real-server-checks/desc.md) | ftp | open |
| 33 | [Registry Editor Find: confirm a regexp finds the end of a non-ASCII text on UTF-8](items/registry-editor-find-confirm-a-regexp-finds-the-end-of-a-non/desc.md) | other-plugins | open |
| 34 | [Share list sign-in (285) by hand: the real Windows dialog on a server that refuses the list](items/share-list-sign-in-285-by-hand-the-real-windows-dialog-on-a/desc.md) | panels-ui | open |
| 35 | [Check Copy UNC Path on a subst drive with a long non-ASCII target](items/check-copy-full-path-as-unc-on-a-subst-drive-with-a-long-non/desc.md) | long-paths | open |
| 36 | [Typed check of the Find Containing and viewer Find refusals (feature 311)](items/typed-check-of-the-find-containing-and-viewer-find-refusals/desc.md) | long-paths | open |
| 37 | [Tabs 312: real keyboard in both key modes and the Tabs page in eight languages](items/tabs-312-real-keyboard-and-eight-languages/desc.md) | panels-ui | open |
| 38 | [Check the Markdown Viewer Page Width submenu on a real screen and in eight languages](items/check-the-markdown-viewer-page-width-submenu-on-a-real/desc.md) | other-plugins | open |
| 39 | [Check the Undelete same-partition warning for a target in an accented mount folder](items/check-the-undelete-same-partition-warning-for-a-target-in-an/desc.md) | other-plugins | open |
| 40 | [Email files on a tree with an unreadable deep folder, with a mail client](items/email-files-deep-folder-with-mapi-client/desc.md) | long-paths | open |
| 41 | [Plug-in messages of feature 130 not driven (SFTP, Renamer, DiskMap, ...)](items/plugin-mixed-template-rows-130/desc.md) | other-plugins | open |
| 42 | [User Menu from the Find window driven by a person](items/user-menu-find-route-person/desc.md) | panels-ui | open |
| 43 | [Real file server rows: shares, other-script names, refused list, SMB timing](items/real-file-server-person-rows/desc.md) | panels-ui | open |
| 44 | [Delete of a cloud placeholder past 780 characters (OneDrive)](items/cloud-placeholder-deep-path-onedrive/desc.md) | data-safety | open |
| 45 | [UNC "Checking path" wait window: real Esc / Close, then an immediate exit](items/unc-wait-window-esc-and-exit/desc.md) | panels-ui | open |
| 46 | [Clipboard and real-screen rows of 124 and 127 (Registry Editor, messages)](items/clipboard-and-screen-rows-124-127/desc.md) | encoding | open |
| 47 | [Real mouse double-click on a shortcut to an accented folder (GitHub #8)](items/shortcut-accented-folder-double-click/desc.md) | panels-ui | open |
| 48 | [Start the 0.1.10 build on Windows 7 SP1 / Server 2008 R2 SP1 (GitHub #6)](items/windows-7-start-of-release-build/desc.md) | build-release | open |
| 49 | [Accented archive edits and long archive paths: rows the probes could not drive](items/archive-edit-and-long-path-rows-owed-to-person/desc.md) | archives | open |
| 50 | [Submit the current release to winget once PR #426090 has settled](items/winget-submit-release-after-pr-426090/desc.md) | build-release | blocked |
| 51 | [On-screen sweep of 084 archivers: run the ready probes, then a visual pass](items/onscreen-sweep-084-archivers/desc.md) | archives | open |
| 52 | [On-screen sweep of 068/069: F1-F8, W1-W20 in cs and hu, V-01 to V-24, G7](items/onscreen-sweep-069-encoding-w-and-v-rows/desc.md) | encoding | open |
| 53 | [On-screen pass of 075 (small hardening): scenarios S1-S5 and gate G6](items/onscreen-pass-075-small-hardening/desc.md) | viewer | open |
| 54 | [On-screen pass of the Code Viewer: 070 quickstart scenarios and 074 gutter steps](items/onscreen-pass-codeview-070-074/desc.md) | viewer | open |
| 55 | [On-screen pass of 081: Markdown Viewer on the shared WebView2 host, sections A-D](items/onscreen-pass-081-mdview-shared-host/desc.md) | webview | open |
| 56 | [Panel tabs (078) by hand on the Release build, and the 88-byte leak watch](items/panel-tabs-078-release-pass-and-leak-watch/desc.md) | panels-ui | open |
| 57 | [Privacy fixes of 085 on screen: checks G1-G6](items/privacy-085-gui-checks-g1-g6/desc.md) | privacy-security | open |
| 58 | [Encrypted ZIP and SFTP passwords by hand: AES round trip, accented passwords](items/zip-sftp-passwords-real-keyboard-086-094/desc.md) | archives | open |
| 59 | [RAR reading and 7-Zip plug-in by hand: associations, WinRAR (087, 089)](items/rar-and-7zip-checks-087-089/desc.md) | archives | open |
| 60 | [Closing for a real update: elevated installer, sign-out, open plug-in windows](items/update-close-real-installer-signout-080-088-118/desc.md) | plugin-api | open |
| 61 | [FTP against real servers: anonymous login, non-ASCII password, SOCKS 5 proxy](items/ftp-real-server-checks-090-116-121/desc.md) | ftp | open |
| 62 | [Name identity of 092 by hand: accented names that differ only in case](items/name-identity-checks-092/desc.md) | data-safety | open |
| 63 | [New texts on screen in a translation: Archive Update (153), refusals (155)](items/dialog-texts-on-screen-153-155/desc.md) | translations | open |
| 64 | [New version check (123): design, real keyboard and mouse, screen reader](items/new-version-check-123-person-steps/desc.md) | panels-ui | open |
| 65 | [Paste, drag and drop and mouse-only routes by hand (099, 101, 107, 119, 121)](items/clipboard-drag-mouse-routes-099-101-107-119-121/desc.md) | data-safety | open |
| 66 | [Clean-machine start: the installer on Windows without the Visual C++ runtime](items/clean-machine-start-077/desc.md) | build-release | open |
| 67 | [Same-file guards on macOS / Samba and case-sensitive shares, snapshots, FAT](items/shares-snapshots-fat-same-folder-guards/desc.md) | data-safety | open |
| 68 | [Undelete on a mount point with an accented name (admin) and real EFS backups](items/undelete-mount-points-and-efs-114-115/desc.md) | other-plugins | open |
| 69 | [GitHub housekeeping: real run of the Node 24 workflows, vulnerability reporting](items/github-repo-housekeeping-091-083/desc.md) | build-release | open |
| 70 | [Antivirus reputation: Avast Whitelisting registration and a FAQ page](items/antivirus-reputation-avast-faq/desc.md) | build-release | open |
| 71 | [PictView: check the Exif information menu item is offered only for photos with Exif](items/pictview-check-the-exif-information-menu-item-is-offered/desc.md) | pictview | open |
| 72 | [Information line of a long-named item: check it on screen (276)](items/information-line-of-a-long-named-item-check-it-on-screen-276/desc.md) | panels-ui | open |
| 73 | [Share root way up (284) by hand: drop onto .., a real server, Esc in the wait](items/share-root-up-284-person-rows/desc.md) | panels-ui | open |
| 74 | [Quick search ignoring accents: check with a real keyboard](items/quick-search-ignoring-accents-check-with-a-real-keyboard/desc.md) | panels-ui | open |
| 75 | [Answer GitHub issue #9 (paste fails in a folder with an exclamation mark)](items/answer-github-issue-9-paste-fails-in-a-folder-with-an/desc.md) | file-ops | open |

## Inbox

| Item | Type | Sev | Area | Source | Created |
|---|---|---|---|---|---|
| [ISO plug-in: an HFS+ file skipped or cancelled at extraction leaks its read buffer](items/iso-plug-in-an-hfs-file-skipped-or-cancelled-at-extraction/desc.md) | bug | 2 | other-plugins | measure:327 | 2026-10-23 |

## Parked

| Item | Area | Reason |
|---|---|---|
| [unchm plug-in: a member path over 259 bytes overflows a stack buffer on F3 / F4](items/unchm-plug-in-a-member-path-over-259-bytes-overflows-a-stack/desc.md) | archives | plug-in unchm not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-10-21 |
| [unrar plug-in: a member name over 259 bytes overflows a stack buffer on F3 / F4](items/unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack/desc.md) | archives | plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20 |
| [Two @GMT snapshot folders joined by a junction could hide a folder alias](items/gmt-snapshot-folders-joined-by-junction-alias/desc.md) | data-safety | reasoned in feature 107's re-check, not reproducible without snapshots (agent sessions have no admin rights to create them) |
| [Encoding: the sites feature 069 deliberately did not convert](items/encoding-sites-069-chose-not-to-convert/desc.md) | encoding | deliberately not on the list (069 §2): each site waits for its own condition for re-opening, stated in the item (a facade migration, the copy-hook change, a shell-boundary pass, a viewer-title pass, a new string); not a rejection |
| [Help pages still carry the 2023 Open Salamander footer](items/help-pages-carry-2023-open-salamander-footer/desc.md) | help-docs | recorded in NEXT-WORK as deliberately not on the list: cosmetic, a single mechanical pass whenever it is wanted. |
| [Automation: a script folder with non-ASCII letters is shown as mojibake in the configuration](items/automation-script-folder-list-code-page/desc.md) | other-plugins | plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20 |
| [CheckVer: the log shows a script path with non-ASCII letters garbled](items/checkver-log-script-path-garbled/desc.md) | other-plugins | plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20 |
| [Multimedia Viewer: the "cannot open" message shows a non-ASCII file name as mojibake](items/mmviewer-open-error-name-mojibake/desc.md) | other-plugins | plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20 |
| [Network plug-in follows a network shortcut to a cut target of 260 or more units](items/network-plug-in-follows-a-network-shortcut-to-a-cut-target/desc.md) | other-plugins | plug-in nethood not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-10-22 |
| [UnMIME: the extraction progress title shows a non-ASCII mail file name as mojibake](items/unmime-progress-title-name-mojibake/desc.md) | other-plugins | plug-in not built or shipped (plugins.cfg off); fix before enabling it; maintainer 2026-10-20 |
| [A program started from the panel fails, from Explorer works (not reproduced)](items/command-shell-environment-not-reproduced/desc.md) | panels-ui | parked as not reproduced (decision of 2026-08-31, `specs/073-fix-cmdshell-env/spec.md` Clarifications); no product change until `evidence/capture.cmd` captures a live occurrence. |
| [SFTP: a stopped listing shows as the directory; an empty NAME ends it](items/sftp-listing-end-ambiguities/desc.md) | sftp | Kept by feature 133: a listing stopped by the user is shown as the directory (old behaviour, kept); an empty name or NAME packet cannot be told apart from the end through `libssh2_sftp_readdir_ex`. |

## Rejected

| Item | Area | Reason |
|---|---|---|
| [7-Zip: an archive that mixes the two password forms stays mixed](items/7zip-mixed-password-forms-stay-mixed/desc.md) | archives | feature 093, listed under NEXT-WORK §C Decided - not to do: the plug-in cannot re-encrypt, so an archive holding items under both password forms stays mixed. |
| [ZIP: the archive comment and the self-extractor stay code page](items/zip-comment-and-sfx-stay-code-page/desc.md) | archives | features 094 (2026-10-02) and 104/121, listed under NEXT-WORK §C Decided - not to do: the ZIP comment is code page by format; the self-extractor routes and the SFX password prompt stay code page because no SFX package is shipped (the routes are unreachable). |
| [ZIP: a code-page .set file that looks like UTF-8 is misread on import](items/zip-set-import-and-favourites-wide/desc.md) | archives | covered by the decision recorded in zip-comment-and-sfx-stay-code-page: no SFX package is shipped, the self-extractor routes (import of .set files, favourites) are unreachable and stay code page; re-open together with that item if an SFX package ships; maintainer 2026-10-23 |
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
