# Feature Specification: Plug-in messages with names and error texts are readable in every language

**Feature Branch**: `130-plugin-mixed-templates`
**Created**: 2026-10-13
**Status**: Implemented (FTP is a separate step)
**Input**: The follow-up of GitHub issue #7 that feature 127 left to the plug-ins
(`specs/NEXT-WORK.md`, section D, item 2 of "Found by the second verification"). The maintainer
asked for it: "Mixed templates in the plug-ins ... the same defect as #7, only outside the core,
so in a non-English language messages with a file name are still shown garbled."

## User Scenarios & Testing

### User Story 1 - A plug-in's message names the file readably (Priority: P1)

A user of a translated version (Czech, German, ...) works with a file or archive whose name has
a letter outside ASCII. A plug-in tells or asks something about it - "Archive X is OK",
"File X already exists. Overwrite?", "Unable to open X" - and the name in that message reads as
a row of wrong letters (`PĹ™Ă­liĹˇ`), or, in another message of the same plug-in, reads right
only because that sentence happens to have no accented letter.

**Why this priority**: a question the user must answer names the wrong thing; this is what
issue #7 reported for the core, still true in the plug-ins.

**Independent Test**: the program in Czech, a file `Příliš žluťoučký kůň.zip`; the plug-in's
command that reports about it; the message holds the translated sentence and the name exactly.

**Acceptance Scenarios**:

1. **Given** a translated version and a name with accented letters, **When** a plug-in shows a
   message that holds the name, **Then** the sentence and the name are both readable.
2. **Given** the same in English, **Then** the text is byte for byte what it was.
3. **Given** a message without any name, **Then** it is what it was.

### User Story 2 - A plug-in's message shows the Windows reason readably (Priority: P2)

The reason Windows gives for a failure (`Přístup byl odepřen.`) inside a plug-in's translated
sentence is readable, as it is in the core since feature 127.

### Edge Cases

- A message whose pieces are all in the code page and whose window shows the code page is right
  today and must stay untouched.
- A window that can only show the code page (an `A` control) cannot show such a name at all:
  the template alone is not enough there - it needs a wide window text, or it is recorded.
- A long name near the end of a fixed buffer: the text may be shortened, at a whole character;
  a path or name that is *used* (not shown) is never cut.
- FTP: names come from the server in the server's encoding - what is right there is measured
  first and may be a separate step.

## Requirements

- **FR-001**: In every enabled plug-in, a message, question or title composed from a translated
  sentence and a file name, path, or Windows error text MUST show both readably in every shipped
  language, wherever the window that shows it can.
- **FR-002**: When a sentence becomes UTF-8, every other piece of it and the place that shows
  it MUST be UTF-8 too (the reverse rule of feature 127) - no message that was readable may
  become unreadable.
- **FR-003**: The way a plug-in gets a translated text as UTF-8 MUST exist once, shared, safe
  from any thread, and be covered by unit checks.
- **FR-004**: Places that are not changed (unreachable, right as they are, or needing a larger
  change) MUST be listed with the reason, per plug-in.
- **FR-005**: No new texts for translation; no change of the plug-in interface.

## Success Criteria

- **SC-001**: An automated run in Czech drives at least one changed message in each plug-in
  that has a reachable one; each row passes on the new build and the same row fails on 0.1.9.
- **SC-002**: The same rows in English give the same text on both builds.
- **SC-003**: Every plug-in has a record that lists each composition and its verdict.

## Assumptions

- The core's message boxes show a text that is valid UTF-8 as UTF-8 and any other through the
  code page (`msgbox.cpp`; feature 063), so a code-page message without a name keeps working.
- The plug-ins receive names in UTF-8 (interface 104) and `GetErrorText` gives UTF-8.
