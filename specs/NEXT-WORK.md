# Next Work — consolidated continuation

**Written**: 2026-09-02 · **Baseline**: `main` at `f4cefa1` (0.1.7, build 191)
**Revised**: 2026-09-20 — release status corrected: **0.1.7 is the last
published version**; 0.1.8 (build 192) exists only in the tree. Feature 080 is
in `main` (`71e340b`); feature 081 closed item 4's first bullet (mdview onto
the shared WebView2 host) and added its on-screen pass to item 3.
**Revised again**: 2026-09-20 — the tree is **prepared for the 0.1.8
release** (section R, step 1 done); building, tagging and publishing are the
maintainer's.
**Revised 2026-09-24** — **0.1.8 is published** (tag `v0.1.8`, GitHub release
2026-09-20) and the maintainer has reviewed the `v0.1.7..v0.1.8` delta with no
findings; section R is closed. Its owed human steps moved to item 3, the winget
submission of 0.1.8 to item 6. The two preserved reference trees item 3 relied
on are **no longer on disk** (see there).

**Revised 2026-10-01** — item 7 (the privacy defects of feature 083) is done
as feature 085; F9, left open there, is done as feature 090; the GUI steps of 085 join item 3. The ZIP salt
item 085's review added is done as feature 086. Item 8 (7-Zip engine, with
RAR reading — 084 stage S7) is done as feature 087; its GUI pass joins item 3.
Item 4 (plug-in interface 107) is done as feature 088.

This file is the single entry point for "what do we do next". It consolidates
the per-feature handoffs — `specs/072-winget-distribution/REMAINING-WORK.md`,
`specs/069-finish-encoding-fixes/REMAINING-WORK.md`,
`specs/070-source-viewer-plugin/REMAINING-WORK.md` and (since 2026-09-20)
`specs/080-restart-manager-upgrade/REMAINING-WORK.md` — into one order. Those files
stay authoritative for the *detail and the reasoning*; this one decides the
**sequence** and records what was verified against HEAD when it was written.

Ordering criterion: what it costs users × what it costs us. Nothing here is a
blocker for anything already shipped.

---

## R. Release 0.1.8 — ✅ PUBLISHED 2026-09-20

> Tag `v0.1.8` (commit `4899f0d`) and the GitHub release (published
> 2026-09-20 14:34 UTC, not a pre-release) exist, so the date in
> `CHANGELOG.md` and `CLAUDE.md` is now a fact and stays as it is. Step 2,
> the review of the `v0.1.7..v0.1.8` delta (64 commits), was done by the
> maintainer after publishing — **no findings** (recorded 2026-09-24). Still
> open from the gate, and carried forward rather than dropped:
>
> - step 3, the human steps (clean-machine start, the panel tabs on the
>   Release build, the elevated machine-wide update) → **item 3**;
> - step 4, the winget manifest for 0.1.8 → **item 6**: checked 2026-09-24,
>   `microsoft/winget-pkgs#426090` (0.1.7) is still open and no pull request
>   for 0.1.8 exists, as intended. Whether the `Publish to winget` workflow
>   was switched off before publishing could not be checked from this
>   session (no `gh`); look at the Actions tab before relying on it.
>
> The original gate follows, unchanged.

<details>
<summary>Original entry</summary>

Features 075, 077, 078, 079, 080 and 081 are all in `main`. The version was
bumped to 0.1.8 / build 192 by feature 078 (`spl_vers.h`,
`setup/tandemcommander.iss`, `CLAUDE.md`), and `CHANGELOG.md` collects all six
features in one section. **Until the maintainer publishes it there is still no
`v0.1.8` tag, no installer in `setup/output/` and no winget manifest** — the
date in the tree states the intended release day, not a fact about GitHub.

Ship gate:

1. ✅ **Done 2026-09-20** — the changelog heading reads
   `## [0.1.8] — 2026-09-20` and the *Not released yet* paragraph is gone
   (`tools/winget/publish.ps1` reads the date from that heading and the
   release summary from the lead paragraph — 820 of its 900 characters; the
   lead gained one sentence for feature 080, which it had never mentioned);
   *not released yet* dropped from the build-192 row in `spl_vers.h` (the row
   now also names 080 and 081) and from `CLAUDE.md`. GitHub release notes
   drafted as `temp/release_notes_v0.1.8.md` (not tracked). **If the release
   is published on another day, the date moves in two places**: the changelog
   heading and the product line in `CLAUDE.md`.
2. Pre-release review of the `v0.1.7..HEAD` delta (the 056 pattern) — the
   delta contains a feature the size of panel tabs. *Not done; the
   maintainer's call.*
3. The owed human steps that gate a release rather than follow it: the
   **clean-machine start** (item 0.1 below — it verifies the very fix the
   release advertises) and a manual pass over the panel tabs on the Release
   build (078 was verified by a GUI driver against the Debug build).
4. `build.cmd full release sign setup`, tag `v0.1.8`, GitHub release, then the
   winget manifest — see item 6 for the state of the catalogue submission.
   **Before publishing, switch the `Publish to winget` workflow off by hand
   on GitHub** (Actions ▸ the workflow ▸ `···` ▸ *Disable workflow*; decided
   2026-09-20) so that publishing 0.1.8 does not open a second pull request
   while #426090 (0.1.7) is still open. A `release: published` event is not replayed, so once #426090 has
   settled: *Enable workflow*, then *Run workflow* with `version: 0.1.8`,
   `submit: true` — or `tools\winget\publish.ps1 -Version 0.1.8 -Submit`
   locally.

Item 2 (Restart Manager) was implemented as feature 080 inside 0.1.8,
without a version bump of its own; its changelog text is in the same section.
Its owed human step 1 — the elevated, machine-wide update with the program open —
belongs to this ship gate too: it is the first thing a `winget upgrade` of the
released 0.1.8 will do on a user's machine.

</details>

---

## 0. Antivirus findings — ✅ DONE (feature 077, 2026-09-17)

> A user reported that Avast "blocked and removed" the program and that the
> installation "had a problem". Feature 076 analysed it
> ([`076-avast-false-positive-review/review-report.md`](076-avast-false-positive-review/review-report.md)):
> most likely reputation-based blocking of a brand-new product (six-week-old
> certificate, Inno Setup 7 loader), plus two real product findings. Feature
> 077 fixed both: the Visual C++ runtime now ships with the product (no
> release before it could start on a machine without the redistributable),
> and start-up no longer patches kernel32 in memory. Record:
> [`077-fix-antivirus-findings/fix-log.md`](077-fix-antivirus-findings/fix-log.md).
>
> **Left open by 077, in priority order:**
>
> 1. **Clean-machine start** (owed human step): install the signed build on
>    a Windows VM/Sandbox that has no "Visual C++ 2015-2022 Redistributable
>    (x64)" entry and confirm the main window and all 20 plugins; steps in
>    `077-fix-antivirus-findings/quickstart.md`, "Owed human step".
> 2. ~~**Minidumps have never worked**~~ — **closed by feature 079**: the
>    crash-reporting helper was removed altogether (antivirus false
>    positives); the text report is the deliverable, now named and announced
>    by the application itself. If minidumps are ever wanted, they would be
>    a new in-process feature (`MiniDumpWriteDump` from the system
>    `dbghelp.dll`), not a revival of the helper.
> 3. ~~**Old bug report blocks start-up**~~ — **closed by feature 079** with
>    the helper: nothing scans the report folder at start-up any more.
> 4. **Reputation work** (076 section 6): Avast Whitelisting Program
>    registration and false-positive submission of each release, SHA-256 +
>    VirusTotal link in the release notes, an "antivirus warning?" FAQ page,
>    keep the same certificate at renewal (2027-08-03).
> 5. **Cosmetics** (076 section 3.4): version resources for `7zwrapper.dll`
>    and `sqlite.dll` (the `HIGH_PRIORITY_CLASS` item went away with the
>    helper in feature 079), `/guard:cf`, remove the dead pre-Vista
>    `ZwQueryInformationProcess` path.
>
> Ship gate for 077: the version bump came with feature 078 and the drafted
> changelog text is now in the `## [0.1.8]` section of
> `CHANGELOG.md`; publishing is section R above.

## 1. Small hardening batch — ✅ DONE (feature 075, 2026-09-02)

> Delivered as `075-fix-small-hardening`: six commits, one per defect, each
> independently reviewed. Record:
> [`075-fix-small-hardening/fix-log.md`](075-fix-small-hardening/fix-log.md).
> `069/REMAINING-WORK.md` §3 is now empty of open items.
>
> Two things worth carrying forward. **The independent review earned its place
> again**: D5's first version ran a UTF-8 walk-back unconditionally and ate the
> last character of an untruncated code-page name — reachable through the ANSI
> `fcremote.exe` — while the build, 1,353 tests and the evidence probe were all
> green. And **the GUI half is still owed**: this session could not drive the
> application or a debugger, so scenarios S1–S5 in
> [`075-fix-small-hardening/quickstart.md`](075-fix-small-hardening/quickstart.md)
> remain a human step, as does gate G6. They are small and they fold naturally
> into item 3's sweep below.
>
> The original entry follows, unchanged.

<details>
<summary>Original entry</summary>

### Small hardening batch (hours, one feature)

Five defects recorded in `069/REMAINING-WORK.md` §3. Feature 069 could not fix
them because its charter (FR-001) forbids a change without a finding behind it —
they were found while doing other work. **The first was re-checked at `f4cefa1`
and is still present.**

| Site | Defect |
|---|---|
| `src/codetbl.cpp:873` | `if (len > bufferLen) len = bufferLen - 1;` must be `>=`. A conversion name of exactly `bufferLen` bytes writes `buffer[bufferLen]` — an **out-of-bounds write**. Callers pass `codeName[200]` (`viewer3.cpp:58`) and `DefaultConvert[200]`; unreachable with the shipped names (longest 33 B), but it is a real overflow. **Verified present.** |
| `src/viewer3.cpp:3291` | `GetCodeType`'s return value ignored → `defCodeType` used uninitialised when the tables are not loaded |
| `src/zip.cpp:3292` | `GetConversionTable` result not NULL-checked (pre-existing, no new exposure) |
| `src/plugins/filecomp/controls.cpp:24,39` | unbounded `strcpy(Text, text)`, safe today only because both sides are `[MAX_PATH]` |
| `src/viewer3.cpp:30,35` | `lstrcpyn(caption, FileName, MAX_PATH)` can cut a path over 259 bytes mid-character, dropping the whole caption to the legacy draw — the F-P4-02 fixes do not help very long non-ASCII paths |

Fold in one unrelated one-liner: `src/plugins/codeview/test/run_tests.cmd`
reports `RESULT: FAILURES` on this machine before *and* after feature 074
(Node v20.18.0 treats `web/worker.js` as CommonJS; passes with
`--experimental-detect-module`, default from Node 22.12 — see
`074/fix-log.md`). While that line is red it masks real regressions.

**Why first**: best risk-to-cost ratio in the whole list, and it makes the test
output trustworthy for everything below.

</details>

## 2. Restart Manager — upgrading over a running instance (winget P1) — ✅ DONE (feature 080, 2026-09-20)

> Delivered as `080-restart-manager-upgrade`; record:
> [`080-restart-manager-upgrade/closing-report.md`](080-restart-manager-upgrade/closing-report.md).
> **The diagnosis below was wrong in its cause.** The reproduction showed that
> the update over a running 0.1.7 failed because of `salmon.exe`: a process
> without a window cannot be closed by the Restart Manager, which then fails
> the whole request at once without asking the main program. Feature 079 had
> already removed the helper, and with it the failure in the idle case. What
> this feature really fixed: the request ran the *interactive* exit, so a
> running file operation or an open plug-in viewer left a prompt on an
> unattended machine and the program exited by itself later; the program was
> not started again after the update; and upgraded installations kept
> `salmon.exe` (where the obvious `[InstallDelete]` remedy re-creates exit 5 —
> measured). Left open, in
> [`080-restart-manager-upgrade/REMAINING-WORK.md`](080-restart-manager-upgrade/REMAINING-WORK.md):
> five human steps (elevated machine-wide update, a real `winget upgrade`, the
> interactive installer, real sign-out/shutdown, a servicing restart) and one
> feature-sized follow-up — **a plug-in-visible "unattended close"** so that
> plug-in *viewer* windows can close silently instead of making the program
> decline the update (plug-in interface 107).
>
> The original entry follows, unchanged. **Start at item 3 now.**

<details>
<summary>Original entry</summary>

The one item that **will fail for real users** as soon as the package is in the
catalogue (checked 2026-09-20: PR #426090, version 0.1.7, is still open —
pipeline passed, waiting for moderator validation — so nobody can hit this
through winget yet). With the program open, `winget upgrade` (which passes
`/SUPPRESSMSGBOXES`) hits the Abort/Retry/Ignore prompt, answers **Abort**, and
the install rolls back with exit 5. Not a regression — it never mattered while
upgrading meant running the installer by hand. Full evidence in
`072/REMAINING-WORK.md` P1.

Scope note taken at HEAD: the plumbing already exists — `src/mainwnd3.cpp:6220`
onwards has an elaborate `WM_QUERYENDSESSION` / `WM_ENDSESSION` handler
including critical-shutdown handling and configuration backup. The work is
therefore *behave correctly on `ENDSESSION_CLOSEAPP` and actually close* (the
crash-reporting helper that was also listed as holding files is gone since
feature 079), and a decision on `RegisterApplicationRestart` — **not** writing
Restart Manager support from scratch.

First step is reproduction with 072 `quickstart.md` §2b and confirming exit 5.
The design question is whether the panels' state survives the restart; the API
is the easy half. Scope is `src/`, not `setup/`. Worth a feature of its own.

</details>

## 3. The owed on-screen sweeps (a GUI session, maintainer only)

**Now the first item.** 0.1.8 is in users' hands, so these verify a shipped
build rather than gate one.

> **The reference trees are gone** (checked 2026-09-24): `build\tandemcommander\`
> holds only `Release_x64` and `translator` — neither `Release_x64_prefix069\`
> nor `Debug_x64_prefix081\` exists any more. The sweeps below can still be
> run against the current build; only the side-by-side comparisons need a
> reference, and it can be rebuilt from git in a separate worktree:
> **069** → `64dcbb5` (the commit before 069's first), Release x64;
> **081** → `6b4d7af` (the commit before 081's first), Debug x64. Do this
> only for a row that actually needs the comparison.

From the 0.1.8 ship gate (section R, step 3), most valuable first:

- **Clean-machine start** — item 0, point 1, above; it verifies the very fix 0.1.8
  advertises (the Visual C++ runtime shipped with the product).
- **The elevated machine-wide update** with the program open —
  `080/REMAINING-WORK.md` P1 step 1 (and its steps 3–5 whenever convenient).
- **A manual pass over the panel tabs on the Release build** — 078 was
  verified by a GUI driver against the Debug build only.

The features complete on paper and unverified on screen:

- **084 (working archivers)**. The probes are ready but were **not run**
  (maintainer's request, 2026-10-01): close your own Tandem Commander, then
  run:
  - `specs/084-archiver-cleanup/probe/make_cfg_fixtures.ps1 -Exe "C:\Program Files\Tandem Commander\tandemcommander.exe" -OutDir specs\084-archiver-cleanup\probe\fixtures\cfg`;
  - `gui_probe.ps1 -Exe <Debug build>`, which covers Autoconfiguration,
    ARJ/Unicode browse and extract through 7-Zip, hiding, Cancel and the
    0.1.8 → 106 migration. Both back up and restore
    `HKCU\Software\Tandem Commander` and verify the restore.

  Then do the visual pass of the Pack/Unpack dialogs and the archiver
  configuration pages in English and Czech, and RAR packing with WinRAR 7.x
  (084 `quickstart.md` §4, §6).

- **069 §4** — the 068 sweep W1–W20 in the Czech UI and then the Hungarian UI
  (proving 069 did not disturb what earlier features repaired), then V-01…V-24
  from its `quickstart.md`. Its side-by-side reference `Release_x64_prefix069\`
  no longer exists (see the note above). Start with
  V-01 (command line), V-09 (help and `config.reg` under an accented install
  path), V-11 (cloud entries).
- **075** — scenarios S1–S5 and gate G6 from its `quickstart.md`.
- **070 §3** — the codeview quickstart scenarios plus the runtime halves of the
  corpus checks (hostile content, request log, key sweep, copy fidelity,
  encoding matrix, performance budgets). The corpora are already written.
- **074** — the human steps listed at the end of its `fix-log.md`.
- **081 §A–D** — the Markdown Viewer's regression pass after it moved onto the
  shared WebView2 host: `specs/081-mdview-shared-webhost/quickstart.md`. The
  machine-checkable half is done (builds, guards, 29 generator assertions, the
  content-policy compatibility check, and probes for the hostile corpus, the
  keeper, cross-plugin warmth and close-during-cold-start); what needs a person
  is the network monitor over the hostile corpus, the *Keep the rendering
  engine ready* toggle and plugin unload/reload through the Plugins Manager,
  the dark menus, and an eye over rows A1–A10 against the pre-migration
  build — `Debug_x64_prefix081\` is gone, rebuild it from `6b4d7af` if the
  comparison is wanted (the pixel diff `render_diff.ps1` already found 0 of
  729,144 pixels different, so this is a confirmation, not the evidence).
- **078/079's 88-byte Debug-CRT leak at exit** — not a sweep, but seen only in
  such sessions: 081 found a leak of exactly that size in `CTcWebKeeper` and
  fixed it. If the report never appears again under a DBWIN listener, record
  it as explained; if it does, it was something else.

Items 1 and 2 are done, so the sweep now runs against a final state.
A sweep failure is a finding: back through fix → independent review → gates.

## 4. Architectural debt to repay before it is copied — ✅ DONE (feature 088, 2026-10-01)

> Both entries were delivered as one interface bump, `088-plugin-interface-107`
> (record: [`088-plugin-interface-107/fix-log.md`](088-plugin-interface-107/fix-log.md)):
> plug-in interface **107** adds `IsUnattendedClose` and
> `SetWindowClosesUnattended`; the four viewer plug-ins declare their windows
> and close them silently, so an update no longer fails because a viewer is
> open; `SAL_MAX_PATH_UTF8` is in the plug-in headers, the buffer comments are
> corrected, PictView and the Database Viewer no longer overflow on a deep
> path. **Left**: windows of the non-viewer plug-ins (File Comparator, Batch
> Renamer, Disk Map, Checksum) still decline an update. **Owed** (joins
> item 3): `088-plugin-interface-107/quickstart.md`. Note (105 review,
> 2026-10-04): its `viewers_probe.ps1` fails 3 rows (Code Viewer / Markdown
> Viewer close, `ERROR_FAIL_SHUTDOWN`) on the hidden desktop - identically
> with the 088 code rebuilt; its 10/10 ran on the visible desktop. Re-run it
> there (or in a VM) to tell the desktop from a WebView2 runtime change.

*Original entries:*

- **A plug-in-visible "unattended close"** (`080/REMAINING-WORK.md` P2). Since
  feature 080 the program declines an installer's close request while *any*
  plug-in window is open — including the Code Viewer's, which is the default
  for F3 — because the viewer plug-ins ask *"close the windows?"* when they are
  unloaded and the core can neither answer for them nor tell a viewer from an
  FTP transfer. An update therefore fails (cleanly) whenever a viewer window
  was left open. The remedy is a small addition to the plug-in interface
  (version 107): a signal that the close is unattended, honoured by the four
  viewer plug-ins. Documented first, per the constitution.

- ~~**mdview onto the shared `src/common/webhost/`**~~ — ✅ **DONE** (feature
  081, 2026-09-20). Both viewer plugins now run on `src/common/webhost/`;
  mdview's own copy is deleted and the browser-arguments set has one
  definition instead of three. mdview gained the shared host's stricter
  posture (content policy on the document, downloads and permission requests
  refused, the close-during-cold-start guard) with no visible change for
  ordinary documents. Records:
  [`081-mdview-shared-webhost/closing-report.md`](081-mdview-shared-webhost/closing-report.md).
  **Its on-screen regression pass is owed and has joined item 3.**
- **`GetNextFileNameForViewer`'s buffer contract.** The header documents *"at
  least MAX_PATH"* (`src/plugins/shared/spl_gen.h:2703`); the core fills it with
  `SAL_MAX_PATH_UTF8` (`src/salamdr6.cpp:205,223`). A plugin that believes the
  header takes a buffer overflow on a long path, and the constant lives in a
  core-only header, so a plugin cannot even name the right size. Correct the
  comment and export the constant — before another plugin copies the documented,
  wrong size. **Still present at `4899f0d`** (checked 2026-09-24:
  `spl_gen.h:2703` says MAX_PATH, `salamdr6.cpp:205,223` copy up to
  `SAL_MAX_PATH_UTF8` = `3 * SAL_MAX_PATH_W + 1`, defined in
  `src/common/salpath.h`). Both entries in this item change the
  plugin-facing headers, so doing them as **one** interface-107 feature
  means one version bump instead of two.

## 5. Encoding: cluster B-2 — ✅ core identity DONE (feature 092, 2026-10-01); the rest below

**Done by 092**: finding an item by name, the overwrite/delete/rename
decisions, core path identity and the sorted name lists use the file
system's rule (`SalNameEqualOrdinalCI` and friends in
`src/common/salunicode.*`; contract
`specs/092-name-identity-unicode/contracts/name-identity.md`). The guard rule
`acp-byte-table-on-name` is strict. What 092 left, each with its reason in
`specs/092-name-identity-unicode/fix-log.md`:

- **Delete-then-retry trusts a name rule alone** (`worker.cpp DoMoveFile`,
  `fileswn5.cpp RenameFileInternal`): on a share whose server folds *more*
  than Windows (NFC/NFD on a macOS server) a rename onto another spelling of
  the same file answers "already exists", and the overwrite branch deletes
  the target - which is the source. Older than 092, narrowed by it. The fix
  is a file-identity test (volume serial + file index) before the delete.
  ✅ **Fixed by feature 103 (2026-10-03)**: reproduced first with a local
  WebDAV server that folds names like a macOS server - the build before 103
  deleted the file on four routes (Quick Rename, F6, F6 without the overwrite
  question, F6 between two server names of one file = copy onto itself +
  delete). Now the file system's identity decides; a rename/move onto
  (possibly) itself goes through a self-checking temporary name, a copy onto
  itself is refused ("Cannot copy/move a file to itself."); Renamer and
  PictView's rename too. Left, each with its reason in
  `specs/103-same-file-delete-guard/fix-log.md`: a real macOS/Samba share
  was not driven; a copy on a file system without file ids refuses a
  *different* file of equal size and times (WebDAV twins); a copy onto a
  symbolic link that points at the source is now refused; hard links on file
  systems that do not share share-mode state between two paths; the ZIP
  plug-in can overwrite a selected source with the new archive's file after
  "overwrite?" (another defect class) - ✅ **fixed by feature 106
  (2026-10-04)**: measured worse than recorded - a multi-volume ZIP whose
  volume name was a selected file lost that file on a Copy too, and with
  Move broke the archive and deleted the other files; a declined
  "overwrite?" for volume 2+ deleted the declined file; and the core's Pack
  dialog *Overwrite* deleted a selected file named like the archive (every
  packer). All refused now by file identity before anything is touched;
  record `specs/106-zip-overwrite-source/fix-log.md`. Found by 106, not
  fixed (small, no loss): a failed multi-volume pack leaves the volumes it
  already wrote; multi-volume into `name.zip` that exists (Add) leaves the
  last volume as `name.z0N` silently (the rename never replaces); the 7-Zip
  plug-in packs a selected archive into itself and Move then shows "Delete
  Error (32)" for it; the ZIP plug-in's *Add* of a selected archive reports
  a sharing violation instead of a clear text; `translate.merge --module zip`
  would re-lay out 510 controls of the committed ZIP translations (tool drift
  since build 185); the Pack dialog's refusal reuses "Cannot copy a file to
  itself." - it names no file and does not say that deselecting the archive
  (or the folder holding it) helps (needs a new core string); a case-sensitive folder still refuses
  `a.txt` -> existing `A.txt` (now provably another file - could offer the
  overwrite). Found by 103, pre-existing: **PictView's Rename fails with
  error 32 for the image it shows** (the viewer keeps it open; both builds,
  NTFS and WebDAV) - ✅ fixed by feature 111 (2026-10-05), see sub-item 5
  queue entry 1. Found by 103's second review: renaming or moving a
  symbolic link onto the file it points at **deleted that file** (both older
  builds) - fixed in 103; **moving a FOLDER onto an alias of itself between
  two roots** (`C:\x\F` -> `\\localhost\C$\x\`) deleted its empty subfolders,
  and a hard link reached through an alias got "overwrite x with x?" then
  error 32 - ✅ **both fixed by feature 107 (2026-10-04)**: measured wider -
  the empty subfolders went also through a junction, the 8.3 spelling and a
  WebDAV NFC/NFD spelling on the SAME drive, and a move INTO itself or into
  its own subfolder through `\\localhost\C$`, `\\127.0.0.1\C$`, a mapped
  drive, SUBST or a second WebDAV server name moved the whole content one
  level down and deleted the originals (nothing lost, the tree gone). Now
  the folder identity decides at script build ("Cannot move a directory to
  itself." / "Cannot copy a file to itself.") plus a worker check for merges
  below the top level; one hard link through an alias is "the same file";
  record `specs/107-folder-alias-move/fix-log.md`. Found by 107, decided or
  small (no loss): a folder COPY into itself or its own subfolder still
  makes a snapshot copy (by name as always; a decision to confirm); a
  refused folder copy says "Cannot copy a file to itself." and a move into a
  subfolder "Cannot move a directory to itself." (clearer texts need two new
  core strings through the translation pipeline); a local folder and a
  WebDAV path of the same folder served from this machine are not
  recognised as one (folder with an id vs. one without = two file systems,
  chosen to avoid refusing uploads to WebDAV); two DIFFERENT WebDAV servers
  holding one path below the server name with equal folder times count as
  one (a refused merge - narrowed by the review's SF2 from "any folder of
  that name"); a folder reachable through two shares of a NAS that gives
  each share its own volume serial is not recognised (the old behaviour);
  restoring an UNCHANGED file from a snapshot is refused "to itself" by
  103's file rule (nothing to restore; folders from a snapshot merge);
  snapshots and FAT volumes could not be driven here (no admin, no FAT
  volume) - rule tests only; two differently named `@GMT` folders joined
  by a junction could hide an alias (reasoned, not reproducible here); a merge costs ~1 ms more per folder over SMB;
  paste and drag & drop cannot be driven on the hidden desktop (clipboard /
  mouse) - a person's pass is owed (`107/quickstart.md` step 5). Still open: the Renamer's refusal says "already exists" (a plug-in
  cannot reach the core's "to itself" texts without a new string or an
  interface change).
- **The panel sort comparator is intransitive with "Use locale" off** for
  names mixing ASCII and other characters (found by the 092 research; not
  touched - it changes what users see).
- **`CSalamanderDirectory`** (archive and plug-in listings) compares names by
  the byte fold, with a case-sensitive mode chosen by the plug-in.
- **The services exported to plug-ins** (`StrICmp`, `IsTheSamePath`,
  `SalParsePath`, `PathsAreOnTheSameVolume`, ...) keep the byte fold: a
  plug-in may pass text that is not UTF-8.
- **The disk cache** keys an archive by its lower-cased (byte fold) name and
  compares keys with `strcmp`; `PrepareCloseCurrentPath` must agree with it.
  One change, both sides. `CCacheDirData::DetachTmpFile` has no caller - ✅
  **fixed by feature 109 (2026-10-04)**, see queue entry 1 below.
- **`CFileTimeStamps::AddFile`** (`salamdr3.cpp`): `ĥ.txt` and `Ĺ.txt`
  edited from one archive collide - ✅ **fixed by feature 108 (2026-10-04)**:
  measured worse than recorded - the second edit's temporary copy was deleted
  under the editor and never offered (7z: edit lost), and with ZIP the second
  MEMBER vanished from the archive (19,015 colliding BMP pairs on CP1250:
  `Í`/`Ý`, `ž`/`ż`, CJK, Cyrillic `м`/`о`, ...). Now an edited member is its
  temporary copy by the file system's rule (`src/common/salarcedit.h`), and a
  folder typed in another case (`arc.zip\DIR` for `Dir`) is mapped to the
  stored spelling in F4 / F3 (one member was two copies, the second update
  replaced the first edit). Record `specs/108-archive-edit-name-collision/fix-log.md`.
  For ZIP the fix holds only when the two copies share one temporary folder
  (see entry 2); for 7z both edits are always packed back.
  **Found by 108 - queue (serious first): next feature 109 = entry 1 (data
  loss), then 110 = entry 2.**
  1. **(feature 109) The disk cache keys an ARCHIVE by its code-page lower-cased name**
     (`fileswn5/6.cpp` key, flushed by that prefix in `fileswn2/9.cpp`; the
     "other panel on the same archive?" test before the flush is `StrICmp`):
     `ĥ.zip` and `Ĺ.zip` in one folder share their members' copies - F4 on
     `x.txt` of `ĥ.zip` in one panel, then on `x.txt` of `Ĺ.zip` in the other
     opened the FIRST archive's copy, and the update packed it into `Ĺ.zip`:
     its `x.txt` silently replaced by the other archive's (measured, ZIP and
     7z, every release; `108/probe/namecoll_probe.ps1 -CacheKeyRows`). This is
     the disk-cache item above - one change, both sides. ✅ **Fixed by feature
     109 (2026-10-04)**: measured worse - leaving the archives packed the one
     shared copy into BOTH archives, F3 in the second was given the first's
     file (also with a pending edit), and the flush by bare key PREFIX
     (`p.zip` flushed `p.zip.zip`) marked a copy being edited there out of
     date, so the next F4 extracted the member over the edit (lost silently,
     every release). One key function now (`GetArchiveCacheKey`,
     `SalNameIdentityKeyAlloc`: key equality = `SalNameEqualOrdinalCI`, legacy
     text behind 0xFF), both builders, both flushes (key + `\`) and the
     "other panel shows this archive?" test; one archive through a SUBST drive
     or `\\localhost\C$` takes the other panel's key when the file identity
     says it is one file (`SalArchiveSharesCacheKey`). Also fixed: with both
     panels on one archive its copies survived a change of the archive on disk
     (F3 showed the old content; every release; the first 109 version extended
     it to the SUBST/UNC pair - caught by its own probe row) - now kept for the
     other panel only while the archive still has the size and time the other
     panel listed. Review (REJECT): an equal key was trusted although it could
     come from a spelling that now names another file (SUBST / network drive
     re-pointed) - now decided by `SalArchiveCacheKeyChoice`, else a unique key.
     Plug-in cache services unchanged. Record
     `specs/109-disk-cache-archive-key/fix-log.md`.
  2. **(feature 110) The ZIP plug-in matches names by `CompareStringA` + `NORM_IGNORECASE`
     on UTF-8** (`zip/add.cpp` update matching; `del.cpp:62` delete,
     `extract.cpp:329` extract selection): packing `ĥ.txt` into an archive
     holding `Ĺ.txt` asks "overwrite?" for both and replaces `Ĺ.txt` - an
     edit of ONE member of such a pair (probe rows `hL1_zip`, `hL2_zip`, both
     builds) or an F5 of such a file into the archive deletes the other member;
     so does an edit of BOTH when their copies land in two temporary folders
     and are packed in two calls (108 review row `split_zip`: edit `d/Ĺ.txt`,
     then root `ĥ.txt`, then root `Ĺ.txt` - the third copy needs a new `SAL`
     folder, and the second call deletes the already-packed `ĥ.txt`; both
     builds; `split_7z` passes on 108);
     answering *Skip* to the question that pairs the wrong files can delete the
     edited member itself (it is already marked for deletion, then not added).
     Needs a UTF-8-aware, plug-in-side identity (header-only, like
     `splunicode.h`; the ZIP project cannot compile shared `.cpp` files).
     ✅ **Fixed by feature 110 (2026-10-05)**: the old comparison was
     LINGUISTIC (`CompareStringA` on UTF-8 bytes read as code-page text), not
     the byte fold - 21,925 BMP pairs on CP1250 (`110/probe/zip_collision_set.py`).
     Measured worse: with both members present F5 asked twice and deleted both
     (one added); in a Unix ZIP the added file was renamed to the OTHER
     member's spelling and then "not found"; `f_skip` lost the edited member
     and stored the other twice. Rule `src/common/salzipname.h` (header-only,
     092's rule: WTF-8 ordinal on UTF-16, legacy text by the old comparison,
     never equal across, no byte-length guard; covered folder bytes counted on
     the member) in `add.cpp CZipPack::MatchFiles` (both comparisons, Move
     folder test, Unix spelling copy with a growing buffer). Behaviour change:
     accented case pairs (`č`/`Č`) and the 7 different-length pairs are one
     name now (overwrite question, as `a`/`A`). Delete and extract were
     correct for files (index + exact name); their folder tests follow the
     core's listing and stay (entry 4 / `CSalamanderDirectory`). Also fixed:
     `CountFilesInRoot` (`del.cpp`) ignored case in a Unix ZIP - with `Dir/`
     and `DIR/` deleting the last file of `Dir` lost the folder. Probe
     `110/probe/zipname_probe.ps1`: 42/42 (build before 10 PASS / 21 FAIL,
     review rows 3 / 8). Review SF1 (old defect, newly reachable for accented
     case pairs): with several members one name with the added file, *Yes*
     for one and *Skip* for another deleted the first and never stored the
     new file (`{ax, Ax, AX}`, every release) - fixed (`CAddInfo::Replaced`).
     Recorded, not fixed: a read error answered *Skip* during `PackFiles`
     after its member was deleted (`DeleteFiles` runs first) loses that
     member (pre-existing, also with one member; needs an I/O error).
     Record `specs/110-zip-plugin-name-matching/fix-log.md`.
     ✅ **That note fixed by feature 113 (2026-10-05) - GUI runs pending**:
     wider by code reading - with the "temporary copy" option off the member
     was lost also on *Cancel* at the error, on a cancelled progress and on
     any error while packing. Rule: a member is deleted only if the file
     replacing it is stored. Temporary-copy mode (default): a member whose
     file is not stored is copied back from the untouched original, byte for
     byte, its central record relocated (`src/common/salzipmember.h`, zip64
     handled; review S1: the plug-in's `UpdateCentrDir` now finds the zip64
     block by its id - it assumed it first); in-place mode: pack first, then delete the stored files'
     members (the compaction moves the added files too, uninterruptible).
     Also fixed: an AES-encrypted file that could not be read was stored
     incomplete after *Skip* (a Move deleted its source) and *Cancel* did not
     stop (the MAC write replaced the error); a use-after-free on the Skip
     path; a double free of `NewCentrDir`; a 12-byte data descriptor (no
     signature) moved the rest of the archive 4 bytes, or silently cut the
     first 4 bytes of the untouched member after it (both modes) - now refused
     before anything moves (reviews S2, R1; the bound fails closed).
     Performance note (not changed): that bound and the existing
     `UpdateCentrDir` walk the central directory once per deleted member -
     about n x d; one sorted offset array with bisection would serve both. 7-Zip plug-in, same loss: a file
     replacing an archived item gets *Retry* / *Cancel* only; a file skipped
     in a Move is no longer deleted. Probe
     `113/probe/zipskip_probe.ps1` (37 rows, locks held by the probe) written,
     not run yet (`113/quickstart.md`). Record
     `specs/113-zip-read-error-skip/fix-log.md`.
  2a. **Found by 109's review, not fixed (data loss, narrow): a flush marks a
     copy with a pending edit out of date.** `CDiskCache::FlushCache` marks every
     still-referenced copy of the key out of date, also one the OTHER panel
     has open for editing (tracked in its `CFileTimeStamps`, not packed yet) -
     after an own update in one panel (every release), and before 109's review
     fix after a forced reopen. A re-F4 / F3 of that member in the other panel
     before that panel's own reopen (which packs first) makes
     `CCacheData::GetName` delete the copy and extract the member over the edit;
     the time stamp then matches, nothing is offered. Not driven (the other
     panel's auto refresh closed the window in every probe row). Needs a design:
     the cache does not know `CFileTimeStamps` - e.g. never mark out of date a
     copy that a panel tracks as edited, or let `GetName` refuse to recreate it.
     ✅ **Fixed by feature 112 (2026-10-05) - GUI runs pending**: the panel's
     lock on a tracked copy is a core-only EDIT lock (`crtCacheEdit`); a flush
     that meets it defers the out-of-date mark until the last edit lock goes
     (`src/common/salcacheedit.h`, `CSalCacheEditPin`); without an edit lock
     the cache behaves as before (plug-ins unchanged, saltests parity). The
     R-side trigger (R re-entering the changed archive) was already closed by
     109's unique key. Probe `112/probe/diskcache_edit_probe.ps1` (refresh off /
     `net use` drive, controls, the left panel's refresh detected) written, not
     run yet (`112/quickstart.md`). Left: a per-member warning when the member
     itself changed in the archive since F4 (needs a string). Trade-off recorded
     (review SF1): an UNTOUCHED tracked copy is pinned too - after another
     program changed that member, L (not refreshed) shows and edits the old
     content until Ctrl+R / leave (before 112 its next F3 / F4 re-extracted the
     new one); telling "untouched" from "editor open with unsaved work" by the
     F4 stamp could lose an edit (2-s FAT times, tools restoring the write
     time) - the per-member warning would cover it.
  3. Small, recorded: `AddFile` returning FALSE on low memory makes
     `ExecuteFromArchive` release the copy the editor is using (pre-existing).
     Also from 109's re-review: two panels whose archives have the same
     spelling, equal size AND equal modification time (100 ns) across a
     re-pointed drive letter still share copies (pre-existing; fix: store each
     panel's file identity at open); the out-of-memory fallback of the cache
     key can re-create sharing without a check (hardening: refuse F3/F4).
     ✅ The first part (`AddFile` on low memory) **fixed by feature 112**:
     `AddFile` returns three results; `ExecuteFromArchive` tracks and locks the
     copy BEFORE launching the editor and refuses ("Insufficient memory.") a
     copy it cannot track; also fixed there: the stamp of an existing copy was
     read after the launch (a fast editor's write counted as "unchanged"). The
     two 109 re-review items stay open.
  4. For the `CSalamanderDirectory` item (108 review NIT 3/4): tar extracts
     case-sensitively (`plugins/tar/untar.cpp:330`, `strcmp`) under a
     case-insensitive listing - a Linux tarball with `Dir/a.txt` and
     `DIR/b.txt` shows one merged `Dir`; a typed `arc.tar\DIR` + F3 on `b.txt`
     worked before 108 by luck and now asks for `Dir\b.txt` (not found; from
     the listing it failed before too). The stored-spelling rule never
     triggers for accented case pairs (`Č`/`č`): the byte-fold listing does
     not find such a typed folder at all. From 110: F5 / an edit into a
     merged ZIP folder (`ĥ/` + `Ĺ/` shown as `ĥ`) now adds `ĥ/x.txt` beside
     `Ĺ/x.txt` (before: replaced `Ĺ/x.txt`, i.e. moved it) - the panel then
     shows two `x.txt` there; the ZIP plug-in's delete/extract folder tests
     (`common.cpp MatchFiles`, byte fold) must change together with the
     listing.
- **`UnselectItemWithName`** (`fileswn0.cpp`) uses the linguistic comparison
  plus a byte-length guard for an identity look-up.
- **`CFindIgnore::Contains`, relative kind** - a substring search by the byte
  fold; the full and rooted kinds are converted.
- **A guard rule for the old comparison functions on names** (092 task T006):
  needs an annotation on every legitimate use first.
- **The comparator's cost**: 2x (ASCII) to 16x (every name accented) the
  byte fold in a sort, because text that is not WTF-8 orders by a property of
  the whole string. A comparator that stops at the first difference needs
  the contract's order for such text redefined.
- **An unbounded `StrICpy` into `buf[MAX_PATH]`** at `fileswn9.cpp` - ✅
  feature 095 (2026-10-02): **it could not overrun** - the archive's path is
  cut to 259 bytes before it gets there (proof in
  `specs/095-archive-path-buffers/fix-log.md`). The four sites now use heap
  strings anyway, and that fixed a real defect (Enter / F4 on a file whose
  archive path + inner folder + name reach about 520 bytes). Found by 095,
  **not fixed**:
  - **An archive whose path is longer than 259 bytes could not be opened,
    and the silent cut could open another archive** - ✅ fixed by feature 097
    (2026-10-03): refused instead of cut, and archives handled by plug-ins
    built for interface 107 open at any length (driven up to 20,000 bytes).
    Left by 097, each with its reason in
    `specs/097-archive-long-path/fix-log.md`: external archivers and older
    plug-ins stay at 259 bytes; the inner path stays at 259 bytes (the
    listing structure is shared with plug-ins); clipboard copy from and
    drop/paste into an archive with a 260+ byte name are refused (the two
    fields are process-internal and could be widened); `-L`/`-R`/`-A` and hot
    paths stay at 519 bytes; a real mouse drag was not driven.
  - **Found by the 097 review** - ✅ all fixed by feature 098 (2026-10-03):
    the crash in deep folders, the Change Directory overrun, the UNC-copy
    overruns, the 7zip message buffers, and a **silent loss** the
    measurement found behind item 4: packing a selection with sub-folders
    from a folder of 260+ bytes left out their contents.
  - **Found by 098 - queue:**
    1. **Moving a folder that contains a junction into an archive deleted
       the files behind it** - ✅ fixed by feature 099 (2026-10-03) for F6,
       drag and drop and paste into archives, and for upload-Move in the FTP
       plug-in (the same loss); SFTP was already safe. Not driven: a real
       drag, the clipboard route, Explorer as the drag source (if Explorer
       itself deletes after a Move drop, that is outside the program).
    2. Change Directory to a file whose NAME has a CJK character: the viewer
       title showed `?` - ✅ measured and fixed by feature 100 (2026-10-03):
       focus and file were always right; every code-page window title lost
       such characters. **Found by 100, not fixed:** the tray icon tip
       (`SetTrayIconText`, `mainwnd1.cpp`) copies UTF-8 into the ANSI tip
       structure - every non-ASCII name there is garbled and can be cut
       mid-character; the File Comparator cannot open files named outside the
       code page at all (its dialog and `fcremote.exe` are code-page
       programs) - ✅ **fixed by feature 102** (2026-10-04): every route
       (dialog, history, drop, Browse, `fcremote`) delivers the exact name;
       no best-fit look-alike can be compared; channel version 2. Found by
       102, recorded: closing the program within ~1 s of `fcremote` starting
       it asks "plugin has rejected to unload. Force?" (also before 102);
       the 093 dialogs probe's Find-menu rows fail on the hidden desktop in
       about one run of three on the builds before and after 102 (8 rows,
       "no menu") - a probe/desktop artefact, the other runs pass 139/0.
    4. **The small leftovers** (tray tip, clipboard paste length, silent UNC
       copy, share matching, drag image, accurate link/too-deep messages) -
       ✅ feature 101 (2026-10-03). Found by 101, not fixed: the Find
       window's *Look in* field cuts paths at 259 bytes; a message box with a
       very long path breaks lines inside words; every clipboard *copy*
       command fails silently when the clipboard cannot be opened; packing a
       tree whose names *relative to the packed folder* exceed 259 bytes
       skips those sub-folders with a message (the archiver plug-in interface
       takes relative names of at most `MAX_PATH`).
    5. **Same class as 102 in other plug-ins** (found by the 102 research,
       not examined): code-page window subclasses on text controls in ftp
       (3), zip (4), 7zip (1); `CreateFileA` fallbacks after a failed UTF-8
       conversion in checksum, peviewer, renamer; `DragQueryFile` in dbviewer
       and pictview; PictView's `salpvenv.exe` helper (probably dormant) -
       ✅ **fixed by feature 104** (2026-10-04). Measured first: the listed
       sites were mostly not defects (the eight subclasses carry no names
       except ZIP's path label, the `DragQueryFile` calls only count, the
       fallbacks are unreachable, `salpvenv.exe` is not built, shipped or
       reachable); the real ones were elsewhere and worse - the **Renamer**
       renamed to a best-fit look-alike (`voilà.txt` -> `voila.txt`, asking to
       overwrite the existing one) and its mask `Ж*.txt` became the wildcard
       `?*.txt`; the plug-in services `SafeGetOpenFileName` /
       `SafeGetSaveFileName` / `GetTargetDirectory` (code page by contract)
       made the Database Viewer, FTP, ZIP, PictView, CAB and Undelete open,
       overwrite or copy into look-alike files and folders. Now two
       header-only Unicode pickers (`splfiledlg.h`), winliblt's field reader
       refuses instead of re-reading through the code page, the Renamer's
       edits and loops are Unicode. Record:
       `specs/104-plugin-unicode-names/fix-log.md`. **Found by 104, not fixed
       (queue):**
       1. **PictView *Save As* onto an existing file deletes it and then
          fails** ("replace?" Yes -> the file is gone, "Unable to save the
          image": the WIC engine of 006 cannot write images). Data loss in
          every release since 006 - first. ✅ **Fixed by feature 105**
          (2026-10-04). Measured first: worse than recorded - Save As saved
          *nothing* in any format (14 types offered, none written) and the
          existing file was deleted before every failure (also in a folder
          that denies creating files, also when canceled). Now the image is
          written into `pvXXXX.tmp` next to the target and only the complete,
          flushed file replaces it (`ReplaceFileW`, `src/common/salsafereplace.h`);
          any failure leaves the target byte-identical with the system's reason.
          Save As writes BMP, PNG, JPEG, GIF, TIFF through the Windows encoders
          with the dialog's depths, compressions, JPEG quality/subsampling,
          rotation/flip and a UTF-8 comment; the type list is filtered to those
          five; saving over the shown image works (its decoder lets the file
          go, the window reloads); *File > Save As* is back in the menu. Same
          one-step replace for *Regenerate thumbnail* and the *Rename*
          overwrite (both unreachable). Record:
          `specs/105-pictview-saveas-loss/fix-log.md`. **Found by 105, not
          fixed (small):** PictView's *Rename* of the shown image still fails
          with 32 (103) - `WicDetachSource` (105) now gives the way to fix it
          (release, rename, reopen); every PNG/TIFF/ICO source asks the
          "alpha channel will be lost" question and "2 colors"/CCITT is never
          offered, because the WIC engine reports every image as 32-bit; the
          wallpaper commands cannot work (no file output in the engine, and
          `%WINDIR%` is not writable for a user). ✅ **All fixed by feature 111**
          (2026-10-05), with the 105 review's NITs (a second window showing the
          file blocked the save; TIFF tag 270 UTF-8 only; the JPEG COM NUL; zoom
          and mirror reset by the reload). Measured first: *Delete* of the shown
          image failed too ("File in use"), and the wallpaper commands of the
          build before called `SPI_SETDESKWALLPAPER` with NULL even after their
          failed save (code reading - never run on the maintainer's session).
          Every PictView window showing the file lets its decoder go for Rename,
          Delete and the replace of Save As and takes the file back (re-attached
          without a reload when unchanged; reopened at the same zoom when
          rewritten; `<Deleted>`); the engine reports the source's real format
          (`WicGetSourceFormat`) to Save As, the title and Image Information;
          the wallpaper is a BMP in `%LOCALAPPDATA%\Tandem Commander` set with an
          explicit path (dry-run seam `TC_PICTVIEW_WALLPAPER_DRYRUN` for probes);
          TIFF comments outside ASCII also in XMP `dc:description`, the JPEG COM
          without its NUL. Record: `specs/111-pictview-shown-image/fix-log.md`.
          **Found by 111, not fixed:** (a) PictView's pipette and histogram
          read the engine's 32-bit rows as 3 bytes per pixel
          (`PixelAccess.cpp`, `Colors >= PV_COLOR_TC24`) - the pipette shows
          another pixel's color with shifted channels and the histogram counts
          misaligned bytes of 3/4 of each row, every release since 006 (code
          reading; display only); (b) a Rename onto another file that a second
          PictView window shows still fails "in use" (only the renamed file's
          windows let go; nothing lost); (c) the GIF comment extension gets
          UTF-8 bytes although GIF89a defines 7-bit ASCII (no Unicode
          alternative in GIF).
       2. Undelete applies a FAT rule (`Replace0xE5`) to UTF-8 names: a
          name whose first byte is 0xE5 (CJK U+5000-U+5FFF) is listed with
          `$` and restored under a garbled name; its volume layer enumerates
          mount points with code-page calls (a mount folder named outside
          ASCII fails or resolves to another volume). ✅ **Fixed by feature
          114 (2026-10-05) - GUI runs pending**: measured wider by code
          reading - the rule ran on the UTF-8 names of every file system
          (listing, path, restore), FAT short names were OEM bytes handed on
          as UTF-8, deleted FAT long names were lost unless their first
          character was ASCII (the lost byte guessed in the ANSI code page),
          and `GetVolumePathNameA` on a UTF-8 path through such a mount folder
          opened the PARENT's volume. The rule now lives on the raw bytes of a
          FAT short-name entry (`src/common/salfatname.h`, record flag
          `FR_FLAGS_NAMEFIRSTCHARLOST`), the volume layer is W
          (`salvolpaths.h`), names WTF-8; the sweep fixed an NTFS stream-name
          buffer (a long stream name joined the default stream) and several
          overruns. Probe `specs/114-undelete-names/probe/undelnames_probe.ps1`
          (FAT12 / exFAT images made by `make_images.py`, no admin) written,
          runs owed; mount points need admin (person step, `quickstart.md`).
          **Found by 114, not fixed** (`fix-log.md`): (a) Restore Encrypted
          Files ignores `SalPathAppend` failures - a source path over 519 /
          259 bytes recurses into the same folder until the stack overflows
          and restores the parent's files into the target (`restore.cpp`);
          (b) `RemoveDuplicateFiles` compares DSSize bytes of a 44-byte
          structure (over-read; the duplicates of {All Deleted Files} are
          never removed); (c) name identity in the restore list / FAT
          numbering is `_stricmp` (ASCII only - 092's rule would apply).
       3. FTP password fields keep a code-page subclass (`CPasswordEditLine`)
          and *Show password* reads through the code page (094 left FTP
          passwords). Since 104 an FTP password, user name, address or
          initial path whose UTF-8 form exceeds its buffer (100 bytes for
          a password or user name - 51+ Czech letters) is not taken: Connect
          and Close say "too long" and keep the dialog open, the stored value
          stays; the build before stored it as code-page bytes (such a saved
          password still works while it is not retyped - except *Retry* in
          the login-error dialog, which refuses it). Widening the FTP
          buffers (and the protocol's byte form of such a password) is open.
       4. checksum: a checksum list written in the code page with accented
          names reports those files as missing (no encoding detection of the
          list file).
       5. Smaller: the plug-in folder picker does not resolve NetHood folder
          shortcuts (the core's `GetTargetDirectory` did); diskmap's log
          window shows paths garbled; the ZIP comment field is code page by
          format; the ZIP self-extractor routes are unreachable (no SFX
          package shipped) and stay code page; PictView's *Regenerate
          thumbnail* cannot work at all since 006. Disabled plug-ins (listed
          in `specs/104-plugin-unicode-names/research.md` 3) are unchanged.
    3. Smaller: the link warning names an unreadable or too-deep folder as a
       "Link"; at depth 1,001 the message says "too long"; clipboard paste
       refuses 520+ bytes although Change Directory takes any length; the
       Find window's UNC copy fails silently when too long; share-prefix
       matching cuts at 259 bytes; dragging a directory-line component at
       7,500+ characters would build a ~280,000-pixel drag image - ✅ all
       fixed by feature 101 (2026-10-03), see sub-item 4.
  - **An edited file with a non-ASCII name was not packed back into its
    archive** - ✅ confirmed (every release) and fixed by feature 096
    (2026-10-02): a code-page look-up of a UTF-8 path in
    `CFileTimeStamps::CheckAndPackAndClear`. Not driven by its probe: the RAR
    external packer with such a name; a critical shutdown with an edited
    file.
- The mask matcher, *Change Case* (B-4), the x86-only code and the
  install-path chain (`plugins2.cpp`, ANSI operands) are not part of B-2's
  identity work.

**B-1 (text typed into windows) - DONE where it was real (feature 093,
2026-10-02).** Measured in the product first: with the common-controls 6
manifest the edit and combo controls are Unicode controls even in dialogs
created through the code-page entry point, so the "88 of 90 ANSI dialogs"
were never lossy as a class. What was lossy and is fixed: typing in Find
Files and in Configuration (code-page message loops), Find's *Look in* /
*Containing* and the in-place list editor (a code-page helper attached), the
command line, and the 7zip plugin's password (handed to the engine garbled
since 0.1.0). Record: `specs/093-unicode-dialogs/fix-log.md`. Left, each
with its reason there:

- **A real-keyboard pass** (owed to a person, `093/quickstart.md`): Alt+F and
  the other menu mnemonics in the main window and in Find, typing with a
  Czech layout, an input method editor, a mouse drag onto the command line.
  The probes post window messages; they cannot press keys.
- **The main window's title** showed `?` for a folder named outside the code
  page - ✅ fixed by feature 100 (2026-10-03).
- **The loops that only drain messages during an operation** and the menus'
  own modal loops are still code-page loops: a character typed ahead into a
  field while one runs is converted; an accented mnemonic typed while the
  menu bar is active is matched only when the keyboard layout's code page is
  the system's.
- **Message boxes, master-password dialogs** (their bytes feed a key - must
  not change), **other plug-ins' dialogs** (FTP, SFTP, ZIP, renamer, ...):
  untouched. **The ZIP and SFTP password prompts were examined and fixed by
  feature 094 (2026-10-02)** - they did not have the 7zip plugin's defect,
  but the ZIP plugin used `?` for every character outside the code page.
  Left by 094 (`specs/094-plugin-password-encoding/fix-log.md`):
  the self-extractor's own prompt (a separate program; a password outside
  the code page stays `?` in a self-extracting archive, and items added to an
  existing self-extracting archive are keyed the new way); the FTP plugin's
  101-byte password buffer (51 or more two-byte characters fall back to a
  code-page read) and its *Show password* read; a real OpenSSH server and a
  key passphrase were not driven; a system with a double-byte or UTF-8 code
  page.
- **The plug-in copy of the dialog library** (`winliblt`) still falls back to
  a code-page read when the text does not fit the buffer.
- **7zip plugin**: an archive that mixes the two password forms stays mixed
  (the plug-in cannot re-encrypt); a damaged item under a two-form password
  is decoded up to three times; the Test command's second pass, cancel during
  a retry pass and RAR were not driven.

What the section said before 092:

Of the five systemic clusters in `069/REMAINING-WORK.md` §1, **B-2 is the only
one with a ready work list**: the guard rule `acp-byte-table-on-name`, 33
report-only hits — code-page byte tables behind all name comparison, so
`Č.txt` != `č.txt`. B-1 (ANSI dialog windows) is the natural second: its surface
is fully enumerated for the command line in 069 `research.md` R2 (word-break
callback ABI, the `WM_CHAR` unit, five selection-offset sites, and
`editwnd.cpp:577`). B-4 (`AlterFileName`, which also drives Change Case and so
renames on disk) is the highest-risk fix in the review — last.

Not part of this: **F-P1-05, the archive listing display encoding**
(`pack1.cpp`). Three attempts produced three defects, including a fatal listing
abort and a split directory tree; the listing must move as a whole. See 069 §0b.

## 6. Cheap winget housekeeping, once PR #426090 has settled

`072/REMAINING-WORK.md` gates everything on whether the submission is merged;
check that first, and change nothing under `tools/winget/templates/` while it is
open. **State on 2026-09-30**: #426090 (0.1.7) is still open; the moderator
asked to drop `DisplayVersion` (same value as `PackageVersion`), done the same
day in the PR and in `templates/installer.yaml.in` (072 fix-log), now awaiting
re-review.

**Read `072/REMAINING-WORK.md` § P0 before anything else here.** An audit on
2026-09-30 found what the moderators are likely to ask next — 0.1.7 does not
start without the VC++ runtime, they ask for the current release (0.1.8),
possibly a `PrivacyUrl` (prepared by feature 083: `PRIVACY.md` + template
field, ready once merged and pushed) — plus two manifest inaccuracies (`DisplayName`,
installer-level `ProductCode`) and stale records. Recommended: re-point
#426090 to 0.1.8. Recorded only, not acted on — the maintainer decides.
Run any 0.1.8 submission from `main`, not tag `v0.1.8` (its template still
has `DisplayVersion`).

- **Submit 0.1.8** (was section R, step 4) once #426090 has settled: in
  GitHub Actions *Enable workflow*, then *Run workflow* with
  `version: 0.1.8`, `submit: true`, or run
  `tools\winget\publish.ps1 -Version 0.1.8 -Submit` locally. The
  `release: published` event of 2026-09-20 will not be replayed.

- ~~**P4** — `actions/checkout@v4` / `actions/upload-artifact@v4` run on the
  deprecated Node 20. Bump all four workflows together so the repository does
  not end up with two conventions.~~ ✅ **DONE (feature 091, 2026-10-01)** —
  static verification only; a real run is owed. **Found on the way, decision
  needed**: `pr-comments-guard.yml` has failed at checkout for every labelled
  fork pull request since 2026-07-20 (`actions/checkout` now refuses fork
  code under `pull_request_target` on every major): opt in with
  `allow-unsafe-pr-checkout: true` or retire the upstream comment-translation
  workflows — analysis in `091-workflow-actions-node/fix-log.md`.
- **P2** — `--scope user` has **never actually been tested**; the entry was
  blamed for the first validation failure and the machine-only manifest then
  failed identically, which refuted that. The procedure needs no new release,
  but it needs Windows Sandbox and a branch of its own.
- **P3** — `checkver` still points at Open Salamander's site. Point it at the
  GitHub Releases API or drop it and declare winget the update channel: a
  product decision, not code.

---

## 7. Privacy-relevant defects found by feature 083 — ✅ F1–F7 FIXED (feature 085, 2026-10-01)

> Delivered as `085-privacy-defect-fixes`; record:
> [`085-privacy-defect-fixes/fix-log.md`](085-privacy-defect-fixes/fix-log.md).
> `PRIVACY.md` was updated in the same change. F1 (passwords in typed
> addresses kept in history — five sinks, two of which 083 had not named:
> the Copy/Move target and Find's *Look in*), F2 (remote-image requests —
> and the probe showed the old code also **answered a Negotiate/NTLM
> challenge with the user's Windows logon**), F3 (navigation without a
> click, with a second layer in mdview's generator because the engine's
> user-gesture flag is *transient*), F6 (salts), F7 (SFTP cancelled prompt),
> F4 (decided 2026-10-01: crash upload off — one options builder for host
> and keeper) and F5 (contract text) are done. The first independent review
> of F1 was **REJECTED** (a password with a space or quote kept in full);
> fixed and re-reviewed.
>
> **Left open:**
>
> - **The GUI steps** `085/quickstart.md` G1–G6 — join item 3's sweep.
> - ~~**F9** — the FTP anonymous-login e-mail default `name@someserver.com` is
>   sent to anonymous servers (`src/plugins/ftp/ftp3.cpp:508`). Not asked
>   for.~~ ✅ **DONE (feature 090, 2026-10-01)**: the placeholder is
>   `anonymous@example.com` (a domain reserved for examples); a stored old
>   placeholder is replaced on load, a user's own address is kept. Record:
>   `090-ftp-anonymous-default/fix-log.md`.
> - **F8** — withdrawn: the shell-extension registration only runs if
>   `utils\salext*.dll` exists (`src/salamdr1.cpp:4384-4398`); 0.1.8 ships
>   neither DLL, so nothing is registered or left behind. Open question
>   instead: is the missing copy hook (drag out of archives into Explorer)
>   intended?
> - ~~**New (found by 085's review): the ZIP plugin's AES salt comes from
>   `rand()` seeded with time ^ pid**~~ — ✅ **DONE (feature 086,
>   2026-10-01)**: AES salts and the ZIP 2.0 header now come from
>   `SalGenRandom` (`src/common/salrandom.h`, shared with the password
>   manager); GUI round trip owed (`086/quickstart.md`). Original note: (`src/plugins/zip/crypt.cpp:118-127`,
>   used by `zip/add.cpp:1632` for AES-encrypted archives). A repeated salt
>   with the same password repeats the AES-CTR keystream. Same fix as F6
>   (`BCryptGenRandom`); small, but it changes archive-creation code, so it is
>   a feature of its own. The vendored 7-Zip has its own generator and belongs
>   to item 8.
> - SFTP: `sftp:user:password@host` is not split (the plugin takes
>   `user:password` as the user name and would echo it into the panel path);
>   unreachable in practice because the server rejects such a user. Recorded
>   in `085/research.md` R1, not changed.

<details>
<summary>Original entry</summary>

Found while inventorying every place the product stores or sends data for
`PRIVACY.md`; evidence and detail in
`specs/083-privacy-policy-winget/research.md` § Side findings. `PRIVACY.md`
describes the product *as it is*, including these — so **fixing any of them
means updating `PRIVACY.md` in the same change** (CLAUDE.md, *Privacy
statement*).

- **F1 — highest priority. A password typed as part of an address
  (`ftp://user:password@host`) is saved in plain text** — in FTP Quick
  Connect's Address history, and equally in the Change Directory history
  (`src/dialogs3.cpp:1200-1202`) and the command-line history. Quick Connect
  (`src/plugins/ftp/dialogs1.cpp:925-931` stores the raw typed text;
  `ftputils.cpp:530` accepts `user:password@host`). The only path by which a
  password reaches the registry unprotected without "Save password". Fix:
  strip the password part before adding to history.
- **F2** — mdview remote-image requests identify as `OpenSalamander-mdview`
  (`src/plugins/mdview/webglue.cpp:96`, pre-rebrand); the comment at `:79`
  says "no cookies" but WinHTTP session cookies are not disabled; the HTTP
  status is not checked.
- **F3** — probably a Markdown document can make the viewer open the default
  browser without a click (`<meta http-equiv="refresh">`; raw HTML passes
  through `htmlgen.cpp:514`; `webhost.cpp:266-281` forwards every cancelled
  navigation to `OnActivateLink` without checking `IsUserInitiated`). Fix:
  check `get_IsUserInitiated` there; confirm with a GUI test. `PRIVACY.md`
  already discloses it ("a document can also trigger this by itself").
- **F4** — WebView2 engine crash dumps are sent to Microsoft by default
  (`IsCustomCrashReportingEnabled` not set) — decide consciously.
- **F5** — `architecture/11-webview2-integration.md:59-60` says the user data
  folder "holds cache only"; it also holds cookie/history/storage databases.
- **F6** — password-manager salts come from `rand()` seeded with time^pid
  (`src/pwdmngr.cpp:37-47`).
- **F7** — SFTP: cancelling the master-password prompt silently saves the
  secret scrambled only (`src/plugins/sftp/dialogs.cpp:851-856`).
- **F8** — withdrawn: the shell-extension registration only runs if
  `utils\salext*.dll` exists (`src/salamdr1.cpp:4384-4398`); 0.1.8 ships
  neither DLL, so nothing is registered or left behind. Open question
  instead: is the missing copy hook (drag out of archives into Explorer)
  intended?
- **F9** — the FTP anonymous-login e-mail default `name@someserver.com` is
  sent to anonymous servers (`src/plugins/ftp/ftp3.cpp:508`). *(Done as
  feature 090.)*

</details>

## 8. Upgrade the vendored 7-Zip 16.04 → 25.x — ✅ DONE as 26.03, with RAR (feature 087, 2026-10-01)

> Delivered as `087-7zip-2603-rar`; record:
> [`087-7zip-2603-rar/fix-log.md`](087-7zip-2603-rar/fix-log.md). The
> maintainer chose **26.03** (25.x would have kept the 2026 handler CVEs),
> the engine reduced to **7z, RAR and RAR5** (so the 7zip plug-in does
> **not** read ARJ/LZH — 084 R5 is answered: they stay with the 7-Zip
> console), and `7zwrapper.dll` removed. Feature 084's stage S7 is part of
> it: RAR opens through the plug-in with no other program installed. Found on
> the way and fixed: item names were used unchecked (a crafted 7z could write
> outside the target folder — all earlier versions), *Unpack and delete*
> deleted a 7z archive after a failed item, the *Word size* setting never
> reached the engine. **Owed** (join item 3): the GUI pass of
> `087-7zip-2603-rar/quickstart.md` — RAR on a fresh and on an upgraded
> configuration (associations), the password prompt, the links message.
> **Left**: a Unicode password prompt belongs to encoding cluster B-1 -
> ✅ done by feature 093 (and the password was garbled for every non-ASCII
> character, not only limited to the code page).
> ✅ **The three items below are DONE (feature 089, 2026-10-01)** — record:
> [`089-7zip-followups/fix-log.md`](089-7zip-followups/fix-log.md): the shared
> plug-in converters (`splunicode.h`) are WTF-8 for every plug-in; 7z update
> matching uses the cleaned names; the core lets an installed plug-in take
> over the association of an external archiver that can never browse, so
> `rar;r##` ends the same on updated and new configurations. Owed (item 3):
> `089-7zip-followups/quickstart.md`.
> Found by the reviews and **not fixed** (older, small; one batch):
> (a) the 7zip plug-in converts names with strict UTF-8, not the house WTF-8
> (a lone surrogate in an archived name becomes U+FFFD; feature 066's rule);
> (b) adding to a 7z archive matches the *stored* names, so a file added into
> a folder whose name had to be cleaned becomes a second item instead of
> replacing; (c) on an upgraded configuration `rar` shares the plug-in's `7z`
> association record, so packing into a RAR archive from the panel is refused
> instead of going to WinRAR as on a fresh configuration — fixing it needs a
> core-side association migration.

*Original entry:*

**Prerequisite of feature 084 stage S7** (RAR out of the box,
`specs/084-archiver-cleanup/`). The 7zip plug-in's engine
(`src/plugins/7zip/7za`, `7za/c/7zVersion.h:4` = **16.04**) is built from
source and already contains 7-Zip's RAR/RAR5 handlers, decoders and RAR crypto
(`7za.dll.vcxproj:263-265/451-461/489-493`). The plug-in does not use them
today. Exposing them on 16.04 would make two known remote-code-execution
defects reachable from any downloaded `.rar`:
- CVE-2018-10115 (RAR handler, fixed in 18.05);
- CVE-2025-53816 (RAR5 heap overflow, fixed in 25.00).

The upgrade is also worth doing for the 7z handling the product already ships.
It touches all `.7z` handling (`7zclient.cpp`, `update.cpp`, `extract.cpp`,
the wrapper DLL), so it is a feature of its own and needs `/speckit-specify`.
The maintainer accepted, on 2026-10-01, shipping and exposing the RAR decoder
under its "unRAR restriction" licence term (084 `research.md` R4). Feature 084
documents that in `doc/third_party.txt`. **Feature 084 is otherwise complete**
(stages S1–S6; `closing-report.md`). After this upgrade, its stage S7
(T046–T053) exposes RAR through the 7zip plug-in. At the same time, decide
whether that plug-in should also read ARJ/LZH (084 research R5).

---

## Recorded, deliberately not on the list

- **Help footers.** 236 of 237 manual pages still carry the 2023 Open Salamander
  footer; only `configuration_cmdshell.htm` (feature 071) was authored after the
  rebrand. Cosmetic, and a single mechanical pass whenever it is wanted.
- **The nine sites 069 chose not to convert**, each with a written reason
  (`069/REMAINING-WORK.md` §2) — `icncache.cpp:796`, the DROPFAKE/CLIPFAKE pair
  that must move together with the ANSI shell extension, the `shellib.cpp`
  `STRRET` sites, `execute.cpp:1213`, the nine `IDS_VIEWERTITLE` call sites, and
  three pieces of dead code. These are decisions, not oversights; re-opening one
  needs a reason the file does not already answer.
- **073** (Command Shell environment) is parked as not reproduced.

## Protocol

`specs/069-finish-encoding-fixes/contracts/fix-protocol.md` is binding for any
fix in items 1, 4 and 5, and it earned its keep: of four review batches, two
were rejected, both for regressions the fixes themselves introduced. Its two
highest-value rules: **check the site is still defective at HEAD first** (three
of 069's 34 items were already fixed, and five site references were stale), and
**enumerate the consumers yourself before writing anything**.
