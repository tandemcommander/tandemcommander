# Feature Specification: Translated sentences with names and error texts are readable

**Feature Branch**: `127-mixed-template-texts`
**Created**: 2026-10-13
**Status**: Draft
**Input**: GitHub issue #7 (`issues/issue_7.md`): "Several places compose a translated template with UTF-8 text (file names, paths, the text of a Windows error). In a translation whose template has non-ASCII letters the composed text is not valid UTF-8 and is drawn as code page: the translated part looks right, the names and error texts are garbage. Find Files status line, Find Files log, a list of message boxes." Target release 0.1.10.

## What was measured before this specification was written

Probe `probe/mixed_probe.ps1` on the released 0.1.9, Czech language, hidden desktop
(`probe/mixed_result_before_v019.txt`, captures in `probe/shots/before_*`):

| Case of the report | Expected | 0.1.9 shows |
|---|---|---|
| Find Files log, a folder that cannot be listed | `Chyba při čtení adresáře: (5) Přístup byl odepřen.` | `Chyba při čtení adresáře: (5) PĹ™Ă­stup byl odepĹ™en.` (read from the list exactly) - **confirmed** |
| Find Files status line during a content search | `Vyhledávání: ...\Příliš žluťoučký kůň 01.bin` | the prefix right, the file name garbage - **confirmed** |
| message box of Copy for a folder that cannot be read | `Chyba při čtení adresáře "<path>".` + `(5) Přístup byl odepřen.` | the template right, the Windows error text `PĹ™Ă­stup byl odepĹ™en.` - **confirmed** |

The report's analysis is right, and its list of 21 places is exactly what the project's
encoding guard reports once it is taught the two things the report names (the text of a
Windows error is UTF-8; a text can reach a message box through a parameter structure or the
Find log).

**The class is larger than the report.** An inventory of every composition of a translated
template with a name, path or error text in the main program (46 candidates, each sink read)
and a search for compositions the guard cannot see found, besides the report's 21 + 4 + 2:

- the Find window's **title** with a non-ASCII mask (Czech, Slovak, Hungarian);
- five more **message boxes and dialog texts** (viewer / editor command too long, a path not
  found in an archive, a UNC name that cannot be made, a junction's target in Properties, the
  title sentence of Copy / Move);
- the **viewer / editor menu** items that name an external command;
- and one that is not a display matter: the name the program **invents for a copy in the same
  folder** ("X - Copy") takes the translated word as code-page bytes - in Slovak (`Kópia`) and
  Hungarian the new file's name is built from a text that is not valid in the program's name
  encoding;
- in the Registry Editor plug-in, five messages that put a registry name or a Windows error
  text into a translated sentence (promised to this feature by feature 124).

Some candidates are **right as they are** and must not be "fixed" (both sides are code-page
text: font names, plug-in file names in the start-up progress), and two need a coordinated
change with plug-ins (recorded, not done here).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find Files tells me what it is doing and what went wrong (Priority: P1)

A user of a translated version searches a folder tree. The status line shows the file being
searched with its real name; the log names a folder that could not be read and gives the
reason in readable words; the window's title shows the mask that was typed.

**Why this priority**: the first two cases of the report; visible in every search in a
non-English language.

**Independent Test**: in Czech, search a folder holding files with accented names and a
subfolder that cannot be listed; read the status line while it searches and the log afterwards.

**Acceptance Scenarios**:

1. **Given** Czech and a file `Příliš žluťoučký kůň 01.bin` being searched, **When** the status line is shown, **Then** it reads `Vyhledávání: <path>\Příliš žluťoučký kůň 01.bin`.
2. **Given** a subfolder that cannot be listed, **When** the log is opened, **Then** its row reads `Chyba při čtení adresáře: (5) Přístup byl odepřen.` exactly.
3. **Given** a path longer than the status line can hold, **When** it is shown, **Then** it is shortened at a whole character and stays readable.
4. **Given** a mask with accented letters, **When** the search runs, **Then** the Find window's title shows the mask as typed.

---

### User Story 2 - Error and question boxes name files and reasons readably (Priority: P1)

Whenever the program reports a problem with a file, folder, command or drive in a translated
sentence, the name and the reason given by Windows are readable - not only the sentence.

**Why this priority**: the third case of the report; an error message that cannot be read is
an error message that does not help.

**Independent Test**: in Czech, copy a folder that holds a subfolder which cannot be read; the
error box names the folder and gives `Přístup byl odepřen.`.

**Acceptance Scenarios**:

1. **Given** Czech and a folder that cannot be read during Copy, **When** the box appears, **Then** the path and the Windows error text are shown exactly.
2. **Given** each place listed in the plan (the report's 21 + 4 and the additional ones), **When** its text is composed in any shipped language, **Then** the whole text is valid in the program's text encoding.
3. **Given** a text too long for its box, **When** it is shortened, **Then** it ends at a whole character.

---

### User Story 3 - A copy in the same folder gets a correctly spelled name (Priority: P1)

A Slovak or Hungarian user copies a file into the folder it is in and lets the program choose
the new name. The name contains the translated word for "copy" spelled correctly (`Kópia`).

**Why this priority**: it is a file name on disk, not only a display.

**Independent Test**: in Slovak, copy a file onto its own folder; read the new file's name
from the disk.

**Acceptance Scenarios**:

1. **Given** Slovak, **When** `a.txt` is copied into its own folder, **Then** the new file is named with the word `Kópia`, exactly as the translation spells it.
2. **Given** English, **When** the same is done, **Then** the name is what it was before the change.

---

### User Story 4 - Registry Editor messages are readable (Priority: P2)

Questions and errors of the Registry Editor that name a key or value, or give a Windows
reason, are readable in translated versions.

**Why this priority**: the same class in one plug-in, handed over by feature 124.

**Independent Test**: in Czech, delete a non-empty key with an accented name; the question
names the key readably.

**Acceptance Scenarios**:

1. **Given** Czech and a non-empty key `Příliš žluťoučký`, **When** it is deleted, **Then** the confirmation names it exactly.

---

### User Story 5 - The guard knows this class (Priority: P2)

A developer who adds such a composition is told by the build's encoding guard.

**Independent Test**: the guard reports the places before the fix and nothing after it; a
deliberately re-broken line is reported.

**Acceptance Scenarios**:

1. **Given** the code before the fix, **When** the guard runs, **Then** it reports the report's 21 places and the one allowed exception.
2. **Given** the fixed code, **When** the guard runs, **Then** it reports nothing.

---

### Edge Cases

- English: every text is unchanged (templates are plain ASCII).
- Texts where **both** parts are code-page text by design (a font name from the system, a plug-in's file name during start-up): unchanged - converting only the template would break them.
- A translated template much longer than the English one (three bytes a letter in some scripts): the text is not written past its buffer; if it must be shortened it is cut at a whole character.
- Many translated texts loaded in one go: a text is never replaced by "ERROR LOADING STRING" because the loader's internal space ran out.
- Languages present but not shipped (Russian, Ukrainian, Chinese): templates are entirely non-ASCII there - the same rules hold.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Find Files status line MUST show the searched file's path and the duplicate-search messages exactly, in every shipped language; a path that does not fit MUST be shortened at a whole character.
- **FR-002**: Every Find Files log row MUST show its text exactly (template and Windows error text).
- **FR-003**: The Find window's title MUST show the typed mask exactly.
- **FR-004**: Every message box, dialog text and menu item listed in the plan MUST show the names, paths, commands and Windows error texts it contains exactly, in every shipped language.
- **FR-005**: The automatically chosen name of a copy in the same folder MUST contain the translation's word spelled exactly.
- **FR-006**: The Registry Editor's messages listed in the plan MUST show registry names and Windows error texts exactly.
- **FR-007**: Texts whose parts are both code-page text by design MUST stay as they are.
- **FR-008**: No composed text may be written past its buffer; a text shortened for display MUST end at a whole character.
- **FR-009**: Loading a translated text MUST NOT fail because of the position of the loader's internal buffer.
- **FR-010**: The encoding guard MUST report this class (a name or a Windows error text in a code-page template handed to a message box, a message-box parameter structure or the Find log) and MUST pass on the fixed code.
- **FR-011**: English texts and behaviour MUST be unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The three cases of the report read correctly in Czech (today: all three wrong).
- **SC-002**: The guard reports 0 findings on the fixed code (22 before, one of them an allowed exception).
- **SC-003**: In Slovak the copy's new name on disk contains `Kópia` exactly.
- **SC-004**: The program builds and all unit tests pass; the probe's rows pass in Czech and nothing changes in English.

## Assumptions

- The other plug-ins (FTP alone has 86 such compositions and its own conventions for server texts) are **not** part of this feature; the guard does not scan plug-ins. Recorded for later.
- Two places of the main program hand a composed text to plug-ins that wrap it in their own code-page sentences (the common "file / directory" description of plug-in file systems; folder-creation errors used by ZIP). Changing only the program's half would make them worse; they need one change with the plug-ins and are recorded, not done.
- The reconnect dialog texts that only run before Windows 7 stay as they are.
- No new or changed translation texts.
- The fix is released in 0.1.10.
