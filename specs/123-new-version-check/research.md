# Research: New Version Check

**Feature**: 123-new-version-check · **Date**: 2026-10-06

Facts marked *measured* come from this session (network measurements are in
[source-analysis.md](source-analysis.md); code facts were read at
`48206df9`). No item is left as NEEDS CLARIFICATION.

## R1. Source of the version information

**Decision**: one request,
`GET https://api.github.com/repos/tandemcommander/tandemcommander/releases/latest`.
No fallback source in this feature.

**Rationale**: the only candidate that gives version, release date and proof
that the installer asset exists in one documented answer (7 KB, measured).
Clarification Q4 made *Download* open the installer file directly, so that
proof matters: a derived address for an asset that is not there would be a dead
download.

**Alternatives considered**: the web redirect `github.com/…/releases/latest`
(no body, no API limit, but no date and no asset proof) — kept in mind as the
fallback *if* the rate limit proves a real problem, not built now; the release
list (11× the data); the Atom feed; a file on tandemcommander.org (a second
publication step per release). Conditional requests with `ETag` are **not**
used: measured, an unauthenticated `304` still counts against the limit, so
they would save 7 KB a day and add stored state.

## R2. HTTP client

> **Superseded in implementation (2026-10-06, after the independent reviews).** The request
> runs in WinHTTP's *asynchronous* mode on the worker thread: Microsoft documents that the
> handle of a synchronous request must never be closed from another thread, and only the
> asynchronous mode lets the worker abandon a request at once and bound the whole request
> (12 s, every phase) by itself. Timeouts are 4 / 4 / 2 / 8 s inside that bound; a cancel
> never touches WinHTTP from the main thread; the exit waits at most 1.5 s for a worker
> that has already been told to stop. The current contract is `contracts/update-source.md`;
> the text below records the original decision.

**Decision**: WinHTTP, synchronous, on a dedicated worker thread, in the core
(`src/updcheck.cpp`). `winhttp.dll` is **delay-loaded**
(`/DELAYLOAD:winhttp.dll` + `delayimp.lib`).

Request settings (contract: [contracts/update-source.md](contracts/update-source.md)):

- `WinHttpOpen` with `WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY` (system proxy
  settings, no interactive sign-in).
- `WINHTTP_FLAG_SECURE`; certificate errors are never ignored.
- `WINHTTP_OPTION_DISABLE_FEATURE` =
  `WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION | WINHTTP_DISABLE_REDIRECTS`;
  a request that cannot be configured so is not sent (the feature-085 rule —
  its probe showed default WinHTTP answering a Negotiate challenge with the
  Windows logon).
- Timeouts through `WinHttpSetTimeouts`: resolve 5 s, connect 5 s, send 5 s,
  receive 8 s; plus an overall deadline of 12 s enforced while reading. With
  the UI's own slack this meets SC-006 (15 s).
- Only status `200` is read; the body is capped at 256 KB (the real record is
  7 KB).

**Rationale**: WinHTTP is the service-grade Windows client, already used and
hardened in the tree (`src/plugins/mdview/remotefetch.cpp`), needs no vendored
code and no UI. Delay-loading keeps the start-up of a program with the check
off byte-for-byte free of the new module (SC-002) and loads it on the worker
thread otherwise.

**Alternatives considered**: WinINet (per-user cache, cookies, UI prompts —
wrong for a silent background request); `URLDownloadToFile` (same stack, less
control); lifting `MdFetchRemote` into `src/common` and sharing it — rejected:
its contract is "any URL, 32 MB, redirects followed", the opposite of what this
request needs; the two stay separate, with the same hardening lines.
Asynchronous WinHTTP — more code for no gain with one request.

**Cancel and exit**: the UI thread cancels by closing the request handle
(documented to abort a pending synchronous call). The worker owns a
reference-counted context; on program exit the handle is closed and the thread
is waited for at most 1 s, then left to end by itself — exit is never held by
the network (spec edge case).

## R3. Reading the answer (JSON)

**Decision**: a small strict JSON reader written for this purpose in
`src/common/salupdcheck.cpp` (pure, no allocation beyond the extracted
strings): full grammar recognition with a nesting limit (32) so that values can
be *skipped* correctly, string unescaping including `\uXXXX` surrogate pairs,
extraction of a fixed set of top-level fields and of `assets[].name / state /
browser_download_url`. Anything that is not well-formed JSON of the expected
shape is "unexpected answer".

**Rationale**: there is no JSON parser in the tree (`src/common/dep/`: bzip2,
crypt, fmt, libssh2, md4c, nanosvg, pnglite, sqlite, webview2, wil, zlib). Five
fields do not justify vendoring a library, and a reader that understands the
grammar is safer than searching for `"tag_name"` in text (the release body is
free text and could contain that very string).

**Alternatives considered**: vendoring nlohmann/json (MIT, GPL-compatible,
~25,000 lines for five fields, exceptions in the core); substring search
(unsafe, above); WinRT `Windows.Data.Json` (COM/WinRT activation in the core
for one request).

## R4. What counts as "a newer release"

**Decision** (pure, `SalUpdValidateRelease`):

1. `draft == false` and `prerelease == false` (the endpoint already excludes
   them; checked anyway).
2. `tag_name` matches `v<major>.<minor>.<patch>`, each part 1–5 decimal digits,
   nothing else.
3. Among `assets` there is one with `name` exactly
   `tandemcommander-<ver>-x64-setup.exe`, `state == "uploaded"`, and
   `browser_download_url` **exactly equal** to the address the program
   constructs itself:
   `https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe`.
4. `html_url` exactly equal to the constructed
   `https://github.com/tandemcommander/tandemcommander/releases/tag/v<ver>`.
5. `published_at` is a valid `YYYY-MM-DDThh:mm:ssZ` time (shown as a long date
   in the user's locale; a missing or invalid date fails the record).

Order: compare (major, minor, patch) with `VERSINFO_SALAMANDER_MAJOR / MINORA /
MINORB`. Higher → *newer*; equal or lower → *up to date*. A record that fails
1–5 is *unexpected answer* for a manual check and silence at start-up.

**Rationale**: with rule 3 and 4 the program never hands the browser a string
that came from the network — it opens only addresses it built from three
validated numbers (FR-004, SC-008). The asset name pattern is the one every
release so far uses and the winget template already depends on
(`tools/winget/templates/installer.yaml.in`).

**Consequence for the release procedure**: the installer must keep this name,
and a release should be published with its asset attached; a release without it
is simply not offered (FR-002).

**Alternatives considered**: accepting any `browser_download_url` under the
official prefix (weaker, no benefit); using the asset `digest` — nothing to
verify it against, since the program does not download the file (FR-005).

## R5. Stored state and several instances

**Decision**: a dedicated subkey `…\0.1\Update Check`, written immediately when
a value changes and read fresh at every use — **not** part of the
`Configuration` structure that is saved on exit. Values in
[contracts/stored-state.md](contracts/stored-state.md).

**Rationale**: three requirements rule out the ordinary configuration path:
the once-a-day limit must hold across instances that are running at the same
time (FR-008); a choice made in the notification must hold for instances
started later even if the first one is still running (edge case) and even with
*Save configuration on exit* off; and an instance that exits later must not
write an old in-memory copy back (the usual last-writer-wins of the
configuration).

**Claiming a check**: under a named mutex
(`Local\TandemCommanderUpdateCheck`) the instance reads the state, applies the
throttle rule and, if due, writes `Last Attempt = now` *before* the request.
A second instance started in the same second finds the attempt and does
nothing.

**Throttle rule** (pure, `SalUpdAutoCheckDue`): due when the option is on and
`now − Last Attempt ≥ interval`, where the interval is 24 h after an attempt in
which the source answered (any HTTP status) and 1 h after an attempt in which
it was not reached at all (no connection). A `Last Attempt` in the future is
ignored (wrong clock, edge case). FR-008 speaks of *contacting the source*; an
attempt that never got an answer has not used the user's daily contact, and a
laptop started offline in the morning should not stay uninformed until the
next day.

**Alternatives considered**: values under `Configuration` (fails all three
requirements above); a file in `%LOCALAPPDATA%` (a second store for no gain);
no cross-process claim (two instances started together would both ask).

**To verify in implementation**: that 0.1.8 neither fails on nor deletes the
unknown subkey when it saves its configuration (probe row; FR-026).

## R6. The notification window

**Decision**: a **modeless** dialog `IDD_UPDATENOTICE` owned by the main
window, with a caption and a close button. Layout and behaviour in
[contracts/ui.md](contracts/ui.md).

- Header band painted like the About dialog (brand artwork
  `IDB_LOGO_IMAGE`, GDI wordmark, the blue→orange accent line, navy or white by
  theme) — the product's identity without a foreign style.
- The versions as the dominant element: installed → available, in a larger
  bold face derived from the dialog font; release date under it; a *Release
  notes* `CHyperLink`.
- Buttons: **Download** (default), *Remind Me Later*, *Skip This Version*; a
  check box *Check for a new version at start-up*.

**Why modeless**: a modal dialog disables the main window, which (a) blocks
the user at start-up, (b) makes the Restart Manager's question find a "busy"
program and fail an update while the notification is open (feature 080,
reason D2), and (c) cannot wait politely behind another window. Modeless, the
window sets `SALCLOSEAPP_WINDOW_PROP` (feature 088: "holds nothing to lose")
so `DecideCloseApp` agrees, and an unattended close destroys it as *Remind me
later*.

**Showing without stealing the keyboard**: the window is shown when the main
window is enabled and no menu is open; it is *activated* only if the main
window is the foreground window, the command line is empty and there was no
keyboard or mouse input in the last 2 seconds; otherwise it is shown without
activation (`SW_SHOWNOACTIVATE`) above the main window. While another modal
window is open it waits (1 s timer).

**One notification per user** (FR-018): the window carries a window property
(`TandemCommander.UpdateNotice`); before showing, the instance enumerates
top-level windows for it — at start-up it then shows nothing, on a manual
check it brings the existing window to the front.

**Alternatives considered**: a message box (cannot carry the design the
maintainer asked for); a modal dialog (above); a tray balloon / toast (needs an
AppUserModelID registration and a shortcut for reliable toasts; outside the
house style); an information bar in the main window (a new UI element across
panels — larger change, less visible "design").

## R7. Manual check

**Decision**: `CM_HELP_CHECKVERSION` starts the same worker with the *manual*
flag. If no result arrives within 500 ms a small modal wait dialog
(`IDD_UPDATECHECKING`: text + Cancel) appears; Cancel closes the request
handle. Result: the notification window (activated), or a house message box —
*up to date* (information), *could not check* in three wordings (source not
reached / source refused, try later / unexpected answer). A manual check while
an automatic one is running attaches to it instead of starting a second
request.

**Menu**: Help → **Check for New Version**, then *About Tandem Commander* (About
stays last, the Windows convention). No ellipsis: the command needs no further
input. Czech: *Zkontrolovat novou verzi* (pinned in `ui-overrides.json`).

## R8. About dialog

**Decision**: one new line under the version, `IDC_ABOUT_UPDATE` (dialog 11
units taller), filled from the stored state at `WM_INITDIALOG`:

| State | Text | Link |
|---|---|---|
| newer known | "Version %s is available." | **Download** → installer address |
| up to date | "This is the latest version (checked %s)." | — |
| not checked | "Not checked for a new version." | **Check now** → posts `CM_HELP_CHECKVERSION` |

`CHyperLink::SetActionOpen` / `SetActionPostCommand` already exist
(`src/gui.h`); the constructed addresses are 110 bytes, inside its
`File[MAX_PATH]`. Opening the dialog makes no request (FR-024); a result that
arrives while it is open updates the line (the service keeps the About
window's handle while it exists).

## R9. The option

**Decision**: check box on the **General** configuration page
(`IDD_CFGPAGE_GENERAL`, free space below `IDC_RELOADENVVARS` at y = 172):
*Check for a new &version at start-up*. Its `Transfer` reads and writes the
stored state directly (R5), so it and the notification's check box are one
setting (FR-025). Turning it off does not erase what is known; the About
dialog keeps showing the last result.

**Alternatives considered**: a new configuration page (one option does not
carry a page; the page index trap of feature 071); the Security page (it is
about passwords).

## R10. Privacy

**Decision**: the request sends a fixed `User-Agent`
`TandemCommander-updatecheck` — **without the installed version**, without any
identifier — plus `Accept: application/vnd.github+json` and
`X-GitHub-Api-Version: 2022-11-28`. No cookies, no authentication, no referrer.

`PRIVACY.md` changes in the same change: the opening claim that the program
uses the network only as a result of the user's action, a new entry under
*When the program uses the network* (host, what GitHub sees: the IP address
and the fixed identification; when: once a day at start-up unless turned off,
and on the Help command), the stored values, how to turn it off, and the
validity line. Each sentence gets a row in the claim map
(`fix-log.md`), checked against the fixture server's request log.

**Rationale**: the version is not needed to answer "what is the latest
release", and sending it would let the host count installations per version.

## R11. Test seam

**Decision**: **Debug builds only** honour two environment variables:
`TC_UPDATECHECK_URL` (an `http://127.0.0.1:<port>/…` address replacing the
endpoint — plain HTTP to loopback only, anything else is ignored) and
`TC_UPDATECHECK_PRETEND_VERSION` (`x.y.z` used as the installed version).
Release builds contain neither.

**Rationale**: SC-003/004/007/008 need a server that returns hostile and
broken answers and counts requests; certificate validation against a local
server cannot be had without weakening the very check under test. Because
addresses are constructed (R4), the seam can never change what the browser is
asked to open. Release is verified against the real endpoint (today: *up to
date*); the *newer* path in a Release build is proven at the first release
after this feature ships — an owed step, recorded in quickstart § H.

**Alternatives considered**: a seam in Release behind a registry value
(a permanent redirect switch in a shipped binary); a local HTTPS server with a
test root certificate installed for the probe (touches the user's certificate
store on the maintainer's machine).

## R12. Windows Package Manager installations (out of scope, recorded)

Facts given to the maintainer on 2026-10-06 (general knowledge of winget and
the project's templates; not measured in this session): winget installs the
same Inno Setup installer and recognises the program by its Add/Remove Programs
entry, so both update paths work crosswise; winget never updates by itself; the
catalogue lags behind a release by its review time. The program cannot tell how
it was installed unless the installer records it — a custom installer switch in
the manifest (`InstallerSwitches: Custom`) writing one registry value would do
it, and would change what the installer writes (→ `PRIVACY.md`).

**Decision**: not in this feature. The notification is the same for everyone
and *Download* is correct for winget installations too. The marker and a
"`winget upgrade tandemcommander`" hint are a possible follow-up; nothing in
this design has to change for it.

## R13. Translations, help, documentation

- New dialogs and strings go through the two-stage `.slt` refresh
  (`translate.merge` with `--templates <build>/translator/templates`); expected
  pins under `_feature_123`: the Czech menu command, the formal register for
  de/fr/nl/es, the product name untranslated. New string IDs are placed in
  free slots of existing bundles where possible (the bundle-ordinal trap of
  features 079 and 084).
- The 3 disabled languages are skipped by the tools by default.
- Help: a new topic for the command and the notification, and the option added
  to `help/src/hh/salamand/configuration_gener.htm` (new pages carry the
  Tandem Commander footer, as `configuration_cmdshell.htm` does).
- `CHANGELOG.md` under `## [Unreleased]`; `CLAUDE.md` Recent Changes entry and
  the Privacy/Key Facts lines; `architecture/04-dependencies.md` gains WinHTTP
  as a system dependency of the core.
