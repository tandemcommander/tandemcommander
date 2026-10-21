# Feature Specification: Registry Editor - Copy / Move of a key onto itself through another root name

**Feature Branch**: `292-regedt-alias-move-self`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item `registry-editor-move-of-a-key-onto-itself-through-hkey-users` - "Registry Editor: Move of a key onto itself through HKEY_USERS deletes the key"; Expected: "A Move or Copy whose target is the source key itself (or lies inside it) under another root name is refused like the same path under the same root, and nothing is deleted. The decision goes by the key's identity, not by its name." From backlog item registry-editor-move-of-a-key-onto-itself-through-hkey-users.

## Measured at 9781daee (before this feature)

Probe `probe/alias292_probe.ps1 -Expect before` on the Debug x64 build of `main` (hidden desktop;
`probe/alias292_before.txt`): 18 PASS / 9 FAIL.

- **Move onto itself through `HKEY_USERS\<own SID>` deletes the key.** F6 of
  `HKEY_CURRENT_USER\Software\TcProbe292\Zdroj\<K>` into `\HKEY_USERS\<own SID>\Software\TcProbe292\Zdroj\`
  asks "Overwrite file ... With file ..." naming two different paths; answered *All*, the key `<K>`
  and its subkey are gone - there is no other copy (row ALIASMOVE).
- **The same for a value.** F6 of the value `v` of `<K>` into the `HKEY_USERS` name of `<K>`
  itself, answered *All*: the value is gone (ALIASVALUE).
- **The same through `HKEY_CLASSES_ROOT`.** F6 of `HKCU\Software\Classes\TcProbe292\Zdroj\<K>` into
  `\HKEY_CLASSES_ROOT\TcProbe292\Zdroj\`, answered *All*: `<K>` is gone (HKCRMOVE).
- **Copy onto itself** asks to overwrite instead of refusing (the data stays) (ALIASCOPY).
- **Move into its own subkey** through `HKEY_USERS` is not refused: the key is copied into itself
  many levels deep until opening a key fails (error 87) (ALIASINTO).
- The same operations under one root name are refused as they should be (MOVESELF, SAMEMOVE); a
  rename and a move to another key through `HKEY_USERS` work (ALIASRENAME, ALIASOTHER).
- What the registry reports for an opened key (its full internal name) is the same for
  `HKCU\Software` and `HKEY_USERS\<SID>\Software`; `HKEY_CURRENT_CONFIG\Software` reports the
  hardware-profile key under `HKLM\SYSTEM\ControlSet001` it links to; `HKEY_CLASSES_ROOT\.txt`
  reports the key under the user's classes it resolves to. A root itself (an empty key path)
  cannot be asked.

## Clarifications

### Session 2026-10-21

- Q: Which root names count as "another name of the same key"? → A: all of them - the decision compares the identity the registry reports for the keys, so `HKEY_USERS\<SID>` / `HKEY_CURRENT_USER`, `HKEY_CURRENT_CONFIG` and any registry link (for example `CurrentControlSet`) are covered without a list of aliases (autonomous run: item - "by the key's identity, not by its name")
- Q: `HKEY_CLASSES_ROOT` is a merged view of the user's and the machine's classes - which key is a path under it? → A: it is treated as possibly being either of the two (and the key it resolves to): the operation is refused when any of them is the source key or lies inside it (autonomous run: conservative - refuses rather than guesses; a rare operation between the merged view and one of its halves may be refused although it would have reached the other half)
- Q: What happens when the identity of a key cannot be established (the key cannot be opened)? → A: the operation does not go on for that key: the existing "Unable to open a registry key" error with Retry / Skip / Skip All / Cancel is shown, as the copy itself would show it (autonomous run: rule - a "safe to delete?" check fails closed, CLAUDE.md 098)
- Q: Which messages are shown? → A: exactly the existing ones of the same-root case - "Can't move/copy key or value to itself." for a target folder that is the source folder, "Name: <key> Error: Can't move/copy a key to itself." for a target inside the key; no new UI text (autonomous run: item - "refused like the same path under the same root")
- Q: With several keys or values selected and a target folder that is, by identity, the panel's own key, is the whole operation refused or only some items? → A: the whole operation, before anything is copied, exactly as under one root name today (back to the target dialog); a target inside one selected key refuses only that key (OK = skip it, Cancel = stop) (autonomous run: item - "refused like the same path under the same root")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A key moved onto itself under another root name is not lost (Priority: P1)

A user in the Registry Editor moves (F6) a key, or a value, into the key that already holds it,
written with another root name - for example a key under `HKEY_CURRENT_USER` into the same key
written under `HKEY_USERS\<the user's SID>`, or a key under `HKCU\Software\Classes` into the same
key under `HKEY_CLASSES_ROOT`. The Registry Editor refuses exactly as it refuses the same path
under the same root name, and the key or value is still there.

**Why this priority**: today the key (with all its subkeys) or the value is deleted and has no
other copy - data loss after a question that does not reveal it.

**Independent Test**: the hidden-desktop probe drives F6 with the aliased target, answers every
question with *All*, and compares the registry before and after.

**Acceptance Scenarios**:

1. **Given** `HKCU\Software\TcProbe292\Zdroj\<K>` with a value and a subkey, **When** the user moves
   `<K>` into `\HKEY_USERS\<own SID>\Software\TcProbe292\Zdroj\`, **Then** the message "Can't move
   key or value to itself." appears and the registry is unchanged.
2. **Given** the value `v` of `<K>`, **When** the user moves it into the `HKEY_USERS` name of `<K>`,
   **Then** the same message appears and `v` keeps its data.
3. **Given** `HKCU\Software\Classes\TcProbe292\Zdroj\<K>`, **When** the user moves `<K>` into
   `\HKEY_CLASSES_ROOT\TcProbe292\Zdroj\`, **Then** the same message appears and the registry is
   unchanged.

---

### User Story 2 - Copy onto itself and Move into itself are refused too (Priority: P2)

Copy (F5) onto itself under another root name is refused like under the same root name, and Move
or Copy of a key into one of its own subkeys under another root name is refused with the message
that names the key.

**Why this priority**: no data is deleted today, but Copy asks a misleading overwrite question and
Move into itself fills the key with copies of itself many levels deep.

**Independent Test**: probe rows ALIASCOPY and ALIASINTO.

**Acceptance Scenarios**:

1. **Given** `<K>`, **When** the user copies it into the `HKEY_USERS` name of its own parent,
   **Then** "Can't copy key or value to itself." appears and nothing changes.
2. **Given** `<K>` with the subkey `<P>`, **When** the user moves `<K>` into the `HKEY_USERS` name
   of `<K>\<P>\`, **Then** "Name: <K> Error: Can't move a key to itself." appears and, after
   Cancel, nothing changes.

---

### User Story 3 - Legitimate operations through another root name keep working (Priority: P3)

A rename through another root name (a new name in the same key) and a move to a different key
written under another root name keep working, and every same-root operation behaves as before.

**Why this priority**: the fix must not refuse what is not "onto itself".

**Independent Test**: probe rows ALIASRENAME, ALIASOTHER, MOVE, MOVESELF, SAMEMOVE.

**Acceptance Scenarios**:

1. **Given** `<K>`, **When** the user moves it to `\HKEY_USERS\<own SID>\Software\TcProbe292\Zdroj\<new name>`,
   **Then** no message appears, the key exists under the new name with its value and subkey and
   `<K>` is gone.
2. **Given** `<K>`, **When** the user moves it into `\HKEY_USERS\<own SID>\Software\TcProbe292\<Cil>\`,
   **Then** it is moved whole without a message.
3. **Given** the same-root cases (move into another key, into its own subkey, into its own
   parent), **Then** the results are those measured before this feature.

### Edge Cases

- The target root is itself inside the source (for example `HKEY_USERS\<SID>` moved into
  `HKEY_CURRENT_USER\`): refused as a move into itself. A root's identity is known without opening
  it (`HKEY_LOCAL_MACHINE`, `HKEY_USERS`) or is that of the key it stands for (`HKEY_CURRENT_USER`,
  `HKEY_CURRENT_CONFIG`; `HKEY_CLASSES_ROOT` - both halves).
- The target key does not exist yet: it cannot be the source key; whether it lies inside the source
  is decided from its parent (which exists) and its name.
- Names differ only in letter case: the same key (the registry ignores case).
- A key that cannot be opened while its identity is checked: the existing open error with Retry /
  Skip / Skip All / Cancel; nothing is copied or deleted for that key.
- Quick Rename (F2) works inside one key under one root name and is not changed.
- Copy / Move to a disk panel or from a disk panel is not concerned.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the target key of a Copy or Move from a Registry Editor panel is, by identity,
  the key the panel shows (the source items' parent), and the operation is not a rename to another
  name, the Registry Editor MUST refuse it with the message the same-root case shows ("Can't
  copy/move key or value to itself.") and change nothing - for keys and values alike, for the
  whole selection, before anything is copied (the target dialog opens again).
- **FR-002**: When the target of a key, by identity, is the source key or lies inside it, the
  Registry Editor MUST refuse that key with the message the same-root case shows ("Name: <key>
  Error: Can't copy/move a key to itself.", OK = skip the key, Cancel = stop) and never delete it.
- **FR-003**: Identity MUST come from what the registry reports for the opened key (its full
  internal name), so that every root name and registry link of one key is the same key; a key
  under `HKEY_CLASSES_ROOT` MUST count as each of the user's and the machine's class key of that
  path and as the key it resolves to.
- **FR-004**: The comparison of two identities MUST ignore letter case and treat a key as inside
  another only at a whole path element ("Key2" is not inside "Key").
- **FR-005**: When the identity of a key needed for the decision cannot be established, the
  operation MUST NOT go on for that key (the existing open-error box), and nothing MUST be deleted
  because of the missing check.
- **FR-006**: Operations that are not onto or into themselves (a rename through another root name,
  a move to another key, every same-root case) MUST behave as before.
- **FR-007**: The pure comparison (equal / inside, case ignored, whole elements; a candidate path
  built from a parent's identity and a name) MUST be a header under `src/common/` with `saltests`
  checks.
- **FR-008**: No UI text is added or removed.

### Key Entities

- **Key identity**: the full internal name the registry reports for an opened key (for example
  `\REGISTRY\USER\<SID>\Software\X`); a key path under `HKEY_CLASSES_ROOT` has up to three.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In every probe row that moves or copies a key or a value onto or into itself through
  another root name (ALIASMOVE, ALIASCOPY, ALIASINTO, ALIASVALUE, HKCRMOVE), the refusal message is
  shown and the registry is byte-for-byte unchanged (0 keys or values lost; before: 3 rows lost
  data).
- **SC-002**: Every control and regression row (ALIASRENAME, ALIASOTHER, MOVE, MOVESELF, SAMEMOVE)
  gives the result it gave before the feature.
- **SC-003**: The probe ends with 0 FAIL rows, no crash report and the product's registry key
  restored identical; `saltests` reports 0 failed checks.

## Assumptions

- Assumption (autonomous run): the registry's own report of a key's full name is available for
  every key the user can open for reading (measured on Windows 11); a root key handle cannot be
  asked, so the roots get a fixed rule (FR-003, Edge Cases).
- Assumption (autonomous run): the drag-and-drop route between two Registry Editor panels uses the
  same Copy / Move code and is covered by the same change; it is not driven by the probe (no real
  mouse on the hidden desktop is needed - the code path is the same function).
- Out of scope: the overwrite question showing names through the code page in the probe's reading
  (the known screen-reader item `screen-readers-get-garbled-names-from-the-core-path-labels`).
