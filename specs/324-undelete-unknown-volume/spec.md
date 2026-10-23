# Feature Specification: Undelete warns when it cannot tell the restore target's volume

**Feature Branch**: `324-undelete-unknown-volume`
**Created**: 2026-10-23
**Status**: Draft
**Input**: User description: "Backlog item undelete-skips-its-same-partition-warning-when-the-target - Undelete skips its same-partition warning when the target volume cannot be told." From backlog item undelete-skips-its-same-partition-warning-when-the-target.

## Background

Before the Undelete plug-in restores files, it warns when the restore target lies on the volume the
files are recovered from (`IDS_SAMEPARTITION`, OK / Cancel, Cancel the default): writing there can
overwrite the clusters of the deleted files not yet recovered. Before it views a deleted file it
likewise asks for a temporary folder on another volume when the system's temporary folder is on the
source volume (`IDS_TEMPDIR`). Both decisions ask the core's plug-in service
`PathsAreOnTheSameVolume`, which answers "different volumes" whenever it could read the volume
name of only one of the two paths - the guard fails open.

Measured at 3162d8b2 (scratch Python/ctypes script, a fixture under `%TEMP%`, no administrator
rights): a junction named `Zálohy` that points at a volume root (`\??\Volume{…}\` - what a mount
folder is) has a volume for the wide API (`GetVolumeNameForVolumeMountPointW` returns the volume)
but not for the code-page API the core calls with the UTF-8 path
(`GetVolumeNameForVolumeMountPointA` fails, error 2); a junction to a volume-GUID subfolder has no
volume name for either API (error 206). The core's reparse walk treats such a folder as a mount
point and may not step to its parent, so the volume of the target "cannot be told", the source
volume's can, and the answer is "different" (with the estimation flag set) although both are the
same volume. A user who recovers volume X (mounted at `E:\` and at `C:\Zálohy\`) into
`C:\Zálohy\restore` is not warned. End-to-end runs of the Undelete restore need an elevated program.

## Clarifications

### Session 2026-10-23

- Q: Fix inside the core service (change what `PathsAreOnTheSameVolume` answers) or inside the
  plug-in? → A: Inside the plug-in; the core service and its plug-in contract (`spl_gen.h`)
  stay unchanged - the plug-in interface is the maintainer's, and the item's *Notes* name the
  plug-in fix as the smaller change (autonomous run: item + rule).
- Q: When the core is unsure and says "different", what decides? → A: The file system's own
  identity of the two places: the volume serial number of the target's nearest existing folder
  and of the source volume's root, read with the wide API at any path length. Equal serials, or a
  serial that cannot be read on either side → the same volume (warn / ask for another temporary
  folder); two readable, different serials → different volumes (autonomous run: item *Expected*
  "fails closed" + the item's alternative "resolve the volume so the answer is known").
- Q: Does a certain answer of the core change? → A: No - "same" stays "same" (warning shown, as
  today) and a certain "different" (both volume names read) stays "different" (autonomous run:
  conservative - keeps the existing behaviour for every case the item does not name).
- Q: A new message for "cannot tell"? → A: No - the existing `IDS_SAMEPARTITION` text already says
  "It seems you are undeleting to the same logical disk"; no UI string changes (autonomous run:
  conservative).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The same-volume warning appears when the target's volume cannot be told (Priority: P1)

A user recovers deleted files of a volume and picks a restore target whose volume the core cannot
name (a mount folder named outside ASCII, a junction to a volume-GUID path) but which lies on the
volume being recovered.

**Why this priority**: the item's data-safety defect - recoverable files overwritten without the
warning.

**Independent Test**: the pure decision (saltests) for every combination of the core's answer, its
estimation flag and the identity comparison; the identity read of the measured fixture paths
(probe); the restore itself through the Undelete GUI is owed to a person (elevation).

**Acceptance Scenarios**:

1. **Given** the source volume is C: and the target is a folder below a junction `Zálohy` that
   points at C:'s volume root, **When** the restore starts, **Then** the same-partition warning is
   shown (unless the user turned it off with "Don't show this again").
2. **Given** the target's nearest existing folder cannot be opened or reports no volume serial,
   and the core is unsure, **When** the restore starts, **Then** the warning is shown.
3. **Given** the target lies on another local volume whose volume name the core reads, **When** the
   restore starts, **Then** no warning is shown (unchanged).

---

### User Story 2 - Viewing a deleted file never puts its temporary copy on the source volume unseen (Priority: P2)

A user views a deleted file; the system temporary folder (or the configured alternative) lies on
the source volume, but its volume cannot be told by the core.

**Why this priority**: the same fail-open rule guards the temporary copy of View; the item names it.

**Independent Test**: the same decision as story 1 drives both checks of the temporary folder.

**Acceptance Scenarios**:

1. **Given** the core is unsure and the identity read finds the temporary folder on the source
   volume or cannot read it, **When** the user views a deleted file, **Then** the plug-in asks for a
   temporary folder on another volume (existing `IDS_TEMPDIR` flow).
2. **Given** the temporary folder is on another volume by a readable identity, **When** the user
   views a file, **Then** no question is asked (unchanged).

### Edge Cases

- The restore target does not exist yet: the nearest existing parent folder decides (the restore
  creates the missing folders there).
- The target path is longer than 259 characters or holds characters outside the code page: read
  whole with the wide API, never cut.
- A network target (`\\server\share`, mapped drive): the core is always unsure there; the identity
  read decides - a share of another machine reports its own volume serial (no warning, as today); a
  share that loops back to the source volume reports the source's serial (warning); a share that
  cannot be read → warning.
- Two different volumes that happen to share a serial number (a cloned disk): treated as the same
  volume - an extra warning, never a missing one.
- An image file as the source (`Volume.IsImage`): no check, unchanged.
- "Don't show this again" was chosen earlier: the warning stays off, unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plug-in MUST treat the restore target as on the source volume when the core
  answers "same volume", exactly as before.
- **FR-002**: When the core answers "different" with certainty (its estimation flag cleared), the
  plug-in MUST keep that answer.
- **FR-003**: When the core answers "different" as an estimation, the plug-in MUST decide by the
  volume serial numbers of the target's nearest existing folder and of the source volume's root:
  different readable serials → different; equal serials → same; either serial unreadable or
  unusable (zero) → same.
- **FR-004**: The same decision MUST guard both checks of the temporary folder used to view a
  deleted file (the system temporary folder and the configured alternative).
- **FR-005**: Paths MUST be read as UTF-8 → UTF-16, whole, with the extended-length form when
  long; no path is cut and no code-page API is used for the new reads.
- **FR-006**: The decision MUST be a pure function in a header under `src/common/` with `saltests`
  checks covering every combination of FR-001..FR-003.
- **FR-007**: The core's `PathsAreOnTheSameVolume`, its plug-in contract and every UI string MUST
  stay unchanged.

### Key Entities

- **Core answer**: same / different, plus the estimation flag the plug-in service already returns.
- **Volume identity**: the volume serial number the file system reports for an open folder
  (64-bit where available, else 32-bit), or "unknown".

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For the measured fixture (a target below a volume-root junction named outside
  ASCII, and below a junction to a volume-GUID subfolder), the decision answers "same volume" in
  100% of runs (probe, after) where the core alone answers "different".
- **SC-002**: For a target on another local volume, the decision answers "different" (no extra
  warning) - probe row.
- **SC-003**: Every combination of core answer, estimation flag and identity result has a saltests
  check; `saltests` reports 0 failed.
- **SC-004**: No change to the core's answer for any caller other than the Undelete plug-in.

## Assumptions

- Assumption (autonomous run): the volume serial number from the open folder's handle is the
  file system's own answer for "which volume holds this folder" and follows junctions, mount
  folders, subst drives and symbolic links the way the restore's writes will.
- Assumption (autonomous run): the restore through the elevated Undelete GUI is not driven in the
  run; it is owed to a person as a person-step item.
- Assumption (autonomous run): the core's use of the code-page `GetVolumeNameForVolumeMountPoint`
  with UTF-8 paths (the cause of the measured unknown volume) is a separate defect of the core,
  recorded as an Inbox item; this feature makes the Undelete guard fail closed whatever the cause.
