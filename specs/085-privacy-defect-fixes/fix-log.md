# Fix log: 085 privacy defect fixes

Baseline `7f50632` (`main`, after feature 084). Branch `085-privacy-defect-fixes`.
Protocol: `specs/069-finish-encoding-fixes/contracts/fix-protocol.md` — HEAD
check first, then the change, its evidence, and an independent review by an
agent that did not write it.

## HEAD check (all five defects still present at `7f50632`)

| Defect | Site | Present |
|---|---|---|
| F1 | `ftp/dialogs1.cpp:925-931` (raw address back into the field before `HistoryComboBox`), `dialogs3.cpp:1200-1202`, `editwnd.cpp:559-580` | yes |
| F2 | `mdview/webglue.cpp:96` `WinHttpOpen(L"OpenSalamander-mdview")`, no feature disabling, no status query | yes |
| F3 | `webhost.cpp:266-299` every cancelled navigation → `OnActivateLink` | yes |
| F6 | `pwdmngr.cpp:37-47` `srand(time ^ pid)` / `rand()` | yes |
| F7 | `sftp/dialogs.cpp:851-856`, `:887-892` encrypt flag = prompt result, saved anyway | yes |

The sink inventory for F1 (an independent read-only sweep) found two sinks
083 had not named: the Copy/Move target history (core dialogs and the FTP
plugin's download dialog through the plugin history service) and Find's
*Look in*. `research.md` R1.

## F1 — passwords in typed addresses

- **Change**: new pure module `src/common/salurlpwd.{h,cpp}` (contract C1–C3);
  applied to the history copy only at the eight sites of contract C4; FTP
  helper `FTPStripAddressPassword` (`ftputils.cpp`); `HistoryComboBox` gained
  an optional `stripPasswords` parameter (Find stays open, so the array is
  cleaned before the drop-down is refilled).
- **Review 1 — REJECT.** BLOCKER: the address part ended at white space and
  quotes, which FTP accepts inside a password (`alice:correct horse@host`
  kept the whole password — the author had found the same gap independently
  while writing `PRIVACY.md`). SHOULD-FIX: form 2 ended at `\`
  (`ftp:corp\alice:pw@host` leaked). NITs: `CCopyMoveDialog` also serves
  Create Directory / Quick Rename / Edit New; `%3A`/`%40` escapes; the FTP
  form untested; both `LoadHistory` implementations could leave an
  uninitialised entry after a failed `GetValue` that C3 would then read.
- **Revision**: single values end only at `/`; the command line keeps word
  endings except inside a quoted URL (`SalStripCommandLinePasswords`);
  escapes count; the FTP form is the pure `SalStripAddressPassword`; the
  copy/move strip is limited to `CopyHistory`; both `LoadHistory` free and
  clear a failed entry. Contract rewritten.
- **Evidence**: `saltests` 1647 → **1816 checks, 0 failed**
  (`TestUrlPasswordStrip085`: values, command lines, the FTP address form,
  C1 directly, C5 invariants incl. UTF-8 validity, C3). Debug build clean.
- **Review 2 — ACCEPT**, one SHOULD-FIX: form 2 without the `\` ending
  damaged Undelete paths (`del:C:\proj\node_modules\@types` → `del:C@types`,
  the drive's `:` taken for a password start) — a plugin path continuing with
  a drive is now left alone; two weak tests strengthened (an escape that could
  not fail, end-of-string escapes). Confirmed by the same reviewer.
- **Incident**: a PowerShell one-liner meant to add BOMs opened five new
  files for writing before reading them and emptied them; restored from the
  session's own text, normalised by a script that reads first and refuses
  empty input. Also, a Bash heredoc halved backslashes in C++ test literals
  (`"C:\\a"` → `"C:\a"`); caught by a `grep -F` check before the first build.
  Both recorded in the session memory.

## F3 — navigation without a click

- **Change**: `webhost.cpp` `NavigationStarting` and `NewWindowRequested`
  forward to `OnActivateLink` only when `get_IsUserInitiated` reports TRUE
  (failure = FALSE). Fixtures `probe/autonav_*.md` for the owed GUI check.
- **Review — ACCEPT** with one SHOULD-FIX: the flag reflects *transient*
  user activation, so a meta refresh firing within seconds of a key press
  (scrolling) could pass. **Second layer**: mdview's generator renames every
  raw-HTML `http-equiv` attribute to `data-tc-equiv` (`htmlgen.cpp`
  `AppendRawHtml`).
- **Review of the second layer — REJECT**: md4c delivers a raw-HTML line
  break as a separate call, so `<meta http-equiv` + newline + `="refresh" …`
  (valid HTML, block and inline) and a form feed before `=` bypassed it.
  Fixed: all HTML whitespace is skipped and the name is renamed when the call
  ends after it; tests for all three bypasses plus the after-quote/`/` forms
  inside a `<div>` block. `tests/mdview_htmlgen_test` 29 → **38 passed,
  0 failed**. Re-review — ACCEPT (no remaining route; the one form that
  passes the rename, an entity-encoded refresh in `<iframe srcdoc>`, runs in a
  frame, which never raises `NavigationStarting`).
- **Not measured**: the runtime behaviour (owed, `quickstart.md` G3).

## F2 — remote image requests

- **Change**: `FetchRemote` moved verbatim to `mdview/remotefetch.{h,cpp}`
  (`MdFetchRemote`, compiled without the PCH), then: user agent
  `TandemCommander-mdview`, `WINHTTP_DISABLE_COOKIES |
  WINHTTP_DISABLE_AUTHENTICATION`, status 200–299 before the body is read.
- **Evidence**: `probe/fetch_probe.cmd` against a local logging server —
  **PASS** (14 fetches, UA, no Cookie, no Authorization, 404/500/401 fail,
  302 followed). Negative control `fetch_probe.cmd pre085` (the pre-085
  function extracted verbatim from git) — **9 failed**: wrong UA, 404/500/401
  accepted as images, a cookie set on a redirect sent with the follow-up, and
  **an `Authorization` header sent in answer to a 401 Negotiate/NTLM
  challenge from 127.0.0.1** — the old code signed in with the user's Windows
  logon automatically (WinHTTP's default autologon policy for local/intranet
  hosts). Not one of 083's findings; fixed by the same change and stated in
  the changelog.
- **Consequence**: behind a proxy that requires Windows sign-in, remote images
  no longer load (review NIT, in the changelog).
- **Review — ACCEPT** (verbatim move confirmed against HEAD, no handle leak,
  PCH-free compile safe).

## F7 — cancelled Master Password prompt (SFTP)

- **Change**: `sftp/dialogs.cpp` `ConnectReadFields`, password and
  passphrase: a failed prompt turns `Save…` off and unchecks the box; nothing
  is saved; the connection keeps using `ConnectPlainPassword/Passphrase`.
- **Review — ACCEPT**: the prompt appears in exactly the old condition; a
  stored blob of that bookmark is cleared (feature 017's rule for unchecking
  by hand); Quick Connect unaffected; no other SFTP site has the defect.

## F6 — salts

- **Change**: `pwdmngr.cpp` `FillBufferWithRandomData` → `BCryptGenRandom`
  (system-preferred RNG), old generator only as a traced fallback;
  `#pragma comment(lib, "bcrypt.lib")`.
- **Evidence**: `tandemcommander.exe` imports `bcrypt.dll`
  (`tools/check_runtime_deps.py` `pe_imports`). Salts are stored with the
  data, so old blobs stay readable (reviewed; runtime check owed, G5).
- **Review — ACCEPT**. Out-of-scope finding: **the ZIP plugin's AES salt for
  encrypted archives still comes from `rand()` seeded with time ^ pid**
  (`zip/crypt.cpp:118-127`, used by `zip/add.cpp:1632`) — recorded in
  `NEXT-WORK.md`.

## F4 / F5 — viewer engine crash upload; contract text

- **Change**: `TcWebBuildEnvOptions()` (`webhost.cpp`) is the one builder for
  host and keeper (the keeper's copy deleted; internal `webenvopts.h`), and
  sets `IsCustomCrashReportingEnabled = TRUE`. `architecture/11` states the
  options rule, the interop consequence, the navigation rule, and corrects
  "the folder holds cache only" (F5).
- **Guards**: `rg -c "put_IsCustomCrashReportingEnabled" src --glob "!src/common/dep/**"`
  → 1 file; `rg -c "disable-features=msWebOOUI" src/` → 1 file.
- **Correction found while writing the records**: the clarification answer
  said a viewer that cannot share the engine "falls back to the text view";
  neither viewer does — both show "engine unavailable" and close
  (`EngineFailed`). Spec, research, contract and changelog state the real
  consequence; the decision is unchanged.
- **Review — ACCEPT**.

## Gates

| Gate | Result |
|---|---|
| Debug x64 build (`build.cmd`) | succeeded, no new warnings in touched code |
| `saltests` | 1816 checks, 0 failed |
| `tests/mdview_htmlgen_test` | 38 passed, 0 failed |
| F2 probe / negative control | PASS / 9 failed (as required) |
| `tools/check_encoding.py` | TOTAL: 0 |
| plugin interface | `git diff src/plugins/shared/` empty — interface 106 |
| `build.cmd full release` | succeeded; runtime closure OK (219 modules) |

## Owed to a person

`quickstart.md` G1–G6 (GUI). Not run by this session: the GUI probes drive
the application against the current user's registry, which was not agreed for
this feature.

## Commits

| Commit | Content |
|---|---|
| `f9c28c0` | spec, research, plan, contract, tasks |
| `257fd24` | F1 |
| `0a47b0f` | F3 (host gate + mdview `http-equiv` rename) and F4/F5 (one options builder, crash reporting, contract text) — one commit because both change `webhost.cpp` |
| `079a7e2` | F2 (+ the fetch probe) |
| `eb176da` | F7 |
| `0ca10d5` | F6 |
| records | `PRIVACY.md`, `CHANGELOG.md`, `NEXT-WORK.md`, `CLAUDE.md`, this log, `quickstart.md` |

`PRIVACY.md` lands in the records commit at the end of the same branch, not
in each fix commit: the rule ("in the same change") is met by the feature as a
whole; a review of the public claims against the committed code ran before
that commit (below).

## Review of the public claims (PRIVACY.md, CHANGELOG.md)

An independent agent checked every changed sentence against the committed
code. Supported: the five history sinks (and that no other history can hold
such a password), the remote-image identification, cookies and sign-in, the
link gate, the salts, FTP/SFTP Master Password cancel. **Corrected**:

- old FTP Quick Connect entries are cleaned only at a configuration save after
  the FTP plugin has been used (a plugin's configuration is saved only while it
  is loaded, `plugins2.cpp:1749`);
- the advice "write `/` as `%2F`" was wrong (FTP decodes `%2F` before it splits
  the address) — removed; the command-line limit lists quotes, `<`, `>` too;
- the location of the engine's crash dumps was not evidenced — every record now
  claims only that they are not sent;
- the interop consequence applies to 0.1.5–0.1.8 (the versions sharing the
  folder) and only once the other instance has started its engine; it rests on
  Microsoft's documentation, not a measurement;
- "a document cannot open them by itself" hedged to "is designed so that…"
  (the runtime check G3 is owed);
- the validity line now lists what is different in 0.1.8 itself, because the
  winget `PrivacyUrl` points at `main` while the published package is 0.1.8.
