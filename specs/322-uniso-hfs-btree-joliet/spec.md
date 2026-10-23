# Feature Specification: The ISO plug-in checks an HFS+ catalog against the image it was read from; Joliet file names are kept whole

**Feature Branch**: `322-uniso-hfs-btree-joliet`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `uniso-hfs-btree-trust-and-joliet-cut` - "ISO plug-in: HFS+ B-tree loader trusts the image; Joliet names cut". From backlog item uniso-hfs-btree-trust-and-joliet-cut.

## Background (measured at a222bd88)

Left by feature 223 (the ISO plug-in checks the lengths an image gives). Traced at HEAD with the
default configuration (`uniso=on`):

- **HFS+ catalog.** Opening an image (`.iso`, `.dmg`, `.img`, ...) whose first block carries an
  Apple partition map or whose offset 1024 carries an HFS+ volume header opens the HFS+ reader -
  alone, or next to ISO 9660 / UDF in a hybrid image. The reader loads the catalog file into memory
  and walks its leaf nodes. The node to start at, the link to the next node, the node size, each
  node's record count and each record's offset are taken from the image as they are: none is
  compared with the size of what was loaded. A link that points back makes the walk endless while
  its record list grows. The listing and the extraction then read each record's key, name and
  folder / file data behind the key length without checking that they lie inside the node.
- **Joliet names.** A Joliet file name is stored as UCS-2 (2 bytes a letter). The reader turns it
  into UTF-8 and then copies the result limited to the stored byte length. A letter of U+0800 and
  above takes 3 bytes in UTF-8, so a file name made mostly of such letters (Chinese, Japanese,
  Korean) loses its end - the extension, possibly part of a letter. Folder names take another path
  and are kept whole.

## Clarifications

### Session 2026-10-23

- Q: What happens with an HFS+ catalog whose structure (node size, start node, links, record table)
  does not fit what was loaded? → A: the HFS+ part is refused as damaged: an image that has only
  HFS+ shows an error and opens nothing; in a hybrid image the other file systems (ISO 9660 / UDF)
  open as today, as they already do when the HFS+ part cannot be read (autonomous run: item -
  "a crafted image is refused, never read out of bounds"; the hybrid behaviour is the existing one)
- Q: What happens with a single catalog record whose key, name or data does not fit its node,
  while the tree itself is sound? → A: that record is skipped, the others are listed - as feature 223
  skips a catalog name longer than its structure (autonomous run: conservative - keeps the existing
  behaviour for the rest of the volume, never reads past the node)
- Q: Is a catalog that is otherwise unusual but in bounds (a leaf node not marked as leaf, a record
  count in the header that differs from the nodes - known from MagicISO 5.2 images) refused? → A: no;
  only what would read outside the loaded catalog, or a walk that never ends, is refused
  (autonomous run: conservative - keeps compatibility with images that open today)
- Q: Which message tells the user an HFS+ catalog is damaged? → A: a new message of the plug-in
  naming the damaged catalog (an existing one would name another cause); translated by the
  run's `.slt` refresh (autonomous run: conservative - a refusal says what it refuses; rule 084 / §2.13)
- Q: Does this run do the fuzzing pass the item names? → A: no - this run does not generate
  mutated or damaged disk images; the bounds are proven by unit checks on catalogs built in memory
  (each one field out of range) and valid images keep working; the fuzzing pass is a deviation
  (stop-rules §2.14), recorded as an Inbox item for the maintainer (autonomous run: conservative -
  the item's main point, the bounds checks, is reached without it)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged or crafted HFS+ image is refused, never crashes (Priority: P1)

A user opens a disk image downloaded from somewhere. Its HFS+ catalog is damaged or made to point
outside itself. The program shows that the catalog is damaged (or, for a hybrid image, opens its
other file systems) and keeps running.

**Why this priority**: the item's main point; a crash or an endless walk loses the user's session.

**Independent Test**: unit checks give the catalog rule catalogs built in memory with one field out
of range each (start node, link, node size, record count, record offset, a link cycle, a short
catalog) - each is refused without a read outside the buffer; a valid HFS+ image still lists and
extracts in the program.

**Acceptance Scenarios**:

1. **Given** a catalog whose first leaf node lies outside it, **When** the rule walks it, **Then**
   it is refused as damaged.
2. **Given** a catalog whose leaf nodes link in a cycle, **When** the rule walks it, **Then** the
   walk ends (refused).
3. **Given** a catalog record whose key or data runs past its node, **When** it is listed, **Then**
   that record is skipped and the others are listed.
4. **Given** a valid HFS+ image (made by a standard tool), **When** the user opens it and extracts
   a file, **Then** listing and content are as before this feature.

### User Story 2 - Joliet file names are kept whole (Priority: P2)

A user opens a CD image made on Windows with Japanese or Chinese file names and extracts a file.
The file keeps its whole name with its extension.

**Why this priority**: data correctness - an extracted file under a cut name loses its extension
and may collide with another file.

**Independent Test**: an ISO 9660 + Joliet image holding files named with 12 CJK letters and an
extension; extract them; the names match the originals.

**Acceptance Scenarios**:

1. **Given** a Joliet image with a file named with 12 CJK letters + `.txt`, **When** the user
   extracts it, **Then** the extracted file has exactly that name and its content.
2. **Given** a Joliet image with ASCII names and folders, **When** listed and extracted, **Then**
   names are as before.

### Edge Cases

- Node size 0, larger than the catalog, or too small for its own descriptor and record table.
- A catalog shorter than the header node.
- A record offset pointing into the node descriptor, the record table or past the node.
- A record count so large the record table would not fit the node.
- A key length that runs past the node; a name length longer than the key.
- A folder / file record shorter than its structure (the listing and the extraction).
- A Joliet name containing letters outside the BMP (surrogate pairs) or lone surrogates (existing
  fallback stays).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The HFS+ reader MUST accept a node number (start node, link) only when the whole node
  lies inside the loaded catalog.
- **FR-002**: The node size MUST be large enough for the node descriptor and the record table it
  holds and no larger than the catalog; the header node MUST fit in the catalog.
- **FR-003**: Each record offset MUST point inside the node's record area (after the descriptor,
  before the record table), with room for the key length.
- **FR-004**: The leaf walk MUST end: a node visited twice (a cycle) refuses the catalog.
- **FR-005**: A structurally wrong catalog MUST refuse the HFS+ part with a message naming the
  damaged catalog (an HFS+-only image) or quietly (a hybrid, as today).
- **FR-006**: The listing, the volume name and the extraction MUST use a record only when its key,
  name and folder / file data lie inside its node; otherwise the record is skipped.
- **FR-007**: The catalog rule MUST be a pure, unit-tested decision: a valid catalog lists all its
  records, and each single field set out of range is refused.
- **FR-008**: A Joliet file name MUST be kept whole after its conversion to UTF-8.
- **FR-009**: Valid images (HFS+, ISO 9660, Joliet, Rock Ridge) MUST list and extract as before.

### Key Entities

- **Catalog**: the HFS+ B-tree of file and folder records, loaded whole into memory.
- **Node**: a fixed-size part of the catalog with a descriptor, records and a table of record offsets.
- **Joliet identifier**: a file name stored as UCS-2 big-endian bytes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every single-field case of the unit checks (start node, link, node size, record count,
  record offset, cycle, short catalog, key / name / data length) is refused or skipped; 0 failed checks.
- **SC-004**: 100% of the Joliet test files with CJK names are extracted under their whole names
  (before: cut).
- **SC-005**: The valid control images list and extract exactly as before (feature 223's probe rows
  still pass).

## Assumptions

- Assumption (autonomous run): the HFS+ reader stays the one it is (no extents-overflow support, no
  HFS); only bounds are added.
- Assumption (autonomous run): HFS+ test images are made by xorriso 1.5.6 (ISO 9660 + Joliet + HFS+
  hybrid) in the maintainer's WSL Ubuntu, fetched without root into `~/tc-xorriso`; Joliet images by
  Windows' IMAPI2; Rock Ridge images by xorriso. Without WSL the HFS+ / Rock Ridge rows are NOT DRIVEN.
- Assumption (autonomous run), deviation (stop-rules §2.14): the fuzzing pass over HFS+ / ISO 9660 /
  Joliet / Rock Ridge is not done by this run - it generates no mutated or damaged images; an Inbox
  item records it for the maintainer.
- Assumption (autonomous run): a memory blow-up by a catalog of very many deeply nested folders is
  not an out-of-bounds read and stays outside this item.
