# Feature Specification: Updates install right away with a restart, never when Tandem Commander closes

**Feature Branch**: `422-install-now-not-at-exit`
**Created**: 2026-11-08
**Status**: Draft
**Input**: User description: "Backlog item update-install-right-away-never-at-exit - implement exactly what it describes." From backlog item update-install-right-away-never-at-exit.

## Clarifications

### Session 2026-11-08

- Q: When does the automatic level install after the download? → A: Right away, without waiting for the user to be idle; only never while something can be lost (maintainer decision 2026-11-08, asked in the session)
- Q: What happens to installation at exit (the automatic fall-back, *Install When I Close*, the question after a failed *Install Now*)? → A: Removed completely (maintainer decision 2026-11-08, asked in the session)
- Q: The installer of an automatic install closed Tandem Commander and the user cancelled it (or declined the administrator prompt); the user starts the program again - does the install start again? → A: Never; the update is only offered from then on, at every start, until the user clicks *Install Now* (maintainer requirement 2026-11-08: "a logical trap - otherwise the user is locked out")
- Q: At the automatic level, what does a check the user starts in the application do (Help > Check for New Version, the About box's *Check now*, a level chosen in the notification)? → A: It always shows the notification with the new version and *Install Now* - it never installs on its own; the automatic install happens only after the background check at start-up (and the start-up completion). A silent install of that version already waiting is cancelled for the session (maintainer requirement 2026-11-08)
- Q: Is the notification closed under the user when the automatic install becomes due while it is open? → A: Only when the user is not in the middle of choosing in it (the level list is not open); otherwise the offer form replaces it (autonomous run: item - "never while something can be lost")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The automatic level installs right away (Priority: P1)

With the level *Install it automatically as soon as it is downloaded*, once the installer is downloaded and verified, the program closes, the installer runs with its progress window, and the program starts again - without waiting for the user to stop working. Only when something could be lost (a copy, a search, a modal dialog, typed command-line text, another running copy...) it waits until that ends, still while the program runs.

**Independent Test**: level 2 with the user "working" (no idle): the installer starts within seconds of the download (run log of the probe seam).

**Acceptance Scenarios**:

1. **Given** level 2 and a newer release, **When** the installer is verified and nothing can be lost, **Then** the installer starts at once (`/SILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS`), also while the user uses the keyboard and mouse.
2. **Given** a file operation / a modal dialog / command-line text / another instance, **Then** it waits and starts as soon as that has ended.

---

### User Story 2 - Nothing is ever installed when the program closes (Priority: P1)

Closing Tandem Commander never starts an installer. The offer form has *Install Now*, *Remind Me Later* and *Skip This Version*; there is no *Install When I Close*. A failed *Install Now* is reported; the update stays offered (no question about installing at close).

**Acceptance Scenarios**:

1. **Given** any plan (automatic, a click's, offered), **When** the program closes normally, **Then** no installer starts.
2. **Given** the offer form, **Then** it shows no *Install When I Close*.
3. **Given** *Install Now* whose installer ended without installing, **Then** the failure is reported in a message with OK only, and the offer comes back.

---

### User Story 3 - A plan not installed while running is installed at the next start (Priority: P2)

An automatic plan whose installer never ran (the program was closed before the moment came, Windows shut down) is installed right away at the next start (close, install, start again).

**Acceptance Scenarios**:

1. **Given** an automatic plan never launched, **When** the program starts, **Then** the installer starts at once (start-up completion).

---

### User Story 4 - A cancelled install never locks the user out (Priority: P1)

The installer of an automatic install (while running or at the start-up completion) closed the program and the user cancelled it (or declined the administrator prompt). When the user starts Tandem Commander again, nothing starts on its own - at this start and every following one, until the user clicks *Install Now*: the update is only offered (the notification at a start whose check is due, as 420 offers an update; a start without a check shows nothing, so the user is not nagged at every start).

**Acceptance Scenarios**:

1. **Given** the automatic install started and the program was closed by its installer (killed in the probe) without the update being installed, **When** the program starts again, **Then** no installer starts and the offer form appears; the same at a second and third start, also when a new check runs.
2. **Given** the start-up completion started the installer and the program was closed by it without the update being installed, **When** the program starts again, **Then** no installer starts; the update is offered.
3. **Given** the installer ended without installing while the program still runs (cancelled, administrator prompt declined), **Then** the failure is reported (OK only), the update is offered, and nothing starts again on its own in this or any later session.

### Edge Cases

- A plan left by a 420/421 build with source *user* (Install When I Close) and never launched: installed at the next start (start-up completion) - not at exit.
- A plan whose launches are used up: only offered (420).
- Test mode: a launched same-version test plan counts as done at the next test start (420).
- The level list open in the notification when the automatic install becomes due: the window becomes the offer (not closed under the user).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The automatic install MUST start right after the download and verification when nothing can be lost (`DecideCloseApp` agrees, no command-line text, no Quick Rename, last instance, no installer running), without any idle condition.
- **FR-002**: While something can be lost, it MUST wait and look again periodically in the running session.
- **FR-003**: The program MUST never start an installer at its exit (420's exit install removed).
- **FR-004**: The offer form MUST NOT offer *Install When I Close*; its button and texts are removed.
- **FR-005**: A failed *Install Now* (or automatic install) whose installer ended while the program runs MUST be reported with OK only (no "install it when you close?"); an automatic plan becomes offered (421's `SalUpdDeclinedArmKept`); the offer comes back.
- **FR-006**: An automatic (or click's) plan never launched since it was planned MUST be installed at the next start right away (420's start-up completion).
- **FR-007**: A plan whose installer was started and did not install the update MUST never be started again on its own - not by the silent install, not at the next start, not after a new check - until the user clicks *Install Now* (420's launch count / confirmation; maintainer requirement).
- **FR-009** (maintainer, added during the run): a check the user starts in the application (Help > Check for New Version, the About box's *Check now*, a level chosen in the notification) MUST show the notification with the new version and *Install Now* at every level and MUST NOT install on its own; at the automatic level a silent install of that version already waiting is cancelled for the session. The automatic install follows only the background check at start-up and the start-up completion.
- **FR-008**: The manual, `PRIVACY.md`, the 420/421 contracts and the translations MUST describe the new behaviour.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With level 2 and continuous user input, the installer starts within 10 s of the verified download (probe).
- **SC-002**: In every probe row, a normal exit starts no installer.
- **SC-003**: After a launched install that did not install the update, three following starts (with and without a check) start no installer and show the offer.
- **SC-004**: saltests cover the changed pure rules; the probes pass.

## Assumptions

- Assumption (autonomous run): the decision still runs in the idle part of the main loop (421: `SalamanderBusy`), looked at every 5 s while waiting.
- Assumption (autonomous run): "the user in the notification" is narrowed to an open level list (an open notification alone no longer stops the install - the maintainer wants it right away).
- Assumption (autonomous run): the debug idle seam `TC_UPDATE_PROBE_IDLE_MS` of 421 is removed with the idle rule.
