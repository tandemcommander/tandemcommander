# Feature Specification: Registry Editor shows the "KEY" text correctly in every language

**Feature Branch**: `124-regedt-key-text`
**Created**: 2026-10-13
**Status**: Draft
**Input**: GitHub issue #3 (`issues/issue_3.md`): "in the Registry Editor plug-in the text shown for a registry key in the information line (Czech `KLÍČ`) is garbled in every language whose translation has non-ASCII letters; the 10-byte buffer is too small for a UTF-8 translation". Target release 0.1.10.

## What was measured before this specification was written

The report was reproduced on the released 0.1.9 build (Debug tree of the release commit, hidden
desktop, `probe/regkey_probe.ps1`, result `probe/regkey_result_before_v019.txt`, captures in
`probe/shots/before_*`), in English and in the eight shipped translations:

| Place | Result on 0.1.9 |
|-------|-----------------|
| Information line, a key focused (`name: KEY, date, time`) | **garbled** in Czech (`KL��`), German (`Schl�ssel`) and Slovak (`K���`); correct in the six languages whose word is plain ASCII |
| Information line, keys/values selected (`1 selected key`) | **garbled** in Czech, German, French, Hungarian and Slovak - *not in the report* |
| Size column of the Detailed view | **correct** in all nine languages - the report's "or the Size column" does not hold: the panel falls back to the code page for a text that is not valid UTF-8 |
| Column names of the Detailed view | correct (the core treats column names as code-page text, as it does for its own columns) |
| The plug-in's Find window, Size cell of a found key | **correct** in all nine languages - and the change proposed in the report would garble it (that window converts the same text from the code page) |

So the report is valid, its cause is right, and its proposed change is incomplete in two ways:
it leaves the selection text garbled and it would break the Find window.

**Added after the independent review of the first fix** (same day, re-measured with the probe's
new rows `DEFAULT`, `DATA`, `LONG`): the same information line is also garbled

- for the **`(Default)` value** - its translated name (`(Výchozí)`, `(Défaut)`,
  `(Alapértelmezett)`, `(Predvolený)`) is made up by the plug-in from code-page text: wrong in
  Czech, French, Hungarian and Slovak;
- for the **data of a text value** (`REG_SZ`, `REG_EXPAND_SZ`, `REG_MULTI_SZ`) with any
  non-ASCII letter - wrong in **all nine languages, English included**; a long text was cut
  after a fixed number of bytes.

They are the same defect in the same line, so they are part of this feature (User Story 4).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The information line names a key in my language (Priority: P1)

A user who runs the program in Czech, German, Slovak (or any language whose word for "key" has
an accented letter) browses the registry in a panel. With a key focused, the information line
under the panel reads `<name>: KLÍČ, <date>, <time>` - the word is readable, exactly as the
translator wrote it.

**Why this priority**: it is the reported defect and it is on screen all the time while
browsing the registry.

**Independent Test**: start the program in each shipped language, open
`reg:\HKEY_CURRENT_USER\Software\<test key>`, focus a subkey, read the information line.

**Acceptance Scenarios**:

1. **Given** the Czech language and a registry key focused in the panel, **When** the user looks at the information line, **Then** it reads `<name>: KLÍČ, <date>, <time>` with no replacement characters.
2. **Given** each of the nine shipped languages, **When** a key is focused, **Then** the information line holds that language's translation of "KEY" exactly.
3. **Given** the Detailed view in any shipped language, **When** the panel lists keys, **Then** the Size column still shows the translation of "KEY" exactly (no regression).

---

### User Story 2 - The selection text is readable (Priority: P1)

The same user selects one or more keys or values. The information line reads
`1 vybraný klíč` / `2 ausgewählte Schlüssel` - readable in every shipped language.

**Why this priority**: the same line, the same cause, found while measuring; fixing one half of
the line and leaving the other garbled would not close the report honestly.

**Independent Test**: select a key (Insert) in each shipped language and read the line.

**Acceptance Scenarios**:

1. **Given** Czech, German, French, Hungarian or Slovak, **When** one key is selected, **Then** the information line shows the translated "N selected key(s)" text without replacement characters.
2. **Given** values selected, or keys and values together, **When** the line is shown, **Then** the texts for values, for both, and the size prefix are readable as well.

---

### User Story 3 - The Find window keeps showing the word correctly (Priority: P2)

A user searches the registry with the plug-in's Find window. Found keys show the translated
word for "key" in the Size column, as they do today.

**Why this priority**: it works today; the story exists because the obvious fix breaks it.

**Independent Test**: search for a known key name in each language and read the Size cell of
the result row.

**Acceptance Scenarios**:

1. **Given** any shipped language, **When** the Find window lists a found key, **Then** its Size cell is exactly that language's translation of "KEY".

---

### User Story 4 - Values are readable too (Priority: P1)

The user focuses a value. The information line reads `<name>: <size>, <type>, <data>`: the
name of the unnamed value is the translated `(Default)`, and the data of a text value is shown
with its accented letters, in any language of the program.

**Why this priority**: found by the review in the same line; a registry is full of text values
with non-English text (paths, descriptions), and this part is wrong even in English.

**Independent Test**: a test key with an accented text value; focus `(Default)` and the value
in each shipped language and read the information line.

**Acceptance Scenarios**:

1. **Given** any shipped language, **When** the `(Default)` value is focused, **Then** the information line starts with that language's translation of `(Default)`.
2. **Given** a text value whose data is `příliš žluťoučký kůň`, **When** it is focused, **Then** the information line and the Data column show exactly that text.
3. **Given** a text value longer than the preview, **When** it is focused, **Then** the shown text ends with `...` after a whole letter.

---

### Edge Cases

- A translation of "KEY" longer than today's nine bytes (the German word takes ten bytes in the panel's encoding, non-Latin translations take three bytes a letter): the word is shown whole, never cut - also not in the middle of a letter.
- A translation that cannot be loaded or converted: the English word is shown rather than an empty or broken text.
- A Windows code page that lacks letters of the chosen language (a Spanish UI on a Central European Windows): the key text and the selection text show every letter; they no longer depend on the code page.
- Languages that are present in the sources but not shipped (Russian, Ukrainian, Simplified Chinese): their words fit and are shown whole once those languages are enabled.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The information line for a focused registry key MUST show the current language's translation of "KEY" exactly, in every shipped language.
- **FR-002**: The Size column of a registry key in the panel MUST show the same word exactly, in every shipped language (it must stay correct, and must no longer depend on the fallback for invalid text).
- **FR-003**: The information line for a selection (keys, values, both, with the size prefix) MUST show the translated text exactly, in every shipped language.
- **FR-004**: The Size cell of a found key in the plug-in's Find window MUST keep showing the translation of "KEY" exactly.
- **FR-005**: The word for "KEY" MUST never be cut: every translation present in the repository (shipped or not) MUST fit whole; a text that would not fit is replaced by the English word, never shortened.
- **FR-006**: The texts of FR-001 to FR-003 MUST NOT depend on the Windows code page of the machine.
- **FR-008**: The name shown for the unnamed value MUST be the current language's translation of `(Default)` exactly - in the panel, in the information line and in the overwrite question of a copy or move.
- **FR-009**: The data preview of a text value MUST show the value's letters exactly (any script), in the Data column and in the information line; a text longer than the preview MUST end with `...` placed after a whole character.
- **FR-010**: The date and time of a key MUST be shown as the user's regional format gives them, independent of the code page.
- **FR-007**: Nothing else in the plug-in's panel may change: column names, the type names, the numeric and binary data previews, value sizes, sorting by the Size column.

### Key Entities

- **Key text**: the translated word shown instead of a size for a registry key; one per language; used by the panel (column and information line) and by the Find window.
- **Selection text**: the translated plural-aware sentence shown for selected items.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In all nine shipped languages the information line of a focused key holds the translation of "KEY" with zero replacement characters (today: wrong in three).
- **SC-002**: In all nine shipped languages the selection text is readable with zero replacement characters (today: wrong in five).
- **SC-006**: In all nine shipped languages the `(Default)` value and an accented text value are shown exactly in the information line (today: the name wrong in four, the data wrong in nine).
- **SC-003**: In all nine shipped languages the Size column and the Find window's Size cell show the same word as before the change (zero regressions).
- **SC-004**: Every translation of "KEY" present in the repository (eleven languages plus English) is shown whole.
- **SC-005**: The program starts, opens the registry panel and closes cleanly in every shipped language (no error window, no crash report).

## Assumptions

- Column names stay as they are: the core treats a plug-in's column names as code-page text, exactly like its own column names, and they are shown correctly wherever the language fits the Windows code page. Making column names independent of the code page is a core-wide matter, not part of this report.
- The message boxes of the plug-in that put a registry name into a translated sentence belong to the class of GitHub issue #7 and are examined there, not here.
- "Shipped languages" are English plus the languages enabled in `translations/languages.cfg` (eight on 2026-10-13).
- The fix is released in 0.1.10.
