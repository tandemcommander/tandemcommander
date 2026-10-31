# Research - 353-uniso-noccd-sessions

## R1 How to tell "more than listed" cheaply

- Decision: compare the listed volume's size (primary volume descriptor, volume space size, bytes
  80..83 little-endian and 84..87 big-endian, logical block size 2048 at 128..129 / 130..131) with the
  whole sectors the file holds past the opened layout's data offset.
- Rationale: one read of 88..132 bytes; needs no knowledge of where a later session lies. A later
  session cannot be within the listed volume (the volume space size of the first session covers that
  session only) - it must be past it.
- Alternatives: scanning the rest of the file for a sync + `CD001` (reads the whole image on every
  open, 700 MB for a CD); reading the sessions without a `.ccd` (a new reader - larger than the item,
  belongs with the track-table item).

## R2 The tolerance past the volume

- Decision: 16 sectors. A later volume's descriptor is at its own sector 16, so a file whose rest past
  the volume is 16 sectors or fewer cannot hold one; 17 or more is marked.
- Rationale: fails closed (CLAUDE.md *Never lose the user's data*). Track-at-once run-out (2 sectors) is
  within it. Measured: genisoimage's 150-sector pad is inside the volume space size (s1.iso 176 / 176).
- Alternatives: 152 (post-gap 150 + run-out 2) or a minimum track length of 300 sectors - would let a
  small later session (crafted, or a dump without gaps) be deleted. Rejected; such single-session dumps
  are kept instead (spec Assumptions).

## R3 Which images

- Decision: only when the `.ccd` could not be opened (missing; also unreadable) and `DetectSectorType`
  found the sync pattern at sector 0 (`SectorType != stISO` right after it), whichever plain check
  then opened the image.
- Rationale: CloneCD writes raw 2352-byte sectors; a 2048-byte `.img` is a disk image (spec, item).
- A refused `.ccd` is already marked by 352; a valid `.ccd` takes the track-table path - unchanged.

## R4 Volume size not readable

- Decision: marked (fails closed): no type-1 descriptor with `CD001` at sector 16 of the opened layout,
  a short read, the two copies of the size differing, a logical block size other than 2048.
- Rationale: refuse rather than guess (stop-rules §1 step 4).

## R5 Where the mark lives

- `CISOImage::ListingLeftOut.SetIncomplete()` in `Open` (as 352's refused `.ccd`, set in
  `ReadSessionCCD` during `Open`); `ListArchive` copies it to `pd->ListingLeftOut`; `UnpackArchive`
  fails a whole unpack of such a listing (feature 328). Consumers of `Open` that do not list (unpack of
  one file, viewer info) ignore the mark.
