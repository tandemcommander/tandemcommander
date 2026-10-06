# Fix log: New Version Check (feature 123)

Running record of the implementation. Branch `123-new-version-check`, started
2026-10-06 from `48206df9`. Nothing is committed or pushed by the
implementation session.

## Baseline

- `build.cmd` (Debug x64) green before any change.
- `saltests`: **17,498 checks, 0 failed** (run 2026-10-06 on the unchanged tree).

## Deviations from the plan (decided while implementing)

| Plan / tasks said | Done instead | Why |
|---|---|---|
| `src/common/salupdcheck.{h,cpp}` | header-only `src/common/salupdcheck.h` | No project-file wiring for `saltests`, and independent testers can compile it stand-alone without the precompiled header (the pattern of features 086–121). |
| Result of a check posted as a heap block in the message | `WM_USER_UPDATECHECK_DONE` carries nothing; the receiver calls `UpdateCheck_TakeResult()` | A result posted to a window that is destroyed meanwhile cannot leak, and exactly one party takes it. |
| Refactor `AboutAndEvalDlgCreateBkgnd` into a painter both dialogs call | new `TCPaintBrandHeader` (`logo.cpp`, declared in new `src/brand.h`) sharing the wordmark routine, the two resources and the palette; the About painter is untouched | The About dialog paints a whole window with the artwork pinned to the top-right corner; forcing both layouts through one function risked a pixel change of About for no gain. The palette moved to `brand.h` (one definition). |
| Synchronous WinHTTP, timeouts 5 / 5 / 5 / 8 s, cancel by closing the request handle from the main thread (research R2) | **asynchronous** WinHTTP on the worker: every step is awaited together with a cancel event and the remaining part of a 12 s deadline for the whole request; the worker closes its handles itself; phase timeouts 4 / 4 / 2 / 8 s inside the deadline | Microsoft documents that the handle of a synchronous request must never be closed from another thread (review 1, finding 4), and the synchronous form could not bound a dripping server (tester D1). The manual check's wait dialog additionally gives up after 15 s (SC-006). |
| "Released" date = long date of the user's locale | the same without the day of the week (`SalUpdStripWeekday`) | "Released Wednesday, 14 October 2026" reads badly in a compact window. |
| Link texts in the dialog templates | string table (`IDS_UPDATE_NOTESLINK`, `…DOWNLOADLINK`, `…CHECKNOWLINK`), set with `LoadStrU8` | `CHyperLink` reads its initial text through the code page; a translation outside the system code page would be damaged. |
| All addresses opened through `CHyperLink::SetActionOpen` | links post a command to their dialog; every address goes through `UpdateCheck_OpenUrl` | One place opens addresses (and one Debug seam records them for the probe). |

## Debug-only seams (not compiled into Release)

| Variable | Effect |
|---|---|
| `TC_UPDATECHECK_URL` | `http://127.0.0.1:<port>/<path>` replaces the endpoint (loopback, plain HTTP; anything else ignored - `SalUpdParseLoopbackUrl`, tested) |
| `TC_UPDATECHECK_PRETEND_VERSION` | `x.y.z` used as the installed version |
| `TC_UPDATECHECK_OPENLOG` | a file; addresses that would be handed to the browser are appended to it instead |

## Task record

| Task | State | Evidence / notes |
|---|---|---|
| T001 | done | this file |
| T002 | done | new files in `salamand.vcxproj` (+ filters); `winhttp.lib;delayimp.lib` + `DelayLoadDLLs` in `sal_base.props` (only the main project imports it); `salupdcheck.h` listed in `saltests.vcxproj` |
| T003 | done | `probe/fixtures/real-0.1.8.json` (7,115 bytes as served 2026-10-06) |
| T004 | done | `probe/updserver.py`, 26 fixtures, `--selftest` |
| T005, T006 | done | `src/common/salupdcheck.h` |
| T007 | done | `TestUpdateCheck123` in `saltests.cpp` + generated `src/saltests/updcheck123_fixture.inc`; **17,498 → 18,140 checks, 0 failed** (before the review fixes below) |
| T008–T010 | done | `src/updcheck.{h,cpp}` |
| T011 | done by the independent tester and reviewer 2 | request headers and result classes per fixture: probe groups A3, B, E1; proxy 407 / 401 / 302 negative controls: `probe/review2/r2_results.txt` |
| T012–T017 | done | `IDD_UPDATENOTICE`, `src/upddlg.{h,cpp}`, `mainwnd3.cpp`, `salamdr1.cpp` |
| T020–T022 | done | `CM_HELP_CHECKVERSION` 2217, `IDD_UPDATECHECKING`, `UpdateCheck_RunManualUI` |
| T024, T025 | done | `IDD_ABOUT` 11 units taller, `CAboutDialog::RefreshUpdateLine` |
| T027 | done | `IDC_CHECKNEWVERSION` on `IDD_CFGPAGE_GENERAL`, bound to the stored state |
| T030 | done | `PRIVACY.md` (claim map below) |
| T031 | done | `CHANGELOG.md`, `## [Unreleased]` intro + Added |
| T032 | done | `help/src/hh/salamand/othertask_newversion.htm`, option in `configuration_gener.htm`, `.hhc` / `.hhk` / `.hhp` |
| T033 | done | `architecture/04-dependencies.md` |
| T018, T023, T026, T028, T034, T039 | done by the independent tester | `probe/updcheck_probe.ps1`, `probe/updcheck_result*.txt`, `probe/shots/` |
| T019 | done by the independent tester | probe group R: `rm_probe.ps1 -Restart` with the notification open and with a hanging check in flight |
| T029 | done | see "Translations" |
| T036 | done | `check_encoding.py` strict `TOTAL: 0`; new files clang-formatted; see "Final verification" |
| T037, T038 | done | see "Independent verification" |

## Found while implementing

- **First smoke run crashed** in `WM_INITDIALOG` of the notification: the Debug
  build's `/RTCc` ("cast to smaller type causing loss of data") fired on
  `(DWORD)utcFileTime` in `UpdateCheck_FormatDate`. Fixed by masking; the same
  cast in the new test was masked too. Lesson repeated from feature 093: a
  64-bit value split into halves must be masked in this code base.
- **Tooling trap, not a product defect**: in this session's shell, Bash
  here-documents collapse doubled backslashes, which silently corrupted two
  generated C++ string literals (`L'\''` became `L'''`, `\x5E74` became
  `^74`). Every script and source file was written with the editor tools from
  then on; the two literals were repaired and are covered by tests.

## Smoke runs (hidden desktop, Debug, fixture server)

| Run | Observed |
|---|---|
| start-up, fixture `newer`, pretending 0.1.8 | one request with exactly `Accept`, `User-Agent: TandemCommander-updatecheck`, `X-GitHub-Api-Version`, `Host`, `Connection`; notification with 0.1.8 → 9.9.9, "Released 14. října 2026"; state stored; exit 1.4 s, code 0 |
| Help command, `same` | "Tandem Commander 0.1.8 is the latest version." |
| Help command, `403` | "… the release server refused the request …" |
| Help command, `html` | "… gave an unexpected answer …" |
| About with a known newer version | "Version 9.9.9 is available. Download" under the version |

## Independent verification

The maintainer asked for tests designed and run by independent agents. Four
agents with fresh context took part; none of them wrote product code, and each
was told to assume defects. Their working files are kept under `probe/`.

### Round 1 (on the first complete build)

| Agent | What it did | Result |
|---|---|---|
| Behaviour tester (`probe/updcheck_probe.ps1`, hidden desktop, fixture server) | derived its own rows from the spec and contracts | 193 PASS, 8 FAIL, 10 NOT DRIVEN - five product defects D1-D5 |
| Adversarial tester of `salupdcheck.h` (`probe/adversary/`) | own harness; differential test against Python's `json`; 3,770,775 inputs; five builds incl. `/RTCc`, with and without `/J`, AddressSanitizer; mutation test of its own suite | **no security defect**: nothing wrongly accepted, no crash, no over-read, no hang (worst 256 KB input 1 ms, stack <= 8 KB); four low findings F1-F4, four nits |
| Code reviewer 1 (refute-first, `probe/review/`) | read the whole change, measured three claims with a stand-alone probe | 1 BLOCKER, 6 SHOULD-FIX, 7 NIT |

**What they found and what was done**

| Finding | Fix |
|---|---|
| Review 1, BLOCKER: a notification "shown without activation" still took the activation and the keyboard focus (the dialog's initialisation returned TRUE) - Enter typed into the command line would have started the download | `WM_INITDIALOG` returns FALSE on the no-activate path; confirmed by tester round 2 (`A1 nofoc`: active window = main window, focus in the panel) and by reviewer 2's model |
| Review 1: a click anywhere in the *Release notes* row opened the browser (the control's own `STN_CLICKED`), probably twice on the text | the links post commands that are not control ids (`IDC_UPDN_NOTESCMD`, `IDC_ABOUT_UPDATECMD`) |
| Review 1: Enter on the focused link ran *Download* | the first fix (a redirect in the `IDOK` handler) was itself wrong - review 2 showed it also caught the button's access key; final fix: `CUpdateLink` answers `WM_GETDLGCODE` and takes Enter itself |
| Review 1: cancelling closed the handle of a synchronous request from another thread, against Microsoft's documentation | asynchronous WinHTTP (see the deviations table). An intermediate version that simply abandoned the synchronous worker left a "monitored handles remained opened" box at exit in Debug (caught by the tester's rows) and was replaced |
| Review 1 + tester D1: the 12 s deadline held only between reads; a dripping server kept the request open (45 s and more), the manual answer came after 15.1 s | the worker's own deadline covers every phase; measured 12.0 s for a never-answering server, a dripping body, dripping headers, a stalled TLS handshake |
| Tester D2: an answer whose body ended before its `Content-Length` was accepted | refused; also an unreadable `Content-Length` |
| Tester D3: a check on demand that found a newer release left the old version in an open notification | this instance's window is replaced |
| Tester D4: `99999.99999.99999` was cut in the large face | `FitVersionFont` chooses the largest face that fits |
| Tester D5: `Last Attempt Answered` was 0 although a status had arrived | "answered" is recorded separately from the result class |
| Review 1: the start-up notification could appear over a message box that does not disable the main window, or during a system menu | also waits for any other dialog of the main thread and for menu / move-size modes; the retry timer backs off after 30 s |
| Review 1: the contract said the values are not exported, the code exports the whole branch | contract and `PRIVACY.md` corrected (the values are exported; the branch-clearing paths reset the option) |
| Adversary F2: tag `v00.01.009` with canonical addresses was accepted as 0.1.9 | the tag must equal the canonical print of its numbers |
| Adversary F4: `SalUpdStripWeekday` left a quoted separator hanging (se-FI) | handled; reviewer 2 ran all 928 Windows locales: 0 suspicious |
| Adversary F1, F3 | documented, not changed: the reader does not check the text encoding (harmless here, said in the header and pinned by a test); an asset repeating one of its members never matches (contract) |

### Round 2 (on the fixed build)

| Agent | Result |
|---|---|
| Behaviour tester, extended probe (8 languages, dark theme, the real Restart Manager, full SC loops) | 239 PASS, 1 FAIL, 12 NOT DRIVEN. All nine claimed fixes confirmed except "a click on the link text opens once" (cannot be driven: the control hit-tests the real cursor). FAIL: the Dutch configuration option was cut off. Restart Manager with the notification open and with a hanging check: `RmShutdown : 0 after 1,2 s`, no survivors, restart registered. |
| Code reviewer 2 (`probe/review2/`, own instrumented copy of the request against raw servers) | **no blocker**. First-round findings 1, 2, 4, 5, 6 FIXED; 3 and 7 PARTLY. Measured: deadline 12.00-12.02 s in every phase, cancel returns within 16 ms, `HANDLE_CLOSING` always arrives, no `Proxy-Authorization` on a proxy 407 (the negative control sends one). New: N1 (the access key of *Download* opened the notes while the link had focus), N2 (the Configuration page could silently turn the check back on), nits N3-N11, documentation D1-D8, translations T1-T3 |

**Round 2 fixes**: N1 (`CUpdateLink`, the redirect removed); N2 (the page
writes the option only when the user changed the box it showed); N3
(unreadable `Content-Length`); N4 (timer back-off); N7 (a session that cannot
be limited to TLS 1.2+ is not used); D1-D5 in `PRIVACY.md`, `CHANGELOG.md`,
help; D6-D8 in the feature's own documents; T1 (Dutch shortened), T2
(Romanian: one register, one caption).

**Left as they are, by decision**: N5 (a check on demand in instance B brings
instance A's older notification forward instead of replacing it - one
notification per user wins); N6 (a cancel in the last microsecond can leave a
stored result although "cancelled" was shown); N8 (a missing `winhttp.dll`
would be a crash report, not "unreachable" - the DLL is part of Windows); N9
(a proxy's 407 reads as "unexpected answer"); N10 (after Tab + a click on the
link another button keeps the default border); T3 (German "Download" button
beside the "Herunterladen" link).

**A side effect to know about**: the Restart Manager rows restart the program
on the user's visible desktop (that is where Windows restarts it); in the
tester's first exploratory run such a window lived up to 8 s, twice. The probe
now ends it within 1.5 s; the implementer's final run leaves group R out.

## Translations (T029)

- Two-stage refresh: `build_langs.cmd --export-templates --module salamand`,
  then `translate.merge --module salamand`: 29 gaps per language, **10,376
  DeepL characters**, 0 validation failures, duplicate accelerators 148 before
  and after.
- Czech pinned whole (26 pins); the other languages 3-12 pins each under
  `_feature_123` in `translations/ui-overrides.json` (reasons in its note):
  the informal register in de/fr/nl/es, "Released %s" without its space or
  turned round in six languages, accelerator collisions on the General page in
  cs/sk/ro/es, the Dutch option too long for its control, Romanian mixing
  registers.
- Placeholders: every translated string keeps the English count of `%s` and
  line breaks (checked from the sources by script, from the built `.slg` files
  by the tester's group ST, and by reviewer 2).
- `build.cmd full`: all 8 language modules build.

## Incident: the product's registry key was left in probe state twice

A development helper of the implementer (`probe/smoke123.ps1`) was damaged by
the here-document trap (a backslash-zero became a NUL byte), hung, and a shell
loop kept starting further runs after its processes had been stopped; the
helper's backup was then taken from an already modified registry and
"restored" over a manual repair. `HKCU\Software\Tandem Commander` was restored
from the backup of the tester's last clean run and verified by SHA-256
(`D0B82006...2904FB9`, the value every probe run of the day started from);
every later run ended on the same hash. No installed instance was running at
the time. Lessons: a probe loop must stop at the first failure; a backup must
be refused when the previous run did not restore; scripts are written with the
editor tools only.

## PRIVACY.md claim map (T030, SC-010)

| Sentence (shortened) | Evidence |
|---|---|
| asks GitHub about once a day, when it starts, unless turned off | `UpdateCheck_OnStartupComplete`, `SalUpdAutoCheckDue`; probe C1 (off: 0 requests in 20 starts), C2 (on: 1 request in 20 starts) |
| at most once in 24 hours; after an unreachable attempt again at a later start, at most once an hour | `SALUPD_INTERVAL_*`; probe C6, C7 |
| the same question on Help > Check for New Version and *Check now* in About | `CM_HELP_CHECKVERSION`, `CAboutDialog`; probe E1, F2 |
| goes to `api.github.com` over an encrypted connection | `SALUPD_HOST_W`, `WINHTTP_FLAG_SECURE`, TLS 1.2+ or not sent; the real-endpoint run |
| GitHub receives the IP address, the time, `TandemCommander-updatecheck` and two fixed lines | server log, probe B: `Accept`, `User-Agent`, `X-GitHub-Api-Version` (+ `Host`, `Connection`) and nothing else |
| not the version, no identifier, nothing about files or settings | the same log; the request has no body and no query |
| no cookies stored or sent | `WINHTTP_DISABLE_COOKIES`; probe B (no `Cookie` after `Set-Cookie`) |
| never signs in to a server or a proxy with Windows credentials | `WINHTTP_DISABLE_AUTHENTICATION`; probe B (`auth401`: one request, no `Authorization`); reviewer 2: a proxy 407 offering Negotiate/NTLM/Basic gets no `Proxy-Authorization`, the negative control sends one |
| uses the proxy settings of Windows, incl. automatic detection | `WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY` |
| uses only the version number and the release date from the answer | `SalUpdParseLatestRelease`, `CSalUpdRelease`; the registry values after probe runs |
| downloads and installs nothing; *Download* hands the installer's address to the browser, *Release notes* opens the release page | `UpdateCheck_OpenUrl` only; probe D1, F1 (the open-log holds exactly the two constructed addresses) |
| how to turn it off (Configuration > General, or the notification) | `IDC_CHECKNEWVERSION`, `IDC_UPDN_ATSTARTUP`; probe D5, G1 |
| stored values under `0.1\Update Check`, written when they change, not removed by Clear History, exported with the configuration, reset by an import or a removed configuration | `contracts/stored-state.md`; probe A1 ("only contract values stored"); `ExportConfiguration` and the `ClearKeyAux` paths (reviewer 1 finding 6, reviewer 2) |
| 0.1.8 has no check and never contacts the internet on its own | the 0.1.8 binary imports no HTTP library (feature 083 research); probe J |

## Final verification (final code, 2026-10-06 evening)

| Check | Result |
|---|---|
| `saltests` | 18,184 checks, 0 failed (baseline 17,498) |
| `build.cmd full` (Debug), `build.cmd full release` | both succeed; 8 language modules; runtime closure OK (218 modules, 4 runtime files shipped) |
| Behaviour probe, full run on the final Debug build - groups A, B, C, D, LK, E, F, G, H, L, K, ST, S2, J (`probe/updcheck_result.txt`) | 238 PASS, 0 FAIL, 2 NOT DRIVEN (mouse click on link text); registry restored and verified |
| Restart Manager rows (group R) | not repeated in the final run (they restart the program on the visible desktop); tester's round 2 on the previous build: 2 PASS, 2 NOT DRIVEN (`probe/updcheck_result_run2_tester.txt`); the close path was not changed afterwards |
| Release binary | `winhttp.dll` only under delay-load imports; strings `TC_UPDATECHECK_` and `127.0.0.1` absent; `TandemCommander-updatecheck` and `api.github.com` present once |
| Real endpoint, Release build, Czech UI | Help command answers "Tandem Commander 0.1.8 je nejnovější verze."; About shows "Toto je nejnovější verze (zkontrolováno 6. října 2026)."; stored `Latest Version 0.1.8`, `Last Attempt Answered 1` |
| Real endpoint, Debug build | the same; automatic check at start-up: nothing shown, one request (GitHub's `X-RateLimit-Used` +1) |
| `tools/check_encoding.py` | strict `TOTAL: 0` |
| clang-format | the six new source files formatted; the touched legacy files have no new violation |
| Regression: feature 093's `dialogs_probe.ps1` on the touched surfaces (config, about, msgbox, find, cmdline) | PASS 23, LOSSY 0, FAIL 0, unexpected windows 0, exit codes 0 |
| Product registry key | SHA-256 `D0B82006...2904FB9` after every run, equal to the state before the first probe |

T035 and T040 done (this section, `closing-report.md`, `CLAUDE.md`, `specs/NEXT-WORK.md`).
