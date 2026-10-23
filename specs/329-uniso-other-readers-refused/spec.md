# Feature Specification: UDF, Xbox, HFS+ and audio entries the panel listing refuses are left out and reported

**Feature Branch**: `329-uniso-other-readers-refused`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses` - "ISO plug-in: UDF, Xbox and HFS+ entries the listing refuses end their folder with Error". From backlog item iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses.

## Background (traced at aa939af0)

The panel listing of an archive takes a folder part, and a folder name, of at most MAX_PATH - 5 bytes
(feature 222). Feature 328 made the ISO 9660 reader of the ISO plug-in (`uniso`, on in the default
build) leave out an entry the listing refuses, name it in one report box per listing and make a
whole-image unpack of such a listing fail. The plug-in's other readers were left as they were:

- **UDF** (a UDF image, or the UDF part of a UDF + ISO 9660 hybrid): a refused entry shows "Error"; the
  rest of its folder is dropped and, from then on, no later folder of the walk is descended.
- **Xbox (XDVDFS)**: the same - "Error", the rest of the folder dropped, no later folder descended.
- **HFS+** (an HFS+ image, or the HFS+ part of a hybrid): "too long path", and every later record of
  the HFS+ catalog is dropped.
- **Audio tracks** (NRG images: a track named by its CD-Text label): a refused track name clears
  everything listed before it.

In every case the listing is not marked incomplete, so Unpack (Alt+F9) of the whole image with
"Delete archive after unpacking" extracts what was listed, reports success and the image is deleted.
The measurement with images (probe, before the fix) is recorded in `fix-log.md`.

## Clarifications

### Session 2026-10-23

- Q: What does the user see for a refused UDF / Xbox / HFS+ / audio entry? → A: what 328 shows for ISO
  9660: no "Error" / "too long path" box for it; the one report box per listing (the system's
  "(206)" text and up to 10 whole in-image paths, then `...`) also names these entries (autonomous
  run: item - *Expected* "as feature 328")
- Q: An HFS+ folder that is left out - what happens to its contents? → A: they are left out with it
  (never listed elsewhere, e.g. at the HFS+ root); only the folder is named in the report, as 328
  names a left-out folder once (autonomous run: item - "left out alone (a folder with its subtree)" of
  328's rule; conservative)
- Q: An entry the listing took by its rule but the core still refused (out of memory)? → A: as 328:
  the listing is kept, marked incomplete (a whole unpack fails); the plug-in's "Error" box is shown
  for it (autonomous run: item - "as 328")
- Q: Read errors of these readers (an unreadable folder or file entry)? → A: unchanged - the Inbox
  item `iso-plug-in-unpack-deletes-image-with-unreadable-folder` covers read errors (autonomous run:
  conservative - scope)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A deep UDF / Xbox / HFS+ image opens whole except what cannot be listed (Priority: P1)

A user opens a disc image whose UDF, Xbox or HFS+ tree holds an entry deeper than the panel listing
takes. Today the image opens with "Error" (or "too long path") and later folders (or the rest of the
HFS+ volume) missing. Now everything the listing can take is shown, and one box names what was left
out.

**Why this priority**: losing folders after a bare "Error" is the defect itself.

**Independent Test**: probe Copy rows for a UDF hybrid, an Xbox image and an HFS+ hybrid of the same
deep tree as 328 (`a<60>/b<60>/c<60>/d<60>/e<60>/deep.txt`, `a<60>/side.txt`, `top.txt`,
`zlast/z.txt`): open, Select All, Copy.

**Acceptance Scenarios**:

1. **Given** such an image, **When** it is opened, **Then** no "Error" / "too long path" box; one box
   with "(206)" and the whole in-image path of the left-out entry; `side.txt`, `top.txt`,
   `zlast\z.txt` of that file system are listed and copy out.
2. **Given** an HFS+ folder left out, **When** the image is listed, **Then** none of its contents
   appears anywhere in the listing.

---

### User Story 2 - Unpack + delete never deletes an image that was not wholly extracted (Priority: P1)

**Why this priority**: today the image is deleted after a partial unpack - data loss.

**Independent Test**: probe Unpack rows (Alt+F9, "Delete archive after unpacking") of the UDF and
Xbox images: the listed files extracted, the report shown, the image kept.

**Acceptance Scenarios**:

1. **Given** an image whose UDF / Xbox / HFS+ / audio listing left an entry out, **When** it is
   unpacked with "Delete archive after unpacking", **Then** every listed file is extracted, the
   report is shown, the image stays.
2. **Given** an image whose listing leaves nothing out, **When** unpacked the same way, **Then** the
   image is deleted as today.

---

### User Story 3 - An audio track with a too long name does not wipe the other tracks (Priority: P3)

**Independent Test**: probe row of a crafted NRG image of two audio tracks, the second labelled with
253 letters: the first track is listed, the second named in the report.

**Acceptance Scenarios**:

1. **Given** an NRG image whose second audio track's name the listing refuses, **When** it is
   opened, **Then** the first track is listed and the second is named in the report.

### Edge Cases

- A hybrid (ISO 9660 + UDF + HFS+): one report box for the whole listing covers every file system; no
  file system's entries are removed because of another's.
- A folder whose own name is taken but whose contents cannot be: the folder is listed, its contents
  left out and reported (UDF, Xbox) - HFS+ the same, each refused entry named.
- A reported path is never cut; the box lists at most 10 paths and then `...`.
- Nothing refused: the listing, its messages and the unpack are exactly as today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An entry of a UDF, Xbox (XDVDFS) or HFS+ volume that the panel listing refuses MUST be
  left out alone - a folder with its subtree: nothing listed before is removed, no "Error" / "too
  long path" box is shown for it, and every later entry and folder is listed and descended as usual.
- **FR-002**: An audio track whose name the listing refuses MUST be left out alone; the other tracks
  stay listed.
- **FR-003**: Every entry left out under FR-001 / FR-002 MUST be named in the listing's one report
  box (feature 328's report: the system's "(206)" text and the whole in-image paths, at most 10, then
  `...`); a path is never cut.
- **FR-004**: A whole-image unpack whose listing left entries out (any file system) MUST extract the
  listed entries and fail, so "Delete archive after unpacking" keeps the image.
- **FR-005**: An entry the listing's rule takes but the core still refuses (out of memory) MUST mark
  the listing incomplete (a whole unpack fails) without removing what was listed.
- **FR-006**: The contents of a left-out HFS+ folder MUST NOT appear in the listing.
- **FR-007**: A listing that leaves nothing out MUST be exactly as today.

### Key Entities

- **Left-out entry**: an entry the listing refused; its in-image path (with its file system's folder,
  e.g. `UDF (label)\...`) is reported and the image's whole unpack fails.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: the new probe's UDF, Xbox, HFS+ (and audio, when the crafted image opens) rows fail
  before the fix and pass after it.
- **SC-002**: features 328 (`iso328_probe`), 327 (`iso327_probe`) and 322 (`iso322_probe`) probes stay
  all PASS.
- **SC-003**: saltests keep 0 failed; the HFS+ subtree decision is covered by new checks.

## Assumptions

- Assumption (autonomous run): the report and its text are 328's - no new UI string, no translation
  refresh. The string "too long path" stays in the module (the conservative choice: removing a string
  needs the translation refresh and gains nothing).
- Assumption (autonomous run): read errors keep their handling (Inbox item
  `iso-plug-in-unpack-deletes-image-with-unreadable-folder`).
- Assumption (autonomous run): the audio row needs a crafted NRG image; if the plug-in does not open
  the crafted image the row is recorded NOT DRIVEN and the audio part rests on review (stop-rules
  §2.14).
