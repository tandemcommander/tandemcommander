# Fix log — 428 portable build

## 2026-11-14 — specify, clarify, plan

- Spec written from the maintainer's request; every open point went to a question catalogue
  ([clarify-questions.md](clarify-questions.md), 31 questions) by the maintainer's instruction.
- State inventory measured by a read-only sweep ([state-inventory.md](state-inventory.md)).
- WebView2 data folder measured on this machine: 27 MB / 373 files, caches and engine bookkeeping
  only; no `localStorage` / `IndexedDB` / cookies in codeview, mdview, webhost → it goes to `%TEMP%`
  (clarification 2).
- Clarify: three passes, 15 answers (spec *Clarifications*). Maintainer's addition in pass 3:
  `build.cmd dist` builds and signs the whole release in one command (name `dist` chosen in the
  session, renamable).
- Plan research — private hive measurements (`RegLoadAppKeyW`, research.md table): creates the
  file even with `KEY_READ`; invisible in `HKEY_USERS`; shared live by two processes and by two
  paths of one file; **locked while loaded**; the read-only attribute does not stop writes; a
  folder without write access refuses the load (5) even for reading; real configuration 512 KB,
  load 66 ms / write 117 ms. FAT32 / exFAT / SMB not measurable here (no volume, no elevation).
- The maintainer chose not to measure on a USB stick and to take the design that works on every
  medium: session hive in `%TEMP%` + `settings\tandemcommander.reg` (export format) written back
  atomically (research R-01), accepting that a crash leaves the session hive in `%TEMP%` until the
  next portable start on that PC.
- reglib checked: Unicode-clean in the core build since 174 (W functions, UTF-8 internally, UTF-16
  v5 files); the `CP_ACP` branches are for other builds. A lossless round-trip gate test is the first
  implementation task.
- Findings on the way (for triage, not fixed here):
  - the installer ships no licence texts in the program folder (`LICENSE`, `doc\third_party.txt`,
    `doc\license\*` are shown in the wizard or not at all) — the ZIP will carry them; whether the
    installed tree should too is a question for the maintainer (candidate Inbox item, `measure:428`).
  - Configuration > General's update level list is not gated by installer eligibility (only by the
    check box) — a non-installed normal copy shows levels it cannot use (candidate, severity low;
    fixed for the portable edition by this feature, the normal edition left as is).

## 2026-11-14 — implementation, Phase 1 (build switch)

- Baseline (SC-010): `build.cmd full` and `build.cmd full release` on clean `ce4bab86` (both up to
  date), manifests `probe/baseline/{debug,release}_x64.json` (611 / 615 files) by
  `probe/tree_manifest.py` (PE files hashed with time stamp, checksum, signature and debug
  directory zeroed — the build is not deterministic otherwise).
- T002-T004: `src/Directory.Build.props` (`TcEdition`, `TcOutSuffix`); `$(TcOutSuffix)` appended to
  the 17 output roots + the Release IntDir token in `Directory.Build.targets` (18 replacements by a
  one-off script that keeps BOM / CRLF); `TC_PORTABLE` for ClCompile + ResourceCompile in
  `sal_base.props` under `TcEdition=portable`.
- T005: `tools/check_outdir_suffix.py` (202 project files); negative control: with
  `sqlite_base.props` reverted it fails naming the line.
- T006 / T007: `build.cmd` `portable` / `dist` / validation / suffix / MSBuild property / help;
  `build_langs.cmd portable`; `tools/portable/dist_summary.py` (summary; removes on failure only a
  release file written during this run — `setup\output\` also archives published installers).
- **Finding (fixed in place, severity 4)**: measured — in `cmd`, an `exit /b 1` inside a
  parenthesized block that also contains a `goto` returns **0** to the caller (`build.cmd dist
  rebuild` printed the error and exited 0; reproduced with a 12-line script). The error and the
  jump are now two statements; all four refusals exit 1.

## 2026-11-14 — implementation, Phase 2 (gate, pure rules, base key)

- More hive measurements (scratchpad `apphive/delete_held.py`): deleting a hive file another process
  holds gives 32 (sharing), also within the same process; after the last handle is closed the file
  is deletable at once; `RegNotifyChangeKeyValue` works on the root of an app hive.
- Core plumbing: `SalCfgBaseKey()` (consts.h; the constant HKEY_CURRENT_USER in the normal edition);
  reglib's system registry maps a key named HKEY_CURRENT_USER to it (`MapRoot`, 12 call sites);
  `CopyBranchTransform` (regcopy.cpp) rewrites values on their way; `src/portstore.cpp` (the store)
  and `src/common/salportable.h` (pure rules); 77 HKCU lines routed or marked by a one-off script,
  the rest by hand; `tools/check_portable_regsites.py` in `build.cmd` (33 classified sites; negative
  control: `callstk.cpp` reverted -> FAIL naming line 623).
- Build trap: `_WIN32_WINNT` is 0x0601 - FILE_ID_INFO / FileIdInfo (Windows 8) are not declared;
  defined locally in portstore.cpp.
- Probe trap: the first gate run "hung" - the seam returned from WinMainBody before NTDLL was freed
  and Debug's handle check asked "Some monitored handles remained opened" at exit (found with a
  window dump on the hidden desktop; one run had shown that box on the maintainer's desktop - the
  process was the probe's own and was closed). The seam now leaves through EXIT_1; every later run
  is on the hidden desktop.
- **Gate (T009) on the real configuration + synthetic values (354 keys, 1,880 values)**: first run
  6 differences. One was a real defect of the design: the store's `$(SalDir)` collided with the
  program's variable - `ExecuteExpSalDir` gives "E:\TC\" (with the backslash) in commands, so a
  user's `$(SalDir)tools\x.exe` came back as an absolute path and would have become
  `E:\TCtools\x.exe` after a move. Fixed by a token of the store's own, `$(PortableDir)`; spec FR-012,
  research R-03, data model, contract and quickstart updated (the clarified decision "relative,
  automatic" is unchanged). After the fix: **0 differences**, 5 documented normalizations: an empty
  REG_SZ / REG_MULTI_SZ gets its terminator (File Comparator's `InputEnc Table 0/1` are such), a
  REG_SZ ends at its first NUL (the same as Export Configuration since 174 - no code of the tree
  writes such a value), the program folder takes the folder's own spelling (case).
- saltests: group `TestPortable428` (scope, names, relativize / expand incl. boundaries, UNC, drive
  root, non-ASCII folding, round trip and move, the start-decision table) -> 287,538 checks, 0 failed.

## 2026-11-14 — implementation, US1 / US2 / US6 / FR-011a (store wired, probes)

- Wired: store opened before `TaskList.Init` (seam first, Debug only: `--portabletest-roundtrip`,
  leaves through EXIT_1), closed at both exits; migration 343, `config.reg` / `-c` import, shell
  extension registration, 245 first-start offer, jump list and the icon-size write skipped under
  `TC_PORTABLE`; `PersistNow` at the end of `SaveConfig`; named objects scoped
  (`PortableScopedName`: process list, load/save lock, update claim, copy-hook event and shared
  memory - the latter two so an installed program's copy hook never reaches a portable copy);
  bug reports `settings\BugReports`, export default `settings\`, import backups `settings\Backups`.
- Plug-in API 109 (`IsPortableEdition`, `GetUserDataFolderW`, `GetInstanceScopeSuffix`),
  `TcWebSetUserDataFolder` (codeview / mdview set it at entry), mdview skips the old-folder
  clean-up, PictView keeps `PrevWallpaper*` in `settings\PictView wallpaper.ini`, File Comparator's
  channel scoped on both sides - fcremote.exe finds the edition by the RCDATA
  `TC_PORTABLE_EDITION` of its program and the scope by the shared CRT-free `salportscope.h`.
- Identity: ` [portable]` in the title, About lines + settings link (run-time controls), badge icon
  (`gen_icons.py`, blue disk; orange first - it merged with the folder), `FileDescription`.
- Update check: portable asset rule (`SalUpdPortableName/Url`, `supeNoPortable`), eligibility FALSE,
  Download opens the release page, General page hides the levels, `--updatetest` refused.
- Strings: 11 new, two-stage `.slt` refresh (12,720 DeepL characters, formality prefer_more), cs
  pinned whole; 'Continue Without' renamed 'Not Now' (every language cut it) and pinned per language
  with distinct access keys. The merge's duplicate-accelerator count 147 -> 148 is the string-table
  bundle 13744-13759 taken as one dialog (an older string of another box shares 'D') - not a defect.
- **Traps found by measuring**:
  - Debug `/RTCc` stopped the first portable start: `(unsigned char)(x >> 8*i)` is a lossy cast for
    the run-time check (saltests are built without it) - masked with `& 0xFF`.
  - **Move probe found a real defect**: `Default Directories` keeps the last folder of each drive
    under the drive's letter; `$(PortableDir)` moved it to the portable folder's drive and the load
    said "Unexpected value". The transform now gets the key path and leaves that key absolute.
  - Probe traps (not product defects): `WM_COMMAND IDOK` to the Configuration dialog only hides the
    property sheet and the program then refuses to close (both editions) - its OK button is id 5,
    pressed with BM_CLICK (123's Cfg-Close); F3 sent as keys opened nothing - `CM_VIEW` (742) works;
    `icacls ... (W)` denies SYNCHRONIZE / READ_CONTROL too, so the program could not even start -
    the read-only rows use `(WD,AD,WEA,WA,DC)` (T6 re-measured with these rights: the hive still
    refuses to load - research holds); a scratchpad script named `token.py` shadowed the stdlib
    module of a later Python run (renamed; scratch tools now in their own folder).
- **Probe results** (Debug, hidden desktop): gate 0 differences; no-trace: 0 keys of ours, the
  installed edition's key unchanged, session folder in %TEMP% with WebView2 and removed at exit,
  settings persisted across starts; negative control (normal edition) 285 keys of ours + its jump
  list -> the probe detects writes. Scenarios: move (subst Z:, non-ASCII path) PASS, unwritable /
  damaged / both damaged PASS, 20 kills during a save PASS, side by side (normal + two portable
  copies, Only one instance) PASS.
- **Finding (documented, not ours)**: when a web viewer creates its environment, the WebView2
  runtime (msedgewebview2.exe) writes its own state - `HKCU\Software\Microsoft\EdgeWebView\
  PreferenceMACs`, `EdgeUpdate\ClientState` - and a jump list of its own
  (`...\CustomDestinations\2a2e0412b8ad04a2.customDestinations-ms`, content: msedgewebview2.exe).
  Not the program's writes and the same for any program using WebView2; listed by the probe as
  "WebView2 runtime", to be stated in PRIVACY.md and the spec's assumptions.

## 2026-11-14 - implementation, US3 (the package), docs, two gaps found while documenting

- **The package**: `tools/portable/make_portable_zip.py` (contract package-layout.md: one top
  folder, sorted entries, the commit time of HEAD as every time stamp, exclusions, `.part` +
  rename, refuses an exe without the RCDATA marker and "(portable)" in its FileDescription, a
  final check that no excluded file slipped in; README's `@VERSION@` filled in);
  `tools/portable/README-portable.txt` (59 lines, the eight points); `build.cmd` makes the ZIP
  after signing for `full release portable` ("Portable ZIP : OK" in the summary).
  `probe/zip_check.py` Z1-Z8.
- **Release portable build** (`build.cmd full release portable`): 624 files, 26.8 MB unpacked,
  8.8 MB packed; zip_check Z1-Z7 PASS. File list of Release_x64 vs Release_x64_portable: identical
  (the shell extension is not in either Release tree - it is built by the installer step).
- **SC-005, two builds of one commit** (`full release rebuild portable` twice, 69 s / 71 s):
  same entry list; 409 files identical, **215 differ only in build time stamps by design** - the
  linker's COFF / debug-directory / export time stamps, the PDB GUID, the header check sum, the
  core's `Built: __DATE__ __TIME__` string, and `plugins.ver`'s time-based version number (feature
  029's auto-install trigger). The same holds for the normal edition - its binaries were never
  bit-reproducible (no `/Brepro`). zip_check Z8 compares after zeroing exactly those fields
  (`normalize`): 0 other differences. **Negative control**: the pair build 1 / build 2 (pictview
  changed in between) -> Z8b FAIL naming exactly `pictview.spl`. Bit-identical binaries would
  need `/Brepro` and the build-time string removed for both editions: an Inbox candidate (the
  constitution's principle I says "identical binaries"), not part of 428.
- **Gap 1 (found while writing PRIVACY.md), fixed**: PictView *Set as Wallpaper* still wrote
  `%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` in the portable edition (FR-007 says
  the picture goes into the folder). `SaveWallpaperFile` asks `GetUserDataFolderW(SALUSERDATA_
  LOCAL)` when the core is portable (interface 109). Probe 111 got `-PortableSettings` (the
  picture expected in `<program>\settings`, the profile's file must not change): wp-center /
  tile / stretch / none PASS, the profile's file untouched, registry identical, real wallpaper
  values unchanged (results: 7 PASS).
- **Gap 2 (found while writing the help page), fixed - FR-013 was not met**: *Options > Import
  Configuration* only tells the user to open the file in Registry Editor - in the portable edition
  that writes the user's registry (the installed edition's key), never the portable settings; and
  the export's hint told about `config.reg` / `-C`, which the portable start does not use (R-09).
  Now, portable only: the command asks for a `.reg` file, checks it exactly as an import would
  (`ImportConfiguration(..., checkOnly)` - the same refusals, nothing written), keeps a byte copy
  as `settings\import.reg` (`.part` + rename) and asks whether to close now (new string
  IDS_PORTABLE_IMPORTPENDING); the next start that does not join a running process of the copy
  imports it where the installed edition imports config.reg (before LoadConfig, so the running
  program's exit save cannot overwrite it), deletes it, and writes the imported values once more
  through the start's expansion (`Seed`) so a `$(PortableDir)` of another portable copy's file
  names this copy's folder. The export shows IDS_PORTABLE_EXPORTHINT instead. Two strings in the
  free slots 14014 / 14015; `.slt` refresh: the merge dropped a `\n` in cs/de/fr/nl/hu/ro (kept
  English) and gave the informal register in de/fr/nl/es - both strings pinned (menu paths in the
  language's own menu wording). `build.cmd full` and `full portable` green.
  `probe/import_probe.py`: I1 command (byte copy, the question asked, exit save does not apply
  it), I2 next start (imported, `$(PortableDir)\docs` of SRC opens DST's docs - title "docs - ...",
  no SRC path in the file), I3 a joined start leaves it pending, the next lone start imports, I4 a
  file with a key outside the configuration refused at once (no question, no file) - all PASS, the
  installed edition's key unchanged. The probe's first run had one FAIL of its own: it looked for
  the English question text in a Czech UI (now language-independent).
- Docs: PRIVACY.md *Portable edition* (and the summary, the validity line), architecture 06
  (interface 109), 11 (the portable WebView2 folder - binding), 12 (the edition, `dist`, the ZIP),
  README (the edition, build commands), help `customize_configuration.htm`, CHANGELOG
  `[Unreleased]`; `backlog/RELEASE.md` step 2 = `build.cmd dist`, step 5 attaches both files, the
  closing pass builds the portable ZIP; `tools/release/release.py artifacts <ver>` (+ 3 tests, 49
  OK); `tools/test_bin_help.py` OK.
- `setup\output\tandemcommander-0.3.0-x64-portable.zip` is a test build of this tree (still
  version 0.3.0, which has no portable edition) - removed at the end of the feature so nothing
  looks like a 0.3.0 artefact.

## 2026-11-14 - US4 / US5 / FR-015a probes, SC-009 / SC-010, what they found

- **Identity probe** (`probe/identity_probe.py`, 8 languages). First run: "label cut" in de/fr/nl
  and "the link does nothing" in every language.
  - The "cut" rows were the **probe's** error: it selected the program's `HFONT` into its own DC -
    a GDI handle of another process does not select, so it measured with the system font. The
    screenshot shows the German line whole. The check now looks at the painted pixels (PrintWindow;
    the ink ends before the control's right edge) and at the label's text (WM_GETTEXT = the
    language's string from its `.slt`). The label is now a plain static that wraps and grows the
    box by as many lines as a language needs (it never needs more than one today) - robust for
    longer translations; coloured by the box's WM_CTLCOLORSTATIC in both themes (screenshots
    evidence/about_portable_default.png, _dark.png, _de-default.png).
  - **Real defect, fixed**: the settings link was a plain `CHyperLink`, which leaves Enter to the
    box's default button - Enter closed the About box without opening the folder (contract: Enter /
    Space / click). It is a `CUpdateLink` now (feature 123's link that takes Enter; its constructor
    got an optional flags argument, default unchanged). A posted click cannot be driven (CHyperLink
    hit-tests at GetMessagePos); Enter is, and the first run is the negative control.
  - Result: 35 rows PASS - title with "[portable]" in all 8 languages, label whole, Enter on the
    link closes the box and the panel shows `settings`, IDI_SALAMANDER = salamand_portable.ico (7
    images) and the normal exe has the plain icon, the normal edition's title and About unchanged,
    registry identical. NOT DRIVEN (person): elevated title, High Contrast, the badge on a real
    taskbar, taskbar grouping.
- **Update probe** (`probe/update_probe.py`, 123's fixture server; new fixtures `with-portable`,
  `portable-not-uploaded` in `specs/123-new-version-check/probe/updserver.py`). **Real defect,
  fixed**: the notification still showed "When a new version is found" with its (disabled) list -
  the contract says no level list. `ApplyForm` hides the label and the list in the portable edition
  and moves the buttons up into their place (the window is shorter by as much; screenshot
  evidence/update_notice_portable.png). The probe now reads only visible controls; the first run is
  the negative control. Result: offered with the ZIP (portable hint, no Download & Install / Install
  Now / level list), not offered without it or with the ZIP not uploaded ("unexpected answer" box),
  General page hides the level, the server saw only /latest requests, no file in Updates,
  registry identical.
- **Password note** (`probe/pwdnote_probe.py`, Debug seam `TC_PORTABLE_TEST_PWDNOTE` in
  `PortableStore_AttachMainWindow` - the trigger lives in FTP / SFTP dialogs a probe cannot drive):
  no note without the seam; shown once, Not Now closes it; ticked "Do not show again" is stored in
  the settings file and the next start shows nothing; Set Master Password opens the master-password
  dialog. Accepted limitation (severity 3, recorded): the note is requested by any EncryptPassword
  call without a master password, also for a password a plug-in only keeps for the session (FTP
  scrambles typed passwords even when "Save password" is off) - the interface does not tell a saved
  password from a session one; the note's wording ("passwords it saves") stays true.
- **SC-009** (`probe/timing_probe.py`, Release, 7 runs + warm-up, interleaved): first measurement
  start-up **+13.4 %** (0.487 s vs 0.429 s) - over the 10 % limit; exit with save +5.3 %. Cause: the
  start dumped the whole seeded hive once only to remember its hash, and `Seed` flushed the hive
  file synchronously. Now the hash is taken from the settings file's bytes (the file is a dump; a
  dump of the hive seeded from it gives the same bytes - the round-trip gate), and the flush is
  gone (the session hive is a working copy; a joining process uses the loaded hive). After:
  start-up +4.2 %, exit +5.3 %; a new row proves two runs without a change leave the settings file
  and its .bak untouched (time stamp and bytes).
- **SC-010**: `build.cmd full release rebuild` (normal) vs the baseline manifest at ce4bab86: 615 ->
  615 files, none added or removed; 31 changed by design (every plug-in: interface 109 in
  spl_vers.h; the 9 core language modules: new strings; the core and fcremote: code). Two
  `full release portable` builds afterwards left the normal Release tree byte-identical (raw
  hashes of all 615 files). The installer sources are untouched.
- **build.cmd argument errors**: `release portable`, `portable setup`, `full release portable
  setup`, `dist full`, `dist sign`, `sign portable`, `full portable sign` - each refused with its
  message in 23-38 ms, exit 1, before any work. **`dist` itself: NOT DRIVEN** - it signs with the
  Certum certificate (time-stamp server) and would overwrite the archived, published
  `setup\output\tandemcommander-0.3.0-x64-setup.exe` (the tree is still 0.3.0); owed to the
  maintainer at the next release (RELEASE.md step 2). Its decisions are unit-tested instead:
  `tools/portable/test_dist_summary.py` (a published installer of the same name is never removed;
  only files of this run; DIST OK needs both files of this run) + the ZIP rules.
- **Tool defect found by those tests, fixed**: `os.path.relpath` raised for an output on another
  drive - `make_portable_zip.py <tree> C:\...\x.zip` wrote the ZIP and then ended with a
  traceback (exit 1). Both tools print an absolute path then. Packing killed at 250 / 500 ms
  leaves only `<name>.part`, never a finished-looking ZIP; the next run removes it.

## 2026-11-14 - three independent refute-first reviews (T064) and what was done

Three agents, given the code and the spec, not my conclusions: (A) the core and plug-in code,
(B) build, package, release tooling and public claims, (C) the adequacy of the tests. Every finding
was checked against the code before acting on it.

**A - core (10 findings, all fixed or decided):**
- A1 (sev 8) a start that decides to join while the last process of the copy closes could load a
  NEW, empty hive (the closing process deleted `session.dat` between the decision and the load) and
  write defaults over `tandemcommander.reg`. Fix: `PortableStore_Close` unloads the hive and removes
  the session folder under the copy's start mutex - the join decision and the load are under the same
  mutex, so a start either finds the hive still loaded or no hive at all (then it seeds from the file).
- A2 (sev 7) a session that started without reading the settings file (unreadable: `spsaReadOnly`)
  runs on defaults with saving off - but a second process joining it probed only the folder and
  became writable, then wrote the defaults over the file. Fix: the starting process leaves
  `readonly.mark` in the session folder whenever it does not save; a joining process keeps to it.
- A3 (sev 7) the persist dumped the hive without the configuration's load/save lock: a dump during
  SaveConfig (which clears and recreates keys) or another process's save could fail (and then
  switched saving off for the rest of the session), skip a subtree, or catch a half-saved
  configuration. Fix: `Persist` takes `LoadSaveToRegistryMutex` first (lock order: that mutex,
  PersistCS, StoreMutex - SaveConfig already holds it and calls PersistNow after leaving it; the
  WM_ENDSESSION path re-enters it on the same thread, a Win32 mutex is recursive). A failed dump is
  transient now (Dirty again, saving stays on). `CLoadSaveToRegistryMutex` got `IsInitialized()` (the
  worker can run before `Init`) and an interlocked debug counter (two threads now).
- A4 (sev 4) a pending import was deleted before the imported settings reached the file (a crash
  later in the start lost it), and a process joining between the store's open and the import could
  write its pre-import view back. Fix: the start lock is kept from the open until the import is
  applied (only when an import is pending); the import is persisted synchronously before
  `import.reg` goes.
- A5 (sev 3) a joining process took its "already written" hash from the live hive, so changes of
  the other process not yet on disk could be skipped at its exit. Fix: a joiner writes once.
- A6 (sev 2) Close closed handles the worker might still use after a 15 s timeout. Fix: 60 s, and on
  a timeout nothing is closed or removed (the next start cleans the session).
- A7 (sev 3) the writer had no size limit while the reader refuses files over 10 MB - a configuration
  that large would be saved and then refused at the next start (defaults). Fix: the writer refuses
  it (a failed save the user is told about).
- A8 (sev 3) codeview / mdview fell back to `%LOCALAPPDATA%\Tandem Commander\WebView2` when the
  portable core gave no folder; and both created that folder at plug-in load in the NORMAL edition
  (it used to be created when the engine starts). Fix: they ask only the portable core; without a
  folder the portable edition creates no web view at all (`TcWebRefuseUserDataFolder`), the normal
  edition is as before.
- A9 (sev 2) a damaged settings file that could not be renamed aside would be overwritten. Fix: then
  the session saves nothing.
- A10 (sev 2) a literal `$(PortableDir)` the user types is expanded at the next start - accepted
  (an escape would change the file format; the token is unlikely to be typed), recorded here.

**B - build, package, claims (11 findings):**
- B1 (sev 7) my PRIVACY.md validity sentence no longer matched `release.py`'s pattern - the next
  `/tandem-release` would have refused. Restored; the portable section says "offered from the
  version after 0.3.0". The three patterns match again (checked with release.py's own regexes).
- B2 (sev 6) the closing pass (`build.cmd full release portable` before the version bump) would
  overwrite the PUBLISHED ZIP of the previous release in `setup\output` - and my own test build
  had put a `tandemcommander-0.3.0-x64-portable.zip` there (0.3.0 has no portable edition). Fix:
  `make_portable_zip.py` writes the ZIP of a version whose tag exists to `build\tandemcommander\`;
  my test ZIP removed; the published 0.3.0 installer unchanged (date 2026-11-08, SHA-256 2a079e35...).
- B3 (sev 5) `/tandem-release`'s report and reference still told the maintainer to run `full
  release sign setup` and attach only the installer (no portable copy would ever hear of a release).
  Updated: `build.cmd dist`, both files.
- B4 (sev 5) 7-Zip (LGPL) shipped without the LGPL text that `doc/third_party.txt` promises. The ZIP
  now carries `doc\license\license_lgpl21.txt` and `doc\license\7zip_license.txt` (zip_check Z2
  requires them). The installer has the same gap - pre-existing, to the Inbox.
- B5 (sev 5) `dist` did not refuse an already released version (it would overwrite the published
  installer winget pins). `dist_summary.py --start` refuses when the tag exists; `build.cmd dist`
  on this tree now stops in 240 ms ("version 0.3.0 is already released"); unit test added.
- B6 (sev 4) `release.py artifacts` checked presence and layout only. It now also checks that the
  program in the ZIP is the portable edition and that it and the installer are validly signed
  (Get-AuthenticodeSignature): published installer Valid, unsigned local build NotSigned; test added.
- B7 (sev 3) "writes nothing to the registry" was absolute; PictView's wallpaper and the Registry
  Editor plug-in's *Open Folder > Active Folder* change Windows settings on the user's request.
  README-portable / README / CHANGELOG say "keeps nothing of its own"; PRIVACY names both commands.
- B8 (sev 3) the portable update hint (14003) told de / fr / sk users to copy the settings folder
  "into the new archive"; hu translated the folder's name. Pinned in all four; merge 0 failures.
- B9 (sev 2) the ZIP tool's determinism sentence corrected (same files apart from build stamps).
- B10 (sev 2) the help page now describes the portable import (pending file, next start).
- B11 (sev 2) PRIVACY lists `settings\import.reg` and the kept `.damaged-` copies.
- Minor: CLAUDE.md interface 109 - done at closing (T065).

**C - test adequacy (20 items); what changed in the probes:**
- notrace: the toggled value must be 1 (the default is 0) - "not None" passed with a lost toggle;
  a sentinel title-bar prefix in the INSTALLED key must never appear in the portable title (the
  normal edition shows it - the negative control fails on it); fails on any change under shell /
  start-up / uninstall / environment / Control Panel keys, and on any changed value anywhere in HKCU
  that names the program or its folder (Windows' own records - UserAssist, MuiCache, AppCompat,
  FeatureUsage, RestartManager, ComDlg32, Bags - aside).
- scenarios: kill - the mark and every key must survive each kill (a complete file of defaults no
  longer passes), counts kills that hit a write, and the crashed session folder must be gone after
  the next start; damaged - the `.bak` carries a mark that must arrive (defaults lack it); unwritable
  - nothing saved in the installed key or the profile; move - started at the non-ASCII path itself
  (no subst), the old folder deleted first, a second setting must travel; new scenario `two` - two
  processes of one copy, the first exits, the second's change is saved, the last exit removes the
  session.
- gate: the case normalization only for the one synthetic value; the dump must carry
  `$(PortableDir)` in the four synthetic values inside the folder (twice in the quoted command) and
  keep the prefix-only folder absolute; prints RESULT.
- update: U2 / U3 need the check's own box (no window at all would have passed); spec US5-2
  aligned with the contract ("could not be checked").
- identity: the link shows the settings folder; a tighter title pattern; new row X (FR-006a):
  Ctrl+C on a file inside a ZIP panel shows the Explorer-integration message.
- import: I5 Export Configuration from the portable copy (absolute paths, no token, our root);
  I6 the installed edition's configuration imports into the portable copy.
- timing: both editions on the same (the maintainer's) configuration - imported into the portable
  copy first; every run changes a setting so the exit really saves; no 50 ms slack.
- zip_check: its own exclusion list (not the packer's function).
- run_all: the negative control must fail on its two named rows, not by a crash; the summary is
  copied to `results/`.
- Not automated (recorded as person checks or accepted): real FAT32 / exFAT and another PC, the
  browser's Mark of the Web, UAC, High Contrast, real drag and drop, the real FTP / SFTP password
  trigger (the note's trigger is a two-line hook; FTP scrambles on load only old-format passwords,
  so no note on every start), third-party plug-ins, UNC folders (string rule covered by saltests).
- Found on the way: Export Configuration in a portable copy whose `settings` path does not fit
  MAX_PATH did nothing at all - the dialog now opens without a start folder.

## 2026-11-14 - after the review fixes: full builds, all probes, three probe defects of my own

- Build: the store's new use of `LoadSaveToRegistryMutex` needed `#include "cfgdlg.h"` in
  `portstore.cpp` (the first full portable build failed; the probes of that run used the previous
  portable binary and are not counted).
- `build.cmd full` / `full portable` / `full release` / `full release portable` green; saltests
  287,558 checks, 0 failed; `check_encoding.py --strict` TOTAL 0; the ZIP of the released version
  0.3.0 went to `build\tandemcommander\` (setup\output holds no portable file), zip_check PASS
  (626 entries with the two 7-Zip licence files).
- `run_all.ps1`: gate, notrace (portable PASS; the normal edition FAILs on exactly its two named rows
  - it reads the sentinel prefix from its key and writes 285 keys), scenarios, identity, update,
  pwdnote, timing PASS; import FAIL -> fixed (below) and PASS on rerun.
- Probe defects found by these runs (mine, not the program's):
  - move: the token check compared one backslash where the file has the `.reg` escape `\`.
  - import I5: the Explorer-style save dialog keeps its file name in an Edit with id 1001 inside a
    ComboBox (measured; the open dialog's is 1148) - the probe pressed Save with the default name;
    the program had exported fine ("Konfigurace byla úspěšně exportována").
  - identity: the settings link's text is painted by the program and not readable from outside -
    the row now checks that the panel the link opened is stored as `$(PortableDir)\settings`.
  - kill: the rewrite count read the file time AFTER the save (0 rewrites reported). Measured then:
    a save of this configuration completes in well under the random window, so random kills almost
    never cut the file write. Now half the runs are killed the moment the write's temporary file
    appears: 13 of 20 kills cut a write in the middle, 4 more after a complete rewrite - every time
    the file was complete with all 338 keys and the mark, the next start showed no message, left no
    temporary file and removed the crashed session folder. A new row requires such hits.
- SC-009 on the same configuration (the maintainer's, imported into the portable copy, 342,746-byte
  settings file), every run with a real change before exit: start-up 0.458 s vs 0.519 s (-11.9 %),
  exit with save 1.270 s vs 1.185 s (+7.2 %).

## 2026-11-14 - second independent round on the fixes (store; release tooling and texts)

**Store re-review (11 findings, no deadlock, no unbounded wait found) - fixed:**
- F1 (5) one failed write (a sync client or virus scanner holding the file) switched saving off for
  the session. Now a write failure is retried after the quiet period; only a permanent error (file
  too large, disk full, write-protected, device or path gone) or 5 failures in a row stop saving and
  tell the user; the exit retries 4 times 500 ms apart.
- F2 (5) a process of the copy that crashed inside SaveConfig left "Save In Progress" in the shared
  hive, and another process's persist could write that half-saved state over the good file. Persist
  never dumps while the hive holds that value (the file keeps the last complete configuration).
- F3 (4) / F4 (3) "nothing changed" compared with what THIS process wrote last: with two processes
  of a copy the last one to close could skip its write, and a start that only hands over to a running
  window ("only one instance") rewrote the file and rotated away the .bak. Now the dump is compared
  with the hash of the file's current bytes (read under the Store mutex) - the last window to close
  wins as in the installed edition, a hand-over writes nothing; the start-up hash shortcut and
  RememberCurrentDump are gone (the start dumps nothing - SC-009 unaffected).
- F5 (3) after the 60 s timeout the worker could run on while static objects are destroyed: it is
  stopped (TerminateThread) and nothing more is saved by this process (a temporary-file write cannot
  damage the settings file; an abandoned mutex goes to the next owner).
- F6 (3) a pending import was deleted after a failed dump (Persist returned TRUE) or applied to a
  session that saves nothing. Persist now returns TRUE only when the file holds the session; the
  import waits for a start that can save.
- F7 (3) a failed dump made the worker spin (timeout 0). Every transient failure restarts the quiet
  period (LastChangeTick shared by the worker and Persist).
- F9 (2) a Store mutex wait that timed out still wrote without the lock - now it retries later.
- F10 (2) the read-only mark was a file whose creation could fail silently: it is a value
  ("TC Session Saves Nothing") at the root of the shared hive, outside the dumped configuration; if
  it cannot be written the start fails instead of letting a joiner write.
- F11 (2) the restore / damaged notes said the unreadable file "was kept" also when it had not been
  moved (a deleted main file, a failed rename) - shown only when the files were moved.
- F8 (2) accepted: with a pending import the start lock is held across the start's own dialogs
  (language selection on a configuration without one, an import error box); a second start meanwhile
  waits up to 60 s and is told to try again - rare (needs both at once), recorded.

**Release tooling / texts re-review (10 findings; published files found safe) - fixed:**
- 1 (5) a stale ZIP / installer of an earlier unreleased build of the same version survived a failed
  `dist` and passed `artifacts`: `dist_summary.py --start` sets earlier files of the version aside as
  `*.before-dist-<time>` (never deletes).
- 2 (4) "released" failed open when git could not answer: `dist` now refuses, the ZIP tool uses the
  build folder.
- 4 (3) `artifacts` checked the signature of the program only: now every executable file of the ZIP
  (exe, dll, spl, slg) and the installer - on today's unsigned local build it reports 214 of 218 (the 4
  Microsoft runtime files are signed by Microsoft); the published 0.3.0 installer is Valid.
- 6 (3) `dist` with another OPENSAL_BUILD_DIR would sign one tree and let the installer pack another
  (`..\build`): refused. 7 (2) the certificate check only looked for a thumbprint line: `--start` now
  asks the certificate stores (as sign_release.ps1 does). Unit tests: 11 (set aside, git cannot tell,
  no certificate, another build folder, released version).
- 3 (3) / 8 (2) RELEASE.md step 2 now names `release.py artifacts`; step 3 says a rebuild after
  tagging needs the (unpushed) tag removed first. 5 (2) the build summary no longer claims
  `setup\output` for a ZIP that went to the build folder. 10 (1) PRIVACY's scope sentence names the ZIP.
- 9 (2) one term per language: de "portable Version", fr "édition portable", hu "hordozható kiadás";
  hu "Do not show again" in the program's formal wording - pinned, merge 0 failures.

## 2026-11-14 - third independent check of the store; the last full run

Third reviewer (store rework only): no deadlock, no busy loop, no path writing older / default /
half-saved state over the file. Fixed:
- a session that keeps failing (a crashed process's "Save In Progress" stuck in the shared hive, a
  dump that keeps failing, a file held for long) retried silently forever: after 60 s of nothing but
  failed persists saving stops and the user is told (replaces the "5 failed writes" rule, which a
  slow sync of more than 10 s would already trip); a permanent write error stops at once;
- a failed save at exit was never reported (the main window and the language module are gone by
  then): the program now says so in an English message box before it ends;
- an applied import whose first persist failed kept `import.reg` and imported it AGAIN at the next
  lone start over the user's later changes: the pending file is deleted by the first persist that
  saves, whenever that is;
- a failure to open the configuration key other than "not found" counted as "nothing to save";
- the damaged-files note followed "writable" instead of what was really moved aside;
- `Joined` was not reset when the second start attempt turned out to be a lone start;
- a worker that does not end within 60 s: the process now ends at once (TerminateProcess) instead of
  TerminateThread, which could leave the thread inside the heap and hang the teardown.
- Accepted: Close's persist can wait without limit for the copy's configuration lock while another
  process of the copy sits in a dialog inside its own save - the installed edition waits the same way
  on the same lock; a persist reads the file and dumps the hive (2 s after a change) - measured cost
  within SC-009.

The previous full run (before these fixes): all builds green, saltests 287,558 / 0, encoding 0, unit
tests OK, zip_check PASS, run_all: everything as expected except one row - after kills during a save
a `tandemcommander.reg.bak~RF<hex>.TMP` stayed in `settings`: ReplaceFileW's own temporary copy,
which a write killed inside the replace leaves. The start's clean-up (only when the settings file is
readable) now removes `tandemcommander.reg*~RF*.TMP` too.
