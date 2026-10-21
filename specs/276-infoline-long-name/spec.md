# Feature Specification: The information line shows items with very long names

**Feature Branch**: `276-infoline-long-name`
**Created**: 2026-10-21
**Status**: Draft
**Input**: User description: "Backlog item focusing-an-archive-member-with-a-very-long-name-shows - focusing an archive member with a very long name shows "Expanded string is too large." twice." From backlog item focusing-an-archive-member-with-a-very-long-name-shows.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Moving the cursor onto a long-named archive member (Priority: P1)

A user browses a ZIP (or other) archive in a panel. One member has a long, valid name - for
example 200 CJK letters + ".txt" (604 bytes of UTF-8, 204 UTF-16 units). When the cursor lands on
it, today an error box "Expanded string is too large." appears (once or twice) and the panel's
information line keeps showing the previous item. After the change the cursor moves silently and
the information line describes the member like any other item.

**Why this priority**: it is the whole defect - every key press onto such an item costs one or
two dismissed boxes, and the information line lies (it describes another item).

**Independent Test**: the probe `infoline276_probe.ps1` opens a ZIP holding two short members and
the long one, focuses a short one, captures the information line, moves to the long one: no box
may appear and the captured information line must change.

**Acceptance Scenarios**:

1. **Given** a ZIP with a top-level member of 200 CJK letters + ".txt", **When** the cursor moves
   onto it, **Then** no message box appears and the information line shows that member.
2. **Given** the same member inside a folder of 84 CJK letters in the archive, **When** the panel
   is in that folder and the cursor moves onto it, **Then** no box and the information line
   changes to that member.
3. **Given** a ZIP member with the longest name the listing takes (251 CJK letters + ".txt",
   757 bytes / 255 units), **When** it is focused, **Then** no box, the line changes.
4. **Given** an archive with only short names, **When** the cursor moves, **Then** the
   information line behaves exactly as before (control).

---

### User Story 2 - Long names on disks without short (8.3) names (Priority: P2)

On a volume that does not generate 8.3 names, a file with a long name (up to 255 UTF-16 units,
765 bytes) has no short name, so the same expansion holds the long name twice. Focusing it must
not show the box either.

**Why this priority**: same defect, reached on disk only on volumes without 8.3 names (the
probe's %TEMP% volume generates them, so the probe's DISK row only shows that the disk case does
not regress).

**Independent Test**: by reading (the expansion is the same code as for archives); the probe's
DISK row (754-byte name) must stay box-free.

**Acceptance Scenarios**:

1. **Given** a disk file of 250 CJK letters + ".txt", **When** it is focused, **Then** no box,
   the information line changes.

### Edge Cases

- A user-defined Information Line content (Configuration, up to 199 characters) that names the
  file several times: the expansion still fits - every name the program lists fits as many
  times as the content can name it.
- A malformed content (e.g. edited in the registry): its syntax error box stays as before.
- A plug-in that fills the information line itself (`GetInfoLineContent`): unchanged - its
  buffer stays 1000 bytes by the plug-in contract.
- Selected items (the "N files, M directories" summary) and an empty panel: unchanged - they do
  not expand names.
- Low memory while growing the buffer: no box, a trace; the information line keeps its text.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Focusing an item whose name the panel lists MUST NOT show "Expanded string is too
  large." for the default Information Line content or any content up to its 199-character limit.
- **FR-002**: The information line MUST show the focused item's whole expanded text (its name is
  never cut by the expansion; the line's own drawing clips what does not fit its width, as for
  any long text).
- **FR-003**: The expansion's hot texts (the clickable parts of the information line) MUST keep
  their positions for the long text.
- **FR-004**: Every other information-line behaviour MUST stay: plug-in supplied content (1000
  bytes, plug-in contract), the selection summary, the empty-panel text, a syntax error box of a
  malformed content.
- **FR-005**: The rule for how large the expansion's buffer may grow MUST be a pure decision in a
  header under `src/common/` with `saltests` checks (that the bound holds the largest reachable
  expansion, and that the growth ends).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `infoline276_probe.ps1`: rows ARCCAP, ARCDEEP, ARCMAX, DISK, ARCSHORT show 0
  boxes and a changed information line (before: ARCCAP and ARCDEEP FAIL with one box each and an
  unchanged line); PIXCTL proves the capture can see a change.
- **SC-002**: `saltests` passes with the new checks; a negative control (a 1000-byte bound) fails
  them.
- **SC-003**: Probes of the neighbouring features 260 and 275 keep their results (260's
  16 / 0, 275's 17 / 0).

## Assumptions

- Assumption (autonomous run): "shortened at a whole letter for display if it does not fit"
  (the item's *Expected*) is met by never needing to shorten - the expansion grows until the
  text fits (bounded at 65,535 bytes, the limit of the hot-text positions, far above the largest
  reachable text: 18 names of 765 bytes + 199 = about 14 KB). The information line's drawing
  already clips a text wider than the window. Nothing is cut, so no letter can be split.
- Assumption (autonomous run): at the bound (unreachable for listed names) the last attempt keeps
  the old behaviour (the box), so a malformed content still reports its error once.
- Long disk names on volumes without 8.3 names are fixed by the same change but are not driven
  by the probe (its volume generates short names; changing that needs an administrator).
- The "twice" of the item: the probe saw one box per focus; the count does not matter once no
  box appears.
