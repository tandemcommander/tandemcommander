# Feature Specification: Renamer "Include subdirectories" never descends into a junction or folder link

**Feature Branch**: `388-renamer-subdir-links`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: User description: "Backlog item renamer-include-subdirectories-descends-into-junctions-and - implement exactly what it describes." From backlog item renamer-include-subdirectories-descends-into-junctions-and.

## Clarifications

### Session 2026-11-02

- Q: Should a link below the selected folder be skipped silently, listed as an item, or walked when its target lies inside the selection? → A: listed as an item (mask applied as for a folder), never walked (autonomous run: item - its *Expected* first option and *Notes* "never descend into a link", with the core's precedent 213)
- Q: Is a selected panel item that is itself a junction walked (the user chose it) or listed? → A: listed, not walked - as the core's Change Case with subdirectories (213, "also a selected junction") (autonomous run: rule)
- Q: Should every selected folder be looked up again to learn whether it is a link, or only one whose panel attributes carry the reparse bit? → A: only one with the reparse bit; a plain folder keeps today's path (its read errors unchanged) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A link below the selected folder is listed, never walked (Priority: P1)

A user selects a folder in a panel, opens the Batch Renamer (Ctrl+Shift+R) and ticks "Include
subdirectories". Somewhere below the folder there is a junction or a directory symbolic link
pointing elsewhere (outside the selected folder, or back up to it). The preview lists the files
of the selected folder and of its plain subfolders, and the link itself as one item - never a
file of the link's target. Renaming renames only what the preview shows: the link's own name may
change, the files of its target never.

**Why this priority**: This is the defect of the item - today the files of the link's target
(outside what the user selected) are offered and renamed, and a link loop fills the preview with
the same files once per level until the "too long path name" box drops the listing.

**Independent Test**: Probe `ren_link_probe.ps1` rows `out`, `loop`, `symlink`, `mask`, `rename`
on the hidden desktop: the preview's full names are compared with the expected list.

**Acceptance Scenarios**:

1. **Given** `sel\a.txt`, `sel\sub\b.txt` and a junction `sel\out` to a folder holding `o1.txt`,
   `o2.txt`, `o3.txt`, **When** `sel` is selected and "Include subdirectories" is ticked,
   **Then** the preview lists exactly `sel\a.txt`, `sel\sub\b.txt` and `sel\out`, and no box.
2. **Given** `sel\a.txt` and a junction `sel\loop` pointing to `sel`, **When** subdirectories are
   included, **Then** the preview lists exactly `sel\a.txt` and `sel\loop`, without the "too long
   path name" box, and "Include subdirectories" stays ticked.
3. **Given** a directory symbolic link `sel\sl` to another folder, **When** subdirectories are
   included, **Then** `sel\sl` is listed and no file of its target.
4. **Given** the setup of scenario 1 and the mask `*.txt`, **When** subdirectories are included,
   **Then** the preview lists `sel\a.txt` and `sel\sub\b.txt` only (the link's name does not
   match the mask, as a selected folder's name would not).
5. **Given** the setup of scenario 1, **When** the new name `n_$(OriginalName)` is applied,
   **Then** `sel\n_a.txt`, `sel\sub\n_b.txt` exist, `sel\out` became the junction `sel\n_out`,
   and the target still holds `o1.txt`, `o2.txt`, `o3.txt` unchanged.

---

### User Story 2 - A selected link is an item, not a folder to walk (Priority: P2)

The user selects a junction itself in the panel and ticks "Include subdirectories". The preview
lists the junction as one item (as the core's Change Case with subdirectories treats a selected
junction, feature 213) instead of the files of its target.

**Why this priority**: The same descent through the same rule, one level up; without it a
selected junction still offers its target's files.

**Independent Test**: Probe row `selected`.

**Acceptance Scenarios**:

1. **Given** a junction `jsel` to a folder holding `o1.txt`, `o2.txt`, **When** `jsel` is
   selected and subdirectories are included, **Then** the preview lists exactly `jsel`.

---

### User Story 3 - Plain folders and other reparse folders keep being walked (Priority: P3)

Plain subfolders, and folders that carry a reparse point that is not a link (a cloud
placeholder such as a OneDrive folder, a deduplicated folder), are walked as before.

**Why this priority**: The fix must not shrink the listing users rely on.

**Independent Test**: Probe row `plain` (`sel\a.txt`, `sel\x\y\z.txt` → both listed) and the
`saltests` checks of the decision rule (a cloud / OneDrive / dedup tag is not a link).

**Acceptance Scenarios**:

1. **Given** `sel\a.txt` and `sel\x\y\z.txt` (plain folders), **When** subdirectories are
   included, **Then** both files are listed.
2. **Given** a folder whose reparse tag is a cloud placeholder (not a name surrogate), **When**
   the rule decides, **Then** it is walked as a plain folder.

### Edge Cases

- A reparse folder whose tag cannot be determined is treated as a link (fail closed, rule of
  feature 197): listed, not walked.
- A volume mount point folder is a name surrogate: listed, not walked (as in the core, 213).
- A file symbolic link is a file: listed as before (its rename renames the link).
- The "N files, M folders" count line counts a listed link as a folder.
- After a rename, the reload (feature 209) re-reads the items: a renamed link item is again
  listed, not walked.
- A link whose own path does not fit the plug-in's path buffer is refused with the existing "too
  long path name" error, as a file of that length is - never cut.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With "Include subdirectories", the Renamer MUST NOT enumerate the content of a
  directory that is a link - a junction, a directory symbolic link, a volume mount point, any
  reparse directory whose tag is a name surrogate, or whose tag cannot be read.
- **FR-002**: Such a link found below a selected folder MUST be offered as an item of its own
  when its name matches the mask (matched exactly as a selected folder's name is: the mask code
  takes the extension from the name, so a link `j.txt` matches `*.txt` - review 1, SHOULD 2).
- **FR-003**: A selected panel item that is such a link MUST be treated the same way: listed
  when its name matches the mask, not walked.
- **FR-004**: A directory with a reparse point whose tag is readable and not a name surrogate
  (cloud placeholder, deduplication) MUST still be walked; a directory without a reparse point
  MUST be walked as before.
- **FR-005**: The listing's count line MUST count listed link items as folders.
- **FR-006**: The link decision MUST be a pure rule in a header under `src/common/` built on
  the core's rule (feature 197 `SalDeleteAsDirLinkDecision`), checked by `saltests`. It is
  stricter in one case: a directory listed with the reparse bit but tag 0 is a link (fail closed
  for a walk), where 197's rule calls tag 0 "no reparse point any more" (review 1, NOTE 1).
- **FR-007**: Nothing else in the Renamer's listing changes: files, plain folders, masks, the
  "too long path name" and "cannot read the folder" errors behave as before.

### Key Entities

- **Directory link**: a directory entry with a reparse point that names another place
  (junction, directory symbolic link, mount point, WSL symlink, unknown name surrogate).
- **Listed item**: an entry offered in the Renamer's preview for renaming.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `ren_link_probe.ps1`: all rows PASS (before the change: 6 FAIL of 7 RUN rows,
  the `plain` control PASS).
- **SC-002**: In no probe row does the preview list a path below a link.
- **SC-003**: A link loop is listed in one pass with no error box.
- **SC-004**: `saltests` passes with the new checks of the decision rule; the encoding guard
  reports 0 findings; the Debug build succeeds.

## Assumptions

- Assumption (autonomous run): of the item's two behaviours, the first one ("list the link
  itself, do not descend") is taken - the item's Notes name "never descend into a link" as the
  conservative one, and the core's feature 213 (Change Attributes / Change Case / Convert with
  subdirectories) does exactly that, also for a selected junction, while its own entry still
  changes.
- Assumption (autonomous run): the link decision uses the reparse tag the directory listing
  already returns (`WIN32_FIND_DATAW.dwReserved0`), for a selected item read by one look-up of
  its own entry; no destination is read - the decision "name surrogate or unknown = a link" is the
  fail-closed half of the core's rule without the destination read (a destination read only ever
  turns an entry INTO a link).
- Assumption (autonomous run): a selected item is looked up only when the panel's attributes
  carry the reparse bit; a plain selected folder is walked as before (its read errors unchanged).
- Feature 282 (long names in the Renamer) is not merged; its depth guard is not on `main`. The
  fix does not depend on it.
- No UI string, dialog or resource changes: no translation refresh.
