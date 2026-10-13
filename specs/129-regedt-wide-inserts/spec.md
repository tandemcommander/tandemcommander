# Feature Specification: Registry Editor - messages and names with registry names outside ASCII

**Feature Branch**: `129-regedt-wide-inserts`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: Found by the second verification of features 124-128 (an independent agent reading the
Registry Editor plug-in): "the question whether to create the target key is an empty Yes/No box
for a name with a non-ASCII letter". The maintainer asked for it to be fixed for 0.1.10.

## User Scenarios & Testing

### User Story 1 - A question about a key names the key (Priority: P1)

A user copies or moves a registry key to a target that does not exist yet. The program asks
whether to create the target key. With a target name that holds a letter such as `č`, `ř`, a
Greek or a Chinese letter, the question was a box with the buttons Yes and No and **no text** -
the user confirmed a write to the registry without seeing what for.

**Why this priority**: an unreadable confirmation before a change of the registry.

**Independent Test**: Copy a key to `...\Cíl řx\New` where `Cíl řx` does not exist; the box
reads `Target key "HKEY_CURRENT_USER\...\Cíl řx" doesn't exist. Do you want to create it?` in
the language of the program.

**Acceptance Scenarios**:

1. **Given** a key and a target whose parent does not exist and has an accented name, **When**
   the user confirms the Copy dialog, **Then** the question names the whole target key.
2. **Given** that question, **When** the user answers No, **Then** nothing is created.
3. **Given** a key copied into its own subkey, **When** the copy reaches it, **Then** the
   message names the key ("Can't copy a key to itself").

### User Story 2 - An error names the whole key (Priority: P2)

A registry key that cannot be opened or accessed is reported with its whole path and the reason
Windows gives. The text used to stop at the first letter outside Latin-1, the closing quote and
the rest of the name lost.

**Independent Test**: Change Directory to `reg:\HKEY_CURRENT_USER\Software\...\Klíč žluťoučký není`
(a key that does not exist): the box holds the whole name and the Windows reason.

### User Story 3 - A viewed value has its own copy (Priority: P2)

F3 on a value writes the value's data to a file in the program's disk cache, named after the
key's path. For keys whose names hold a letter outside Latin-1 that path was lost, so the value
`v` of one such key and the value `v` of another shared one file: opening the second replaced
the file the first viewer was showing.

**Independent Test**: two keys with accented names, each with a value `v` of different data; F3
on both, both viewers open: two different files, each viewer its own data.

### Edge Cases

- Names with letters of the Windows code page only up to U+00FF (`é`, `í`, `ü`) worked by
  accident before and must stay right; names in any other script must work the same.
- A name with a character outside the Basic Multilingual Plane (an emoji) is one character.
- The registry root (an empty key name) and ASCII names give exactly the texts and cache names
  they gave before.
- A text that cannot be composed (no memory): the question is not asked and nothing is created.
- English and every translation: the same sentences as before, only complete.

## Requirements

- **FR-001**: Every text of the Registry Editor that holds a registry name MUST show the whole
  name, whatever letters it has. The name is never cut.
- **FR-002**: The question whether to create a target key and the "can't copy / move a key to
  itself" message MUST name the key; when the text cannot be composed, the plug-in MUST NOT
  create or copy anything.
- **FR-003**: The errors "unable to open / access registry key" MUST hold the whole key path and
  the Windows reason, readable in every language.
- **FR-004**: The name a viewed value has in the disk cache MUST be different for values of
  different keys, for every name; for ASCII names it MUST be the name it was before.
- **FR-005**: The rule that composes these texts MUST exist once, without the C runtime's
  locale, and be covered by unit checks.
- **FR-006**: No new texts for translation; no change of the plug-in interface.

## Success Criteria

- **SC-001**: In an automated run in Czech and in English, the four situations above (question,
  self-copy message, open error, two viewed values) give the expected text or state in every
  row; the same run on 0.1.9 fails in those rows.
- **SC-002**: The situations with ASCII names behave as before (control rows).
- **SC-003**: After the user answers No / Cancel, the registry holds exactly the keys it held
  before.

## Assumptions

- The message boxes of the core show UTF-8 text (they do since feature 063).
- Other narrow compositions of the plug-in with code-page parts (`%s`) are not part of this
  change (the class of feature 127).
