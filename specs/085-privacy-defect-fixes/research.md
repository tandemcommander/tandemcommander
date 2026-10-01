# Research: Privacy defect fixes (085)

All sites below were re-checked at HEAD `7f50632` (2026-10-01) before any
design was written — the 069 fix-protocol rule "check the site is still
defective at HEAD first". Every one of F1, F2, F3, F6 and F7 is still present.

## R1 — F1 inventory: which histories can hold a typed address

An independent read-only sweep (every caller of `AddValueToStdHistoryValues`,
every history array, every location store) produced this table. "Raw" means
the user's typed text is stored before any plugin normalises it.

| # | Sink | Array | Add site | Saved at | Raw typed URL? |
|---|---|---|---|---|---|
| 1 | Change Directory (Shift+F7) | `Configuration.ChangeDirHistory` (20) | `dialogs3.cpp:1202` (`CChangeDirDlg::Transfer`) | `mainwnd2.cpp:1959` | **yes** — stored on OK, before `PostProcessPathFromUser`, even if the change fails |
| 1a | same array via the plugin service | `SALHIST_CHANGEDIR` (`zip.cpp:4136`) | `demoplug/fs1.cpp:133` (sample plugin, not shipped) | same | yes |
| 2 | Core Copy/Move, disk → anywhere | `Configuration.CopyHistory` (20) | `dialogs3.cpp:634` (`CCopyMoveMoreDialog`) | `mainwnd2.cpp:1957` | **yes** — the target may be a plugin path (`fileswn8.cpp:533`, upload to FTP) |
| 2a | Core Copy/Move, plugin FS / archive → target | same | `dialogs3.cpp:439` (`CCopyMoveDialog`) | same | **yes** |
| 2c | FTP plugin's download dialog | same, via `SALHIST_COPYMOVETGT` (`zip.cpp:4122`) | `ftp/dialogs4.cpp:1329` → `CSalamanderGeneral::AddValueToStdHistoryValues` (`zip.cpp:4173`) | same | **yes** |
| 3 | Command line | `Configuration.EditHistory` (30) | manual loop `editwnd.cpp:559-580`, only when the command ran | `mainwnd2.cpp:1970` | **yes**, any command text |
| 4 | Find *Look in* | `FindLookInHistory` (30) | `finddlg1.cpp:1813` via `HistoryComboBox` (`viewer.cpp:49`) | `mainwnd2.cpp:1951` | possible, unlikely (validation rejects only an empty list) |
| 5 | FTP Quick Connect *Address* | `Config.HostAddressHistory` (30) | `ftp/dialogs1.cpp:930`; the edit text is reset to `LastRawHostAddress` at `:927` so the history gets the unsplit string | `ftp.cpp:864`, only with `SALCFG_SAVEHISTORY` | **yes** (the 083 finding) |
| 6 | FTP Quick Connect *Initial path* | `Config.InitPathHistory` | `ftp/dialogs1.cpp:934` | `ftp.cpp:865` | no — the path is split out of the address; a URL would have to be typed into the path box |
| 7 | FTP *Send FTP Command* | `Config.CommandHistory` | `ftp/dialogs8.cpp:157/165` | `ftp.cpp:861` | not an address; `PASS x` is kept out when sent as a secret command (`Config.SendSecretCommand`) — unchanged |

Not address-bearing (masks, names, search text): Convert, Filter, Select, File
List, Create Dir, Quick Rename, Edit New, Find *Named* and *Containing*,
viewer search; the renamer, regedt, dbviewer, mmviewer, pictview and filecomp
histories.

**Location stores record the path the plugin reports back**, not the typed
text: Working Directories (Alt+F12, `fileswn2.cpp:1514/3029/3164` from
`GetPluginFS()->GetCurrentPath()`), per-panel back/forward history (not saved),
panel tabs (`paneltabs.cpp:179/327`, `GetGeneralPath`), hot paths
(`GetGeneralPath`), panel path / per-drive last folder (disk paths only). FTP's
`GetCurrentPath`/`GetFullName` go through `MakeUserPart`
(`ftp/fs2.cpp:80`), which writes `//user@host[:port]/path` — **no password**.
They are out of scope.

**SFTP** does not split a password out of an address: `ParseUserPart`
(`sftp/fs.cpp:298-314`) takes everything before `@` as the user name, so
`sftp:u:secret@h` would set the user name to `u:secret` and echo it into the
panel path. The server rejects such a user name, so the session never lists
and the path is never recorded; the typed text itself is covered by sinks 1–3.
Recorded, not changed.

**Persistence**: `SaveHistory` (`salamdr2.cpp:2662`, FTP `ftp.cpp:454`) clears
the key and rewrites the in-memory array; `LoadHistory` (`salamdr2.cpp:2618`,
FTP `ftp.cpp:418`) reads it back unchanged. So an entry saved by 0.1.8 is
re-saved on every configuration save until it is pushed out — which is why the
cleaning must also run at load (FR-005).

## R2 — F1 decision: one rule, stripped at the history, never at the operation

**Decision**: a pure function in `src/common/salurlpwd.{h,cpp}`, compiled into
the core, `saltests` and the FTP plugin (the same way `src/common/webhost/` is
compiled into both viewer plugins). It is applied to the **history copy** only;
the value handed to the operation is never touched, so how an address is parsed
for connecting does not change at all.

Where it is applied:

- after each add to sinks 1, 2, 2a, 3, 4 — the whole (≤ 30-entry) array is
  cleaned, which also removes a duplicate the add may have created;
- inside `CSalamanderGeneral::AddValueToStdHistoryValues` when the array is
  one of the two core path histories it hands out (`CopyHistory`,
  `ChangeDirHistory`) — covers 1a and 2c **without changing the plugin
  interface**;
- in FTP Quick Connect, the text written back into the Address field before
  `HistoryComboBox` reads it (sink 5) is the stripped copy of
  `LastRawHostAddress`; the drop-down and the history then both hold the clean
  form, and the connection data split on `CBN_KILLFOCUS` is untouched;
- after `LoadHistory` for sinks 1/2/3/4 (core) and 5 (FTP).

**Alternatives rejected**:

- *Strip inside `::AddValueToStdHistoryValues` for every caller*: it also
  serves masks and search text; a grep text such as `http://u:p@h` would be
  rewritten in a history whose purpose is to recall it exactly.
- *Strip at save time only*: the in-session drop-down would still show the
  password on screen, and an exported configuration taken before the save
  would contain it.
- *Reuse the FTP plugin's own parser (`FTPSplitPath`)*: for
  `user:p@ss@host` it yields password `p` and host `ss@host`
  (`ftputils.cpp:493-512`, the right-to-left parse gives up on an `@` in the
  password), which would leave `ss` of the password in history. A history
  rule must err towards removing more.

## R3 — F1 rule details

The address part starts:

1. after every `://` preceded by a scheme of ≥ 2 characters
   (`[A-Za-z][A-Za-z0-9+.-]+`), anywhere in the text (the command line can hold
   several URLs — clarification Q2);
2. after a leading (white space skipped) `name:` with name ≥ 2 characters,
   when no `//` follows (the file-system form `ftp:user:pw@host`);
3. after a leading `//` (the user part of a plugin path sent directly to a
   plugin, `//user:pw@host`).

The FTP plugin computes the start itself (its own two file-system names, then
an optional `//`) and calls the authority function directly, because in Quick
Connect `alice:pw@host` is an address, while in the core it would look like a
scheme named `alice`.

The address part ends at the first `/`, white space, `"`, `'`, `<`, `>` or the
end of the text; for form 2 also at `\` (so a registry path
`reg:HKCU\Soft:x@y` is never touched). In forms 1 and 3 `\` does not end it —
FTP accepts `ms-domain\name` as a user name (`ftputils.cpp:465`).

Inside it: `at` = the **last** `@`; `colon` = the **first** `:` before `at`.
If both exist, `[colon, at)` is removed. No `@` → no user part → unchanged
(`host:2121` keeps its port). No `:` before `@` → no password → unchanged.

One-letter schemes are drive letters (`C:`), never treated as a scheme.
Bytes are compared as ASCII; all delimiters are < 0x80, so UTF-8 text (the core
contract) is safe. The FTP plugin's history may hold code-page text in a DBCS
locale, where a trail byte can be 0x40 (`@`); the worst case is that part of a
user name containing `:` is also removed from the history entry — privacy-safe,
and not reachable in a Latin-script locale.

**Revised after the first independent review (REJECT, 2026-10-01).** The rule
above ended the address part at white space and quotes everywhere and at `\`
in form 2; FTP accepts all of these inside a password (`FTPSplitPath`'s
`passEnd` loop stops only at `@ : / \`, "leave the password as is (do not
skip spaces)"), so `alice:correct horse@host` kept the whole password. Now a
single value ends only at `/`; the command line keeps the word ending, except
inside a quoted URL; `%3A`/`%40` count as `:`/`@` (the FTP plugin decodes them
first when *ConvertHexEscSeq* is on); the FTP address form is the pure, tested
`SalStripAddressPassword`; and the copy/move strip is limited to `CopyHistory`
(the dialog also serves Create Directory, Quick Rename and Edit New). The
contract (`contracts/history-password-strip.md`) holds the current rule.

## R4 — F3: the engine's user-gesture flag

`ICoreWebView2NavigationStartingEventArgs::get_IsUserInitiated` and
`ICoreWebView2NewWindowRequestedEventArgs::get_IsUserInitiated` are both on the
**base** interfaces in the vendored SDK (`WebView2.h:54838`, NewWindowRequested
base interface), so no `QueryInterface` and no runtime-version gate is needed.
A `<meta http-equiv="refresh">`, a script-driven `location` change and a
redirect report FALSE; a mouse click or keyboard activation of a link reports
TRUE.

**Decision** (`src/common/webhost/webhost.cpp:266-299`): keep cancelling every
navigation that is not the host's own document; forward to `OnActivateLink`
only when `IsUserInitiated` is TRUE; same for `NewWindowRequested` (always
`Handled`). A failed `get_IsUserInitiated` counts as FALSE (fail closed).

Consequences beyond the external browser: an automatic refresh to a relative
`.md` would today spawn a new viewer window (`mdview/viewer.cpp:745`), and one
to any other local target would raise a message box (`:770`) — both gone with
the same check. The Code Viewer's handler is a no-op
(`codeview/viewer.cpp:1039`), so it is unaffected.

The host's own `Navigate()` is matched by the `baseUrl` prefix before the
check, exactly as today (`webhost.cpp:276`), so the document still loads.

## R5 — F2: remote fetch

`FetchRemote` (`mdview/webglue.cpp:82-140`): `WinHttpOpen(L"OpenSalamander-mdview", …)`,
no `WINHTTP_OPTION_DISABLE_FEATURE`, no status query.

**Decision**: move the function verbatim into
`src/plugins/mdview/remotefetch.{h,cpp}` (no plugin globals, so a probe can
compile it alone), then: user agent `TandemCommander-mdview`;
`WinHttpSetOption(hr, WINHTTP_OPTION_DISABLE_FEATURE,
WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION)` on the request;
after `WinHttpReceiveResponse`, `WinHttpQueryHeaders(WINHTTP_QUERY_STATUS_CODE
| WINHTTP_QUERY_FLAG_NUMBER)` and fail unless 200–299, before any body is read.
Redirects keep WinHTTP's default (followed, never HTTPS → HTTP), which
`PRIVACY.md` already describes. No version in the user agent — less
fingerprinting, and nothing to keep in sync.

## R6 — F6: the generator

`FillBufferWithRandomData` (`pwdmngr.cpp:37-47`) is the only producer of the
AES salt (`:556`) and the verifier's salt and dummy (`:762-763`).

**Decision**: `BCryptGenRandom(NULL, buf, len, BCRYPT_USE_SYSTEM_PREFERRED_RNG)`
(`#pragma comment(lib, "bcrypt.lib")`, the house style of `salamdr1.cpp:51`).
On the practically impossible failure, `TRACE_E` and fall back to the old
generator rather than leave the buffer as it was (an all-zero salt would be
worse than a weak one). Salts are stored with the data they protect, so every
existing blob stays readable (SC-005). `ScramblePassword`'s padding (`:84-98`)
is obfuscation, not cryptography — left as it is.

## R7 — F7: cancelled Master Password prompt

`sftp/dialogs.cpp:851-856` (password) and `:887-892` (passphrase):
`enc = pm->AskForMasterPassword(hwnd)` and then `EncryptPassword(…, enc)` runs
regardless, so a cancel stores the scrambled form.

**Decision**: FTP parity (`ftp/dialogs1.cpp:1755-1760`, `:1891-1898`): when the
prompt fails, do not save the secret, turn `SavePassword`/`SavePassphrase` off
and uncheck the box. `ConnectPlainPassword`/`Passphrase` were already filled
above, so a connection still uses the typed secret. Because
`ConnectCommitToEntry` builds a fresh `CSFTPServer` (`:962`), "save off" also
clears a previously stored blob — the same rule feature 017 set for unchecking
the box by hand (FR-007 there).

Other prompt sites were checked and are not affected: the FTP Quick Connect
split (`ftp/dialogs1.cpp:1755`) and bookmark dialog (`:1893`) already uncheck;
the FTP proxy dialog asks when the box is ticked (`dialogs8.cpp:2075`) and
unticks on cancel; `ftp.cpp:1477` is the one-time legacy import, which the
next configuration save re-encrypts.

## R8 — F4/F5: viewer engine crash upload

`CoreWebView2EnvironmentOptions` in the vendored
`WebView2EnvironmentOptions.h:357` implements
`ICoreWebView2EnvironmentOptions3::put_IsCustomCrashReportingEnabled`.
Microsoft's reference: *"When `IsCustomCrashReportingEnabled` is set to
`TRUE`, Windows won't send crash data to Microsoft endpoint. […] default
`FALSE`, in this case, WebView will respect OS consent."* (Introduced in SDK
1.0.1518.46; the vendored SDK is 1.0.4078.44.) Where the engine then keeps the
dumps is not documented there and was not measured — the records claim only
that they are not sent (corrected after the claims review).

The options object is built twice — `TcWebBuildEnvOptions` (`webhost.cpp:51`)
and `TcWebKeeperEnvOptions` (`webkeeper.cpp:28`) — and Microsoft documents
for `CreateCoreWebView2EnvironmentWithOptions`: *"WebView creation fails with
`HRESULT_FROM_WIN32(ERROR_INVALID_STATE)` if the specified options does not
match the options of the WebViews that are currently running in the shared
browser process."* (Not measured in this feature.) **Decision**: one options builder. `TcWebBuildEnvOptions()` in `webhost.cpp`
stops being `static`, sets the browser arguments **and**
`IsCustomCrashReportingEnabled = TRUE`, and is declared in a new internal
header `src/common/webhost/webenvopts.h` (it needs the WRL headers, so it
cannot live in the COM-free `webhost.h`). The keeper's own
`TcWebKeeperEnvOptions()` is deleted and calls the shared builder — the
single-definition rule feature 081 applied to the argument string, extended to
the whole options object, so the two can never drift apart again.
Guard: `rg -c "put_IsCustomCrashReportingEnabled" src/` == 1 (outside
`src/common/dep/`).
Accepted risk (clarification Q1): an older instance running at the same time
holds an engine with the old setting; the viewer started later gets
`ERROR_INVALID_STATE`, and `EngineFailed` (both viewers) shows "engine
unavailable" and closes the window, until that instance closes. (The
clarification question had said "falls back to the text view"; checking the
code during implementation showed that neither viewer does that after the
runtime check — corrected here and in the changelog.)

F5: `architecture/11-webview2-integration.md:59-60` says the folder "holds
cache only"; it also holds cookie, history and storage databases (083 R-side
findings) and, from now on, crash dumps. Corrected with the contract change.

## R9 — Not in scope

- F9 (FTP anonymous e-mail placeholder) — not asked.
- The SFTP `user:password@host` echo (R1) — not reachable in practice.
- FTP *Initial path* history (sink 6) — holds a path, not an address.
- Whether the copy hook's absence is intended (083 open question, F8).
