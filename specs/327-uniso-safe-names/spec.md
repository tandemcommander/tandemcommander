# Feature Specification: Every name the ISO plug-in lists is made safe before extraction

**Feature Branch**: `327-uniso-safe-names`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe` - "ISO plug-in: Joliet and ISO 9660 names are not made safe before extraction". From backlog item iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe.

## Background (measured at e50d62ad)

The ISO plug-in (`uniso`, on in the default build) lists a disc image in a panel and extracts its
files with F5. It reads names from six places of an image: plain ISO 9660 identifiers, Joliet
names, Rock Ridge names (made safe by feature 326), UDF names, HFS+ names and Xbox (XDVDFS) names;
a hybrid image is listed as one folder per file system named after its volume label
(`ISO (<label>)`, `UDF (<label>)`, `HFS (<label>)`). An image tool refuses names Windows cannot take,
but an image can hold any bytes there.

Measured on the Debug build of HEAD with the new probe `probe/iso327_probe.ps1` (hidden desktop,
crafted images: byte patches of placeholder names of IMAPI2 Joliet / UDF images and of an xorriso
plain ISO 9660 image, a hand-built Xbox image, an xorriso ISO 9660 + Rock Ridge + HFS+ hybrid with
Linux names, and a copy of it whose primary volume identifier is `v\..\..\w`) ->
`probe/result_before.txt`: **PASS 19, FAIL 39**.

- In every reader: `12:30...` became a file `12` with the data in an NTFS alternate stream; a name
  starting `con.` was created as it is (a device name); a name ending in dots was created with its
  dots (a file Windows tools cannot open or delete by name); a name with `/` and a name or folder
  `..\..\x` failed with "Error Creating File (3)" and were lost (HFS+ alone already maps `\` to `_`).
- VOL: the volume label folder `ISO (v\..\..\w)` made the whole set be written to `<row>\w)\set\...`
  - outside the target folder.

## Clarifications

### Session 2026-10-23

- Q: Which rule makes a name safe? → A: feature 087's rule for one name (the rule feature 326
  applies to Rock Ridge names): every control character, `\`, `/`, `:`, `<`, `>`, `"`, `|`, `?`, `*`
  becomes `_`; trailing dots and spaces become `_`; a reserved device name (`con`, `prn`, `aux`,
  `nul`, `com1`-`com9`, `lpt1`-`lpt9`, also with an extension) gets a `_` prefix; an empty name
  becomes `_`. A separator inside a name is a character of that name, not a path step - these file
  systems store one name per entry (autonomous run: item - "made safe as feature 087 does";
  rule - feature 326's per-name form)
- Q: What if the `_` prefix of a device name does not fit the name's buffer? → A: the name's first
  character (an ASCII letter of the device name) becomes `_` instead - the name keeps its length,
  is never cut and never dropped (autonomous run: item - "renamed, never dropped; never a cut name";
  conservative)
- Q: Are the volume label folders of a hybrid image included? → A: yes - they are names the plug-in
  lists (folders every file of that file system is extracted into); the whole folder name
  `ISO (<label>)` is made safe by the same rule (autonomous run: item - "every name the ISO plug-in
  lists, from any of its readers")
- Q: Does HFS+ keep its own existing cleaning (trailing spaces removed, a trailing `/` removed,
  `\` `?` `*` and control characters to `_`)? → A: yes, unchanged; the shared rule runs after it
  (autonomous run: conservative - keeps the existing behaviour for every case the item does not
  name)
- Q: Is the listed name cleaned again when a file is extracted? → A: yes - each reader's extraction
  joins the target path with the listed name passed through the same rule once more (a no-op for a
  name the listing already cleaned; it guards a name that reaches extraction another way) (autonomous
  run: rule - CLAUDE.md "Archive item names are cleaned at listing and again at extraction", 087)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Extracting a crafted image never writes outside the target or into a stream (Priority: P1)

A user opens a disc image someone else made and extracts files with F5. Whatever names the image
stores, every file lands inside the chosen target folder under a name Windows takes as it is.

**Why this priority**: an image is untrusted input; a name that leaves the target folder or hides data
in a stream is what feature 087 forbids for every archive.

**Independent Test**: the probe's sets JOLIET, PLAIN, UDF, XBOX and HFS - each extracts a folder
holding unsafe names and checks the safe names, nothing outside the folder, no streams.

**Acceptance Scenarios**:

1. **Given** a Joliet image holding `..\..\jesc.txt`, `12:30jaaa.txt`, `con.txtjaaa`,
   `jtrailaaaaa..`, `j/slasha.txt` and a folder `..\..\jd`, **When** its folder is extracted,
   **Then** the files are `.._.._jesc.txt`, `12_30jaaa.txt`, `_con.txtjaaa`, `jtrailaaaaa__`,
   `j_slasha.txt` and `.._.._jd\inner.txt`, each with its content, all inside the extracted folder,
   no alternate stream.
2. **Given** the same unsafe names as plain ISO 9660 identifiers, UDF names, Xbox names or HFS+
   names, **When** extracted, **Then** the same safe forms result.
3. **Given** an ordinary name (`top.txt`, `TOP.TXT`), **When** extracted, **Then** it is unchanged.

---

### User Story 2 - A hybrid image's volume label cannot steer files elsewhere (Priority: P1)

A hybrid image is listed as one folder per file system named after its volume label. A label with
`\..\` or `:` must not move the files out of the target or into a stream.

**Why this priority**: measured - the label moved the whole set outside the target folder.

**Independent Test**: the probe's set VOL - the folder `ISO (v_.._.._w)` holds the set, nothing is
written outside it.

**Acceptance Scenarios**:

1. **Given** a hybrid whose primary volume identifier is `v\..\..\w`, **When** its ISO folder is
   extracted, **Then** the target holds `ISO (v_.._.._w)\set\...` and nothing outside it.

### Edge Cases

- Two names that differ only in characters the rule replaces (`a:b`, `a_b`) end at the same name:
  the usual overwrite question appears (feature 087's accepted class); nothing is lost silently.
- A device name whose `_` prefix does not fit the buffer: its first character becomes `_`.
- A name that is entirely dots (`..` stored as a Joliet name) becomes `__`; the records `.` and `..`
  of the directory itself (identifiers 0 and 1) stay skipped as before.
- Rock Ridge names keep feature 326's handling; the names the plug-in generates itself (boot images
  `s01-bootdisk...ima`, audio tracks, `Session NN`) contain no unsafe characters and are unchanged.
- The rule keeps every byte of 0x80 and above: a multi-byte UTF-8 letter is never split or changed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every file and folder name the ISO plug-in lists from plain ISO 9660 identifiers and
  from Joliet names MUST be made safe by the rule of the Clarifications before it is listed, and the
  same safe name MUST be used for the folder path the plug-in descends with.
- **FR-002**: The same MUST hold for UDF names, HFS+ names (after its existing cleaning) and Xbox
  (XDVDFS) names.
- **FR-003**: The volume label folders of a hybrid image (`ISO (<label>)`, `UDF (<label>)`,
  `HFS (<label>)`) MUST be made safe as one name.
- **FR-004**: A name MUST never be cut and never dropped by the rule; a name already safe MUST stay
  byte for byte as it was.
- **FR-005**: The rule MUST be a pure function in a header under `src/common/` with unit checks
  (stop-rules §2.5); feature 326's Rock Ridge rule keeps its exact behaviour.
- **FR-006**: Extraction (F5, unpack whole archive) MUST use the listed (safe) names, as it does for
  Rock Ridge names, and each reader's extraction MUST pass the file name through the same rule again
  before joining it to the target path: no name from the image reaches a target path uncleaned.

### Key Entities

- **Listed name**: one component of a path inside the image as the panel shows it and extraction
  writes it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe `iso327_probe.ps1` goes from 39 FAIL rows (before) to 0 FAIL rows on the
  fixed build; every NAME, OUTSIDE and STREAMS row PASS.
- **SC-002**: Feature 326's probe (`iso326_probe.ps1`, 28 rows) and feature 322's probe
  (`iso322_probe.ps1`, 18 rows) still pass on the fixed build.
- **SC-003**: The unit checks of the rule pass and fail when any one of its parts (separators, colon,
  trailing dot, device prefix, the prefix-does-not-fit fallback) is removed (negative control).

## Assumptions

- Assumption (autonomous run): extraction uses the names of the listing only (confirmed for Rock Ridge
  by feature 326's review: `UnpackArchive`, `UnpackOneFile`, `ExtractAllItems`); cleaning at the
  listing covers every extraction path of the plug-in.
- Assumption (autonomous run): the side observations of the measurement (the message "Cannot read
  sector #00000020" when an xorriso HFS+ hybrid is opened; "Detected memory leaks!" boxes at exit
  after the HFS set, Debug build) are outside this item - recorded as Inbox items if they persist on
  the fixed build.
- The item's note that Joliet needs a crafted image holds: every set uses a crafted or patched image.
