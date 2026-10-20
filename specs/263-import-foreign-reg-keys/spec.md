# Feature Specification: Importing a configuration file never writes or deletes keys outside the program's own root

**Feature Branch**: `263-import-foreign-reg-keys`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item importing-a-configuration-file-writes-every-key-of-a-foreign: "Importing a configuration file writes every key of a foreign .reg file". From backlog item importing-a-configuration-file-writes-every-key-of-a-foreign.

At every start the program imports a configuration file into the registry when one exists:
`config.reg` in the installation folder, in `%APPDATA%\Tandem Commander`, or the file named with
the `-C` parameter. The import is meant for the program's own settings
(`HKEY_CURRENT_USER\Software\Tandem Commander\0.1`, the file the program's own *Export
Configuration* / *Save Configuration As* writes). Today it writes and deletes **every** key the file
names - keys of other programs, `HKEY_CLASSES_ROOT`, `HKEY_LOCAL_MACHINE` where the user may write.

Measured at `0e36adce` (probe `probe/import263_probe.ps1`, `probe/result_before.txt`, PASS 7 /
FAIL 3):

- a file holding our key **and** `HKCU\Software\TC263ProbeForeign`: no message at all, the foreign
  key was written;
- a file holding only the foreign key: the question *"... does not contain configuration for this
  version of Tandem Commander. Do you want to import it anyway?"* (default No); *Yes* wrote the
  foreign key;
- a file holding our key and the delete line `[-HKEY_CURRENT_USER\Software\TC263ProbeVictim]`: no
  message, another program's key was **deleted**;
- the controls (only our keys; a delete line inside our root) imported as expected.

The defect is therefore broader than the item's text: also a file that does contain our
configuration writes and deletes foreign keys silently.

## Clarifications

### Session 2026-10-20

- Q: The item allows two outcomes - import only our keys and skip (and name) the others, or refuse a file without our configuration. Which one for a file that holds our keys and also a key outside our root? → A: The whole file is refused before anything is written, with the existing message "Unable to import the specified file. It is not a configuration file." (`IDS_IMPORTCFG_NOTREG`). Skipping the foreign keys would guess what the user wanted from a file that is not the program's own export (the program's export never contains a foreign key), and *naming* the skipped keys needs a new UI string, which needs the translation refresh a run cannot do (autonomous run: conservative + rule 084)
- Q: What happens to a file that holds no key under our root (the old *"import it anyway?"* question)? → A: It is refused with the same message, without a question; *Yes* could only write foreign keys - also Open Salamander / Altap keys, which the program never writes (CLAUDE.md *Product identity*) (autonomous run: item + rule)
- Q: Which keys count as "ours"? → A: `HKEY_CURRENT_USER` + exactly the current configuration root `Software\Tandem Commander\0.1` or a key below it (the root followed by `\`); compared case-insensitively as the registry does; the parent `Software\Tandem Commander`, a sibling such as `Software\Tandem Commander\0.10`, any other root key (`HKEY_CLASSES_ROOT`, `HKEY_LOCAL_MACHINE`, ...) and a bare root line (`[HKEY_CURRENT_USER]`) are outside (autonomous run: conservative)
- Q: Do delete lines (`[-key]`) follow the same rule? → A: Yes - a delete line outside our root refuses the file like a key line; delete lines inside our root (the program's own export starts with `[-HKEY_CURRENT_USER\Software\Tandem Commander\0.1]`) keep working (autonomous run: conservative)
- Q: Does the now unused question text `IDS_IMPORTCFG_NOTOURVER` get removed? → A: No - removing a UI string also needs the translation refresh; it stays in the resources unused (autonomous run: rule 084)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A configuration file with a foreign key writes nothing (Priority: P1)

A user (or someone who can drop a file next to a portable installation) places a `config.reg`
that holds Tandem Commander settings and also a key of another program - for example a key under
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` or `HKEY_CLASSES_ROOT`. At the next start the
program shows "Unable to import the specified file. It is not a configuration file." with the
file's name, writes nothing from the file, and starts with the configuration it had.

**Why this priority**: this is the silent case - the measurement shows no message at all today and
the foreign key written.

**Independent Test**: start the program with `-C <file>` holding our key and a foreign key; check
that neither key exists afterwards and the message was shown (probe row MIXED).

**Acceptance Scenarios**:

1. **Given** a file with our key and `HKCU\Software\<other>`, **When** the program starts with it,
   **Then** the refusal message names the file and neither key is written.
2. **Given** a file with our key and a `HKEY_CLASSES_ROOT\<x>` key, **When** the program starts with
   it, **Then** the file is refused the same way.

---

### User Story 2 - A delete line never removes another program's key (Priority: P1)

A file holding our settings and the line `[-HKEY_CURRENT_USER\Software\<other program>]` is refused
before anything is deleted; the other program's key stays.

**Why this priority**: a deletion of another program's settings is a loss of user data.

**Independent Test**: probe row DELETE - the victim key created by the probe still exists.

**Acceptance Scenarios**:

1. **Given** an existing key `HKCU\Software\<victim>` and a file with our key plus
   `[-HKEY_CURRENT_USER\Software\<victim>]`, **When** the program starts with it, **Then** the
   victim key still exists and our key is not imported.

---

### User Story 3 - A file without our configuration is refused without a question (Priority: P2)

A file that holds no key under our root (another program's export, an old Salamander
configuration) is refused with the same message; the question "Do you want to import it anyway?"
no longer appears.

**Independent Test**: probe row NOROOT - the foreign key is not written whatever the probe answers.

**Acceptance Scenarios**:

1. **Given** a file holding only foreign keys, **When** the program starts with it, **Then** the
   refusal message is shown and nothing is written.
2. **Given** a valid .reg file with no key at all, **When** the program starts with it, **Then** it
   is refused the same way.

---

### User Story 4 - The program's own configuration files import as before (Priority: P1)

A file the program exported (`Export Configuration`, `Save Configuration As` with the clear-key
option: the delete line of our root, then our keys) and any file holding only keys under our root
import exactly as today, without a message.

**Independent Test**: probe rows OURS and OWNDEL pass before and after.

**Acceptance Scenarios**:

1. **Given** a file holding only keys under our root, **When** the program starts with it, **Then**
   they are imported and no message appears.
2. **Given** a file with a delete line inside our root followed by our keys, **When** the program
   starts with it, **Then** the deleted key is gone and the keys are imported.

### Edge Cases

- A key named like our root with a different letter case (`software\tandem commander\0.1`) is ours.
- A sibling root that starts with our root's text (`Software\Tandem Commander\0.10`,
  `Software\Tandem Commander\0.1x`) is not ours.
- The parent key `Software\Tandem Commander` (with or without values) is not ours.
- A key with a doubled backslash after the root key name (`HKEY_CURRENT_USER\\Software\...`) is not
  recognised as ours and refuses the file (fail closed).
- Values before the first key line or after a delete line already fail the check run in memory and
  refuse the file (unchanged).
- A UTF-16 (`Windows Registry Editor Version 5.00`) and a `REGEDIT4` file follow the same rule.
- The installer's upgrade path (`autoImportConfig`) skips the file import as today (unchanged).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before anything is written to the registry, the import MUST check every key line and
  every delete line of the file; if any of them names a key that is not the current configuration
  root `HKEY_CURRENT_USER\Software\Tandem Commander\0.1` or a key below it, the whole file MUST be
  refused and nothing from it written or deleted.
- **FR-002**: A refused file MUST be reported with the existing message `IDS_IMPORTCFG_NOTREG`
  ("Unable to import the specified file. It is not a configuration file." with the file name); no
  new UI string is added.
- **FR-003**: A file that holds no key under our root MUST be refused with the same message, without
  the question `IDS_IMPORTCFG_NOTOURVER`.
- **FR-004**: The writing pass MUST apply the same restriction as the check, so that it can never
  write or delete a key outside the root even if the check were bypassed.
- **FR-005**: Files holding only keys and delete lines inside our root MUST import exactly as today
  (same values, same handling of `.hidden` names, same error messages for format and registry
  errors).
- **FR-006**: The decision "is this key inside the root" MUST be a pure rule under `src/common/`
  with `saltests` checks (equal, below, sibling with a longer name, parent, other root keys, letter
  case, empty name, doubled backslash).

### Key Entities

- **Configuration root**: `HKEY_CURRENT_USER` + `Software\Tandem Commander\0.1`
  (`SalamanderConfigurationRoots[0]`) - the only branch an import may write or delete.
- **Key line / delete line**: `[<root key>\<path>]` / `[-<root key>\<path>]` lines of a .reg file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows MIXED, NOROOT and DELETE fail at `0e36adce` and pass after the change; no
  key outside our root is written or deleted in any row.
- **SC-002**: Probe rows OURS and OWNDEL pass before and after the change.
- **SC-003**: `saltests` covers the root rule with at least the eight cases of FR-006, 0 failed.
- **SC-004**: Encoding guard `TOTAL: 0`, Debug build succeeds, no new UI string.

## Assumptions

- Assumption (autonomous run): the program's own export never contains a key outside its root
  (`ExportConfiguration` copies only `HKCU\<SALAMANDER_ROOT_REG>`), so refusing such files cannot
  refuse a file the program wrote.
- Assumption (autonomous run): an old Salamander / Open Salamander `config.reg` imported "anyway"
  had no use in Tandem Commander (single root, no legacy chain since 032; feature 245 reads those
  roots read-only and never writes them); refusing it loses no supported workflow.
- Assumption (autonomous run): `PRIVACY.md` needs no change - the change only narrows what the
  program writes to its own key.
- Out of scope: the user-started *Import Configuration* of feature 245 (it does not parse .reg
  files); naming the offending key in the message (needs a new UI string - a leftover item).
