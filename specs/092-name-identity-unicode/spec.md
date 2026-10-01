# Feature Specification: File names are the same when Windows says they are

**Feature Branch**: `092-name-identity-unicode`
**Created**: 2026-10-01
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5, encoding cluster **B-2** (`specs/069-finish-encoding-fixes/REMAINING-WORK.md` §1): code-page byte tables stand behind the comparison of file names, so `Č.txt` and `č.txt` are not the same name to the program — and some different names are.

## Clarifications

### Session 2026-10-01

The maintainer is away and asked for the recommended option at every decision. The research (`research.md`) changed the picture the backlog had; the decisions follow it.

- Q: What is actually wrong today? → A: **Equality, not order.** Sorting has been Unicode-aware since 0.1.0. What is wrong is every place that asks *"is this the same name / the same path?"*: it folds case byte by byte with a table built for the system code page, which sees the bytes of UTF-8. Two letters that differ only in case and are not ASCII compare as **different** (`Č`/`č`); and a few different letters whose UTF-8 bytes happen to fold alike compare as **equal** (`ĥ`/`Ĺ` on a Central European system).
- Q: Which rule replaces it? → A: **The file system's own**: case-insensitive, character by character, with no other equivalences — the rule NTFS applies (in Windows terms: ordinal, ignore case). Not the linguistic comparison the sort uses: that one also treats `straße` and `strasse`, or a name with an invisible soft hyphen, as equal, which is right for *searching* and wrong for deciding whether two names are the same file.
- Q: How far does this feature go? → A: **The program's own decisions about identity**: which item the cursor returns to, whether a rename is only a change of case, whether two paths are the same place, whether a name is already taken, and the internal look-ups that must agree with those decisions. **Not** the services exported to plug-ins (their behaviour is a published contract — plug-ins such as FTP use them for text that is not file names), not the sort order, not *Change Case*, not archive listings held for plug-ins. Each exclusion is recorded with its reason.
- Q: The guard rule that was called "the work list" (33 hits)? → A: **It is not one**: 29 of the 33 index the table with a drive letter and are harmless. The guard is corrected so that it means something.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — The cursor follows a name that differs only in the case of an accented letter (Priority: P1)

A user renames `Č.txt` to `č.txt` (or an archive, a refresh, a plug-in asks to focus `č.txt` while the panel holds `Č.txt`). The cursor stays on that file. With two files whose names the old comparison confused (`ĥ.txt`, `Ĺ.txt`), the cursor lands on the right one, not on whichever comes first.

**Why this priority**: it is the confirmed, user-visible defect of the review (068, verdict V2) and touches nothing persistent.

**Independent Test**: a folder with `Č.txt`; ask the panel to focus `č.txt`; the focused item is `Č.txt`. A folder with `ĥ.txt` and `Ĺ.txt`; ask for `Ĺ.txt`; the focused item is `Ĺ.txt`.

**Acceptance Scenarios**:

1. **Given** a panel showing `Č.txt`, **When** the program looks for the item named `č.txt` (after a rename, a refresh, returning from a subfolder, a command from a plug-in), **Then** it finds `Č.txt`.
2. **Given** a panel showing `ĥ.txt` and `Ĺ.txt`, **When** it looks for `Ĺ.txt`, **Then** it finds `Ĺ.txt` and never `ĥ.txt`.
3. **Given** names made only of ASCII characters, **Then** every such look-up gives exactly the result it gave before.

### User Story 2 — A change of case is recognised as one (Priority: P1)

A user renames `Článek.txt` to `článek.txt`, or copies a file onto a target whose name differs only in the case of an accented letter. The program treats it as it treats `A.txt` → `a.txt`: a rename that only changes case is carried out as such; a copy onto the "same" name asks about overwriting once, and never treats a genuinely different name as the same.

**Independent Test**: unit tests of the comparison; an evidence probe with the verbatim before/after decision code; on real NTFS, the helper's answer equals the file system's answer for the same pairs.

**Acceptance Scenarios**:

1. **Given** source `Článek.txt` and target `článek.txt` in the same folder, **When** the program decides whether the operation is only a change of case, **Then** the answer is yes.
2. **Given** source `ĥ.txt` and target `Ĺ.txt`, **Then** the answer is no — they are different files.
3. **Given** `straße.txt` and `strasse.txt`, **Then** they are different files (as on the disk).

### User Story 3 — Two spellings of one path are one place (Priority: P2)

Two paths that differ only in the case of accented letters (`C:\Dokumenty\Článek` and `c:\dokumenty\článek`) are the same place for the program: the same panel path, the same history entry, the same archive, the same cached listing. Paths that differ in a real letter are different places.

**Acceptance Scenarios**:

1. **Given** the two spellings, **When** the program compares them (panel paths, history, "is this the archive already open", "is this path under that one"), **Then** they are equal.
2. **Given** `C:\ĥ` and `C:\Ĺ`, **Then** they are different (today they are taken for one).
3. **Given** a path that is a prefix of another only up to the middle of a character, **Then** it is not a prefix.

### User Story 4 — Internal look-ups agree with those decisions (Priority: P3)

Lists the program keeps sorted to search them (selected names remembered across a refresh, folder sizes, the names used during a batch operation, keys of files extracted from archives) use the same rule on both sides — where they are filled and where they are searched — so a name is found exactly when it is the same name.

**Acceptance Scenarios**:

1. **Given** names with accented letters selected in a panel, **When** the panel is refreshed, **Then** the same items are selected.
2. **Given** any set of names, **Then** every name put into such a list is found in it again (verified as a property over generated names, before and after).

### Edge Cases

- A name with an unpaired surrogate (legal on NTFS): equals itself and its ASCII-case variants; two names differing only in the surrogate differ.
- Two spellings of the same accented letter (precomposed and decomposed): **different** names, as on NTFS.
- Letters whose upper and lower case have different lengths in UTF-8: measured over the whole Basic Multilingual Plane there are 973 case pairs, 7 of them with a 2-byte and a 3-byte member (for example `ⱥ` U+2C65 / `Ⱥ` U+023A). No comparison may be skipped because the byte lengths differ, and "is a prefix of" must count on the path itself. (Dotless `ı` / `I` and long `ſ` / `S` are **not** the same letter for the file system.)
- Text that is not valid UTF-8 (a legacy plug-in's name): compared exactly as before.
- Turkish system locale: the rule does not depend on the locale.
- Plug-ins calling the exported comparison services: unchanged results.
- Very long paths (beyond 260 characters) and 100,000 names in a folder: no noticeable slow-down.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The program MUST have one rule for "these two names are the same name": equal after ignoring case character by character, exactly as the file system does; no other characters are equivalent (no linguistic equivalences, no normalization).
- **FR-002**: For names made only of ASCII characters the rule MUST give the same result, including the sign of a three-way comparison where one is used for look-ups within one list, as before — or, where the internal order changes, both the side that sorts and the side that searches MUST change together.
- **FR-003**: Text that is not valid UTF-8 MUST be compared as before.
- **FR-004**: Finding an item by name in a panel (cursor after rename, refresh, leaving a subfolder or an archive, a request from a plug-in, drag and drop, Find's "go to file") MUST use the rule.
- **FR-005**: The decisions "this rename or copy only changes the case of the name" and "the target is the source" MUST use the rule.
- **FR-006**: The program's own comparisons of paths (same path, path under path, same archive, history entries) MUST use the rule, and "is a prefix" MUST respect character boundaries.
- **FR-007**: Each internal sorted list MUST be sorted and searched with the same comparison.
- **FR-008**: The comparison services exported to plug-ins (the string and path comparison primitives a plug-in calls with text of its own choosing), the sort order of panels, *Change Case*, mask matching, and archive listings kept for plug-ins MUST NOT change in this feature; each MUST be recorded as deferred with its reason. Services that operate on *file names* (creating a file or directory safely, splitting a target path) are not comparison primitives: their internal "is this the same name" decisions follow FR-001 whether the core or a plug-in calls them.
- **FR-009**: The encoding guard MUST stop reporting harmless drive-letter look-ups and MUST fail the build when a byte table is applied to a name again. (A rule that fails on the old *comparison function* in converted files was planned and is deferred: converted files still hold legitimate uses of it on text that is not a name; recorded in the fix log and the backlog.)
- **FR-010**: No stored data changes shape; the plug-in interface stays 107; the product version does not change.

### Key Entities

- **Name identity**: the relation "same name" (FR-001).
- **Path identity / prefix**: the same relation applied to whole paths, component boundaries respected.
- **Sorted pair**: a list and its search, which must share a comparison.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For **100 %** of upper/lower-case pairs of letters in the Latin-1 Supplement, Latin Extended-A, Greek and Cyrillic ranges, names differing only in that pair are the same name; for **100 %** of the pairs the old comparison confused on a Central European system, the names are different.
- **SC-002**: For **100 %** of ASCII-only test pairs the result equals the old one.
- **SC-003**: For every tested pair, the rule's answer equals what NTFS itself answers on the build machine.
- **SC-004**: The comparison used for sorted lists is a consistent order: **0** violations of antisymmetry and transitivity over the generated test set.
- **SC-005**: Refreshing a folder of 100,000 files takes no more than **10 %** longer than before.
- **SC-006**: Debug and Release builds succeed; all unit tests and the probes of features 087–089 pass; the strict encoding guard reports 0 findings and is proven to fire on a planted defect.

## Assumptions

- The Windows case table used by the comparison equals the one NTFS uses except for a handful of characters added to Unicode after a volume was formatted — the same accepted difference every Windows program has.
- GUI confirmation of the scenarios with a person at the screen remains owed; what can be driven without a person is driven by probes.
