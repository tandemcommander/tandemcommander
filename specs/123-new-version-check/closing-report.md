# Closing report: New Version Check (feature 123)

**Branch** `123-new-version-check` · **Date** 2026-10-06 · **State**: implemented,
verified by independent agents in two rounds, not committed, not released. No
version bump (it ships with the next release). Plug-in interface untouched
(107). No configuration version bump, no migration.

## What was built

| Part | Where |
|---|---|
| Rules: version order, a strict JSON reader, the rules a release record must meet, the two constructed addresses, the throttle rule | `src/common/salupdcheck.h` (header-only, pure) |
| Stored state, the worker thread, the one HTTPS request (asynchronous WinHTTP, delay-loaded) | `src/updcheck.{h,cpp}` |
| Notification window (modeless), wait dialog, answers of the manual check, opening addresses | `src/upddlg.{h,cpp}`, brand header painter in `src/logo.cpp` / `src/brand.h` |
| Start-up hook, Help command, deferred showing, exit | `src/salamdr1.cpp`, `src/mainwnd3.cpp`, `src/menu4.cpp` |
| About dialog line, Configuration > General option | `src/logo.cpp`, `src/dialogs4.cpp` |
| Resources and 8 languages | `src/lang/*`, `translations/*/salamand.slt`, `translations/ui-overrides.json` |
| Documents | `PRIVACY.md`, `CHANGELOG.md`, help topic `othertask_newversion.htm`, `architecture/04-dependencies.md` |

Source of truth for the version: `GET https://api.github.com/repos/tandemcommander/tandemcommander/releases/latest`
(see `source-analysis.md`). The program never opens an address taken from the
answer: the installer and release-notes addresses are built from the validated
version, and the answer must contain exactly those.

## Evidence per success criterion

| Criterion | Result | Evidence |
|---|---|---|
| SC-001 notification within 10 s, 20 of 20 | met | probe A1X: 20 of 20, 0.17-0.22 s after the main window |
| SC-002 no start-up delay | met | probe S2: median 0.46-0.56 s to a responsive main window with the check off, on, server down, server silent |
| SC-003 off = 0 requests | met | probe C1: 20 starts, 0 requests, `winhttp.dll` not loaded |
| SC-004 at most one request a day | met | probe C2: 20 starts, 1 request; C3: three instances at once, 1 request and 1 notification |
| SC-005 one action to the download | met | probe D1, F1: *Download* hands over exactly the constructed installer address |
| SC-006 manual answer within 15 s | met | probe E1: at most 12.07 s (never-answering 10.8 s, dripping server 12.1 s); the request's own limit measured 12.0 s in every phase by reviewer 2 |
| SC-007 failures are silent | met | probe A3: 29 failing answers - nothing shown, knowledge kept, exit about 1.2 s |
| SC-008 hostile answers never notify or open | met | probe A3/E1; adversarial test: 3,770,775 inputs, 0 wrongly accepted, 0 crashes |
| SC-009 design | partly | measured: no cut or overlapping text in 9 language modules at 100 % and in the dark theme (cs, de, en); **the maintainer's acceptance and 150 % / 200 % are owed** |
| SC-010 privacy statement true | met | claim map in `fix-log.md`; reviewer 2 checked every sentence against the code and measured the request (5 headers, no cookie, no credentials to a server or a proxy) |

## Final verification (on the final code)

| Check | Result |
|---|---|
| `saltests` | **18,184 checks, 0 failed** (17,498 before the feature) |
| Behaviour probe, full run on the final Debug build (`probe/updcheck_result.txt`) | **238 PASS, 0 FAIL, 2 NOT DRIVEN** (a mouse click on link text cannot be posted - the control reads the real cursor); the group with the real Restart Manager was left out of this last run because it restarts the program on the visible desktop - it passed in the tester's run on the previous build (2 PASS), and nothing on that path changed afterwards |
| `build.cmd full` (Debug) and `build.cmd full release` | both succeed, all 8 language modules; runtime closure OK |
| Release binary | `winhttp.dll` only among delay-load imports; no `TC_UPDATECHECK_` and no `127.0.0.1` string (the Debug seams are not compiled in) |
| Real endpoint, Release and Debug, Czech UI | Help command: "Tandem Commander 0.1.8 je nejnovější verze."; About: "Toto je nejnovější verze (zkontrolováno 6. října 2026)."; automatic check: `Latest Version 0.1.8`, nothing shown; GitHub's rate-limit counter rose by one per request |
| `tools/check_encoding.py` | strict `TOTAL: 0` |
| Registry of the product after all runs | SHA-256 equal to the state before the first probe of the day |

## Independent verification

Two rounds, four agents with fresh context (a behaviour tester, an adversarial
tester of the parser, two code reviewers). Round 1: one blocker (the
notification took the keyboard), six should-fix findings, five behaviour
defects, no security defect in the parser. Round 2 on the fixed build: no
blocker; two new should-fix findings and one clipped Dutch text, all fixed and
confirmed by the final run. Details, including what was deliberately left, are
in `fix-log.md`.

## Owed to a person

1. **Design acceptance** of the notification window (captures of every
   language and the dark theme: `probe/shots/`, contact sheets in
   `probe/shots/_sheets/`), also at 150 % and 200 % scaling.
2. **Real keyboard and mouse**: typing in the command line while the
   notification arrives (the focus must stay), a real click on *Release notes*
   and on the About link (each must open once), Alt access keys, the Help menu
   item's place.
3. **Screen reader** (Narrator) on the notification.
4. **A real browser download** from *Download*; "Yes" in the "copy the
   address" message.
5. **A real installer update** with the notification open (the Restart Manager
   path was driven by the probe; the restarted program could not be observed).
6. **At the next release**: the "newer version" path in a Release build
   against the real endpoint (it cannot exist before a newer release does),
   one antivirus scan of the Release build (first outbound connection of the
   core), and publishing the release with its installer attached (the rule in
   `contracts/update-source.md`).

## Known limits (decided, recorded)

- Users are first notified one release after the one that brings the feature.
- An installation through the Windows Package Manager is not told apart; the
  catalogue may offer a version a little later than the notification does.
- The date is written in the user's regional format whatever the UI language.
- Review 2 nits N5, N6, N8, N9, N10 and translation nit T3 are left as they
  are (`fix-log.md`).
- `research.md` R2 records the original, superseded request design; the
  contract `contracts/update-source.md` is current.
