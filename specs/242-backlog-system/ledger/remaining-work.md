# Ledger part remaining-work

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
