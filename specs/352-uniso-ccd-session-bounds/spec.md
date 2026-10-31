# Feature Specification: A damaged CloneCD .ccd never makes the ISO plug-in write or read outside its tables

**Feature Branch**: `352-uniso-ccd-session-bounds`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-clonecd-session-number-from-the-ccd-writes` - "ISO plug-in: a CloneCD session number from the .ccd writes outside the reader arrays". From backlog item iso-plug-in-a-clonecd-session-number-from-the-ccd-writes.

## Background (measured at 2f260c23)

The ISO plug-in (`uniso`, on in the default build) opens a CloneCD disc image (`.img`) by reading
the `.ccd` text file beside it: `[Session n]` sections, `[Entry n]` sections (the table of contents,
each naming its session) and `[TRACK n]` sections (each track's mode and `INDEX 1` start). The
reader keeps four per-session tables sized by the number of `[Session n]` sections, and splits the
track list into sessions where a track's `INDEX 1` is 0.

- An entry's session number is used as a table index unchecked: `Session=0` writes before the
  table, `Session=200` far past a one-session table; the number is also stored in a byte, so
  `Session=257` becomes session 1.
- When the number of `[Session n]` sections and the number of track splits differ, the reader reads
  past its split list (more sections) or past its per-session tables (more splits).
- A `MODE=`, `INDEX 1=`, `Session=`, `Point=`, `PLBA=`, `ADR=`, `PreGapMode=` or `PreGapSubC=` row
  whose value does not parse, or a row given twice while another is missing, still counts as
  present: the field keeps an uninitialised value.

Measured with the hidden-desktop probe `iso352_probe` (images by `img352.py` from feature 334's
`mkimg334.sh` seeds; a whole Unpack, Alt+F9, with "Delete archive after unpacking") on the Debug
build at 2f260c23: 8 PASS / 10 FAIL - `Session=0`: CRT "HEAP CORRUPTION DETECTED ... img.cpp(438)";
`Session=200`: no window, the image **deleted**; `Session=257`: run-time check "cast to a smaller
data type"; two sections / one split: "Index is out of range (index = 1, Count = 1)"; one section /
two splits: passes visibly but reads past a one-element table; `MODE=x`: "Unknown file format";
an entry without `PLBA` and with `Session` twice: run-time check "plba used without being
initialized". The two controls (one session; two sessions, two splits) extract and delete the image
correctly.

## Clarifications

### Session 2026-10-31

- Q: Should a `.ccd` the reader refuses also mark the image's listing incomplete, including `.ccd` files refused for a missing row before this feature? → A: Yes - the existing box stays, plain detection continues as today, and the listing is marked incomplete so a whole unpack keeps the image (autonomous run: conservative)
- Q: When sections and splits disagree, should the `.ccd` be refused instead of opened? → A: No - opened within bounds and marked incomplete; real multi-session dumps have that shape (autonomous run: item - "opens with its listing marked incomplete" - and conservative)
- Q: Should a value with trailing text after a number (`Session=1x`) count as not parsing? → A: No - parsed as today (the leading number); only a value with no number fails (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged .ccd cannot corrupt memory or cost the user the image (Priority: P1)

A user opens or unpacks a CloneCD image whose `.ccd` is damaged or crafted: an entry names a session
the file does not have, or a row's value does not parse. The plug-in refuses the `.ccd` with the
existing message "Bad format of .CCD file. Displayed image could be incomplete." - no memory outside
its tables is written or read. A whole unpack with "Delete archive after unpacking" then fails and
the image is kept.

**Why this priority**: memory corruption from a file's content, and an image deleted after a
silent overrun, are the item's main point.

**Independent Test**: probe rows R-S0, R-S200, R-S257, R-MODEX, R-DUP: the bad-format box shows, no
fatal window or bug report, the image is kept.

**Acceptance Scenarios**:

1. **Given** a one-session `.ccd` whose entry says `Session=0` (or 200, or 257), **When** the user
   unpacks the whole image with "Delete archive after unpacking", **Then** the bad-format message
   shows, no heap corruption or run-time check fires, and the image is kept.
2. **Given** a `.ccd` with `MODE=x` in a track, or an entry without `PLBA` but with `Session=`
   twice, **When** the user unpacks the whole image the same way, **Then** the bad-format message
   shows, no uninitialised value is used, and the image is kept.

---

### User Story 2 - Session sections and track splits that disagree are read within bounds (Priority: P1)

A user opens a CloneCD image whose `.ccd` declares more `[Session n]` sections than the reader finds
track splits (for example a multi-session dump whose `INDEX 1` values are absolute), or fewer. The
image opens as CloneCD without reading past any table; because its session layout cannot be trusted,
the listing is marked incomplete, so a whole unpack fails and the image is kept.

**Why this priority**: the same reader, the same out-of-bounds class; the item names it.

**Independent Test**: probe rows R-ABS, R-SPLIT: no bad-format box, no fatal window, image kept.

**Acceptance Scenarios**:

1. **Given** two `[Session n]` sections and one split, **When** the user unpacks the whole image,
   **Then** no index-out-of-range failure occurs and the image is kept.
2. **Given** one `[Session n]` section and two splits, **When** the user unpacks the whole image,
   **Then** the reader does not read past its one-session tables and the image is kept.

---

### User Story 3 - Valid CloneCD images behave as before (Priority: P1)

A user unpacks a valid one-session or two-session (two splits) CloneCD image: everything is
extracted and "Delete archive after unpacking" deletes the image, as today.

**Independent Test**: probe controls C-M1, C-M1M1; 351's probe `iso351_probe` unchanged.

**Acceptance Scenarios**:

1. **Given** a valid `.ccd`, **When** the user unpacks the whole image, **Then** all files are
   extracted, no window shows, the image is deleted.

### Edge Cases

- An image without a `.ccd` beside it: unchanged (the "Missing .CCD file" warning and plain
  detection), never marked by this feature.
- A `.ccd` refused for a reason that existed before (a required row missing): handled like the new
  refusals - the existing message, plain detection, and the listing marked incomplete.
- An entry for a session that exists but has no split (more sections than splits): it stays within
  the tables; it is simply not used for a track.
- A split with no `[Session n]` section (more splits than sections): its tracks get no session
  offset from the table of contents (zero), and the listing is marked incomplete.
- A session number written with extra text after the digits (`Session=1x`): read as the C runtime
  reads it today (the leading number); only a value with no number at all fails to parse.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An `[Entry n]` whose session number is not between 1 and the number of `[Session n]`
  sections MUST make the `.ccd` refused before any per-session table is written; the session number
  MUST be compared at its full value (no truncation to a byte).
- **FR-002**: A row of a `[TRACK n]`, `[Entry n]` or `[Session n]` section that the reader needs
  MUST count only when its value parses; a needed row that is missing, does not parse, or is given
  twice MUST make the section, and so the `.ccd`, refused.
- **FR-003**: A refused `.ccd` MUST show the existing bad-format message (no new text) and the
  plug-in MUST continue as it does today for a refused `.ccd` (plain detection of the image), with
  the image's listing marked incomplete, so a whole unpack fails and the image is kept.
- **FR-004**: When the number of `[Session n]` sections and the number of track splits differ, the
  reader MUST NOT read or write outside its split list or its per-session tables; the image MUST
  open as CloneCD where it can and its listing MUST be marked incomplete.
- **FR-005**: A valid `.ccd` (sections and splits agree, every entry's session in range, every
  needed row parses once) MUST be read exactly as before.
- **FR-006**: An image without a `.ccd` MUST behave as before (not marked).
- **FR-007**: The bound and parse decisions MUST be a pure rule in a header under `src/common/` with
  `saltests` checks.

### Key Entities

- **Session section**: a `[Session n]` section of the `.ccd`; their count sizes the per-session tables.
- **Track split**: a run of tracks starting at a track whose `INDEX 1` is 0; their count is the
  plug-in's session list.
- **Entry**: an `[Entry n]` section: session number, point, PLBA, ADR.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe `iso352_probe` goes from 8 PASS / 10 FAIL (main, 18 rows) to 20 PASS / 0 FAIL (20 rows: + C-NOCCD, an image without a `.ccd`, FR-006) on the
  Debug build.
- **SC-002**: No damaged `.ccd` of the probe deletes its image after a whole unpack with "Delete
  archive after unpacking" (0 of 7).
- **SC-003**: The controls and feature 351's probe keep their results (C-M1 / C-M1M1 PASS; 351's 10 / 0).
- **SC-004**: `saltests` passes with new checks of the rule, and a mutant of the rule fails them.

## Assumptions

- Assumption (autonomous run): a refused `.ccd` keeps today's handling (the bad-format box, then the
  plain detection that may still list the image) and additionally marks the listing incomplete - the
  message already says "Displayed image could be incomplete", and the plain detection lists only the
  first session of a multi-session image, so deleting it after a "successful" unpack could lose data
  (conservative: no data loss, no new UI string). This also applies to the `.ccd` files refused before
  this feature (a missing row).
- Assumption (autonomous run): sections and splits that disagree are not refused - real multi-session
  dumps with absolute `INDEX 1` values look like that (related item
  `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`); their geometry stays as wrong as
  today (that item's job) but bounded, and the listing is marked incomplete.
- Assumption (autonomous run): a needed row given twice refuses the section (today a complete
  section with a duplicated row was already refused by its row count; only the duplicate-plus-missing
  case was accepted with an uninitialised field).
- The `[Disc]` section's values are parsed but not used; they are left as they are.
- Crafted images only; no real damaged CloneCD dump is available.
