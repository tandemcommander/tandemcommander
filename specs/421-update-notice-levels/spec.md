# Feature Specification: Update notification - level choice, Download & Install, silent automatic install

**Feature Branch**: `421-update-notice-levels`
**Created**: 2026-11-08
**Status**: Draft
**Input**: User description: "Backlog item update-level-and-download-install-in-notification - implement exactly what it describes (the update level can be chosen in the new-version notification; the notify-only notification offers Download & Install; a copy not installed by the installer says it updates only through the browser; the automatic level shows no notification and installs as soon as the installer is downloaded and verified, when nothing can be lost)." From backlog item update-level-and-download-install-in-notification.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Download & Install from the notification (Priority: P1)

A user whose setting is *Notify me only* (or who sees the notification without a downloaded installer - a metered connection, a failed background download) gets a notification about a new version. Instead of downloading the installer in the browser, finding it and running it by hand, the user clicks **Download & Install**. The program downloads the installer itself, proves it is the published, project-signed installer of that version, and installs it the way *Install Now* does: the program closes, the update is installed with a progress window, and the program starts again.

**Why this priority**: it removes the most manual work for the user and is the explicit request of the maintainer.

**Independent Test**: with the notify-only level and a loopback release fixture, show the notification, click Download & Install, and observe the download progress, the verification and the start of the installer (recorded by the probe seam).

**Acceptance Scenarios**:

1. **Given** the notify-only level and an installed copy, **When** the notification appears, **Then** it shows *Download & Install*, *Download*, *Remind Me Later* and *Skip This Version*, and a hint that explains both download buttons.
2. **Given** that notification, **When** the user clicks *Download & Install*, **Then** the window shows the download progress in per cent and the button becomes *Cancel Download*; when the installer is downloaded and verified, the installer is started as by *Install Now*.
3. **Given** a download in progress, **When** the user clicks *Cancel Download* (or closes the window), **Then** the download stops, its partial file is removed and the window returns to its first state (or is gone).
4. **Given** a download that fails or an installer that does not pass the verification, **When** it ends, **Then** the user is told so in a message that points to *Download* (the browser), and the window offers its first state again.
5. **Given** a verified installer of that version already in the updates folder, **When** the user clicks *Download & Install*, **Then** nothing is downloaded and the installer starts at once.

---

### User Story 2 - Choose the update level in the notification (Priority: P2)

The notification shows the setting *When a new version is found* with the same three choices as Configuration > General. A change is stored at once (as the check box *Check for a new version at start-up* already is) and takes effect for the window on screen where it can.

**Why this priority**: the setting is hard to find in Configuration; the notification is the moment the user cares about it.

**Independent Test**: show the notification in each form, change the choice, read the stored value and observe the window.

**Acceptance Scenarios**:

1. **Given** the notification of an installed copy with the check at start-up on, **When** it appears, **Then** the choice shows the stored level and can be changed.
2. **Given** the notify-only form, **When** the user chooses *Download it and offer installation*, **Then** the level is stored and the program downloads the installer in the background; when it is verified the window is replaced by the offer form (*Install Now*, *Install When I Close*).
3. **Given** the notify-only form, **When** the user chooses the automatic level, **Then** the level is stored, the installer is downloaded and, once verified, installed by the automatic level's rule (User Story 4); the window is closed when the installation is planned.
4. **Given** the offer form, **When** the user chooses *Notify me only*, **Then** the level is stored and the window turns into the notify-only form.
5. **Given** the offer form, **When** the user chooses the automatic level, **Then** the level is stored, the update is planned for the automatic install and the window closes.
6. **Given** the check box *Check for a new version at start-up* cleared in the window, **Then** the level choice is disabled (as in Configuration), and enabled again when it is checked.
7. **Given** a level other than automatic chosen while an automatic plan exists, **Then** that plan is dropped (as when the setting is changed in Configuration).

---

### User Story 3 - A copy not installed by the installer says so (Priority: P2)

A user runs a copy of Tandem Commander that the installer did not install (a portable copy, a build tree). Its notification does not offer *Download & Install* and does not let the user pick a level that has no effect for it; instead it says that this copy is updated only by downloading the installer in the browser.

**Why this priority**: the maintainer misread exactly this case while testing 420.

**Independent Test**: run a copy without the uninstall entry; the notification shows no *Download & Install*, the level choice is disabled and the hint states the reason.

**Acceptance Scenarios**:

1. **Given** a copy not installed by the installer, **When** the notification appears at any level, **Then** it shows *Download*, *Remind Me Later*, *Skip This Version*, the level choice disabled and the hint "This copy ... cannot update itself ...".

---

### User Story 4 - The automatic level installs without a window (Priority: P1)

With the level *Install it automatically as soon as it is downloaded*, the program downloads and verifies the installer and starts the installation itself, without showing a notification, as soon as nothing can be lost: no file operation, search, plug-in file system or plug-in work in progress, no file opened from an archive waiting to be packed back, no dialog or menu open, and the user has not used the keyboard or mouse for a short while. Until then it waits; if the program is closed first, the installation at the exit (and at the next start) of feature 420 still applies.

**Why this priority**: the maintainer's request - the automatic level was not automatic, and its window was redundant.

**Independent Test**: with the automatic level and the loopback fixture, start the program; no notification appears, and after the idle time the installer is started (recorded by the probe seam). With a file operation running, the installer waits until it finishes.

**Acceptance Scenarios**:

1. **Given** the automatic level and a newer release found at start-up, **When** the installer is downloaded and verified and the program is idle with nothing to lose, **Then** the installer starts (progress window, close, restart) and no notification is shown.
2. **Given** the same, **When** something could be lost (a file operation runs, a dialog is open, the user is typing), **Then** the installer does not start until that has ended; closing the program first installs it at the exit.
3. **Given** another instance of the program runs in the session, **Then** no instance starts the automatic install while the program is running; the exit of the last instance installs it (420).
4. **Given** the automatic install started and its installer ended without installing (cancelled, the administrator prompt declined), **Then** the user is told as after a failed *Install Now*, the program does not start it again on its own in that session, and the next start offers the update instead of installing it (420's launch count and confirmation).
5. **Given** a version the user skipped, **Then** the automatic level never installs it on its own; a check the user asked for offers it.
6. **Given** a check the user asked for (Help > Check for New Version) at the automatic level, **When** the installer is verified, **Then** the installation starts without waiting for the idle time, still only when nothing can be lost.

---

### Edge Cases

- The release has no installer asset, no published checksum, or an installer larger than the limit: *Download & Install* is not offered (only *Download*).
- The installer of that version was refused before as not the project's (another signer or version): *Download & Install* is not offered, except in test mode (as 420).
- A metered connection: *Download & Install* still downloads - the click is the user's explicit consent; the background download of the offer and automatic levels stays off on a metered connection (420).
- Another installer of the product is running: *Download & Install* says so (420's message) instead of starting a second one; the automatic install waits.
- The user clicks *Skip This Version* during a *Download & Install* download: the download's result is discarded and its file deleted (420 round 4).
- The window is replaced by another version's notification during the download: the request belongs to the old version and is dropped.
- The download of the offer level is already running when the user clicks *Download & Install* on the classic form shown during a check the user asked for: no second download; when it finishes, the installer is started.
- Test mode (`--updatetest`): all paths work with the published version treated as new; nothing of 123's stored state is written (420).
- The program closes (or is closed by an installer) during a *Download & Install* download: the download is abandoned as 420 abandons a background download.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The notification MUST show the setting *When a new version is found* with the three levels of Configuration > General, showing the stored level when the window appears.
- **FR-002**: A change of that choice MUST be stored at once in the same stored value as Configuration and MUST drop an automatic plan that no longer applies (420's rule).
- **FR-003**: The choice MUST be enabled only for a copy installed by the installer and only while *Check for a new version at start-up* is checked.
- **FR-004**: A level change MUST take effect for the window on screen: notify-only form + offer or automatic level → the installer is downloaded (unless *Download & Install* would not be offered), then the offer form replaces the window or the automatic install follows; offer form + notify-only → the notify-only form; offer form + automatic → the update is planned for the automatic install and the window closes.
- **FR-005**: The notify-only form of an installed copy MUST offer *Download & Install* when the release has an installer asset with a published checksum within the size limit and the installer was not refused before (test mode ignores the refusal).
- **FR-006**: *Download & Install* MUST download with 420's download and verification (the asset address built from the validated number, the redirect allow-list, the published SHA-256 checksum, the signer pin, the version resource) and MUST start the verified installer as *Install Now* does (the same command line, the same plan and launch count, the same failure handling).
- **FR-007**: *Download & Install* MUST download also on a metered connection (an explicit click).
- **FR-008**: While it downloads, the window MUST show the progress in per cent and offer *Cancel Download*; cancelling (or closing the window) MUST stop the download it started and leave no partial file.
- **FR-009**: A failed download or verification MUST be reported with a message that points to the browser *Download*, and the window MUST return to its first state.
- **FR-010**: A copy not installed by the installer MUST NOT offer *Download & Install*; its level choice MUST be disabled and its hint MUST say that it cannot update itself and is updated by the browser download.
- **FR-011**: At the automatic level, a downloaded and verified installer MUST NOT be announced by a notification; the update is planned (420's automatic plan) and installed by FR-012. When the plan cannot be used for a silent install (its installer ran since the last confirmation, its launches are used up, the version was skipped), the offer form is shown instead.
- **FR-012**: The automatic install MUST start the installer (as *Install Now*) only when all hold: the plan is the automatic level's, still honoured, its installer never ran since it was planned or confirmed, its launches are not used up, the installed copy is the program's, no other instance of the program runs, no installer of the product runs, the program agrees to be closed without asking anybody anything (the rule of an installer's close, feature 080/088), and the user has not used the keyboard or mouse for 30 seconds (not required after a check the user asked for). Otherwise it MUST wait and look again periodically; it MUST start at most once per session for a version.
- **FR-013**: The automatic level MUST keep 420's fall-backs: the installation at a normal exit and the completion at the next start.
- **FR-014**: The automatic level's name MUST say that it installs as soon as the update is downloaded, in Configuration and in the notification; the manual and `PRIVACY.md` MUST describe the new behaviour.
- **FR-015**: The automatic notification form of 420 (OK / Install Now / Skip) MUST be removed, with its texts.
- **FR-016**: All new and changed texts MUST be translated for every enabled language in the formal register.

### Key Entities

- **Update level**: the stored value *Update Level* (0 notify only, 1 download and offer, 2 automatic); unchanged layout, new place to change it.
- **Install request**: the in-session request of *Download & Install* for one version (whether this request started the download); not stored.
- **Automatic install wait**: the in-session waiting for the moment the automatic install may start (version, whether the user asked for the check, whether it already started once); not stored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From the notify-only notification, the update is installed with one click (no browser, no file to find).
- **SC-002**: The level can be changed in the notification in one choice, and the stored value equals the choice in 100 % of the probe cases.
- **SC-003**: At the automatic level no notification window appears for an update that is installed automatically (probe: no notification window in the session).
- **SC-004**: The automatic install never starts while a file operation, a dialog or user input within the last 30 seconds is present (probe rows with each obstacle).
- **SC-005**: A copy not installed by the installer never shows *Download & Install* and always shows the reason (probe row).
- **SC-006**: The pure rules of the feature are covered by `saltests` checks; 420's probe rows that still apply pass unchanged.

## Assumptions

- Assumption (autonomous run): the automatic install waits for 30 seconds without keyboard or mouse input (any program) before it starts in the background; a check the user asked for does not wait for input idleness. A countdown window was not chosen because the maintainer asked for no window at the automatic level.
- Assumption (autonomous run): "nothing can be lost" is the existing rule of an installer's close (`DecideCloseApp` agrees without asking) - the same rule the installer's own close of the program applies, so an install started under it is not declined by the program.
- Assumption (autonomous run): the automatic install is not started while another instance of the program runs (its close would affect the user's other windows); the exit of the last instance installs it, as in 420.
- Assumption (autonomous run): *Download & Install* on a metered connection downloads (the click is consent; item *Approach*).
- Assumption (autonomous run): closing the notification (Remind Me Later, Esc) during a *Download & Install* download cancels the request and stops the download only when the request started it.
- Assumption (autonomous run): choosing the automatic level on the offer form plans the update and closes the window; the installation then follows FR-012 with the 30-second idle wait (the user has just used the mouse).
- Assumption (autonomous run): the network communication is 420's (same requests, same hosts); what changes is when it happens (on a click at the notify-only level, and the automatic level installing before the exit) - `PRIVACY.md` is updated in the same change as the item asks.
- The release checks, the signer pin, the stored-state layout and the installer's command line of 420 are unchanged.
