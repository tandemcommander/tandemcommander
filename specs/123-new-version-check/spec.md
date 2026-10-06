# Feature Specification: New Version Check

**Feature Branch**: `123-new-version-check`  
**Created**: 2026-10-06  
**Status**: Draft  
**Input**: User description: "Cilem tohoto rozsireni je pridani detekce nove verze programu Tandem Commander a pripadne, ze je dostupna nova verze informovani uzivatale, ze je mozne ji nainstalovat. Kontrola dostupnosti nove verze pri spusteni bude defaultne zapnuta, ale uzivatel si ji muze v dialogovem okne vypnout, pripadne ji muze zapinat a vypinat v nastaveni aplikace a zaroven v Menu Napoveda bude vedle polozky O programu Tandem Commnader nova Polozka "Zkontrolovat novou verzi". V dialogovem okne "O programu Tandem Commander" je zobrazena atualni verze a v pripade, ze bude dostupna nova verze, tak se zde tato informace zobrazi s moznosti odkazu na stazeni teto nove verze. V ramci pripravy musime rozhodnout z jakeho zdroje se zjisti dostupnost nove verze. Aplikace vcetne oficialnich releasu je na GitHubu: https://github.com/tandemcommander/tandemcommander, resp. zde jsou releases: https://github.com/tandemcommander/tandemcommander/releases. Mozna pujde pouzit i https://api.github.com/repos/tandemcommander/tandemcommander/releases coz je verejny API endpoint o vsech releasech. Zde je vlastne i download link. Detailne vse prover a analyzuj moznosti. Cilem je, aby nove dialogove okno, ktere se zobrazi pri spusteni v pripade ze je dostupna nova verze by velmi hezky designove navrzene."

## Background

Tandem Commander has no way to tell its user that a newer version exists. A user
who installed the program from the downloaded installer learns about a release
only by visiting the project page; a user who installed it through the Windows
Package Manager learns about it only by running an upgrade command. Fixes for
data-loss defects therefore reach users late or never.

This feature makes the program look up the latest officially published release
and tell the user about it — once at start-up (unless turned off), on demand
from the Help menu, and permanently in the About dialog.

The source of the version information was examined before this specification
was written; the measured comparison of the candidate sources is in
[source-analysis.md](source-analysis.md). Its conclusion is reflected in the
requirements below as *what* the source must provide, not *how* it is read.

**This is the first time the program contacts the network without the user
asking for a network operation.** The published privacy statement currently says
the opposite, so it changes with this feature (see FR-027 and Assumptions).

## Clarifications

### Session 2026-10-06

- Q: Should the first automatic check after an upgrade from a version without this feature happen without telling the user beforehand? → A: Yes, silently — the check runs at the first start; the disclosure is in the privacy statement, the changelog and the configuration option (no first-run notice).
- Q: Which choices should the notification window offer besides downloading and turning the start-up check off? → A: Download, Remind me later, Skip this version, and the check box for the start-up check; a skipped version is no longer offered at start-up, a newer one is.
- Q: How often should the program ask for a new version by itself while the check is on? → A: At most once in 24 hours, at the first start after the interval has passed; a long-running instance does not check again by itself.
- Q: What should open when the user chooses to download the new version? → A: The installer file itself (the browser starts downloading it); the release notes stay reachable through their own link.
- Q: Should the notification window show the "what is new" text itself, or only a link to the release notes? → A: Only the version, the release date and a *Release notes* link; no release text is shown inside the window.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Told about a new version at start-up (Priority: P1)

A user starts Tandem Commander as usual. A newer version has been published
since they installed theirs. Shortly after the main window is ready, a
well-designed window tells them which version they have, which version is
available and when it was released, links to the release notes, and offers to
download it. The user can download it, postpone the decision, decide to ignore this
particular version, or turn the start-up check off right there.

**Why this priority**: this is the purpose of the feature — a user who never
looks for updates must still learn that one exists. Everything else supports
or refines this.

**Independent Test**: install a build with an older version number than the
latest published release, start it with a working internet connection, and
confirm the notification appears with the correct two versions and a working
download action.

**Acceptance Scenarios**:

1. **Given** the start-up check is on and a newer release is published,
   **When** the user starts the program, **Then** the main window appears and
   is usable without delay, and the notification is shown afterwards naming
   the installed version, the available version and its release date.
2. **Given** the notification is shown, **When** the user chooses to download,
   **Then** the user's default browser starts downloading the installer of
   that version from its official location and the notification closes.
3. **Given** the notification is shown, **When** the user chooses to be
   reminded later, **Then** the notification closes and is offered again at a
   later start, not more than once a day.
4. **Given** the notification is shown, **When** the user chooses to skip this
   version, **Then** the start-up notification is not shown again for that
   version, and is shown again when a still newer version is published.
5. **Given** the notification is shown, **When** the user turns off checking
   at start-up in it, **Then** no further start-up checks are made and the
   setting in the program's configuration shows the same state.
6. **Given** the start-up check is on and the installed version is the latest,
   **When** the user starts the program, **Then** nothing is shown.
7. **Given** the start-up check is on and the computer is offline or the
   source cannot be reached, **When** the user starts the program, **Then**
   nothing is shown, start-up is not slowed down, and no error appears.

---

### User Story 2 - Checking on demand from the Help menu (Priority: P2)

A user wants to know now whether they are up to date. They choose *Check for
New Version* in the Help menu, next to *About Tandem Commander*. The program
checks and always answers: a newer version is available (the same notification
as at start-up), the installed version is the latest, or the check could not be
completed and why.

**Why this priority**: it makes the feature usable for users who turned the
start-up check off, and it is the only way to get a definite answer, including
a negative one.

**Independent Test**: with the start-up check off, choose the Help menu item in
three situations (newer version exists, up to date, no connection) and confirm
each gives its own clear answer.

**Acceptance Scenarios**:

1. **Given** a newer release is published, **When** the user chooses *Check
   for New Version*, **Then** the notification with the new version is shown,
   also when that version was skipped earlier.
2. **Given** the installed version is the latest, **When** the user chooses
   the command, **Then** a message says the program is up to date and names
   the installed version.
3. **Given** there is no connection or the source does not answer, **When**
   the user chooses the command, **Then** a message says the check could not
   be completed, in words a user can act on, and nothing else changes.
4. **Given** the command was chosen, **When** the answer takes longer than a
   moment, **Then** the user sees that a check is running and can cancel it;
   the program stays usable.
5. **Given** the start-up check is off, **When** the user chooses the command,
   **Then** the check runs anyway and the start-up setting stays off.

---

### User Story 3 - Seeing the update state in the About dialog (Priority: P2)

A user opens *About Tandem Commander*. Beside the installed version the dialog
says what is known about newer versions: that a newer version is available,
with a link to download it; that the installed version is the latest; or that
it has not been checked.

**Why this priority**: the About dialog is where users look for the version;
it keeps the information reachable after the notification was closed or
skipped.

**Independent Test**: open the About dialog after a check that found a newer
version and after one that did not, and with checking turned off and never
run; confirm the three states and that the link opens the download location.

**Acceptance Scenarios**:

1. **Given** a check found a newer version, **When** the user opens the About
   dialog, **Then** it shows the installed version and states that the newer
   version is available, with a link that downloads its installer.
2. **Given** the last check found the installed version to be the latest,
   **When** the user opens the About dialog, **Then** it says so.
3. **Given** no check has been made (checking is off, or no check succeeded
   yet), **When** the user opens the About dialog, **Then** it does not claim
   the program is up to date, and it makes no network request by being opened.
4. **Given** the user skipped a version, **When** they open the About dialog,
   **Then** the newer version is still shown as available.

---

### User Story 4 - Turning the start-up check on and off (Priority: P3)

A user decides whether the program may look for new versions by itself. The
program's configuration has one clearly worded option for it, on by default.
The same choice is offered in the notification window. Both always show the
same state.

**Why this priority**: the default covers most users; the control is a
requirement of trust rather than of function.

**Independent Test**: turn the option off in the configuration, restart with a
newer release published and confirm that nothing is requested and nothing is
shown; turn it on again and confirm the notification returns.

**Acceptance Scenarios**:

1. **Given** a new installation or an upgrade from a version without this
   feature, **When** the program first starts, **Then** the start-up check is
   on.
2. **Given** the user turns the option off in the configuration, **When** the
   program is started any number of times, **Then** it makes no version
   request by itself.
3. **Given** the option was turned off in the notification, **When** the user
   opens the configuration, **Then** the option is shown as off, and turning
   it on there restores the start-up check.
4. **Given** the option is off, **When** the user uses *Check for New
   Version* or the About dialog, **Then** those keep working as described.

---

### Edge Cases

- **Installed version newer than the latest release** (a development build, or
  a release that was withdrawn): treated as up to date; never offered a
  "newer" version that is older.
- **Pre-releases and drafts** on the release page are not offered.
- **A release without an installer** for this platform (publication in
  progress): not offered until the installer is there.
- **Unexpected or damaged answer** from the source (not the expected content,
  truncated, oversized, a captive portal page of a hotel network): treated as
  "could not check"; nothing from it is shown or opened.
- **Source refuses because of too many requests** from the user's network
  (shared address in a company): start-up check stays silent and is retried
  another day; the manual check says it could not be completed and suggests
  trying later.
- **Several instances** started at once or running side by side: the user gets
  one notification, not one per instance; a choice made in one instance (skip,
  turn off) holds for the others started later.
- **Program started and closed quickly**, or closed while the check is
  running: closing is never delayed by the check.
- **Start-up with another window already open** (a start-up error message, a
  dialog opened by a command-line action): the notification waits; it never
  appears on top of, or behind, another modal window, and never takes the
  keyboard away from text the user is typing.
- **An installer closing the program for an update** (feature 080) while the
  notification is open: the notification holds nothing to lose and must not
  be the reason the update fails.
- **Clock set wrongly or changed**: the once-a-day limit must not stop checks
  for good (a last-check time in the future is ignored).
- **Very long or unusual release text**: not shown in the program at all (the
  window only links to it), so it cannot distort the window or inject content.
- **No default browser / the download location cannot be opened**: the user is
  told, and the address can be copied.
- **Read-only or unavailable configuration store**: the check still works; a
  choice that could not be stored simply does not persist.
- **User interface in a language other than English**: all text of the
  feature is in that language; the linked release notes are as published.

## Requirements *(mandatory)*

### Functional Requirements

**Finding out**

- **FR-001**: The program MUST be able to determine the latest officially
  published stable release of Tandem Commander — its version, its release
  date, the location of its release notes and the location of its installer —
  from the project's official release publication.
- **FR-002**: Only releases that are published, are not marked as
  pre-release or draft, and offer an installer for the user's platform MUST be
  considered.
- **FR-003**: A release MUST be reported as newer only when its version is
  higher than the installed version by the product's version order; equal or
  lower versions MUST be reported as "up to date".
- **FR-004**: The information received MUST be treated as untrusted: the
  connection MUST be encrypted and the server's identity verified; the answer
  MUST be bounded in size and validated before use; any location the program
  offers to open MUST belong to the project's official publication places,
  otherwise the release is not offered.
- **FR-005**: The program MUST NOT download or run an installer by itself in
  this feature; it leads the user to the official download.
- **FR-006**: A check MUST send nothing that identifies the user, the
  computer or the installation, and nothing about the user's files, settings
  or usage. What the request necessarily reveals (the network address, and
  that it comes from Tandem Commander) MUST be stated in the privacy
  statement.

**Start-up check**

- **FR-007**: With the start-up check on, the program MUST check for a new
  version after it starts, without delaying the appearance or the use of the
  main window and without any visible sign while the check runs.
- **FR-008**: The start-up check MUST contact the source at most once in 24
  hours per user, however many times and in however many instances the
  program is started. It runs only as part of a start: an instance that stays
  open for days does not check again by itself.
- **FR-009**: A start-up check that fails for any reason MUST be silent and
  MUST NOT change what the program last knew about available versions.
- **FR-010**: The start-up check MUST be on by default, for new installations
  and for existing users after an upgrade. The first check runs at the first
  start without a preceding notice or question; the user is informed through
  the privacy statement, the changelog and the configuration option.
- **FR-011**: With the start-up check off, the program MUST NOT make any
  version request unless the user explicitly asks for one.

**Notification window**

- **FR-012**: When a start-up check finds a newer version that the user has
  not skipped, the program MUST show the notification window once the main
  window is ready and no other modal window is open.
- **FR-013**: The notification MUST show: that a new version is available;
  the available version and its release date; the installed version; and a
  *Release notes* link that opens the release notes of that version in the
  default browser. The text of the release notes is not shown in the window.
- **FR-014**: The notification MUST offer these choices: download the new
  version (hands the address of that version's installer file to the default
  browser, which downloads it — not a page the user has to search);
  remind me later; skip this version; and an option to turn the check at
  start-up off (or back on).
- **FR-015**: The notification MUST be a distinctly designed window that
  presents the product's identity (its icon or artwork) and a clear visual
  hierarchy — the new version as the dominant element, the download as the
  default action — while remaining consistent with the look of the rest of
  the program, including its fonts, themed controls, high-DPI scaling,
  keyboard operation (default button, Esc, access keys) and screen-reader
  names.
- **FR-016**: Closing the notification by Esc or the window's close button
  MUST mean "remind me later".
- **FR-017**: "Skip this version" MUST suppress only the start-up
  notification, only for that version; the manual check and the About dialog
  keep showing it.
- **FR-018**: At most one notification MUST be visible for a user at a time,
  across all running instances.

**Manual check**

- **FR-019**: The Help menu MUST contain a command *Check for New Version*
  placed next to *About Tandem Commander*, available regardless of the
  start-up setting.
- **FR-020**: The manual check MUST always end with an answer: the
  notification window (newer version), an "up to date" message naming the
  installed version, or a "could not check" message that distinguishes at
  least *no connection / source unreachable* from *source answered
  unexpectedly or refused*.
- **FR-021**: While a manual check runs, the user MUST see that it is running
  and MUST be able to cancel it; the check MUST give up by itself after a
  bounded time.
- **FR-022**: The manual check MUST always ask the source (it is not subject
  to the once-a-day limit) and MUST ignore the skipped version.

**About dialog**

- **FR-023**: The About dialog MUST show, with the installed version, one of
  these states: a newer version is available (naming it, with a link that
  downloads its installer, as in FR-014); the installed version is the latest (as of
  the last successful check); not checked.
- **FR-024**: Opening the About dialog MUST NOT cause a network request by
  itself. It shows what the program last learned; if a check is running at
  that moment, the dialog reflects its result when it arrives.

**Setting and stored state**

- **FR-025**: The program's configuration MUST contain one option that turns
  the check at start-up on and off; the option in the notification window and
  this option are the same setting.
- **FR-026**: The program MUST remember, per user: the setting, the time of
  the last check, the latest version it learned of (with what is needed to
  show it in the About dialog), and the skipped version. Existing
  configurations MUST keep working without migration, and an older version of
  the program started with these values present MUST be unaffected.

**Documentation and language**

- **FR-027**: The privacy statement MUST be updated in the same change: that
  the program now contacts the release publication by itself at start-up
  unless turned off, what the request reveals and to whom, what is stored
  locally, and how to turn it off. Every sentence it currently contains that
  this feature makes untrue MUST be corrected.
- **FR-028**: All new text MUST be available in every language the program
  ships in; the name of the Help menu command in Czech is *Zkontrolovat novou
  verzi*.
- **FR-029**: The change MUST be recorded in the changelog as a user-visible
  addition, stating that the check is on by default and how to turn it off;
  the user manual MUST describe the command, the option and the notification.

### Key Entities

- **Installed version**: the version of the running program, as shown in the
  About dialog.
- **Latest release**: what the official publication says is the newest stable
  release — version, release date, release-notes location, installer
  location.
- **Check result**: one of *newer version available*, *up to date*, *could not
  check* (with a reason class); only the first two replace what the program
  last knew.
- **Update preferences**: the start-up setting (on by default), the skipped
  version, the time of the last check — per user, shared by all instances.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a newer release published and a working connection, a user
  who starts the program sees the notification within 10 seconds of the main
  window appearing, in 20 of 20 starts.
- **SC-002**: The time from starting the program to a usable main window is
  the same with the start-up check on and off, within measurement noise, also
  when the computer is offline or the source does not answer.
- **SC-003**: With the start-up check off, the program makes zero version
  requests over 20 starts, verified by observing its network activity.
- **SC-004**: With the start-up check on, 20 starts within one day produce at
  most one version request.
- **SC-005**: A user can go from the notification to the official download in
  one action, and from the About dialog in one action.
- **SC-006**: The manual check gives its answer within 15 seconds in every
  case (newer, up to date, unreachable), and the "could not check" answers
  tell the user what to do next.
- **SC-007**: In every failure case of the start-up check (offline, source
  unreachable, refused, damaged answer) the user sees nothing: no window, no
  message, no delay on exit.
- **SC-008**: Test answers that are malformed, oversized, or point to a
  location outside the official publication never lead to a notification and
  never to an opened address — 0 of all such test cases.
- **SC-009**: In a review of the notification window at 100 %, 150 % and
  200 % display scaling and in every shipped language, no text is cut off or
  overlapping, every action is reachable by keyboard, and the maintainer
  accepts the design as fitting the product.
- **SC-010**: The privacy statement, read after the change, contains no
  sentence the shipped program contradicts — verified claim by claim against
  the observed network activity.

## Assumptions

- **Source of truth**: the project's GitHub release page is the official
  publication. The comparison of ways to read it
  ([source-analysis.md](source-analysis.md)) recommends the public "latest
  release" record as the primary source, because it alone provides the
  version, release date and installer location in one small answer and already
  excludes drafts and pre-releases; the final choice and a fallback are made
  in planning. No server of the project's own is introduced.
- **Default on** is the maintainer's explicit decision. The constitution asks
  for user-facing behaviour changes to be opt-in; this is recorded as a
  deliberate, documented exception (as panel tabs were in feature 078),
  justified by fixes for data-loss defects reaching users.
- **No in-program download or installation.** The program opens the browser;
  the user runs the installer, which already closes and restarts a running
  program (feature 080). Automatic updating is a possible later feature.
- **Windows Package Manager installations** are told about a new version like
  any other. The catalogue can lag behind the release by the time its review
  takes, so the notification leads to the official download and does not
  promise that an upgrade command already works. Detecting how the program
  was installed is out of scope.
- **Frequency**: once a day at most for the automatic check is frequent
  enough and keeps well inside the source's limits, including for users
  behind a shared network address.
- **One channel**: only stable releases are offered; there is no beta
  channel.
- **Release notes are not shown in the program**; the notification links to
  them as published (English). Their text is neither translated nor
  rendered.
- **Version order** follows the product's existing numbering (major, minor,
  patch) as used for release tags.
- **Proxies**: the check uses the system's network settings; environments that
  require interactive proxy sign-in are treated as "could not check".
- **Plug-ins** are not checked or updated by this feature, and the plug-in
  interface does not change.
- **"Designed" within the house style**: the notification is a designed
  window but uses the application's standard fonts and themed controls
  (constitution, principle VI); the quality comes from layout, artwork,
  hierarchy and wording, not from a foreign visual style.
