---
description: "Task list for feature 123 - New Version Check"
---

# Tasks: New Version Check

**Input**: Design documents from `/specs/123-new-version-check/`
**Prerequisites**: plan.md, spec.md, research.md (R1–R13), data-model.md, contracts/ (update-source, stored-state, ui), quickstart.md

**Tests**: included. The plan's verification strategy requires `saltests` coverage of the pure rules and a GUI probe against a fixture server (project practice since feature 075); they are not optional here.

**Organization**: by user story. US1 = start-up notification (P1), US2 = Help menu command (P2), US3 = About dialog (P2), US4 = the option (P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: different files, no dependency on an unfinished task
- Paths are relative to the repository root
- House rules that apply to every code task: new source files are UTF-8 with BOM and clang-formatted; new comments in English; texts for wide sinks come from `LoadStrW` (never `SplU8ToWAlloc(LoadStr(..))`); every finished step is recorded in `specs/123-new-version-check/fix-log.md`

---

## Phase 1: Setup

**Purpose**: files, project wiring and the test fixture, so that everything after compiles and can be probed

- [X] T001 Create `specs/123-new-version-check/fix-log.md` (running record: date, branch, baseline `saltests` count from an actual run, table of tasks done) and keep it current after every task
- [X] T002 Add empty compilable `src/common/salupdcheck.h` + `src/common/salupdcheck.cpp`, `src/updcheck.h` + `src/updcheck.cpp`, `src/upddlg.h` + `src/upddlg.cpp` to `src/vcxproj/salamand.vcxproj` and `salamand.vcxproj.filters`; add `salupdcheck.cpp` to `src/vcxproj/saltests/saltests.vcxproj`; link `winhttp.lib` and `delayimp.lib` with `/DELAYLOAD:winhttp.dll` in the main project (all configurations, x64); `build.cmd` green
- [X] T003 [P] Save the real answer of `https://api.github.com/repos/tandemcommander/tandemcommander/releases/latest` (0.1.8, fetched with `curl -H "User-Agent: TandemCommander-research"`) as `specs/123-new-version-check/probe/fixtures/real-0.1.8.json`
- [X] T004 [P] Write `specs/123-new-version-check/probe/updserver.py` (standard library only): serves `/latest/<name>` for every fixture named in quickstart.md § B (generated from `real-0.1.8.json` by mutation: newer, same, older, prerelease, draft, noasset, asset-not-uploaded, foreign-url, foreign-html-url, bad-tag, dup-tag, oversized, truncated, html, empty, 403, 429, 500, redirect, auth401, hang, slow), and appends every request with all headers to a log file given by `--log`

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the rules, the stored state and the request — everything every story uses. No user-visible change yet.

**⚠️ No user story work before this phase is complete**

- [X] T005 Implement the pure types and rules in `src/common/salupdcheck.{h,cpp}` per data-model.md: `CSalUpdVersion` (parse from tag `v<a>.<b>.<c>` and from stored `<a>.<b>.<c>`, 1–5 digits per part, total order), `CSalUpdRelease`, `CSalUpdResult`, `SalUpdInstallerUrl` / `SalUpdReleaseNotesUrl` (constructed addresses, contracts/update-source.md), `SalUpdParseUtcTime` (`YYYY-MM-DDThh:mm:ssZ` → FILETIME, real dates only), `SalUpdClassify`, `SalUpdStartupNoticeWanted`, `SalUpdKnownState`, `SalUpdAutoCheckDue` (24 h after an answered attempt, 1 h after an unanswered one, a time in the future ignored). No Windows state, no allocation beyond fixed buffers
- [X] T006 Implement the strict JSON reader and `SalUpdParseLatestRelease` in `src/common/salupdcheck.cpp` per research R3/R4 and contracts/update-source.md: full grammar recognition with a nesting limit of 32, string unescaping incl. `\uXXXX` surrogate pairs, 512-byte limit per extracted string, top-level fields `draft`, `prerelease`, `tag_name`, `published_at`, `html_url` and `assets[].name/state/browser_download_url`; a duplicate top-level `tag_name` fails; `html_url` and the asset address must equal the constructed ones exactly; the asset must be `uploaded`
- [X] T007 Add the `salupdcheck` test group to `src/saltests/saltests.cpp`: version parse/order (leading zeros, 6 digits, signs, spaces, missing parts); time parsing (invalid month/day/hour, missing `Z`); the embedded real 0.1.8 record parses to 0.1.8 / 2026-09-20; a mutation sweep over that record (each byte deleted, each structural character replaced) never yields a release with a different version or address and never crashes; every negative fixture class of quickstart § B; nesting depth 32/33; unpaired `\u` surrogates; throttle rule table incl. clock in the future and the option off; `SalUpdKnownState` after "user installed the newer version". Run `saltests`, record the new count in `fix-log.md`
- [X] T008 Implement the stored state in `src/updcheck.{h,cpp}` per contracts/stored-state.md: `CUpdateState` load/save against `HKCU\…\0.1\Update Check` through the house registry facade (wide), each value written individually and at once, defensive reads (wrong type, unparsable text, time in the future = absent), and `UpdateCheck_ClaimAutomatic()` that reads, applies `SalUpdAutoCheckDue` and writes `Last Attempt` under the named mutex `Local\TandemCommanderUpdateCheck`; a store that cannot be written is not an error
- [X] T009 Implement the request in `src/updcheck.cpp` per contracts/update-source.md and research R2: one synchronous WinHTTP GET with the fixed `User-Agent` `TandemCommander-updatecheck`, `Accept` and `X-GitHub-Api-Version` headers; `WINHTTP_FLAG_SECURE`; cookies, authentication and redirects disabled (a request that cannot be configured so is not sent); timeouts 5/5/5/8 s and a 12 s overall deadline; status → result class table; only `200` read, 256 KB cap; then `SalUpdParseLatestRelease` + `SalUpdClassify`. Debug builds only: honour `TC_UPDATECHECK_URL` (loopback, plain HTTP, anything else ignored) and `TC_UPDATECHECK_PRETEND_VERSION`
- [X] T010 Implement the worker and its life cycle in `src/updcheck.cpp`: one worker thread at a time with a reference-counted context (house thread conventions: call-stack object, `HANDLES`), flags *manual* and *attached manual*, result stored per contracts/stored-state.md rule 4 and posted to the main window as `WM_USER_UPDATECHECK_DONE` (new message id in `src/mainwnd.h`) with a heap result the receiver frees; `UpdateCheck_Cancel()` closes the request handle from the UI thread; `UpdateCheck_Shutdown()` cancels and waits at most 1 s; a result posted to a window that no longer exists is freed
- [X] T011 Probe the request alone: a small console driver or a Debug command-line switch that runs T009 once against `probe/updserver.py` for every fixture and prints the result class; record the table and the server's header log in `fix-log.md` (expected: the contract's headers exactly, no `Cookie`, no `Authorization` after `auth401`, no second request after `redirect`, `hang` ends at the deadline). Include the negative control of feature 085: the same request with the disable-features call removed must show the `Authorization` header, proving the probe can see it

**Checkpoint**: rules tested, request proven against hostile answers, state persists — stories can start

---

## Phase 3: User Story 1 — Told about a new version at start-up (P1) 🎯 MVP

**Goal**: with the check on (default), a start finds a newer release and shows the designed notification without delaying or interrupting the user.

**Independent test**: Debug build with `TC_UPDATECHECK_PRETEND_VERSION=0.1.7` (or the `newer` fixture): start → main window usable → notification within 10 s with both versions, the date and working *Download* / *Release notes*; `same` and every failing fixture → nothing.

- [X] T012 [US1] Add the notification dialog template `IDD_UPDATENOTICE` and its control ids to `src/lang/lang.rc` + `src/lang/lang.rh` per contracts/ui.md § 1 (`DIALOGEX`, `DS_SHELLFONT`, `FONT 8, "MS Shell Dlg"`, caption, close button; placeholder statics for the header band, the two versions and their captions, the date line, the *Release notes* link, the explanatory text, the check box, three buttons with access keys D / L / S / C) and the strings it needs to `src/lang/texts.rc2` + `lang.rh` — ids in free slots of existing bundles (research R13: no new bundle that shifts ordinals)
- [X] T013 [US1] Implement `CUpdateNoticeDialog` in `src/upddlg.{h,cpp}` (modeless, owner = main window): header band painted with the About dialog's helpers (`AboutAndEvalDlgCreateBkgnd` pattern in `src/logo.cpp` — refactor the shared painting into a function both dialogs call rather than copying it), heading font ≈1.4× and version font ≈2× derived from the dialog font and the window DPI, the available version in the brand orange and the installed one muted, the arrow drawn; light and dark theme as About; date via `GetDateFormatEx` long date in the user's locale; `CHyperLink` for *Release notes*; accessible names for the two version statics; `WM_DPICHANGED` handled if the house dialogs do
- [X] T014 [US1] Implement the notification's actions in `src/upddlg.cpp` per data-model.md § Notification choices: Download (constructed installer address through wide `ShellExecute`, close; on failure a message with the address and a Copy button, window stays), Release notes link, Remind Me Later = Esc = close button, Skip This Version (writes `Skipped Version`), check box writes `Check At Startup` at once; window properties `TandemCommander.UpdateNotice` and `SALCLOSEAPP_WINDOW_PROP` set on create and removed on destroy
- [X] T015 [US1] Start the automatic check in `src/salamdr1.cpp` right after `RegisterRestartForUpdates()`: `UpdateCheck_OnStartupComplete()` → `UpdateCheck_ClaimAutomatic()` → worker. Nothing but registry reads on the UI thread; no call into WinHTTP there (the delay-loaded DLL must load on the worker)
- [X] T016 [US1] Handle `WM_USER_UPDATECHECK_DONE` for automatic results in `src/mainwnd3.cpp`: on `surNewer` and `SalUpdStartupNoticeWanted` schedule the notification; show rules of contracts/ui.md § Showing — not while the main window is disabled or a menu is open (1 s timer `IDT_UPDATENOTICE`, id in `src/mainwnd.h`), not if another instance's notification exists (`EnumWindows` + `GetProp`), activate only when the main window is foreground, the command line is empty and `GetLastInputInfo` is older than 2 s, otherwise `SW_SHOWNOACTIVATE`; every other automatic result is silent
- [X] T017 [US1] Close paths in `src/mainwnd3.cpp` / `src/mainwnd4.cpp`: main window closing and the unattended close of feature 080 destroy the notification without a question and call `UpdateCheck_Shutdown()`; confirm `DecideCloseApp` agrees with the notification open (the modeless window must not count as a foreign window or as "busy") and adjust only if the measurement says so
- [X] T018 [US1] Write `specs/123-new-version-check/probe/updcheck_probe.ps1` (hidden desktop, whole-key registry backup/restore, `-Expect fixed|before`, default browser replaced by a logging stub for the session) with rows C1–C3, C5–C8, C12–C15 of quickstart.md; run on the Debug build; record PASS/FAIL per row in `fix-log.md`
- [X] T019 [US1] Run feature 080's `specs/080-restart-manager-upgrade/probe/rm_probe.ps1` with the notification open (quickstart § D) and record the result in `fix-log.md`

**Checkpoint**: MVP — start-up notification works end to end against the fixture server

---

## Phase 4: User Story 2 — Checking on demand from the Help menu (P2)

**Goal**: *Check for New Version* always answers: notification, "latest version", or a "could not check" message by class.

**Independent test**: with the option off, choose the command against `newer`, `same`, a stopped server, `403`, `html`, `hang` + Cancel.

- [X] T020 [US2] Add `CM_HELP_CHECKVERSION` to `src/resource.rh2`, the menu string `IDS_MENU_HELP_CHECKVERSION` ("Check for &New Version") to `src/lang/texts.rc2` + `lang.rh`, and the item above *About* in the Help popup of `src/menu4.cpp` (same `MNTS_B | MNTS_I | MNTS_A`); verify the command is enabled in every state the About command is
- [X] T021 [US2] Add the wait dialog `IDD_UPDATECHECKING` (text + Cancel) to `src/lang/lang.rc` + `lang.rh` and the four answer strings + title of contracts/ui.md § 3 to `src/lang/texts.rc2`; implement `CUpdateCheckingDialog` in `src/upddlg.{h,cpp}` (modal, shown only if no result within 500 ms, Cancel/Esc → `UpdateCheck_Cancel()`, closes itself when the result message arrives)
- [X] T022 [US2] Implement the command in `src/mainwnd3.cpp`: start a manual check, or attach to a running automatic one (promote it to manual); on the result: `surNewer` → notification activated (or another instance's brought to the front), ignoring the skipped version; `surUpToDate` → information box naming the installed version; `surUnreachable` / `surRefused` / `surUnexpected` → the three warning texts; `surCancelled` → nothing. Composition with `LoadStrW`/`LoadStrU8` per the house rule; the manual check does not change `Check At Startup` and is not throttled
- [X] T023 [US2] Extend `probe/updcheck_probe.ps1` with rows C10 and C11 and the "manual check shows a skipped version" half of C7; run; record

**Checkpoint**: US1 and US2 work independently

---

## Phase 5: User Story 3 — Update state in the About dialog (P2)

**Goal**: the About dialog shows what is known and links to the download; opening it sends nothing.

**Independent test**: open About in the three known states (stored values set by the probe) and after a check that completes while it is open.

- [X] T024 [US3] Add `IDC_ABOUT_UPDATE` (text) and `IDC_ABOUT_UPDATELINK` (link) under the version line of `IDD_ABOUT` in `src/lang/lang.rc` (dialog 11 units taller, controls below moved down, the bottom line and Close button with them) and the three line texts + two link texts of contracts/ui.md § 4 to `src/lang/texts.rc2` + `lang.rh`
- [X] T025 [US3] Fill the line in `CAboutDialog` (`src/logo.cpp`, `src/dialogs.h`): read `CUpdateState`, `SalUpdKnownState`; newer → text + `CHyperLink::SetActionOpen(installer address)`; up to date → text with the last success date in the user's locale; not checked → text + `SetActionPostCommand(CM_HELP_CHECKVERSION)` routed to the main window; colours through the existing `WM_CTLCOLORSTATIC` branch; register the dialog's window with the update service while it exists so a result arriving meanwhile refreshes the line; the About dialog remains usable while the manual check's wait dialog is shown
- [X] T026 [US3] Extend `probe/updcheck_probe.ps1` with row C16 (three states, *Check now*, and the server log proving that opening the dialog sends no request); run; record

**Checkpoint**: US1–US3 work independently

---

## Phase 6: User Story 4 — Turning the start-up check on and off (P3)

**Goal**: one option in Configuration → General, the same setting as the notification's check box, on by default.

**Independent test**: fresh registry → on; turn off → 20 starts send nothing; turn off in the notification → configuration shows off.

- [X] T027 [US4] Add the check box `IDC_CHECKNEWVERSION` ("Check for a new &version of Tandem Commander at start-up") to `IDD_CFGPAGE_GENERAL` below `IDC_RELOADENVVARS` in `src/lang/lang.rc` + `lang.rh`; bind it in `CCfgPageGeneral::Transfer` (`src/dialogs4.cpp`, `src/cfgdlg.h`) to `CUpdateState::CheckAtStartup` — read from the registry when the page opens, written at once on OK, not a member of `Configuration`
- [X] T028 [US4] Extend `probe/updcheck_probe.ps1` with rows C4 and C9 and a "fresh registry and 0.1.8-shaped registry both start with the option on" row; run; record

**Checkpoint**: all four stories work

---

## Phase 7: Polish & cross-cutting

**Purpose**: translations, documentation the constitution and `CLAUDE.md` make mandatory, compatibility and performance proofs, reviews

- [X] T029 Translations: run the two-stage `.slt` refresh for the 8 enabled languages (`translate.merge` with `--templates <build dir>/tandemcommander/translator/templates`; `SSL_CERT_FILE` = certifi for DeepL); add pins under `_feature_123` in `translations/ui-overrides.json` (Czech menu command *Zkontrolovat novou verzi*, product name untranslated, formal register for de/fr/nl/es, anything the review of the output finds); dry run reports 0 gaps; `build.cmd full` green; record DeepL characters and pins in `fix-log.md`
- [X] T030 [P] `PRIVACY.md`: correct the opening claim about using the network only on the user's action; add the entry under *When the program uses the network* (host `api.github.com`, when, what GitHub sees: IP address and `TandemCommander-updatecheck`, nothing else sent); list the stored values of contracts/stored-state.md; how to turn it off; that the download and the release notes open in the browser; update the validity line. Add the claim map (sentence → evidence: code location, server-log line) to `fix-log.md`
- [X] T031 [P] `CHANGELOG.md`: entry under `## [Unreleased]` (Added) in the user's terms — what is new, that the check at start-up is on by default and where to turn it off, what it sends, that nothing is downloaded or installed automatically, and that users are first notified one release after the one that brings the feature
- [X] T032 [P] Help: new topic in `help/src/hh/salamand/` for the command and the notification (Tandem Commander footer, as `configuration_cmdshell.htm`), the option added to `help/src/hh/salamand/configuration_gener.htm`, both entered in `help/src/salamand.hhc` and the index; wire the notification's and the wait dialog's help ids if the house dialogs carry them
- [X] T033 [P] `architecture/04-dependencies.md`: WinHTTP as a system dependency of the core (delay-loaded); `architecture/03-build-pipeline.md` only if the link settings need a note
- [X] T034 Extend the probe with rows C17 (start-up time on / off / offline, 20 runs each; `winhttp.dll` absent from the module list when the option is off) and quickstart § E (published 0.1.8 started and exited with the `Update Check` subkey present: subkey intact); run; record
- [X] T035 Release build: `build.cmd full release` green; `dumpbin /imports` (from PowerShell) shows `winhttp.dll` only under delay imports; `tools/check_runtime_deps.py` green; the Debug seam strings are absent from the Release binary (`strings`-style search for `TC_UPDATECHECK_`); quickstart § F against the real endpoint in Debug and Release ("0.1.8 is the latest version", rate-limit counter +1 per command); record
- [X] T036 Guards: `python tools/check_encoding.py` strict `TOTAL: 0`; clang-format on the new files; `saltests` final count recorded; regression probes that touch the same surfaces unchanged — 080 `rm_probe.ps1` (5/5), 093 `dialogs_probe.ps1` (General page and About still open and transfer), 121 `batch121_probe.ps1` message-box rows
- [X] T037 Independent review 1 (refute-first, network and parsing): give a fresh reviewer `src/common/salupdcheck.*`, `src/updcheck.*`, contracts/update-source.md and the fixture server — brief: make the program show a notification for, or open an address from, a hostile answer; find a way exit waits for the network; find any header or datum sent beyond the contract. Fix findings; record verdict and each finding's outcome in `fix-log.md`
- [X] T038 Independent review 2 (UI and instances): `src/upddlg.*`, the `mainwnd3.cpp` / `logo.cpp` / `dialogs4.cpp` changes, contracts/ui.md and stored-state.md — brief: focus theft, a notification behind or above a modal window, two notifications, a lost or stale option between instances, the Restart Manager path, clipped text in the longest translation. Fix findings; record
- [X] T039 Screenshots for the design acceptance: the probe captures the notification at 100 / 150 / 200 %, light and dark, in the 8 languages, plus the About dialog's three states and the General page, into `specs/123-new-version-check/probe/shots/` (gitignored if large); list them in `fix-log.md` for the maintainer's pass (quickstart § G)
- [X] T040 Closing records: `specs/123-new-version-check/closing-report.md` (what was built, evidence table per success criterion SC-001…SC-010, what is owed to a person: quickstart § G and § H); the feature's entry in `CLAUDE.md` *Recent Changes* and the *Privacy statement* / *Key Facts* lines it affects (`PRIVACY.md` validity, WinHTTP in the core); `specs/NEXT-WORK.md` — owed steps under section B and the winget-marker follow-up of research R12 as a recorded option

---

## Dependencies & Execution Order

### Phases

- **Setup (1)** → **Foundational (2)** → stories → **Polish (7)**
- **US1 (3)** needs Phase 2 only.
- **US2 (4)** needs Phase 2 and, for its "newer" answer, the notification window of US1 (T012–T014). Its other answers are independent.
- **US3 (5)** needs Phase 2; *Check now* uses US2's command (T020, T022); the *Download* link is independent.
- **US4 (6)** needs Phase 2 only (the notification's check box of T014 writes the same value).
- **Polish**: T029 after every string exists (T012, T020, T021, T024, T027); T030–T033 any time after Phase 2; T034–T040 after all stories.

### Within Phase 2

T005 → T006 → T007; T008 after T005; T009 after T006; T010 after T008 + T009; T011 after T009 (and T004).

### Shared files (do not parallelise)

- `src/lang/lang.rc`, `lang.rh`, `texts.rc2`: T012, T020, T021, T024, T027
- `src/mainwnd3.cpp`: T016, T017, T022
- `src/upddlg.{h,cpp}`: T013, T014, T021
- `src/updcheck.cpp`: T008, T009, T010
- `probe/updcheck_probe.ps1`: T018, T023, T026, T028, T034, T039

### Parallel opportunities

- Phase 1: T003 and T004 beside T002.
- Phase 2: T008 beside T006/T007 (different files) once T005 is in.
- After Phase 2: US4 (T027) beside US1; documentation T030–T033 beside any code task.
- Reviews T037 and T038 beside each other.

```text
Example after T005:
  agent A: T006 → T007   (src/common/salupdcheck.cpp, src/saltests/saltests.cpp)
  agent B: T008          (src/updcheck.{h,cpp} — stored state)
Example after Phase 2:
  agent A: T012 → T013 → T014 → T015 → T016 → T017   (US1)
  agent B: T030, T031, T033                           (documents)
```

---

## Implementation Strategy

**MVP = Phases 1–3 (T001–T019)**: the start-up notification against the
fixture server, with the option reachable only through the notification's own
check box. That already delivers the purpose of the feature and exercises
every risky part (network, parsing, cross-instance state, the modeless window,
the Restart Manager path).

**Increments**: US2 (definite answer on demand) → US3 (About) → US4
(configuration page) — each ends with its probe rows green and a `fix-log.md`
entry; commit per phase.

**Not shippable before Phase 7**: strings added in Phases 3–6 break
`build.cmd full` for every language until T029 runs, and `PRIVACY.md` (T030)
must be in the same change as the network code.

**Owed to a person afterwards** (cannot be done by an agent): the design
acceptance, the real-keyboard and screen-reader pass, a real browser download
(quickstart § G); the Release "newer" path and one antivirus scan at the next
release (§ H).
