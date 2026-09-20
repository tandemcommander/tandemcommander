# Next Work — consolidated continuation

**Written**: 2026-09-02 · **Baseline**: `main` at `f4cefa1` (0.1.7, build 191)
**Revised**: 2026-09-20 — release status corrected: **0.1.7 is the last
published version**; 0.1.8 (build 192) exists only in the tree. Feature 080 is
in `main` (`71e340b`).

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

## R. Release 0.1.8 — not done yet

Features 075, 077, 078, 079 and 080 are all in `main` (080 fast-forwarded at
`71e340b`, 2026-09-20) but **unpublished**. The version was
bumped to 0.1.8 / build 192 by feature 078 (`spl_vers.h`,
`setup/tandemcommander.iss`, `CLAUDE.md`), and `CHANGELOG.md` collects all five
features in one section headed `## [0.1.8] — unreleased` (the changelog drafts
that 075 and 077 left in their fix-logs are applied there). No `v0.1.8` tag,
no installer in `setup/output/`, no winget manifest.

Ship gate, when the release is decided:

1. Replace `unreleased` in the changelog heading with the release date and
   delete the *Not released yet* paragraph under the lead
   (`tools/winget/publish.ps1` reads the date from that heading and the
   release summary from the lead paragraph); drop *not released yet* from the
   build-192 row in `spl_vers.h` and from the version line in `CLAUDE.md`.
2. Pre-release review of the `v0.1.7..HEAD` delta (the 056 pattern) — the
   delta contains a feature the size of panel tabs.
3. The owed human steps that gate a release rather than follow it: the
   **clean-machine start** (item 0.1 below — it verifies the very fix the
   release advertises) and a manual pass over the panel tabs on the Release
   build (078 was verified by a GUI driver against the Debug build).
4. `build.cmd full release sign setup`, tag `v0.1.8`, GitHub release, then the
   winget manifest — see item 6 for the state of the catalogue submission.

Item 2 (Restart Manager) was implemented as feature 080 inside the unreleased
0.1.8, without a version bump; its changelog text is in the same section. Its
owed human step 1 — the elevated, machine-wide update with the program open —
belongs to this ship gate too: it is the first thing a `winget upgrade` of the
released 0.1.8 will do on a user's machine.

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
> changelog text is now in the `## [0.1.8] — unreleased` section of
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

Three features are complete on paper and unverified on screen:

- **069 §4** — the 068 sweep W1–W20 in the Czech UI and then the Hungarian UI
  (proving 069 did not disturb what earlier features repaired), then V-01…V-24
  from its `quickstart.md`. The side-by-side reference build
  `build\tandemcommander\Release_x64_prefix069\` (347 files) is preserved for
  exactly this and is ageing; **do not delete it before the sweep**. Start with
  V-01 (command line), V-09 (help and `config.reg` under an accented install
  path), V-11 (cloud entries).
- **070 §3** — the codeview quickstart scenarios plus the runtime halves of the
  corpus checks (hostile content, request log, key sweep, copy fidelity,
  encoding matrix, performance budgets). The corpora are already written.
- **074** — the human steps listed at the end of its `fix-log.md`.

Best done **after** items 1 and 2, so the sweep runs once against a final state.
A sweep failure is a finding: back through fix → independent review → gates.

## 4. Architectural debt to repay before it is copied

- **A plug-in-visible "unattended close"** (`080/REMAINING-WORK.md` P2). Since
  feature 080 the program declines an installer's close request while *any*
  plug-in window is open — including the Code Viewer's, which is the default
  for F3 — because the viewer plug-ins ask *"close the windows?"* when they are
  unloaded and the core can neither answer for them nor tell a viewer from an
  FTP transfer. An update therefore fails (cleanly) whenever a viewer window
  was left open. The remedy is a small addition to the plug-in interface
  (version 107): a signal that the close is unattended, honoured by the four
  viewer plug-ins. Documented first, per the constitution.

- **mdview onto the shared `src/common/webhost/`** (`070/REMAINING-WORK.md` §2).
  `src/common/webhost/` exists and codeview uses it; `src/plugins/mdview/webview.cpp`
  is still its own copy — verified at HEAD. The product ships two copies of the
  WebView2 host, the exact duplication
  `architecture/11-webview2-integration.md` exists to prevent. Its acceptance
  (the 021 lockdown re-verification and the 065 keeper scenarios) is a manual
  GUI pass, so it pairs naturally with item 3.
- **`GetNextFileNameForViewer`'s buffer contract.** The header documents *"at
  least MAX_PATH"* (`src/plugins/shared/spl_gen.h:2703`); the core fills it with
  `SAL_MAX_PATH_UTF8` (`src/salamdr6.cpp:205,223`). A plugin that believes the
  header takes a buffer overflow on a long path, and the constant lives in a
  core-only header, so a plugin cannot even name the right size. Correct the
  comment and export the constant — before another plugin copies the documented,
  wrong size.

## 5. Encoding: cluster B-2 next

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
open.

- **P4** — `actions/checkout@v4` / `actions/upload-artifact@v4` run on the
  deprecated Node 20. Bump all four workflows together so the repository does
  not end up with two conventions.
- **P2** — `--scope user` has **never actually been tested**; the entry was
  blamed for the first validation failure and the machine-only manifest then
  failed identically, which refuted that. The procedure needs no new release,
  but it needs Windows Sandbox and a branch of its own.
- **P3** — `checkver` still points at Open Salamander's site. Point it at the
  GitHub Releases API or drop it and declare winget the update channel: a
  product decision, not code.

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
