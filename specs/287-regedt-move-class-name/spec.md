# Feature Specification: Registry Editor - Move of a key and the "class name differs" question

**Feature Branch**: `287-regedt-move-class-name`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item `regedit-key-name-buffer-size-and-move-rows` - "Registry Editor: fs3.cpp passes a third of the key-name buffer size"; Expected: "`fs3.cpp:218` passes the real buffer size; a probe drives Move of a key and the 'class name differs' question with a Czech key name." From backlog item regedit-key-name-buffer-size-and-move-rows.

## Measured at 243174e4 (before this feature)

- **The buffer size is already right.** Feature 131 (commit d041841a,
  `specs/131-plugin-defect-batch/items/regedt.md` §8) changed
  `CPluginFSInterface::AcceptChangeOnPathNotification` to pass the sizes of its buffers
  (`WStrToU8(key, sizeof(key), ...)`, `SalPrintf(path2, sizeof(path2), ...)`, `path1` as large
  as `path2`). Nothing is left to change there; this feature only records it.
- **The "class name differs" question can never appear.** When a key is copied or moved into a
  key that already holds a key of the same name, the target key is opened as it is and keeps its
  own *class name* (a rarely used attribute of a registry key). The Registry Editor means to warn
  ("Class name of the key cannot be copied to the target key. Do you wish to continue?",
  Yes / All / Cancel), but it reads the target's class name from the **source** key, so the two
  always compare equal and the contents are merged silently. Upstream since the first Open
  Salamander commit.
- **Move of a key was never driven by a probe** with a name that holds letters outside ASCII
  (feature 129 drove only Copy: the "create the target?" question and the copy-onto-itself
  message).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Warned before a key's class name is lost (Priority: P1)

A user copies (F5) or moves (F6) a registry key, for example `Klíč žluťoučký`, into a key that
already holds a key of the same name with a different class name. Before anything is copied the
Registry Editor asks whether to continue, naming the key; Cancel stops the operation with nothing
copied and nothing deleted, Yes continues (the target keeps its own class name), All continues and
does not ask again for the rest of the operation.

**Why this priority**: it is the only defect left in the item - a warning the program was written
to give never appears, and with Move the source key is deleted afterwards.

**Independent Test**: a fixture with two keys of the same Czech name and different class names;
Copy and Move one onto the other on the hidden desktop; read the question and the registry after
each answer.

**Acceptance Scenarios**:

1. **Given** source key `Klíč žluťoučký` (class A, a value `v`) and a target key holding
   `Klíč žluťoučký` with class B and no values, **When** the user copies the source key into the
   target key and answers Cancel, **Then** the question named the key in full and showed the
   question text of the user's language, and the target key holds no value `v`.
2. **Given** the same fixture, **When** the user moves the source key and answers Cancel,
   **Then** the source key with its value is still there and the target holds no value `v`.
3. **Given** the same fixture, **When** the user moves the source key and answers Yes, **Then**
   the target holds the value `v`, the source key is gone, and the target keeps class B.
4. **Given** the target holds a key of the same name with the **same** class name, **When** the
   user copies the key, **Then** no question is asked and the contents are copied.
5. **Given** the target key does not hold a key of that name, **When** the user copies the key,
   **Then** no question is asked and the new key gets the source's class name.

---

### User Story 2 - Move of a key with a Czech name (Priority: P2)

A user moves (F6) a key with a Czech name and a subkey into another key, and tries to move a key
into its own subkey.

**Why this priority**: the item's other gap - Move shares the code with Copy but was never driven.

**Independent Test**: on the hidden desktop, F6 of the key; the registry after the move; F6 into
its own subkey and the message text.

**Acceptance Scenarios**:

1. **Given** key `Klíč žluťoučký` with a value `v` and a subkey `podklíč`, **When** the user moves
   it into an existing key `Cíl řx`, **Then** `Cíl řx\Klíč žluťoučký` holds `v` and `podklíč`, and
   the source key is gone.
2. **Given** the same key, **When** the user moves it into its own subkey and answers Cancel,
   **Then** the message names the key and says it cannot be moved into itself (the text of the
   user's language), and nothing is created, moved or deleted.

### Edge Cases

- The target's class name cannot be read (access denied): the existing error box for the key is
  shown; Cancel stops the operation before anything is copied - the same handling the source key
  already has.
- Class names that differ only in letter case count as equal (the comparison already used).
- "All" covers the rest of the same operation only; the next operation asks again.
- A Move answered Yes deletes the source after its contents are copied - exactly as a Move
  without a class name difference; the class name the user was warned about is the only loss.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a key is copied or moved into an existing key of the same name, the class name
  compared with the source's MUST be the class name of the target key.
- **FR-002**: When the class names differ, the question MUST be asked before any value or subkey
  is copied, MUST name the source key in full (letters outside ASCII intact), and MUST show the
  existing question text of the user's language.
- **FR-003**: Cancel MUST stop the operation with nothing copied for that key and nothing deleted
  (for Move the source stays whole); Yes MUST continue; All MUST continue and suppress the question
  for the rest of the operation.
- **FR-004**: Copy or Move into a target where the key does not exist, or exists with an equal
  class name, MUST behave as before (no question).
- **FR-005**: The record of the item MUST state that the buffer size at
  `AcceptChangeOnPathNotification` was fixed by feature 131 (no change in this feature).
- **FR-006**: A hidden-desktop probe MUST drive Move of a key with a Czech name (result, source
  removed, the move-into-itself message) and the class-name question (Copy + Cancel, Move + Cancel,
  Move + Yes, equal class names, new target), in Czech and in English, and MUST fail on the build
  without the fix for the rows that expect the question.
- **FR-007**: No new or changed UI strings, no change of the plug-in interface or of what is stored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the build before the fix the probe's question rows FAIL (no question; the value is
  copied); on the fixed build every row PASSes, in Czech and in English.
- **SC-002**: In every Cancel row the registry fixture is unchanged after the answer (same keys,
  same values).
- **SC-003**: Every probe run ends with exit code 0 of the program, no stray window, no crash
  report, the fixture removed and the product's registry key restored identical (SHA-256).
- **SC-004**: The probes of feature 129 still pass on the fixed build.

## Assumptions

- Assumption (autonomous run): reading the target's class name from the target key is within the
  item's scope - the item asks for the question to be driven, and at HEAD it cannot appear; the
  question, its text and its buttons already exist, so the change only makes the written behaviour
  happen (no new string, no stored data, no interface).
- Assumption (autonomous run): the probe sets class names through the Windows registry API in its
  own fixture key under `HKCU\Software`; only that key is created and removed.
- Assumption (autonomous run): the long-name error box of Copy/Move (key name over the limit) is
  not part of the item and is not driven.
