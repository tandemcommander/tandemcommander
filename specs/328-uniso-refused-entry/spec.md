# Feature Specification: An ISO entry the panel listing refuses is left out and reported, never wiping the listing

**Feature Branch**: `328-uniso-refused-entry`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing` - "ISO plug-in: an entry the listing refuses ends the listing with Error, a folder lost". From backlog item iso-plug-in-an-entry-the-listing-refuses-ends-the-listing.

## Background (measured at d61d0612)

The panel listing of an archive takes a folder part of at most MAX_PATH - 5 bytes (feature 222,
`sallistingname.h`). The ISO plug-in (`uniso`, on in the default build) adds every entry of an ISO
9660 volume (plain ISO 9660, Joliet or Rock Ridge names) to that listing; when the listing refuses
one, the plug-in shows "Error", clears everything it had listed and goes on - and after that error
it no longer descends into later folders.

Measured on the Debug build of HEAD with the new probe `probe/iso328_probe.ps1` (hidden desktop;
seed images made in WSL by genisoimage and xorriso from one tree:
`a<60>/b<60>/c<60>/d<60>/e<60>/deep.txt` - a Rock Ridge / Joliet folder part of 305 bytes -,
`a<60>/side.txt`, `top.txt`, `zlast/z.txt`) -> `probe/result_before.txt`: **PASS 0 of 6 rows**.

- genisoimage `-R` (every record starts with `RR`, the root carries `SP`), the same image without
  `SP`, and genisoimage `-J` (Joliet): "UnISO: Error" at the open; the listing holds only
  `a<60>\side.txt` and `top.txt` - the deep tree and `zlast\z.txt` are gone. Feature 326's fallback
  to ISO 9660 names only switches the `SP` detection off; `RR` records still give the Rock Ridge
  names.
- xorriso (Rock Ridge 1.12): no message, but the whole volume is listed under its ISO 9660 names
  (`TOP.TXT`, `A<31 letters>`) because one entry did not fit (feature 326, FR-009).
- Unpack (Alt+F9) with "Delete archive after unpacking" of the Joliet and the genisoimage image:
  "Error", two of the four files extracted, and the **image deleted** - the whole-image unpack
  extracts what the listing holds and reports success.

## Clarifications

### Session 2026-10-23

- Q: Rock Ridge names that would be refused - list the whole volume under ISO 9660 names (326), or
  keep Rock Ridge names where they fit? → A: keep them where they fit: a folder is listed under its
  Rock Ridge name unless that lists fewer entries of its subtree than its ISO 9660 name would (the
  deeper levels then decide again); a file is listed under its Rock Ridge name when the listing
  takes it, else under its ISO 9660 name. Never fewer entries than 326's whole-volume ISO 9660
  listing (autonomous run: item - *Expected* "a Rock Ridge tree keeps its names where they fit",
  "or the deep part is reachable another way"; 326's clarification left "a better partial listing"
  to this item)
- Q: How does the user learn which entries were left out? → A: as TAR since feature 321: once per
  listing, an error box with the system's text for a name that is too long ("(206)") followed by
  the whole in-image paths of the left-out entries (up to 10, then `...`); no new UI string
  (autonomous run: item - *Notes* name 321 as the model)
- Q: Unpack of the whole image (Alt+F9) when the listing left entries out? → A: everything listed
  is extracted, the report is shown, and the operation fails - "Delete archive after unpacking"
  keeps the image (autonomous run: rule - CLAUDE.md "a safe to delete? check fails closed", 098)
- Q: The UDF, Xbox (XDVDFS), HFS+ and audio readers have the same kind of refusal handling (an
  "Error" box, the rest of the folder or the whole file system lost) - fixed here? → A: no; the
  item names the ISO 9660 reader. They are an Inbox item (autonomous run: conservative - scope)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A deep image opens whole except what cannot be listed (Priority: P1)

A user opens a disc image (genisoimage, Joliet, an `RR` image without `SP`) whose deepest folder
lies deeper than the panel listing takes. Today the image opens with an "Error" box and most of the
tree missing. Now everything the listing can take is shown, and one box names what was left out.

**Why this priority**: losing whole folders silently (after a bare "Error") is the defect itself.

**Independent Test**: probe rows J-COPY, G-COPY, L-COPY: open the image, Select All, Copy.

**Acceptance Scenarios**:

1. **Given** a Joliet image with a 305-byte folder part above `deep.txt`, **When** it is opened,
   **Then** no "Error" box, one box with "(206)" and the whole path of `deep.txt`; `side.txt`,
   `top.txt`, `zlast\z.txt` are listed and copy out.
2. **Given** an entry left out inside folder X, **When** the image is listed, **Then** the entries
   after it - in X and in every later folder - are listed as usual.

---

### User Story 2 - Unpack + delete never deletes an image that was not wholly extracted (Priority: P1)

**Why this priority**: today the image is deleted after a partial unpack - data loss.

**Independent Test**: probe rows J-UNP-DEL (left-out entry: image kept, "(206)" shown, the rest
extracted) and G-UNP-DEL (nothing left out: all four files, image deleted).

**Acceptance Scenarios**:

1. **Given** an image whose listing leaves an entry out, **When** it is unpacked with "Delete archive
   after unpacking", **Then** every listed file is extracted, the report is shown, the image stays.
2. **Given** an image whose listing leaves nothing out, **When** unpacked the same way, **Then** the
   image is deleted as today.

---

### User Story 3 - A deep Rock Ridge tree keeps its names where they fit (Priority: P2)

**Independent Test**: probe rows G-COPY, X-COPY, L-COPY: all four files copy out; `top.txt`,
`zlast\z.txt`, `a<60>\side.txt` under their Rock Ridge names; `deep.txt` below
`a<60>\b<60>\c<60>` (the deeper folders under their ISO 9660 names).

**Acceptance Scenarios**:

1. **Given** an xorriso image whose Rock Ridge tree is too deep, **When** opened, **Then** no message;
   the shallow names are the Rock Ridge ones, only the folders that must be shorter carry ISO 9660
   names, and `deep.txt` is listed (as 326 listed it).

### Edge Cases

- A folder whose own name is taken but whose contents cannot be (its folder part would exceed the
  bound under both names): the folder is listed, its contents are left out and reported.
- An entry with no ISO 9660 alternative (Joliet, a record without Rock Ridge): left out and reported.
- A multi-session image listed as session folders, a hybrid: the report covers every ISO 9660 volume
  of the listing; other file systems' entries are never removed.
- A reported path is never cut; the box lists at most 10 paths and then `...`.
- Names are cleaned as features 326 / 327 clean them, under either name.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An entry of an ISO 9660 volume (plain, Joliet, Rock Ridge) that the panel listing
  refuses MUST be left out of the listing alone: nothing listed before is removed, no "Error" box
  is shown for it, and every later entry and folder is listed and descended as usual.
- **FR-002**: When a listing left entries out, the user MUST see one error box per listing with the
  system's "file name too long" text (206) and the whole in-image paths of the left-out entries (at
  most 10, then `...`); a path is never cut.
- **FR-003**: A whole-image unpack whose listing left entries out MUST extract the listed entries
  and fail, so "Delete archive after unpacking" keeps the image; with nothing left out it behaves
  as today.
- **FR-004**: A Rock Ridge entry MUST keep its Rock Ridge name where it fits - the listing takes it
  and the panel's operations reach it from the image's root (an in-image path below MAX_PATH bytes,
  as the core's Copy from an archive needs; measured in the first after run): a file under its Rock
  Ridge name when that fits, else its ISO 9660 name when that fits, else the first name the listing
  takes, else left out (FR-001); a folder under its Rock Ridge name unless its ISO 9660 name lets
  more entries of its subtree fit or be listed. The listing MUST hold no fewer entries, and no fewer
  that fit, than feature 326's whole-volume ISO 9660 listing.
- **FR-005**: A volume whose Rock Ridge names all fit is listed exactly as today (one check pass,
  then the listing); a volume without Rock Ridge names keeps its names.
- **FR-006**: Names are never cut; the cleaning of features 326 / 327 applies to either name.

### Key Entities

- **Left-out entry**: an entry of the image the listing refused under every name it has; its
  in-image path is reported and the image's whole unpack fails.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: probe `iso328_probe.ps1` 0 / 6 -> 6 / 6 (before / after).
- **SC-002**: features 326 (`iso326_probe`, 28 rows), 327 (`iso327_probe`, 77 rows) and 322
  (`iso322_probe`, 18 rows) probes stay all PASS (326's DEEP row: `deep.txt` still extracted).
- **SC-003**: saltests keep 0 failed; the pure naming decision is covered by new checks.

## Assumptions

- Assumption (autonomous run): the report reuses the system error text (as TAR 321) - no new UI
  string, no translation refresh.
- Assumption (autonomous run): a name collision between a sibling's Rock Ridge name and another
  entry's ISO 9660 fallback name is not resolved (rare; the core lists both; an extraction asks
  before overwriting) - recorded as a limit.
- Assumption (autonomous run): the extra check walks happen only for a volume whose Rock Ridge
  names do not all fit; their cost (each directory read again per level) is accepted.
