# Feature Specification: Automatic update - download the new installer in the background and install it

**Feature Branch**: `420-auto-update-install`
**Created**: 2026-11-08
**Status**: Draft
**Input**: User description: "Backlog item automatic-update-background-download - implement exactly what it describes" (full input: the item's Problem / Evidence / Expected / Approach / Notes and the maintainer's requirements given with the run). From backlog item automatic-update-background-download.

## Context

Since feature 123 the program checks GitHub about once a day for a newer published release and
shows a notification whose *Download* button hands the installer's address to the web browser.
The user still has to download the installer, run it and click through it. The maintainer decided
on 2026-11-08 (item *Log*) that the program downloads the new installer itself, verifies it and
installs it - on the user's click, or automatically when the program closes - controlled by one
setting with three levels. Measured at `824e8f58`: nothing in the program downloads or runs an
installer; the release record of the GitHub API carries a SHA-256 digest of the installer; the
published installer is signed with the project's certificate.

## Clarifications

### Session 2026-11-08

- Q: Does the next start ask before it completes an update the exit did not install? → A: No - it installs at once through the *Install Now* route (progress window, close, restart); the maintainer asked for completion, and the arm already was the user's or the level's consent (autonomous run: item).
- Q: Does a check the user asks for (Help > Check for New Version, About > Check now) also download? → A: Yes, with the same level rules; the notification appears at once in today's form when no verified installer exists yet and is replaced by the downloaded form when the download completes (autonomous run: recommended - one behaviour for both checks).
- Q: Does the About box's *Download* link change? → A: No, it still opens the browser download (autonomous run: conservative - unchanged behaviour for a case the item does not name).
- Q: What happens to a downloaded installer when the user switches to *Notify me only*? → A: It stays on disk until it is superseded, its version is reached or the user skips it; it is never run while the level forbids it (autonomous run: conservative - nothing deleted that may be wanted again).
- Q: What does *Remind Me Later* do on the downloaded-form notification? → A: Closes it; nothing is armed; the verified installer is reused at the next check without a new download (autonomous run: conservative).
- Q: The maintainer asked that an update planned for the exit that was not performed at the exit is completed at the next start - does that include an installer the exit started that was cancelled by the user or whose elevation prompt was declined? → A: No - the item (*Expected* 5) says a declined prompt leaves the update offered; completed at the next start is every case in which the exit did not start the installer (crash, kill, power loss, sign-out / shutdown, another instance, the program reopened during the exit); a started installer that did not install it is offered at the next start (autonomous run: item; review 2 S1).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Download in the background and offer the installation (Priority: P1)

A user with the default setting starts the program. The daily check finds a newer release. The
program downloads that release's installer in the background, proves that it is the published
file and signed by the project, and then shows the notification: the new version is downloaded
and verified; *Install Now* or *Install When I Close*, *Remind Me Later*, *Skip This Version*.
*Install Now* closes the program, installs the update with a progress window and starts the
program again; *Install When I Close* installs it when the user closes the program.

**Why this priority**: it is the new default for every user and the core of the item.

**Independent Test**: with a fixture release (a signed installer and its record) the probe sees the
download, the verification, the notification with the four buttons, and the installer command
line of each button.

**Acceptance Scenarios**:

1. **Given** the default level and an installed copy, **When** the check finds a newer release, **Then** the installer is downloaded into the program's folder under `%LOCALAPPDATA%`, verified, and the notification offers *Install Now* / *Install When I Close* / *Remind Me Later* / *Skip This Version*; nothing is installed without a click.
2. **Given** that notification, **When** the user clicks *Install Now*, **Then** the installer runs in the install mode of the existing installation, closes the program through the update close of features 080 / 088 / 118, installs with a visible progress window and starts the program again.
3. **Given** that notification, **When** the user clicks *Install When I Close* and later closes the program normally, **Then** the installer runs silently after the program has ended and the next start runs the new version.
4. **Given** the download or the verification failed, **When** the check result is shown, **Then** the user gets today's notification (*Download* in the browser) and the failed file is gone.

---

### User Story 2 - Full automatic update at exit, completed at the next start if the exit did not do it (Priority: P1)

A user who chose *Install automatically when the program closes* is told once that the new version
is downloaded and will be installed when they close the program. When they close it, the update is
installed silently and the next start runs the new version. If that did not happen - the program
ended without its normal exit (crash, kill, power loss, sign-out or shutdown of Windows), or the
installer did not finish - the next start completes the planned update.

**Why this priority**: the maintainer's explicit requirement of this run ("prove that an update
planned for the exit that was not performed at the exit is completed at the next start").

**Independent Test**: arm the update, end the program without its normal exit, start it again and
observe the installer started at once with the update close and restart arguments; a second run
with the real signed installer over a per-user test installation proves the files change.

**Acceptance Scenarios**:

1. **Given** the automatic level and a verified installer, **When** the user closes the program normally and it is the last running instance of this installation, **Then** the installer is started silently with no restart of the program, and the next start runs the new version.
2. **Given** an armed update, **When** the program ends without its normal exit, **Then** the next start installs the update at once (progress window, the program closed and started again).
3. **Given** an armed update and an installer launched at exit that did not finish (the version is still the old one at the next start), **Then** the next start installs it again; after 3 launches for the same version the program stops trying and offers the update in the notification instead.
4. **Given** other instances of the same installation are running, **When** one instance closes, **Then** it does not install (it would close the others); the last instance to close installs.
5. **Given** Windows is signing out or shutting down, or an installer is closing the program, **When** the exit runs, **Then** no installer is started at that exit; the next start completes the update.

---

### User Story 3 - One setting to change the behaviour later (Priority: P1)

The user opens Configuration > General and finds, under the existing *Check for a new version at
start-up* box, a choice *When a new version is found*: *Notify me only* / *Download it and offer
installation* (default) / *Install it automatically when I close Tandem Commander*. Turning the
check off, or choosing *Notify me only*, stops all downloading and installing.

**Why this priority**: the maintainer's requirement of this run ("a place in the settings to change
the behaviour - switch it off, or full automatic update").

**Independent Test**: the probe sets each level through the page and reads the stored value; with
*Notify me only* no download happens and today's notification appears.

**Acceptance Scenarios**:

1. **Given** a configuration without a stored level (new or existing users), **When** the page opens, **Then** *Download it and offer installation* is selected.
2. **Given** the check box *Check for a new version at start-up* is cleared, **Then** the level choice is disabled and nothing is downloaded or installed.
3. **Given** an update armed by the automatic level, **When** the user changes the level to another value or turns the check off, **Then** the armed update is cancelled (an update the user armed by a click stays armed).

---

### User Story 4 - Never run a file that is not proven ours (Priority: P1)

Whatever the network returns, the program runs only the installer that GitHub publishes for that
release, byte for byte, signed with the project's certificate, carrying the announced version.

**Why this priority**: without it the update is a path to running foreign code.

**Independent Test**: a fixture server returns a tampered file, a file signed by another publisher, an
unsigned file, a truncated file, an installer of another version, a redirect to another host; each
is refused, deleted and never started.

**Acceptance Scenarios**:

1. **Given** a downloaded file whose SHA-256 differs from the release record's digest, **Then** it is deleted and never run.
2. **Given** a file that is not validly Authenticode-signed, or signed by a certificate other than the project's, **Then** it is deleted and never run.
3. **Given** a file whose version resource names another product or another version than the announced one, **Then** it is deleted and never run.
4. **Given** a redirect to any host other than GitHub's release download hosts, or to plain HTTP, **Then** the download is refused.
5. **Given** a verified file on disk, **When** it is about to be run (at once, at exit or at the next start), **Then** it is verified again first.

---

### User Story 5 - Test mode `--updatetest` (Priority: P2)

The maintainer starts an installed copy with `--updatetest`. The program checks at once, treats the
latest published release as newer even when it is the installed version, and runs the whole update
for real - download, verification, the chosen level, the install mode, the close and the restart -
so the process can be repeated on the same version without making a new release.

**Why this priority**: the maintainer's requirement (item point 8); needed to test the feature at all.

**Independent Test**: start with `--updatetest` twice in a row; each run downloads, verifies and
installs the same published version; the program restarted after the install runs without the
switch.

**Acceptance Scenarios**:

1. **Given** `--updatetest`, **When** the program starts, **Then** the check runs at once regardless of the daily interval, the *Check at start-up* option and a skipped version, and writes none of the stored check state.
2. **Given** `--updatetest` and an installed version equal to (or newer than) the published one, **Then** the published release is treated as new and the notification and the About box say *test mode*.
3. **Given** a restart after the install, **Then** the restarted program has no test mode (the switch is not carried into the restart command line).
4. **Given** an update armed in test mode that was not launched, **When** the program is started again with `--updatetest`, **Then** it is completed at that start; started without the switch, the test arm is dropped and nothing is installed.

---

### User Story 6 - Copies that cannot update themselves (Priority: P3)

A portable copy, a build tree or a copy not installed by the installer has no matching uninstall
entry: every level acts as *Notify only*. A metered connection does not download in the background.

**Independent Test**: start a build tree on a machine with an installed copy elsewhere - today's
notification only, no download.

**Acceptance Scenarios**:

1. **Given** no uninstall entry of the program whose install folder is the running program's folder, **Then** the program behaves as *Notify only*.
2. **Given** Windows reports the connection as metered, **Then** no background download starts in that session; today's notification is shown.

### Edge Cases

- A release record without a digest, without the asset, or with an asset larger than 64 MB: no download; today's notification.
- A download interrupted (exit, network): the partial file is deleted at the next start and never run.
- A newer release announced later: the earlier download is deleted and replaced.
- The user declines the elevation prompt of an all-users update: nothing changes; the update stays armed for the next exit / offered in the notification; the user is told the update was not installed when the installer ends while the program runs.
- *Install Now* while a file operation runs: the update close declines (080), the installer ends with a failure exit code, the program stays and tells the user, and the update stays armed for the exit.
- The setting *Notify only* or the check turned off while a download runs: the download finishes or is abandoned without being offered or armed.
- A second instance started with *Allow only one instance* on activates the first instance; `--updatetest` then has no effect (documented for the maintainer).

## Requirements *(mandatory)*

### Functional Requirements

**Setting**
- **FR-001**: Configuration > General MUST offer the level *When a new version is found*: *Notify me only* / *Download it and offer installation* / *Install it automatically when I close Tandem Commander*, enabled only while *Check for a new version at start-up* is on. The value is stored with the check's state (written at once, read fresh), default *Download it and offer installation* when absent.
- **FR-002**: With the check off or *Notify me only*, the program MUST NOT download or install anything; it behaves exactly as feature 123.

**Eligibility**
- **FR-003**: Downloading and installing MUST apply only to a copy installed by the installer: an uninstall entry of the program's AppId in the per-machine (64-bit view) or per-user uninstall key whose install location is the running program's folder (same-path rule of the project). The key where it is found selects `/ALLUSERS` or `/CURRENTUSER` for the installer.
- **FR-004**: A metered connection MUST NOT start a background download.

**Download**
- **FR-005**: The installer MUST be downloaded only from the address constructed from the validated release (the GitHub API asset address built from the numeric asset id, which must equal the record's own `url`), over HTTPS, with redirects followed only to `release-assets.githubusercontent.com` or `objects.githubusercontent.com` over HTTPS, at most 3 hops, without cookies or Windows credentials.
- **FR-006**: The download MUST be written to a `.part` file in `%LOCALAPPDATA%\Tandem Commander\Updates`, limited to the record's size (and at most 64 MB), hashed while written, and renamed to the installer's name only when complete and matching; a leftover `.part` and installers of versions not newer than the running one MUST be deleted at start-up; a test-mode start deletes every installer except the one of an arm it completes (test mode always downloads afresh).
- **FR-007**: A download MUST be abandonable at program exit within the same bounds as the check (the exit never waits for the network).

**Verification**
- **FR-008**: Before a file is offered, armed or run, the program MUST verify: SHA-256 equal to the release record's digest; a valid Authenticode signature (WinVerifyTrust, no network revocation retrieval); the signer certificate's SHA-1 thumbprint equal to the project's signing certificate (`tools/codesign/codesign.cfg`); the version resource's ProductName `Tandem Commander` and ProductVersion equal to the announced version. A file failing any check MUST be deleted and never run.

**Offering and installing**
- **FR-009**: Level *Download it and offer installation*: when a verified installer exists, the notification MUST offer *Install Now*, *Install When I Close*, *Remind Me Later*, *Skip This Version*.
- **FR-010**: Level *Install automatically*: when a verified installer exists, the update MUST be armed for the exit and the notification (not taking the keyboard from a working user, as in 123) MUST say so, with *Install Now*, *OK*, *Skip This Version*.
- **FR-011**: *Install Now* MUST start the installer with `/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS` plus the install-mode switch and a log file in the updates folder, record the attempt, and when the installer ends while the program still runs with a non-zero exit code, tell the user and keep the update armed for the exit.
- **FR-012**: At a normal exit (not an installer's close, not a sign-out, shutdown or critical shutdown) of the last running instance of this installation, an armed and verified update MUST be started with `/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS`, the install-mode switch and the log file, as the last step of the exit, and the attempt recorded.
- **FR-013**: At start-up, an armed update whose installer the exit did **not start** (no normal exit, sign-out / shutdown, another instance, an installer still running) and whose version is still newer than the running one (or, in test mode, one never launched) MUST be completed at once by the *Install Now* route, when no other instance and no installer of the product runs. An armed update whose installer **was started** and did not install it (cancelled, elevation declined, failed) MUST be offered in the notification, never started again at the start; the exit tries again at most until 3 launches in total for the version (review 2).
- **FR-014**: At start-up an armed update whose version the running program has reached MUST be cleaned up (arm and installer removed).
- **FR-015**: *Skip This Version* MUST drop an arm of that version and delete its installer.
- **FR-015a**: A check the user asks for MUST follow the same level rules; when its result is a newer version without a verified installer yet, today's notification appears at once and is replaced by the downloaded form when the download completes. The About box's *Download* link stays a browser download.
- **FR-016**: The restart command line of the update close MUST stay the identity-only command line of feature 080.

**Test mode**
- **FR-017**: `--updatetest` (new options take two dashes; the old switches stay) MUST work in Release builds; the check MUST run at once ignoring the interval, the option and the skipped version, write none of the stored check state, and treat the published release as newer; everything else runs for real; the mode MUST last for the session only and MUST be shown in the notification and the About box and written to the trace.
- **FR-018**: An arm made in test mode MUST be marked; a later start without `--updatetest` drops it without installing; a start with it completes it only when it was never launched.

**Records**
- **FR-019**: `PRIVACY.md` MUST describe the download (host, what is sent, when), the stored values and the files in the updates folder in the same change; the configuration page, the notification and the About box MUST be translated for the enabled languages.

### Key Entities

- **Update level**: notify only / download and offer / install at exit; stored with the check's state.
- **Downloaded installer**: `tandemcommander-<ver>-x64-setup.exe` in the updates folder, valid only after verification; its `.part` while downloading.
- **Armed update**: the version to install, who armed it (the user / the automatic level / test mode) and how many times its installer was launched.
- **Installation**: the uninstall entry (per-machine or per-user) whose install location is the running program's folder.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With the default level, a user goes from "a new version exists" to the new version running with one click and no browser, download folder or installer wizard.
- **SC-002**: With the automatic level, closing the program is the only action; the next start runs the new version (per-user installs with no prompt at all).
- **SC-003**: Every armed update that the exit did not install is installed at the next start (probe: 100 % of the not-at-exit scenarios driven).
- **SC-004**: 0 of the hostile fixture files (tampered, foreign-signed, unsigned, truncated, other version, other host, plain HTTP) is ever started; each is deleted.
- **SC-005**: The update can be repeated on the same installed version any number of times with `--updatetest`, without a new release.
- **SC-006**: Program exit is never delayed by a download by more than the check's existing bound.

## Assumptions

- Assumption (autonomous run): the download goes through the GitHub API asset address (`https://api.github.com/repos/tandemcommander/tandemcommander/releases/assets/<id>`, `Accept: application/octet-stream`) - measured 2026-11-08: `browser_download_url` answered 504 three times while the API address answered 302 to `release-assets.githubusercontent.com` and that 200 with the exact asset. The id is a validated decimal number; the record's `url` must equal the constructed address (the 123 rule "never open an address from the network").
- Assumption (autonomous run): a release record without a `sha256:` digest is not installed automatically (conservative; every asset uploaded since 2025 has one).
- Assumption (autonomous run): the signer is pinned by the thumbprint of `codesign.cfg`, as `publish.ps1` (072) does - the item names it. After a certificate rotation a program pinned to the old thumbprint falls back to today's notification (browser download) for releases signed with the new certificate; the closing report states this for the maintainer.
- Assumption (autonomous run): the update installed at the next start uses the *Install Now* route (progress window, update close of 080, restart), because the user just started the program and expects it back.
- Assumption (autonomous run): a metered connection makes the session *Notify only* (the item: "downloads only on request"; a browser download is on request).
- Assumption (autonomous run): Inno Setup with `/ALLUSERS` / `/CURRENTUSER` on the command line does not ask and does not apply `UsePreviousPrivileges` (Inno documentation, *PrivilegesRequiredOverridesAllowed*); the program passes the mode of the installation it runs from, which equals the previous mode anyway.
- The installer, `setup/tandemcommander.iss`, is not changed.
- The plug-in interface is not changed.
