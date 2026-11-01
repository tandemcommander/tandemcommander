# Feature Specification: UnCAB - a cabinet name with an unpaired surrogate no longer fails the whole cabinet

**Feature Branch**: `381-uncab-wtf8-name`
**Created**: 2026-11-01
**Status**: Draft
**Input**: Backlog item `uncab-wtf8-flagged-name-refused` - "UnCAB: one UTF-8 cabinet name with an
unpaired surrogate makes the whole cabinet fail". From backlog item uncab-wtf8-flagged-name-refused.

## Background (measured at bd7cc15e)

A cabinet (`.cab`) entry may say that its stored name is UTF-8 (the entry's "name is UTF" flag).
Windows allows a file name to hold an unpaired UTF-16 surrogate; a Windows packer that converts such
a name to UTF-8 writes the surrogate as its 3-byte form (WTF-8, the form the program itself uses for
such names since feature 066). The UnCAB plug-in checks a flagged name with a strict UTF-8 test,
which rejects that form, and a rejected name aborts the whole cabinet.

- Fixture: `probe/cab381.py` writes small stored cabinets with chosen name bytes (Windows'
  `expand.exe` lists and extracts its control cabinet). Each holds the case's flagged name
  (content `N1`) followed by a plain `c.txt` (content `C1`).
- Hidden-desktop probe `probe/cab381_probe.ps1` on the Debug build of HEAD
  (`probe/result_before.txt`): flagged `a<ED A0 80>b.txt` (lone U+D800) and `a<ED B0 80>b.txt`
  (lone U+DC00) - **Unpack extracts nothing** (not even `c.txt`), the cabinet is kept, and **Enter
  on the cabinet does not open it**; in both cases **no message at all** is shown. Control: flagged
  valid UTF-8 `a<U+00E9>.txt` lists and unpacks both files. Flagged `a<FF>b.txt` and
  `a<C0 80>b.txt` (not WTF-8) are refused the same silent way.
- Correction to the item: the item says the failure shows an "FDI error". It does not - the aborted
  cabinet ends as a user abort, for which the plug-in shows no message. That silence is a separate
  defect, recorded as its own backlog item, not part of this feature.

## Clarifications

### Session 2026-11-01

- Q: A continued entry (one that starts in the previous cabinet of a set) is reported without its
  flags, so its encoding is guessed from the bytes. Should that guess also take the WTF-8 form as
  UTF-8? → A: Yes. The item's Approach is to accept the WTF-8 form "in the probe", and the guess uses
  the same probe; it keeps the name of a continued entry equal to the name the same entry has in the
  cabinet where it starts. Bytes that are neither UTF-8 nor WTF-8 are still read in the code page as
  before. (autonomous run: item)
- Q: Should a refused (not even WTF-8) flagged name now show a message, or be skipped while the rest
  of the cabinet opens? → A: No - the item asks only that such a name "is still refused"; its
  behaviour stays exactly as today. The silent refusal is recorded as a new backlog item.
  (autonomous run: conservative)
- Q: Names that are not flagged (in the code page), and the next-cabinet / next-disk names of the
  cabinet header? → A: Unchanged - always read in the code page. (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open and unpack a cabinet holding a name with an unpaired surrogate (Priority: P1)

A user opens (Enter) or unpacks (Alt+F9) a cabinet one of whose entries is flagged UTF-8 and
carries an unpaired surrogate in the WTF-8 form. The cabinet opens, every entry is listed, and
unpacking creates every file - that entry under its exact name, with the surrogate.

**Why this priority**: today one such entry makes the whole cabinet unusable, silently.

**Independent Test**: probe rows `U-WTF8`, `U-WTF8L` (unpack) and `L-WTF8`, `L-WTF8L` (open).

**Acceptance Scenarios**:

1. **Given** a cabinet with flagged `a<U+D800>b.txt` (WTF-8 bytes) and `c.txt`, **When** the user
   unpacks it, **Then** both files exist in the target, `a<U+D800>b.txt` under exactly that name,
   with their contents, and no message is shown.
2. **Given** the same cabinet, **When** the user presses Enter on it, **Then** the panel shows the
   inside of the cabinet, with no message.
3. The same holds for a lone low surrogate (U+DC00).

---

### User Story 2 - Malformed flagged names stay refused, ordinary names unchanged (Priority: P2)

A flagged name that is neither UTF-8 nor WTF-8 is refused exactly as before; a valid UTF-8 name and
a code-page name behave exactly as before.

**Why this priority**: the fix must not turn malformed bytes into some other name (a name is never
guessed), and must not change any cabinet that works today.

**Independent Test**: probe rows `U-OK`, `L-OK` (control), `U-BAD`, `U-OVER`, `L-BAD` (refusal).

**Acceptance Scenarios**:

1. **Given** a cabinet with flagged `a<U+00E9>.txt`, **When** unpacked or opened, **Then** it works
   as before.
2. **Given** a cabinet with flagged `a<FF>b.txt` or `a<C0 80>b.txt`, **When** unpacked or opened,
   **Then** nothing is extracted and the cabinet does not open, as before.

### Edge Cases

- A WTF-8 sequence for a surrogate *pair* written as two 3-byte forms (CESU-8 style) decodes to two
  lone surrogates, exactly as the core's and the plug-in helpers' WTF-8 decoder reads it - the same
  name the program gives such bytes everywhere else.
- A name whose WTF-8 form does not fit the plug-in's name buffer is refused as before (never cut).
- An entry continued from the previous cabinet (no flags reported) with WTF-8 bytes: read as UTF-8
  (Clarification 1).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A flagged cabinet entry name that is valid WTF-8 (strict UTF-8, or UTF-8 whose 3-byte
  sequences may encode a lone surrogate) MUST be accepted byte for byte, so that the entry is listed
  and extracted under exactly that name.
- **FR-002**: A flagged name that is not valid WTF-8 MUST still be refused, with today's behaviour.
- **FR-003**: Names without the flag and the cabinet header's next-cabinet / next-disk names MUST be
  read as before (code page).
- **FR-004**: For an entry reported without flags (continued entry), bytes that are valid WTF-8 MUST
  be taken as UTF-8; other bytes are read in the code page as before.
- **FR-005**: The decision "is this byte string valid WTF-8" MUST use the same rule as the
  program's and the plug-in helpers' WTF-8 decoder, and be covered by unit checks.
- **FR-006**: `python tools/check_encoding.py --plugins` MUST no longer report `uncab/uncab.cpp`.

### Key Entities

- **Cabinet entry name**: the stored bytes plus the entry's "name is UTF" flag.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's 4 WTF-8 rows (unpack and open, high and low surrogate) go FAIL -> PASS.
- **SC-002**: The probe's 5 control and refusal rows stay PASS before and after.
- **SC-003**: The plug-in encoding scan reports one finding fewer, none in `uncab/uncab.cpp`.
- **SC-004**: Unit checks of the WTF-8 validity rule pass, including malformed inputs.

## Assumptions

- Assumption (autonomous run): which real CAB writers produce such names is not measured (the item
  says so too); the fixture writes the bytes directly, as the item's Approach allows.
- Assumption (autonomous run): multi-cabinet sets (continued entries) are not driven by the probe;
  FR-004 is covered by the unit checks of the shared rule and by reading.
- Out of scope: a message for a refused name (new backlog item); the sibling TAR / UnMIME items.
