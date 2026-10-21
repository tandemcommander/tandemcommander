# Feature Specification: "*.ext" masks match accented extensions by whole letters

**Feature Branch**: `283-mask-code-page-fold`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item mask-matcher-code-page-fold (backlog/items/mask-matcher-code-page-fold/desc.md) - implement exactly what it describes. From backlog item mask-matcher-code-page-fold.

## Background

A file mask is matched against a name by the mask matcher. For most masks the matcher compares
whole letters (case-insensitive, canonically equivalent spellings equal - feature 004). A mask of
the form `*.xxx` (an extension without wildcards) takes a shortcut instead: the name's extension is
compared with the mask's extension byte by byte through the code page's lower-case table - also
when the extension holds letters outside ASCII, whose UTF-8 bytes the table does not understand.
With ten or more such masks in one group the shortcut also files them in a table keyed by the same
byte folding.

Measured at cb0d80f5 (hidden-desktop probe `mask283_probe.ps1`, ACP 1250, Convert LF -> CRLF of the
focused file with a mask):
- `A.ČTX` with `*.čtx`: "There is no file that matches the specified file mask" - the other case
  of an accented letter is missed; the same with ten ASCII masks in front (the table);
- `|*.čtx` (everything except `.čtx`) **converted** `A.ČTX`;
- `*.ĥ` **converted** `x.Ĺ` - a different letter (their second UTF-8 bytes fold together in
  CP1250) - also through the table;
- the decomposed spelling `A.C` + U+030C + `TX` is not matched by `*.čtx`;
- controls `b.čtx` / `*.čtx`, `c.TXT` / `*.txt` (also through the table) matched, `c.TXT` / `*.doc`
  did not.

The other byte-table sites the item names are not reachable with UTF-8 names (measured): the
general matcher's byte loop runs only for an ASCII name and an ASCII mask (or text that is not
UTF-8), the quick-search byte loop only for an ASCII name and an ASCII quick-search text.

The same mask group serves Select / Unselect, the panel filter, Find, Convert, Copy / Move masks,
Recycle Bin masks, highlighting, thumbnails, archive associations, viewer masks and the plug-in
mask service - a wrong answer selects, converts, copies, recycles or deletes the wrong files.

## Clarifications

### Session 2026-10-21

- Q: "The file system's case rule" or the matcher's existing letter rule for accented masks? → A: the matcher's existing rule for non-ASCII masks (whole letters, case-insensitive per character, canonically equivalent spellings equal) - the same rule every other mask of the group already uses, so a `*.ext` mask answers exactly as `*.ext*`-style masks do; for accented letters (Č/č, Ĺ/ĺ, Cyrillic, Greek) it agrees with the file system's rule; changing the matcher's rule for all masks is not part of this item (autonomous run: conservative - 068 recorded that rule as correct; 092 left masks outside the identity rule, masks are searching)
- Q: Keep the shortcut for ASCII extensions? → A: yes, byte for byte unchanged - every mask and name made of ASCII only matches exactly as before (autonomous run: conservative / constitution principle II)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An accented extension mask finds the other case (Priority: P1)

A user selects, filters, finds or converts files with a mask like `*.čtx`; files named `A.ČTX`
(or written with a decomposed accent) are matched like `b.čtx`.

**Why this priority**: the defect the item names; a miss leaves files out of an operation without
a word ("no file matches").

**Independent Test**: probe rows `miss`, `miss-hash`, `nfd` (Convert of the focused file).

**Acceptance Scenarios**:

1. **Given** a folder with `A.ČTX`, **When** Convert runs with the mask `*.čtx`, **Then** the file is converted.
2. **Given** the same, **When** the mask is ten ASCII `*.aNN` masks followed by `*.čtx`, **Then** the file is converted.
3. **Given** `A.C`+U+030C+`TX`, **When** the mask is `*.čtx`, **Then** the file is converted.

### User Story 2 - A mask never acts on a file it does not match (Priority: P1)

A user's mask `*.ĥ` must not select, convert, copy or delete `x.Ĺ`; an exclusion `|*.čtx` must
exclude `A.ČTX`.

**Why this priority**: acting on the wrong file changes user data (Convert rewrote a file the mask
does not match; Recycle Bin masks decide between recycling and deleting).

**Independent Test**: probe rows `false`, `false-hash`, `miss-excl`.

**Acceptance Scenarios**:

1. **Given** `x.Ĺ` on ACP 1250, **When** Convert runs with `*.ĥ` (alone or after ten ASCII masks), **Then** the file is unchanged.
2. **Given** `A.ČTX`, **When** Convert runs with `|*.čtx`, **Then** the file is unchanged.

### User Story 3 - ASCII masks behave as before (Priority: P2)

**Independent Test**: probe rows `same`, `ascii`, `ascii-hash`, `ascii-no`; saltests checks of the
decision.

**Acceptance Scenarios**:

1. **Given** `c.TXT`, **When** the mask is `*.txt` (alone or among eleven), **Then** it is converted; with `*.doc` it is not.

### Edge Cases

- An extension mask mixing ASCII and accented letters (`*.tčx`) - matched by whole letters.
- An ASCII extension mask against an accented extension (`*.ctx` vs `x.čtx`) - no match, as before.
- Ten or more ASCII extension masks plus accented ones - the ASCII ones keep the table, the accented ones are matched by letters; the answer does not depend on how many masks there are.
- A name or mask that is not valid UTF-8 (transitional) - the matcher's existing byte fallback, as before.
- Names starting with a dot (`.čtx`) and names with several dots (`a.b.čtx`) - same answer as before for ASCII, the letter rule for accented.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A mask `*.xxx` whose extension contains a character outside ASCII MUST be matched by the same whole-letter rule as every other non-ASCII mask (include list, exclusion list after `|`, and regardless of how many masks the group has).
- **FR-002**: A mask group MUST give the same answer for a name whether or not it holds ten or more extension masks.
- **FR-003**: Masks and names made of ASCII only MUST match exactly as before (byte-for-byte the same decisions).
- **FR-004**: The decision which masks may use the byte shortcut MUST be a pure rule checked by saltests, including checks that the old byte folding confused or missed the measured pairs and that the rule sends them to the letter matcher.
- **FR-005**: The sites the item names that stay byte-based (the general matcher's ASCII loop, the quick-search ASCII loop) MUST be documented as unreachable for UTF-8 names (fix-log), with their guarding conditions unchanged.

### Key Entities

- **Mask group**: a list of include masks, optionally `|` and exclude masks; `*.xxx` masks may take a shortcut.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `mask283_probe.ps1`: 6 FAIL -> 0 FAIL, the 4 controls still PASS.
- **SC-002**: saltests: the new checks pass, the count rises, 0 failed.
- **SC-003**: No ASCII-only mask decision changes (saltests differential checks against the old shortcut for ASCII extensions).

## Assumptions

- Assumption (autonomous run): the letter rule is the matcher's existing one (`AgreeMask`: NFC + per-character lower case); special characters where it differs from the file system's rule (Kelvin sign, dotted capital I) keep the matcher's existing behaviour - not named by the item.
- Assumption (autonomous run): an ASCII extension mask compared with an accented extension keeps the byte comparison; continuation bytes of UTF-8 never fold to ASCII, so it cannot match (checked by saltests over the process's table).
- No UI string, registry value, plug-in interface or installer change.
