# Feature Specification: Upgrading Over a Running Instance (Restart Manager)

**Feature Branch**: `080-restart-manager-upgrade`
**Created**: 2026-09-20
**Status**: Draft
**Input**: User description: "Restart Manager – upgrade přes běžící instanci (v backlogu specs/NEXT-WORK.md bod 2, označený „start here“). Problém: při spuštěném programu skončí `winget upgrade` (předává /SUPPRESSMSGBOXES) na dotazu Abort/Retry/Ignore, zvolí se Abort a instalace se vrátí zpět s exit 5. Základ už existuje v handleru WM_QUERYENDSESSION / WM_ENDSESSION v src/mainwnd3.cpp (včetně critical shutdown a zálohy konfigurace). Zbývá korektně reagovat na ENDSESSION_CLOSEAPP a skutečně se ukončit, a rozhodnout o RegisterApplicationRestart, tedy zda stav panelů a tabů přežije restart. První krok je reprodukce podle specs/072-winget-distribution/quickstart.md §2b a potvrzení exit 5. Je to samostatná feature v src/, ne v setup/. Úpravy se realizují v rámci rozpracované (nevydané) verze 0.1.8 / build 192 – číslo verze se nezvyšuje; changelog se doplní do sekce `## [0.1.8] — unreleased`. Celý flow běží autonomně (uživatel je AFK): vše detailně zapisovat do specs/<NNN>-*/fix-log.md a otestovat."

## Background

Since feature 072 Tandem Commander is distributed through the Windows Package
Manager, which makes `winget upgrade` the product's first real update path.
An update through a package manager is **unattended**: the installer runs
silently, every question it would ask is answered with its default, and the
user expects to come back to an updated program.

A file manager is a program people leave open all day, so the normal state of
the machine during an update is *"Tandem Commander is running"*. In that state
the update fails today. The installer notices that the running program holds
files it has to replace and asks Windows to close it; the program does not
end, the installer falls back to its Abort / Retry / Ignore question, the
silent mode answers **Abort**, and the whole installation is rolled back with
exit code 5 (evidence: `specs/072-winget-distribution/REMAINING-WORK.md`, P1).
The user sees a failed update and no hint that closing the program first would
have helped.

This is not a regression. The installer has always behaved this way; it did
not matter while updating meant running the installer by hand, where the same
situation shows a dialog a person can answer.

The application already reacts to the *other* reasons Windows asks it to end —
log-off, shutdown, and the forced "critical" shutdown — with an elaborate,
carefully tuned sequence that saves or backs up the configuration within the
few seconds Windows allows. A close request from an installer is a different
situation that this sequence was never designed for: nobody is signing out,
Windows will **not** end the process on the program's behalf, nobody is
sitting at the machine to answer a question, and the installer waits only a
limited time before it gives up.

The helper process `salmon.exe`, which the 072 evidence also named as holding
files, no longer exists (removed in feature 079). Whether it was a
contributing cause is part of the baseline this feature has to establish.

### What the baseline showed (added 2026-09-20, after the reproduction)

The reproduction required by FR-001 was done before planning, and it changed
the picture. It is recorded here because the rest of this document has to be
read in its light; the evidence is in `fix-log.md` and `research.md`.

- **The failure in 0.1.7 was caused by the helper, not by the program.**
  Windows cannot close a process that has no window, and when the list of
  programs to close contains one, it gives up on the whole list at once. The
  main program was never even asked. Asked on its own, it closes in about a
  second — in 0.1.7 as well as now.
- **With the helper gone the basic case already works**: a silent update over
  an idle, running program succeeds, from 0.1.7 to the current build and from
  the current build to itself.
- **What does not work is everything around the basic case.** The program
  treats the installer's request like the user signing out and runs its
  complete *interactive* exit while the installer waits. When a file operation
  is running, or when a viewer window of a plug-in is open — which is the
  everyday state, because the plug-in viewer is the default for F3 — the
  update fails after a timeout, **a question is left on the screen of a
  machine nobody is sitting at, and when that question is answered minutes or
  hours later the program exits by itself**, with no installer left to bring
  it back.
- **After a successful update the program is simply gone.** Nothing starts it
  again.
- **An installation upgraded from 0.1.7 keeps `salmon.exe` on disk.** The
  installer does not delete files it no longer ships, so the file antivirus
  engines flag (the reason for feature 079) stays in every upgraded
  installation. The obvious remedy would bring the original failure back —
  see User Story 5.

User Story 1 therefore describes a guarantee that must be *kept and proven*
rather than a defect to be removed; the defects are in User Stories 2, 3
and 5.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An unattended update succeeds while the program is open (Priority: P1)

A user runs `winget upgrade tandemcommander` (or any silent run of the
installer) and does not close Tandem Commander first. The running program is
asked to close, closes by itself without asking anything, the installer
replaces its files and finishes successfully.

**Why this priority**: This is the failure real users will hit on the first
update after the package appears in the catalogue. Everything else in this
feature refines what happens around this one outcome.

**Independent Test**: Install a build into a scratch location, start the
installed program, leave it idle, run the installer again silently with the
package manager's switches, and read the installer's exit code and log. Value
on its own: the update no longer fails.

**Acceptance Scenarios**:

1. **Given** an installed copy whose program is running and idle, **When** the
   installer is run over it silently with message boxes suppressed, **Then**
   the installer finishes with exit code 0, its log records that the running
   program was closed, and no file of the installation is left un-replaced.
2. **Given** the same situation, **When** the program receives the installer's
   close request, **Then** its process ends completely — not only its window —
   within the time the installer allows, and with a comfortable margin.
3. **Given** a running program whose *Confirm on program exit* option is on,
   **When** the installer asks it to close, **Then** it closes without showing
   that confirmation or any other prompt.
4. **Given** the unmodified product as it stands before this feature, **When**
   the same test is performed, **Then** the failure is reproduced and recorded
   (exit code, installer log, what the program did with the request) so the
   fix is measured against evidence and not against the description alone.
   *(Done: reproduced with the published 0.1.7, exit code 5; not reproducible
   with the current build in the idle case — see Background.)*
5. **Given** an installed and running **0.1.7** — the version real users have —
   **When** the installer of this version is run over it silently, **Then** it
   finishes with exit code 0, although the old program still has its helper
   process running.

---

### User Story 2 - Closing for an update loses nothing (Priority: P1)

The program that closes for an update leaves the user exactly what a normal
exit would have left: the configuration is saved the way the user's settings
say it should be, the panels' directories and the tabs are remembered, and
nothing the user was in the middle of is destroyed. Where closing safely would
require asking the user something, the program does not guess — it declines
the request, keeps running untouched, and the update fails cleanly the way it
does today.

**Why this priority**: An update that silently destroys a half-finished copy
or discards edits made inside an archive is worse than an update that fails.
The unattended close is only acceptable if it is never more destructive than
the close the user performs by hand.

**Independent Test**: Put the program into each "busy" state in turn (a file
operation in progress, a modal dialog open, files edited inside an archive
waiting to be packed back), send the close request, and check that the program
is still running, fully usable and unchanged, that no prompt appeared, and
that the requester got its refusal quickly. Then repeat from an idle state and
compare the saved configuration with the one a manual exit produces.

**Acceptance Scenarios**:

1. **Given** an idle program with *Save configuration on exit* enabled,
   **When** it closes for an update, **Then** the saved configuration is
   equivalent to the one a manual exit from the same state produces —
   including both panels' directories, every tab, and the active tab.
2. **Given** an idle program with *Save configuration on exit* disabled,
   **When** it closes for an update, **Then** the stored configuration is left
   exactly as it was, as a manual exit would leave it.
3. **Given** a copy, move or delete operation in progress, **When** the close
   request arrives, **Then** the program declines it promptly, shows no
   prompt, the operation continues undisturbed, and the installer fails
   without having replaced any file.
4. **Given** a modal dialog open in the program (for example Configuration),
   **When** the close request arrives, **Then** the program declines promptly,
   shows no message, and the dialog remains open and usable.
5. **Given** any state in which a manual exit would ask the user a question
   before it can proceed (unsaved changes to pack back into an archive, a
   plug-in that cannot be unloaded without a decision, a search that has to be
   stopped), **When** the close request arrives, **Then** the program either
   completes the close without data loss and without the question, or
   declines promptly — and which of the two applies to each such state is
   decided deliberately and written down, never left to a timeout.
6. **Given** a close request that the program declined, **When** the user
   looks at the program afterwards, **Then** every window it had open (panels,
   Find windows, viewers, progress dialogs) is still there and works.

---

### User Story 3 - The program comes back after the update (Priority: P2)

After the installer has replaced the files, the program the user had open is
started again, showing the same directories and tabs it showed before. The
user finds an updated program where they left the old one.

**Why this priority**: Without it the update works but the user's tool simply
vanishes from the screen with no explanation — technically correct and
unsettling. With it, an update behaves the way updates of other modern desktop
programs behave. It ranks below the first two stories because a successful
update without a restart already removes the failure.

**Independent Test**: With the program running on known directories and
several tabs, run the silent update and afterwards check that a new instance
of the *updated* program is running and shows the same directories, tabs and
active tab.

**Acceptance Scenarios**:

1. **Given** a running program with *Save configuration on exit* enabled,
   **When** a silent update closes it and completes, **Then** the program is
   started again automatically and shows the panels' directories, the tabs and
   the active tab it had when it closed.
2. **Given** a running program with *Save configuration on exit* disabled,
   **When** the same happens, **Then** the program is started again and shows
   what its stored configuration says — the same result as the user closing
   and reopening it by hand.
3. **Given** an installer run that asks for applications **not** to be
   restarted, **When** the update completes, **Then** the program stays
   closed.
4. **Given** the program ends for any other reason (a normal exit, a crash, a
   hang ended by the user, a sign-out or reboot), **When** that happens,
   **Then** nothing restarts it — the automatic restart belongs to the update
   and to nothing else.
5. **Given** the program restarted after an update, **When** it starts,
   **Then** it starts as an ordinary instance: no special window, no message
   about the update, no difference in behaviour from a manual start.

---

### User Story 4 - Sign-out, shutdown and the normal exit behave as before (Priority: P2)

Everything the program did when Windows signs the user out, shuts down, or
forces a critical shutdown — and everything it does on the ordinary
*Exit* command — stays exactly as it was. The update close is an addition next
to those paths, not a rewrite of them.

**Why this priority**: The existing sequence protects the user's
configuration against being half-written when Windows kills the process; it is
old, subtle and was tuned experimentally across Windows versions. Breaking it
would trade a failed update for a corrupted configuration.

**Independent Test**: Exercise the normal exit (with and without the exit
confirmation, with a file operation running, with a Find window open) and the
sign-out style requests with and without the "critical" marking, before and
after the change, and compare the observable behaviour.

**Acceptance Scenarios**:

1. **Given** the normal *Exit* command in each state covered today (idle,
   confirmation enabled, file operation running, Find windows open), **When**
   it is used, **Then** prompts, waiting windows and the saved configuration
   are identical to the behaviour before this feature.
2. **Given** a sign-out or shutdown request that is not an installer's close
   request, **When** it arrives, **Then** the program follows the existing
   sequence unchanged, including the configuration backup taken for a critical
   shutdown.

---

### User Story 5 - An upgraded installation no longer contains the removed helper (Priority: P2)

A user who installed 0.1.7 or older and upgrades to this version ends up with
the same set of files as a user who installed this version fresh. In
particular the crash-reporting helper removed in feature 079 — the file
antivirus engines flag — is no longer in the installation folder.

**Why this priority**: Feature 079 removed the helper because antivirus
products blocked the program over it. For everyone who upgrades instead of
installing fresh, the file is still there, so for them 079 has not happened.
It belongs to this feature because it is a defect *of the upgrade path*, it
was found by this feature's baseline, and the straightforward fix collides
head-on with User Story 1: telling the installer to delete the file makes the
installer ask Windows to close the old, still-running helper — which Windows
cannot do — and the update fails exactly as it did in 0.1.7.

**Independent Test**: Install the published 0.1.7 into a scratch location,
start it, run this version's installer over it silently, and list the
installation folder.

**Acceptance Scenarios**:

1. **Given** a running 0.1.7 installation, **When** this version's installer
   is run over it silently, **Then** the installer succeeds (User Story 1,
   scenario 5) **and** the helper file is gone from the installation folder
   afterwards.
2. **Given** a 0.1.7 installation whose program is *not* running, **When** the
   installer is run over it, **Then** the helper file is gone afterwards.
3. **Given** a fresh installation of this version, **When** it is installed or
   upgraded to itself, **Then** the removal step finds nothing and changes
   nothing.
4. **Given** the helper file cannot be deleted (still in use, no permission),
   **When** the installer reaches that step, **Then** the installation still
   succeeds and the installer's log says the file was left behind.

---

### Edge Cases

- **Several instances are running.** Each of them holds the installation's
  files, so each must close for the update to succeed, and each that closed is
  eligible to be started again. They all read the same stored configuration,
  so after the restart they show the same state — as they would if the user
  reopened them by hand.
- **One instance is busy, another is idle.** The busy one declines, the update
  fails cleanly; the idle one may already have closed. This is acceptable (it
  closed the way a manual exit closes, nothing was lost) and is recorded as
  the expected outcome rather than prevented.
- **The program runs elevated, the installer does not** (per-user
  installation). Windows does not let the lower-privileged installer close the
  program; the update fails as it does today. Out of the program's hands,
  documented.
- **The request arrives while the program is still starting up**, before its
  main window is ready to close. It declines promptly; nothing is half-closed.
- **The request arrives less than a minute after start.** Closing works the
  same; whether Windows honours the restart for such a young process is
  recorded by testing, not assumed.
- **Windows of the program other than the main window** — Find windows,
  internal and plug-in viewers (including the ones that host a browser
  engine), progress dialogs, hidden helper windows — all receive the same
  request. None of them may prevent a close the main window agreed to, none
  may keep the process alive after the main window is gone, and none may close
  on its own while the main window declines.
- **Files opened from the installation folder by the program itself** (help,
  language modules, plug-ins) must be released by the time the process ends;
  nothing may stay locked by a leftover process.
- **The Windows shell has the program's shell extension loaded.** The
  installer may then also want to close Windows Explorer. That is the
  installer's and Windows' business and is the same before and after this
  feature; the baseline records whether it occurs.
- **A plug-in file system connection is open** (FTP, SFTP). Closing for an
  update disconnects it the same way a normal exit does when no question is
  required; if the plug-in insists on asking, the request is declined.
- **The interactive installer** (a person runs Setup by hand and lets it close
  the running program) uses the same close request and therefore benefits
  from the same behaviour.
- **The user disabled the saving of configuration on exit** — covered in User
  Stories 2 and 3: the update neither saves nor loses more than a manual exit.
- **The update is started while the program shows its own exit confirmation
  or "saving configuration" window**, i.e. while it is already closing: the
  request must not start a second, nested close.
- **Uninstalling while the program is running** is a different mechanism of
  the installer and is out of scope; its behaviour is unchanged.

## Requirements *(mandatory)*

### Functional Requirements

**Baseline and evidence**

- **FR-001**: Before any product change, the failure MUST be reproduced
  against the current state of the product and recorded: the installer's exit
  code and log, which processes and windows received the close request, what
  each answered, and why the process did not end. The record MUST state
  whether the removed `salmon.exe` helper was part of the original failure.
- **FR-002**: The project MUST gain a repeatable way to issue the same close
  request an installer issues — and optionally the same restart — against a
  running build, without building or running an installer, so the behaviour
  can be tested in seconds and re-tested after every change. It MUST report
  what the request found, how long the program took, whether the process
  ended, and whether it was started again.

**Closing for an update**

- **FR-003**: When an installer or updater asks the program to close so that
  its files can be replaced, an idle instance MUST agree and its process MUST
  end completely, releasing every file of the installation, well within the
  time the requester allows (the requester's limit is about 30 seconds; the
  program's target is 10 seconds or less with the default set of plug-ins).
- **FR-004**: Such a close MUST preserve everything a normal exit preserves
  and MUST respect the same user settings: with saving on exit enabled the
  configuration — including both panels' directories, all tabs and the active
  tab — is stored as a normal exit stores it; with saving disabled the stored
  configuration is not touched. The stored configuration MUST never be left
  half-written by such a close.
- **FR-005**: During such a close the program MUST NOT ask or tell the user
  anything: no exit confirmation, no question, no message box, no error
  dialog. A waiting window that needs no answer is permitted.
- **FR-006**: In every state in which closing would require a decision from
  the user or would interrupt work in progress — at minimum: a file operation
  running, a modal dialog or other "busy" state, start-up not finished, a
  close already under way, a plug-in or panel that cannot be left without a
  question — the program MUST decline the request instead, and MUST be left
  exactly as it was: same windows, same state, fully usable. The handling of
  each such state (close silently and safely, or decline) MUST be decided
  explicitly and documented.
- **FR-007**: A refusal MUST be given promptly — within 5 seconds of the
  request — so the installer fails fast instead of waiting for a timeout.
- **FR-008**: Every window of the program that receives the request MUST
  behave consistently with the main window's decision: none blocks an agreed
  close or keeps the process alive after it, and none closes by itself when
  the main window declines.
- **FR-009**: The program MUST NOT begin an irreversible close on the mere
  *question* whether it can close, if the platform's protocol distinguishes
  the question from the final instruction and another participant can still
  cancel the operation after the program has answered. If the evidence shows
  that acting at the question stage is the only reliable way to end in time,
  that deviation MUST be justified in the records.

**Coming back after the update**

- **FR-010**: The program MUST make itself eligible to be started again by
  the installer after a close that the installer requested. The restarted
  program MUST be an ordinary instance started the ordinary way, restoring its
  state from the stored configuration exactly as a manual start does.
- **FR-011**: That eligibility MUST be limited to the update case. The program
  MUST NOT be restarted automatically after a crash, after a hang, after a
  normal exit, or after a sign-out or reboot.
- **FR-012**: The decision whether the program is actually restarted stays
  with the installer and the person running it (the installer's existing
  "do not restart applications" switch MUST keep working). No new option is
  added to the program's configuration for this.

**What must not change**

- **FR-013**: The normal exit, sign-out, shutdown and critical-shutdown
  behaviour — prompts, waiting windows, timing safeguards, the configuration
  backup — MUST remain as it is for every request that is not an installer's
  close request.
- **FR-014**: The plug-in interface MUST NOT change (interface version stays
  106); no plug-in has to be rebuilt or modified for the feature to work.
- **FR-015**: The configuration format and its version MUST NOT change, and no
  new stored setting is introduced.
- **FR-016**: The product version and build number MUST remain 0.1.8 / 192.
  The user-visible change is described in the `## [0.1.8] — unreleased`
  section of `CHANGELOG.md`.
- **FR-017**: The fix of the close-and-restart behaviour belongs to the
  application. The installer script MUST NOT be changed for it. The only
  change to the installer script is the removal step of FR-021, and it MUST
  keep everything the package-manager distribution depends on (feature 072)
  intact — the privilege directive, the application identifier, silent
  operation.

**Leftovers of the removed helper**

- **FR-021**: Upgrading an installation of 0.1.7 or older MUST remove the
  crash-reporting helper's file from the installation folder. The removal
  MUST NOT make the installer treat that file as one it has to free — i.e. it
  MUST NOT cause the old, running helper to be put on the list of programs
  Windows is asked to close — because that is what made every update over a
  running 0.1.7 fail.
- **FR-022**: The removal step MUST be harmless: nothing happens when the file
  does not exist, a file that cannot be deleted never fails the installation,
  and the outcome is written to the installer's log.

**Verification and records**

- **FR-018**: The outcome MUST be verified end to end with a real installer
  built from this source tree: a silent installation with suppressed message
  boxes over a running, idle instance finishes with exit code 0, and the
  restart behaves as specified. The verification MUST NOT disturb the user's
  machine: the published 0.1.7 installation, the archived release installers
  and the user's stored configuration are left as they were found, and that
  is checked, not assumed.
- **FR-019**: Work and findings MUST be logged as they happen in
  `specs/080-restart-manager-upgrade/fix-log.md` — including dead ends,
  measurements, and every step that could not be performed autonomously and
  is therefore owed to a person.
- **FR-020**: The backlog and project records MUST be brought up to date:
  `specs/NEXT-WORK.md` (item 2), `specs/072-winget-distribution/REMAINING-WORK.md`
  (P1), `CLAUDE.md`, and the user manual wherever it describes exiting the
  program or updating it.

### Key Entities

- **Close request**: the request an installer sends, through Windows, to every
  window of a program that holds files it needs to replace. It has a question
  stage ("can you close?") and an instruction stage ("close now" or "never
  mind"), is distinguishable from sign-out and shutdown requests, and comes
  with time limits set by the requester.
- **Close decision**: the program's answer — agree or decline — together with
  the rule that produced it (which state the program was in). Deliberate,
  documented per state, and never the product of a timeout.
- **Restart eligibility**: the program's standing declaration to Windows that
  it may be started again after an update closed it; scoped to the update
  case only, carrying nothing but the ordinary way to start the program.
- **Stored configuration**: the existing per-user settings, including the
  panels' directories and the tabs (feature 078). It is the only carrier of
  state across the restart; its format is unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A silent update over one running, idle instance succeeds in 5
  out of 5 consecutive attempts (installer exit code 0) — both over the
  published 0.1.7 and over this version itself. (With the published 0.1.7
  installer over a running 0.1.7 it fails in every attempt; that is the
  recorded starting point.)
- **SC-002**: An idle instance with the default plug-ins ends its process
  within 10 seconds of the close request, measured on the development
  machine, in every one of those attempts.
- **SC-003**: After a successful update the program is running again within
  15 seconds of the installer finishing, and shows the same panel directories,
  the same number of tabs with the same directories, and the same active tab
  as before — verified by comparing the stored state before and after.
- **SC-004**: In each defined "busy" state the program declines within
  5 seconds, zero prompts appear, the work in progress completes correctly
  afterwards, and the installer leaves the existing installation unmodified.
- **SC-005**: Zero prompts, questions or message boxes appear on the screen
  during any unattended close, agreed or declined, across all tested states.
- **SC-006**: The configuration stored by a close for an update is equivalent,
  value by value, to the one stored by a manual exit from the same state
  (apart from values that legitimately differ between any two runs, such as
  timestamps and window-activation order).
- **SC-007**: The normal exit and the sign-out / shutdown paths show no
  observable difference from the behaviour before the feature in the states
  tested, and the existing automated test suite passes with no fewer checks
  than before.
- **SC-008**: After the verification the machine is as it was found: the
  published installation, the archived installers (hash-checked) and the
  user's stored configuration are unchanged.
- **SC-009**: After upgrading a running 0.1.7 the installation folder contains
  no crash-reporting helper, and the file list of the upgraded installation is
  identical to that of a fresh installation of this version (apart from the
  installer's own uninstall records).
- **SC-010**: In the two everyday "not idle" states found by the baseline — a
  file operation running, a plug-in viewer window open — the request is
  answered within 5 seconds, nothing is left on the screen, and the program
  does **not** exit later on its own.

## Assumptions

- **The restart is on by default and has no switch in the program.** The
  constitution asks for user-facing behaviour changes to be opt-in. This one
  replaces a failure rather than changing a working behaviour, happens only
  when the user (or their package manager) runs an installer, and is already
  controllable where it belongs — the installer's "do not restart
  applications" switch. Adding a program option for it would create a setting
  almost nobody could find a reason to change. Recorded as a deliberate,
  documented decision in the manner of feature 078's default-on tabs.
- **State survives the restart through the stored configuration, not through
  the restart command line.** Panels and tabs are already saved on exit and
  restored at start (feature 078). Passing directories on the command line
  would duplicate that mechanism, could not carry tabs, would be limited in
  length, and would make the restarted instance behave differently from a
  manually started one. Consequence, accepted: with *Save configuration on
  exit* disabled the restarted program shows its stored state, not the state
  at the moment of closing — which is precisely what that option means.
- **Restart after a reboot or sign-out is excluded** even though Windows
  offers it to programs that declare themselves restartable. It cannot be
  verified in this autonomous session, it would make the program reappear at
  sign-in for users who enabled the corresponding Windows setting — a
  behaviour change unrelated to updates — and it can be added later as its
  own small decision.
- **Declining is the safe default for every state that would need a
  question.** An unattended update that fails can be retried; work destroyed
  by an unattended close cannot be recovered.
- **An open plug-in window makes the program decline**, including plug-in
  *viewer* windows, which hold nothing that could be lost. Closing them
  silently would be the better behaviour, but the only ways to do it without
  the plug-ins' cooperation are to force-unload plug-ins (which also cancels
  transfers of the FTP and SFTP plug-ins) or to imitate a click on every
  window's close button (which can raise a plug-in's own question on an
  unattended machine — the very defect being removed). Doing it properly
  needs a way to tell plug-ins that a close is unattended, i.e. an addition to
  the plug-in interface, which this feature must not touch (FR-014). Recorded
  as follow-up work; the user-visible consequence — *close viewer windows
  before updating, or the update is declined* — is stated in the changelog
  and the manual.
- **The installer's behaviour is already correct.** It asks the program to
  close, would restart it afterwards, and rolls back cleanly when the program
  does not close. The 072 evidence supports this; the baseline (FR-001)
  confirms or refutes it.
- **Verification uses a per-user installation into a scratch folder**, which
  needs no elevation and was already proven workable in features 072 and 077.
  The machine-wide (elevated) variant of the same test — including the check
  that an elevated installer restarts the program *without* elevation — cannot
  be run without a person answering the elevation prompt and is recorded as
  an owed human step. The same applies to a real `winget upgrade`, which is
  only possible once the package is in the catalogue and a newer version than
  the installed one is published.
- **The test instance shares the user's stored configuration**, because the
  product has a single per-user configuration location by design. Tests
  therefore back the configuration up first and restore it afterwards, and
  the restoration is verified (the practice established in features 078
  and 079).
- **Windows 11 is the target**; the behaviour of older Windows versions
  towards these requests is not investigated, consistent with the
  constitution's platform commitment.
