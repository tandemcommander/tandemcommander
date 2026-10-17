# Ledger part numbered-1 — NEXT-WORK §R, §0–§4 (lines 869–1211 at 7993914c)

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
