# Feature Specification: A long single mask never overruns the mask group preparation

**Feature Branch**: `298-mask-group-long-mask`
**Created**: 2026-10-22
**Status**: Draft
**Input**: User description: "Backlog item mask-group-prepare-unbounded-mask-copy - a single mask longer than 259 bytes overruns the mask group preparation buffers." From backlog item mask-group-prepare-unbounded-mask-copy.

## Clarifications

### Session 2026-10-22

- Q: Should the sources that deliver long masks (registry readers with a 1001-byte cap, the tab filter, plug-ins, the viewer masks passed in directly) also be capped or refused? → A: No - only the preparation becomes safe for any length; the sources keep their behaviour, and a mask they deliver is used whole (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long mask from the configuration does not crash the program (Priority: P1)

A user's configuration holds a mask group with one mask longer than 259 bytes - written by a hand edit of
the registry, a settings import, or a plug-in (for example a plug-in's thumbnail masks, a tab's filter, the
name masks of saved criteria). Today the program crashes while it prepares that group; for the thumbnail
masks of a plug-in the crash happens at every start ("A problem has occurred", stack memory corruption),
so the program cannot be started at all until the value is removed by hand.

**Why this priority**: a reachable stack overrun - a crash at start, or silent memory corruption - and the
user cannot recover from inside the program.

**Independent Test**: write one plug-in's `ThumbnailMasks` registry value as a single mask of 300 bytes
(and of 1000 bytes), start the program on the hidden desktop: it starts, stays responsive and exits with
code 0, no bug report.

**Acceptance Scenarios**:

1. **Given** a plug-in's thumbnail masks hold one mask of 300 bytes, **When** the program starts,
   **Then** it shows its main window, answers messages and exits cleanly (exit code 0, no bug report).
2. **Given** the same with one mask of 1000 bytes (the longest a mask group keeps), **When** the program
   starts, **Then** the same.
3. **Given** a group of many short masks totalling 1000 bytes or one mask of 252 bytes (the controls),
   **When** the program starts, **Then** it behaves as before the change.

---

### User Story 2 - A long mask is used whole, never cut (Priority: P1)

A mask group whose single mask is longer than 259 bytes is prepared with that mask whole: it matches
exactly the names the whole mask matches - never the names a shortened mask would match.

**Why this priority**: a silently cut mask selects, filters, copies or deletes other files than the
user asked for (standing rule: a name or mask is never cut).

**Independent Test**: saltests over the preparation rule: a 300-byte and a 1000-byte single mask, with
`;;`, `|`, leading and trailing spaces, `**` and `*?` - the prepared mask equals the reference result
computed with an unbounded buffer, and nothing is written past the work buffer.

**Acceptance Scenarios**:

1. **Given** a single mask of 300 bytes ending in a distinct letter, **When** the group is prepared,
   **Then** the prepared mask holds all 300 bytes (after the usual normalization) and a name equal to the
   whole mask matches while a name equal to its first 259 bytes does not.
2. **Given** a mask group string passed directly to the preparation (not stored in the group, longer
   than 1000 bytes), **When** it is prepared, **Then** nothing is overrun and every mask is kept whole.

### Edge Cases

- A single mask exactly 259, 260 and 261 bytes long (the old buffer edge).
- A mask made of 3-byte UTF-8 letters (100 letters = 300 bytes).
- Escaped separators `;;` inside a long mask (the unescaped mask is shorter than its text).
- A long mask after `|` (exclude part).
- An empty group, a group of only spaces and separators - unchanged behaviour.
- Memory for the work buffer cannot be obtained: the preparation fails as it already does when memory
  runs out (returns failure with error position 0), never overruns and never prepares a cut mask.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Preparing a mask group MUST never write past its work storage, whatever the length of a
  single mask and whatever the length of the group string (stored in the group or passed in directly).
- **FR-002**: A single mask longer than 259 bytes MUST be prepared whole - never shortened. (Chosen of
  the two options the item allows: a work storage sized to the group text; the alternative, a refusal,
  would make valid configurations unusable and needs no new message.)
- **FR-003**: For every mask group that prepared correctly before the change (each mask up to 259 bytes),
  the prepared result, the success/failure and the reported error position MUST be unchanged.
- **FR-004**: The plug-in interface MUST stay unchanged: the exported single-mask preparation keeps its
  signature and its contract (the caller's buffer holds the source mask's length + 1).
- **FR-005**: The splitting and normalization rule MUST be checked by saltests, including a reproduction
  that a 300-byte single mask needs more than the old 260-byte storage and fits the new one.
- **FR-006**: If the work storage cannot be obtained, preparation MUST fail as on out-of-memory today
  (failure, error position 0), leaving the group unprepared.

### Key Entities

- **Mask group**: a `;`-separated list of masks with an optional `|` exclude part, stored up to 1000 bytes
  or passed in as a string of any length.
- **Single mask**: the text between two separators, with `;;` meaning a literal `;`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's rows M300 and M1000 move from FAIL (crash at start) to PASS; the controls SHORT
  and MULTI stay PASS.
- **SC-002**: saltests prove that masks of 300 and 1000 bytes are prepared whole and equal to the
  unbounded reference, and that every mask up to 259 bytes is prepared exactly as before; 0 failed.
- **SC-003**: No new UI string, no change to the plug-in interface, no change to stored data.

## Assumptions

- Assumption (autonomous run): the item allows "refuse" or "a buffer sized to the mask"; the sized buffer
  is taken (item: never cut; conservative: a configuration that worked keeps working, a new one is not
  refused, no new UI string).
- Assumption (autonomous run): the single-mask preparation never makes its output longer than its input
  (it only drops repeated `*` and swaps `*?` to `?*`, and trims spaces), so a storage of the group text's
  length + 1 always suffices; saltests check it.
- The sources that can deliver such masks (registry values read with a 1001-byte cap, plug-ins, the
  viewer masks passed in directly) are not changed by this feature - they stay as they are; only the
  preparation becomes safe for any length.
- Matching itself (`AgreeMasks`) already works on heap copies of any length and is out of scope.
