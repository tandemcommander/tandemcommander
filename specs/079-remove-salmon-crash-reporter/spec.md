# Feature Specification: Remove the salmon.exe Crash Reporter

**Feature Branch**: `079-remove-salmon-crash-reporter`
**Created**: 2026-09-19
**Status**: Draft
**Input**: User description: "Remove the salmon.exe crash reporter from the build and the shipped product entirely. Users have reported that their antivirus blocked the program because of salmon.exe. The application must still handle an unhandled exception sanely without salmon: keep writing the textual bug report, tell the user where it is, terminate as before. Remove the helper from the solution, build, installer, resources, translations, tooling and documentation. Do not bump the application version. Test thoroughly. Executed autonomously via the Spec Kit flow."

## Background

Tandem Commander inherited from Open Salamander a separate helper program,
`salmon.exe`, that the main application starts at every launch and keeps
running for the whole session. Its job was to capture a memory dump of the
main program from the outside when it crashed, pack the dump together with a
textual report, and upload the package to the vendor's server. It also opened
a dialog at start-up whenever it found reports from earlier crashes and asked
whether to upload them.

In Tandem Commander none of that value remains:

- Uploading was permanently switched off in feature 032 (reports are private
  and stay on the user's disk).
- No memory dump has ever been produced in any Tandem Commander release: the
  helper needs a debugging library that the product does not ship (found in
  feature 077).
- What users actually receive after a crash is a **text report** that the
  main application writes by itself, plus a dialog opened by the helper.

Meanwhile the helper causes real harm. A background program that starts with
the application, holds an open handle to it, waits to read its memory and
writes dumps of it is exactly the pattern behaviour-based antivirus engines
flag. Users have reported that their antivirus blocked Tandem Commander
because of `salmon.exe`. Feature 076 reviewed the false-positive findings and
feature 077 removed one such trigger (an in-process code patch); this feature
removes the helper itself.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The product ships and runs without the helper (Priority: P1)

A user installs Tandem Commander, or unpacks a build, and runs it. No second
program is started alongside the file manager, nothing in the installed
folder is a crash-reporting helper, and antivirus heuristics that keyed on
the helper have nothing left to flag.

**Why this priority**: This is the reason the feature exists. Users who were
blocked by their antivirus cannot use the product at all; every other story
is about keeping what worked while this one removes the cause.

**Independent Test**: Build the product, inspect the output folder and the
installer contents for the helper, start the application and list the
processes that belong to it. Delivers value on its own: the flagged file is
gone.

**Acceptance Scenarios**:

1. **Given** a complete Release build, **When** the build output and the
   installer's payload are searched for the crash-reporting helper, **Then**
   no such file exists anywhere in the tree and the `utils` folder contains
   only the other helpers it always contained.
2. **Given** a freshly installed product and no prior configuration,
   **When** the user starts Tandem Commander, **Then** exactly one process
   belongs to the application for the whole session, the main window appears
   as fast as before, and no message about a bug reporter is shown.
3. **Given** a complete Debug build, **When** the same checks are made,
   **Then** the result is the same (the helper is gone from every build
   flavour, not only from the shipped one).

---

### User Story 2 - A crash still leaves a usable report and tells the user where it is (Priority: P1)

Something goes badly wrong inside Tandem Commander (a fault in the program or
in a plugin). The program writes a textual report of the failure into the
user's local application-data folder, tells the user that it must close and
where the report was saved, and then closes. Nothing is sent anywhere. The
user can attach the report to an issue on GitHub exactly as before.

**Why this priority**: Removing the helper must not turn a crash into a
silent disappearance or a hang. The text report is what the project relies
on to diagnose user-reported crashes, and today the helper is the only thing
that tells the user a report exists.

**Independent Test**: Provoke an unhandled fault in the running application
(the feature-077 probe does this for the main program and for a loaded
plugin) and observe the report file, the message and the exit.

**Acceptance Scenarios**:

1. **Given** the application is running and the report folder does not exist
   yet, **When** an unhandled fault occurs on the main thread, **Then** the
   folder is created, a report file with the same content as today
   (exception details, faulting address, registers, call stacks, loaded
   modules) is written into it, a message names the full path of the report
   and states that nothing is sent anywhere, and after the user dismisses the
   message the process ends with the same exit code as before.
2. **Given** the fault happens inside a loaded plugin, **When** the report is
   written, **Then** it records the faulting address inside that plugin's
   address range, exactly as it does today.
3. **Given** two crashes happen within the same second (for example two
   instances), **When** both reports are written, **Then** neither overwrites
   the other; both are present with distinct names.
4. **Given** the user interface language has not been loaded yet (a crash very
   early in start-up), **When** the message is shown, **Then** it is shown in
   English and still names the report path.
5. **Given** the report file cannot be written (folder creation or file
   creation fails), **When** the crash is handled, **Then** the user is still
   told that the program must close and that the report could not be saved,
   and the process still terminates instead of hanging.
6. **Given** a fault is provoked through the Task List *Break* command from a
   second instance, **When** the target instance handles it, **Then** the
   report and the message appear in the target instance exactly like for a
   spontaneous crash.
7. **Given** the existing special crash notifications for a crashing shell
   extension or icon-overlay handler, **When** such a crash occurs, **Then**
   those notifications keep appearing as they do today, followed by the
   standard report and message.

---

### User Story 3 - Start-up is never interrupted or blocked by old reports (Priority: P2)

A user whose earlier session crashed starts Tandem Commander again. Today a
"older bug reports were found" question pops up from the helper while the
main window sits unresponsive until it is answered. After this feature the
program simply starts; the earlier report files stay untouched on disk for
the user to pick up whenever they want.

**Why this priority**: The blocking dialog is a known usability defect (it
stalled the feature-077 crash probe too) and it disappears as a direct
consequence of removing the helper. It is a separate story because it has
its own observable behaviour and its own test.

**Independent Test**: Place a few report files (text, dump and archive
extensions) in the report folder and start the application.

**Acceptance Scenarios**:

1. **Given** three report files from earlier crashes exist in the report
   folder, **When** the user starts Tandem Commander, **Then** no dialog or
   question about them appears, the main window responds immediately, and the
   three files are still there with unchanged names afterwards.
2. **Given** the helper's registry key from an earlier version still exists
   on the machine, **When** the application starts and runs, **Then** it
   neither reads nor writes that key, and the key's presence or absence has no
   visible effect.

---

### User Story 4 - The repository carries no dead crash-reporter baggage (Priority: P3)

A maintainer building, translating, signing or documenting the product finds
no trace of the removed helper: no project in the solution, no source
directory, no dialog template or message strings in the language resources,
no entries in the translation sources, no exclusion in the encoding checker,
no line in the base-address table, no icon in the brand generator, and no
description of the helper in the architecture documents or the manual. The
change log records the removal under an unreleased heading, and the product
version stays 0.1.8.

**Why this priority**: Leftovers are not user-visible, but stale resources
and translations would be shipped inside every language module, the icon
generator would try to write a file into a directory that no longer exists,
and the next contributor would rediscover the helper in the documentation.

**Independent Test**: Search the repository for the helper's name outside
historical feature records and third-party code; build every enabled
language; run the brand icon generator and the encoding checker.

**Acceptance Scenarios**:

1. **Given** the feature is complete, **When** the repository is searched
   case-insensitively for the helper's name, **Then** the only matches are
   in historical feature records under `specs/`, in the change log, and in
   third-party code where the word is a colour name.
2. **Given** all eight enabled languages, **When** the full build produces
   the language modules, **Then** every language builds and no translation
   source contains the helper's strings or dialog.
3. **Given** the repository tooling (brand icon generator, encoding checker,
   runtime-dependency checker, signing sweep), **When** each is run, **Then**
   none of them fails or warns because of a missing helper file.

---

### Edge Cases

- **Report folder missing or read-only**: the folder is created on demand;
  if that fails the user still gets the closing message (stating that the
  report could not be saved) and the process terminates.
- **Name collision**: report names carry the product version and a
  timestamp; a collision within the same second gets a numeric suffix.
- **Crash before the language module is loaded**: English fallback text.
- **Crash on a background thread**: the same path applies; the message is
  shown from the reporting thread, as the existing shell-extension crash
  notice already is.
- **Second instance of an older version (0.1.8) running at the same time**:
  the two instances share a process-list record; its layout must stay
  compatible so that Task List and single-instance activation keep working
  across the versions.
- **Leftover files from the old helper** (`.DMP`, `.7Z`, renamed text
  reports): never touched, never offered, never deleted.
- **Debug build under a debugger**: unchanged; the fault is passed to the
  debugger instead of producing a report.
- **Windows Error Reporting**: unchanged; the product never configured it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The build output of every configuration (Debug and Release) and
  the installer payload MUST NOT contain the crash-reporting helper program
  or its debug symbols; the `utils` folder MUST continue to ship its other
  helpers unchanged.
- **FR-002**: The application MUST NOT start, wait for, or communicate with
  any helper process for crash handling, at start-up or at any later time.
- **FR-003**: The application MUST NOT show any message about a bug reporter
  failing to initialise or not running; those messages cease to exist in
  every language.
- **FR-004**: The application MUST NOT inspect, offer, rename or delete
  earlier crash reports at start-up or at any other time.
- **FR-005**: On an unhandled exception the application MUST write a text
  report with the same content as today (exception details and faulting
  address, registers, call stacks of all threads, loaded modules) into the
  per-user local application-data folder of Tandem Commander, creating that
  folder if it is missing.
- **FR-006**: Report file names MUST be unique per crash, carry the product
  version and the local date and time of the crash, and keep the `.TXT`
  extension so existing instructions and tooling that look for text reports
  keep working.
- **FR-007**: After the report is written the application MUST tell the user
  that it has to close, name the full path of the report (or state that it
  could not be saved), and state that nothing is sent anywhere; the text MUST
  be in the loaded interface language, with an English fallback when no
  language has been loaded yet.
- **FR-008**: The crash path (report, message, termination) MUST complete
  without waiting on anything outside the process and MUST terminate the
  process with the same exit code as today; a failure to write the report
  MUST NOT prevent the message or the termination.
- **FR-009**: The existing special crash notifications (shell-extension
  crash, icon-overlay-handler crash) and the Task List *Break* command MUST
  keep working and MUST end in the standard report and message.
- **FR-010**: The crash-reporter dialog template, its control identifiers and
  all its message strings MUST be removed from the language resources, and
  the translation sources of every language MUST be regenerated so that they
  contain neither the removed strings nor the removed dialog.
- **FR-011**: The application MUST stop reading and writing the `Bug
  Reporter` registry key (the helper's machine identifier); no other
  configuration value changes and the configuration version stays the same.
- **FR-012**: The shared process-list record used between running instances
  MUST keep its current layout so that an instance of version 0.1.8 and an
  instance built from this feature can run side by side.
- **FR-013**: The helper's project MUST be removed from the solution and the
  build so that no build step, signing step, runtime-dependency check or
  solution filter references it; the encoding checker, the base-address
  table and the brand icon generator MUST no longer refer to it.
- **FR-014**: The architecture documents, the project instructions file, the
  manual pages that describe the Bug Report dialog, and the change log
  (an unreleased entry) MUST be updated to describe the new behaviour.
- **FR-015**: The product version and build number MUST remain 0.1.8 / 192;
  the plugin interface version and the plugin ABI MUST remain untouched.

### Key Entities

- **Crash report**: a text file written by the application when it must
  close because of an unhandled fault; identified by product version and
  timestamp; stored in the user's local application-data folder; private
  (never transmitted).
- **Process-list record**: the small shared record every running instance
  publishes so other instances can find, activate or break it; its layout is
  a compatibility contract between versions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A search of the complete Release build tree and of the
  installer payload for the crash-reporting helper returns zero files.
- **SC-002**: During a full session started with a fresh configuration,
  exactly one process belongs to Tandem Commander, and the main window is
  responsive within 5 seconds of appearing.
- **SC-003**: With three stale report files present, start-up shows no dialog,
  the main window is responsive within 5 seconds of appearing, and all three
  files are unchanged afterwards.
- **SC-004**: In 3 of 3 provoked crashes of the main program and 3 of 3
  provoked crashes inside a plugin, a report naming the faulting address is
  written within 60 seconds, the closing message names that report's path,
  and the process exits with code 1 after the message is dismissed.
- **SC-005**: A complete Debug build and a complete Release build succeed; the
  unit-test executable passes with no failures (baseline 1405 checks); the
  signing sweep, the runtime-dependency check and the encoding checker
  (strict rules) all finish clean.
- **SC-006**: All eight enabled languages build, and the crash message is
  available in each of them; zero translation sources contain the removed
  strings.
- **SC-007**: A case-insensitive search of the repository for the helper's
  name yields matches only in historical records under `specs/`, in the
  change log, and in third-party sources where it is a colour name.

## Assumptions

- Memory dumps are not a requirement. No Tandem Commander release ever
  produced one, and the text report is what the project uses to diagnose
  crashes; if dumps are wanted later they can be produced in-process by a
  separate feature.
- Nobody depends on the helper's machine identifier in the registry; it was
  only ever used to prefix uploaded report names.
- The `utils` folder stays, because other shipped helpers live there.
- The closing message is an ordinary message box in the house style, not a
  new dialog; it adds one new message string (plus title) to the language
  resources, translated through the established pipeline.
- The main application already contains the report writer; the feature
  reuses it and only takes over the two duties the helper performed for it
  (naming the report and informing the user).
- Leftover files and registry keys from the helper on users' machines are
  left alone; the uninstaller behaviour is unchanged.
- No application version bump: the change ships with the next release, under
  an unreleased heading in the change log until then.
