# Feature Specification: The ISO plug-in reads Rock Ridge names of images that carry no `RR` entry (xorriso, RRIP 1.12)

**Feature Branch**: `326-uniso-rrip-without-rr`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read` - "ISO plug-in: Rock Ridge names of xorriso images are not read, the ISO 9660 names are listed". From backlog item iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read.

## Background (measured at 2c033750)

Traced at HEAD with the default configuration (`uniso=on`): opening an `.iso` image in a panel
lists it through the ISO plug-in; an image without Joliet is listed from its ISO 9660 directory
records. For each record the plug-in looks at the first entry of the record's System Use area: only
when that entry is `RR` does it read the Rock Ridge name (`NM`, followed into a continuation area
`CE` since feature 223). Otherwise the plain ISO 9660 name is listed - upper case, at most 31
letters, with the version suffix removed.

Rock Ridge 1.12 (RRIP 1.12) dropped the `RR` entry. xorriso / libisofs 1.5.6 - the tool most Linux
distributions build their images with - never writes it (measured: not even with
`-compliance old_rr`). Its images carry, in the root directory's first record (`.`), the SUSP
`SP` entry (length 7, check bytes `BE EF`, LEN_SKP 0), then `PX`, `TF`, `CE`; the continuation area
holds the `ER` entry `RRIP_1991A`. Every other record carries `PX`, `TF`, `NM` (and `CE` for a long
name). genisoimage writes `SP`, `ER` and, in every record, a first entry `RR`.

Measured on the Debug build of HEAD with feature 322's probe (`iso322_probe.ps1`, hidden desktop):
row RR - `top.txt` of an xorriso Rock Ridge image is listed and extracted as `TOP.TXT`; row RR-LONG -
a file of a 200-letter Rock Ridge name is extracted under a 31-letter upper-case ISO 9660 name.

## Clarifications

### Session 2026-10-23

- Q: By what does the plug-in recognise that a volume uses Rock Ridge when no `RR` entry exists?
  → A: by the SUSP `SP` entry at the start of the System Use area of the root directory's first
  record (`.`): signature `SP`, length 7, version 1, check bytes `BE EF`. SUSP requires it on every
  volume that uses System Use entries, and `NM` (the name) is defined only by Rock Ridge; this is
  how the Linux kernel recognises Rock Ridge. The `ER` entry is not required (it may lie in a
  continuation area, and the kernel does not require it either) (autonomous run: item - "the `SP` /
  `ER` of the root directory's first record"; conservative - the one mandatory marker)
- Q: Do images whose records start with `RR` but carry no `SP` keep working? → A: yes - a record
  whose first entry is `RR` is read as Rock Ridge exactly as today, with or without `SP`
  (autonomous run: item - "images with `RR` keep working")
- Q: What does the plug-in do with the `SP` entry's LEN_SKP (bytes to skip at the start of every
  other System Use area)? → A: when `SP` was found, the reader skips LEN_SKP bytes at the start of
  each record's System Use area before reading entries; a LEN_SKP that leaves no room for an entry
  means no Rock Ridge name for that record (the plain name). Without `SP` nothing is skipped (today's
  behaviour) (autonomous run: conservative - follows SUSP 1.12, never reads past the record)
- Q: Does a Joliet image now show Rock Ridge names? → A: no - when the image has a Joliet tree the
  plug-in keeps listing the Joliet tree, as today (autonomous run: conservative - keeps the existing
  behaviour for every case the item does not name)
- Q: What happens with a broken or cut Rock Ridge name in an image recognised by `SP`? → A: the
  same as for `RR` images since feature 223: the plain ISO 9660 name is listed, never a cut name
  (autonomous run: rule - "a path or name is never cut", feature 223)
- Q: Is an `SP` entry looked for anywhere but at the very start of the root's `.` System Use area
  (CD-XA images put a 14-byte XA record first)? → A: no - only at the start, as SUSP 1.12 places it;
  CD-XA images keep today's behaviour (autonomous run: conservative - the item does not name CD-XA;
  today `RR` is looked for only at the start too)
- Q (review 1, MUST): a Rock Ridge name may hold `..\`, `:`, a trailing dot or a device name - is
  it listed as it is? → A: no - it is cleaned as feature 087 cleans archive names (FR-008); the
  ISO 9660 and Joliet names keep today's handling (an Inbox item) (autonomous run: rule - CLAUDE.md
  "archive item names are cleaned at listing and again at extraction", 087)
- Q (review 1): a deep tree of Rock Ridge names passes the folder part the listing takes; the
  plug-in then shows "Error" and loses the folder, where the ISO 9660 names listed it whole - what
  happens? → A: such a volume is listed as before this feature (FR-009), decided by a check pass
  with the listing's own rule before anything is added; a better partial listing is an Inbox item
  (autonomous run: conservative - never worse than before for an image that opened)
- Q (review 2, partial work of a stopped reviewer): Rock Ridge names keep their case - two names of
  one folder that differ only in case were merged / both acted on by the panel (feature 252's
  defect, which the ISO plug-in did not have while its names were upper case) - what happens?
  → A: the ISO plug-in builds its listing as TAR and 7-Zip do since 252 (FR-010) (autonomous run:
  rule - feature 252's rule for archive listings; "never lose the user's data")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Files of an xorriso Rock Ridge image keep their names (Priority: P1)

A user opens a Linux image made with xorriso (no Joliet) and copies a file out of it. The file is
listed and extracted under its Rock Ridge name - lower case and whole - not under the upper-case
8.3-like ISO 9660 name.

**Why this priority**: the item's main point; names lose case and length, two files can collide.

**Independent Test**: open xorriso's `rr.iso` (folder `folder`, file `top.txt`) and `rrlong.iso`
(one file of a 200-letter name) in the program, extract the file to the other panel.

**Acceptance Scenarios**:

1. **Given** an xorriso image with Rock Ridge and without Joliet holding `top.txt`, **When** the
   user opens it and copies the file out, **Then** the panel lists `top.txt` and the extracted file
   is `top.txt` with its content.
2. **Given** an xorriso image holding a file of a 200-letter Rock Ridge name (the name continues in
   a continuation area), **When** the user extracts it, **Then** it is extracted under exactly that
   200-letter name with its content.
3. **Given** the same image, **When** the user opens a folder, **Then** the folder's name is its
   Rock Ridge name (`folder`, not `FOLDER`).

---

### User Story 2 - Images that worked keep working (Priority: P2)

Images with an `RR` entry (genisoimage), plain ISO 9660 images and Joliet images list and extract
as before.

**Why this priority**: the item requires it; a regression would rename files in images that work
today.

**Independent Test**: the pure detection rule checked with System Use areas built in memory
(with `RR`, with `SP`, with neither, with a damaged `SP`); a plain xorriso image (`-rockridge off`)
and a Joliet image still extract under their names in the program.

**Acceptance Scenarios**:

1. **Given** a record whose first System Use entry is `RR`, **When** it is listed, **Then** its
   `NM` name is used (with or without `SP` on the volume).
2. **Given** a plain ISO 9660 image (no System Use entries), **When** it is listed, **Then** the
   ISO 9660 names are listed as before (`TOP.TXT`).
3. **Given** an image with Joliet, **When** it is listed, **Then** the Joliet names are listed as
   before.

### Edge Cases

- An `SP` entry with wrong check bytes or wrong length: not recognised; records are read as today
  (only `RR` enables Rock Ridge).
- An `SP` entry with a LEN_SKP larger than a record's System Use area: that record gets its plain
  ISO 9660 name.
- The root directory cannot be read when the image is opened: no `SP` is recognised; the listing
  then reports the read error as today.
- A recognised volume whose record has no `NM` entry: the plain ISO 9660 name.
- A damaged `NM` / `CE` chain in a recognised volume: the plain ISO 9660 name (feature 223), never a
  cut name.
- A record of the root directory's `.` / `..` entries: not listed (as today).
- A CD-XA image (an XA record before the `SP` entry): `SP` is not recognised; today's behaviour.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the image is not read through its Joliet tree, the plug-in MUST recognise a
  volume as using System Use entries when the System Use area of the root directory's first record
  starts with a valid `SP` entry (signature `SP`, length at least 7, check bytes `BE EF`).
- **FR-002**: On such a volume the plug-in MUST read the Rock Ridge name (`NM`, continued in `CE`
  areas as since feature 223) of every directory record, whatever its first entry is, after
  skipping the `SP` entry's LEN_SKP bytes at the start of each record's System Use area.
- **FR-003**: A record whose first System Use entry is `RR` MUST keep being read as Rock Ridge on
  every volume, as today.
- **FR-004**: On a volume without a valid `SP`, a record whose first entry is not `RR` MUST keep its
  plain ISO 9660 name, as today.
- **FR-005**: A Rock Ridge name MUST be listed and extracted whole, with its case; a name that
  cannot be read whole MUST fall back to the plain ISO 9660 name, never a cut name.
- **FR-006**: No read MAY go past a record's System Use area or the sector read for a continuation
  area; a LEN_SKP that leaves no room for an entry MUST give the plain name.
- **FR-007**: The decision "is this System Use area an `SP` entry, and what is its LEN_SKP" and
  "where does the entry parsing of a record start" MUST be a pure rule with unit checks.
- **FR-008** (review 1): every Rock Ridge name (file or folder) MUST be made safe for Windows
  before it is listed, as feature 087 cleans archive item names: control characters, `\`, `/`,
  `:`, `<`, `>`, `"`, `|`, `?`, `*` become `_`; trailing dots and spaces become `_`; a reserved
  device name gets a `_` prefix; an empty name becomes `_`. Nothing is written outside the target
  folder or into a stream. A name the cleaning cannot hold falls back to the plain ISO 9660 name.
  The cleaning works on the UTF-8 name the listing shows, after a legacy code page name was
  converted (review 2: on the raw bytes a Shift-JIS second byte 0x5C or 0x7C changed the letter).
- **FR-009** (review 1): a volume recognised by `SP` whose Rock Ridge names the panel listing would
  refuse (a folder part over its bound) MUST be listed with the names it had before this feature
  (ISO 9660 names, `RR` records as before) - never an error and a lost folder where the image
  opened whole before.
- **FR-010** (review 2): an image whose names differ only in case in one folder (`a.txt` / `A.txt`,
  folders `D` / `d` - possible with Rock Ridge names, never with upper-case ISO 9660 names) MUST be
  listed case-sensitively as TAR and 7-Zip are since feature 252 (`salcasetwins.h`): the selected
  twin, and only it, is hidden, restored and copied; folders `D` and `d` stay two folders. Without
  twins the listing is the case-insensitive one it was.

### Key Entities

- **System Use area**: the bytes of a directory record after its name (and padding byte), holding
  SUSP entries (signature, length, version, data).
- **`SP` entry**: the SUSP indicator in the root directory's first record; tells the volume uses
  SUSP and how many bytes to skip in every other System Use area.
- **Rock Ridge name**: the `NM` entries of a record (possibly continued in a continuation area).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An xorriso Rock Ridge image lists and extracts `top.txt` (not `TOP.TXT`) and the
  folder `folder`; a 200-letter Rock Ridge name is extracted with all 200 letters.
- **SC-002**: Images that opened before (plain ISO 9660, Joliet, HFS+ and the rows of feature 322's
  probe) list and extract the same names as before.
- **SC-003**: The unit checks of the detection rule pass, and each fails when its rule is broken
  (negative control).

## Assumptions

- Assumption (autonomous run): the GUI proof uses xorriso images made in WSL (feature 322's
  `mkimg322.sh`); a genisoimage image (with `RR`) needs Docker, which is not running - the `RR` path
  is proven by the unit rule and by its code being unchanged; when Docker is not available the
  probe row of feature 223 (`RR-LONG` with genisoimage) is recorded NOT DRIVEN as in feature 322.
- The probe rows of feature 322 that expected the ISO 9660 name (`RR` → `TOP.TXT`, `RR-LONG`
  "the Rock Ridge name used False") change their expectation with this feature.
- No UI string, dialog or menu changes; no translation refresh is needed.
- Out of scope: the xorriso hybrid image's "Cannot read sector #00000020." (its own Inbox item from
  feature 322); Rock Ridge data other than the name (permissions, symbolic links, times).
