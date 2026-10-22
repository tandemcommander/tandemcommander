# Feature Specification: A subst drive's target is read whole or refused, never cut or in the code page

**Feature Branch**: `301-subst-target-whole`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item a-subst-drive-whose-target-is-long-or-outside-the-code-page (backlog/items/a-subst-drive-whose-target-is-long-or-outside-the-code-page/desc.md) - implement exactly what it describes. From backlog item a-subst-drive-whose-target-is-long-or-outside-the-code-page.

## Background

A subst drive (`subst Z: C:\some\folder`) is a drive letter that Windows maps to a folder. The
program asks Windows for that folder (the subst target) in several places: to turn a path on the
subst drive into the real path (path resolution - used by the delete question for links, the drive
type and volume checks, the same-volume decision of a move), to show "local drive (subst: ...)" in
Drive Information, to show the target in the Change Drive menu, to build a UNC path for *Copy Full
Path as UNC*, and in the bug report's drive list.

The program reads the target into a buffer of 260 UTF-16 units and converts it to UTF-8 into a
260-byte buffer. When the UTF-8 form does not fit - a folder with letters outside ASCII and more
than about 86-130 characters - it asks Windows again **in the system code page**: every letter
outside the code page becomes `?`, and that wrong path is then used. A target of more than 260
UTF-16 units is not read at all. The path was also copied with a cut (`lstrcpyn`) into the caller's
buffer.

Measured at 0f7bd140 (Debug x64, code page 1250): `subst.exe` accepts a target folder named by 80
CJK letters (138 UTF-16 units, 298 bytes of UTF-8) and refuses one over 260 UTF-16 units;
`DefineDosDeviceW` accepts both. A hidden-desktop probe with a subst drive holding a junction `J`:

| Case | F8 on `J` (Recycle Bin off) | Drive Information type line |
|---|---|---|
| SHORT (ASCII folder) | "delete junction J" - PASS | "local drive (subst: C:\...\s)" - PASS |
| CJK (80 CJK letters, 282 bytes) | "delete **directory** J" - FAIL (the link not recognised) | empty - FAIL |
| LONG (343 UTF-16 units) | "delete junction J" - PASS (the path is left unresolved) | "local drive" - PASS |

## Clarifications

### Session 2026-10-22

- Q: When a subst target cannot be used whole by a caller (its buffer is too small), what happens? → A: the caller refuses it: path resolution leaves the path on the subst drive unchanged and reports failure (as it already does for a resolved path that does not fit); the displays show no target; nothing ever uses a cut or `?` path (autonomous run: item - *Expected* "a target that cannot be represented is refused"; rule - "a path is never cut")
- Q: Should the plug-in function `ResolveSubsts` change (a larger buffer, a new size argument)? → A: no - its signature and its `MAX_PATH` buffer contract stay; only what it does with a target that does not fit changes (refusal instead of a `?` path) (autonomous run: rule - the plug-in ABI is append-only; conservative)
- Q: Should the display callers (Drive Information, Change Drive menu, Copy as UNC) get larger buffers so that every target `subst.exe` can create is shown whole? → A: yes where the caller already has or can cheaply have room (Drive Information, the menu text, Copy as UNC up to its existing 520-byte buffer); otherwise refused (autonomous run: item - "a subst target is read whole")
- Q: Does the "related cut" of the Change Drive menu (the remembered remote path, `min(l, MAX_PATH - 1)`) need a change? → A: no - measured by reading: the source buffer is 260 bytes, so the copy never cuts; recorded in the fix-log (autonomous run: measure first)
- Q: A subst path that is now left unresolved would make the same-volume checks say "different volumes" (a move becomes copy + delete; the Undelete plug-in skips its "restoring to the same partition" warning; Drive Information shows no volume) - before, the `?` path happened to have the right drive root. Keep the refusal, or keep the `?` path for volume checks? → A: keep the refusal, and give the volume checks the volume of the whole wide target (`GetSubstPathVolume`: the subst target + the rest of the path, `GetVolumePathNameW` + `GetVolumeNameForVolumeMountPointW`, measured to work at every length) when their own walk ends at the subst root - so no check loses its answer and no cut path is built (autonomous run: item - *Expected* "never work with a cut or '?' path"; rule - a "safe?" check fails closed (098); first answered "keep the refusal, record the fail-open" - rejected by review 1, M1, which showed the whole-path alternative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Delete of a link on a subst drive with a long non-ASCII target (Priority: P1)

A user has a subst drive `Z:` mapped to a folder whose name has many letters outside the code page
(e.g. Japanese). In `Z:\` there is a junction `J`. The user presses F8 (Recycle Bin off). The
question names `J` a **junction** - the program recognised the link - exactly as it does on a subst
drive with a short ASCII target.

**Why this priority**: today the link is not recognised because the program works with a `?`
path; this is the reachable wrong result in a delete decision.

**Independent Test**: hidden-desktop probe, case CJK, row DEL: before "directory", after "junction";
J and its target's files are untouched (the question is answered No).

**Acceptance Scenarios**:

1. **Given** `Z:` substed to a folder of 80 CJK letters holding the junction `J`, **When** F8 is
   pressed on `J`, **Then** the question says "junction".
2. **Given** `Z:` substed to an ASCII folder, **When** F8 on `J`, **Then** "junction" - as before.
3. **Given** `Z:` substed (by `DefineDosDeviceW`) to a folder of over 260 UTF-16 units, **When** F8
   on `J`, **Then** "junction" - as before.

---

### User Story 2 - Drive Information shows the subst target whole (Priority: P2)

The user opens Drive Information on `Z:\`. The drive type line reads "local drive (subst:
<the whole target folder>)" with every letter exact - also for the CJK folder. For a target the
line cannot hold, the line reads "local drive" without any part of the target.

**Why this priority**: a display, but it is today empty for the CJK case.

**Independent Test**: probe row INFO: the text of the drive-type line contains the whole target and
no `?` (SHORT, CJK); LONG: the whole target or none of it.

**Acceptance Scenarios**:

1. **Given** the CJK subst drive, **When** Drive Information opens, **Then** the drive type line
   contains the whole CJK folder path and no `?`.
2. **Given** the SHORT drive, **Then** as before.

---

### User Story 3 - Other users of the target never see a cut or `?` path (Priority: P3)

*Copy Full Path as UNC* of a file on the CJK subst drive builds the path from the exact target (or
refuses as "too long" when it cannot hold it); the Change Drive menu shows the exact target or
nothing; the bug report lists the exact device text or omits it; the drive type, volume and
same-volume checks never resolve the subst drive to a `?` path.

**Why this priority**: same defect, less visible callers.

**Independent Test**: code review of every caller (enumerated in the plan) and `saltests` checks of
the pure target-parsing rule; the clipboard is not available on the hidden desktop (Copy as UNC is
a person step).

**Acceptance Scenarios**:

1. **Given** a subst target that does not fit a caller's buffer, **When** that caller asks for it,
   **Then** it receives a refusal and does not use any part of the target.
2. **Given** a target that fits, **Then** the caller receives it exactly (no conversion through the
   code page).

### Edge Cases

- The drive letter is not a subst drive (a hard disk `\Device\HarddiskVolume1`, a mapped network
  drive `\Device\LanmanRedirector\...`): "not a subst" - as before.
- A subst to a UNC path (`\??\UNC\server\share`): the target is `\\server\share`, exact; path
  resolution keeps leaving it to the network code (as before). One whose path does not fit
  `MAX_PATH`: resolution now reports failure (FALSE, the path unchanged) - before it reported
  success over a `?` path; no caller acts on that return value except the same-path shortcut of
  the same-volume check, which then is skipped (review 1, S2).
- A subst to a drive root (`\??\D:`): `D:` - as before (resolution turns `D:` into `D:\`).
- A target over 260 UTF-16 units: read whole (the buffer grows); refused by every caller whose
  buffer cannot hold it.
- A target whose wide form is not convertible to UTF-8: WTF-8 converts every UTF-16 sequence, so
  only a size limit can refuse.
- A subst chain (`Y:` → `Z:\a`, `Z:` → folder): each step resolved as before; a step whose target
  is refused stops the resolution with failure, the path left as the previous step made it (a
  valid path through the remaining subst).
- Windows answers with more than one mapping (a stacked `DefineDosDevice`): the first one, the
  current mapping - as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The subst target MUST be read from Windows as wide text, whole, whatever its length
  (up to the system's limit); the program MUST NOT ask for it in the system code page.
- **FR-002**: The target MUST be converted to UTF-8 (WTF-8) exactly; when the result does not fit
  the caller's buffer, the caller MUST receive a refusal - never a cut text.
- **FR-003**: Path resolution of a path on a subst drive whose target is refused MUST leave the
  path unchanged and report failure (the existing too-long behaviour of the plug-in function);
  its signature and buffer contract MUST NOT change.
- **FR-004**: Drive Information MUST show the subst target whole for every target `subst.exe` can
  create (fewer than 260 UTF-16 units), or no part of a target its line cannot hold.
- **FR-005**: The Change Drive menu text of a subst drive to a network path (the only subst drive
  whose target the menu shows - a remote drive) MUST be the exact target, or empty when it cannot
  be held.
- **FR-006**: *Copy Full Path as UNC* MUST use the exact target or report the path as too long
  (feature 101's message) - never a `?` or cut path.
- **FR-007**: The bug report's drive list MUST show the exact device text or omit it.
- **FR-008**: The rule that turns the Windows device text into a subst path (the `\??\X:` and
  `\??\UNC\` forms, refusal on a too-small buffer, "not a subst" otherwise) MUST be a pure rule
  under `src/common/` with `saltests` checks.
- **FR-010**: The volume checks (same volume for a move, Undelete's same-partition warning, Drive
  Information's mount point and volume name) MUST still tell the volume of a path on a subst drive
  whose target is refused: from the whole wide target plus the rest of the path, never from a cut
  or `?` path (review 1, M1).
- **FR-009**: No user-interface text is added or removed; no plug-in interface change.

### Key Entities

- **Subst target**: the Windows device text of a drive letter - `\??\C:\folder`, `\??\UNC\server\
  share`, or a device name for a real drive; up to about 32,767 UTF-16 units.
- **Subst path**: the target without its `\??\` prefix (`C:\folder`), or `\\server\share` for the
  UNC form.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The hidden-desktop probe passes all rows after the fix (18 of 18 with the VOL and
  MOVE rows of review 1; the first version: 9 of 9, before 7 of 9 - the CJK DEL and INFO rows fail).
- **SC-002**: The program no longer imports the code-page device query (0 imports of
  `QueryDosDeviceA` after, 1 before).
- **SC-003**: `saltests` checks of the pure rule pass, including the refusal at a buffer one byte
  too small and the exact fit.
- **SC-004**: The encoding guard stays at 0 findings.

## Assumptions

- Assumption (autonomous run): a path on a subst drive that is left unresolved is still a valid
  path - Windows resolves it itself. The checks that need its real volume ask for it with the whole
  wide target (FR-010) when their own walk ends at the subst root without a volume.
- Assumption (autonomous run): `Copy Full Path as UNC` cannot be driven on the hidden desktop (no
  clipboard) - its confirmation is a person step.
