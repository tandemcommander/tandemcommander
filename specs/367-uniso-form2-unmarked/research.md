# Research - 367-uniso-form2-unmarked

## R1 Read whole or fail closed?

- Decision: read whole, decided per sector by its subheader (the item's first alternative).
- Rationale: every case is decidable at listing - the subheaders are in the image; an unreadable sector counts as
  2048 and its read fails at unpack (338's tally keeps the image). It removes the cut instead of only keeping the
  image, and needs no maintainer decision (the item's Note asks for the decision item before the fail-closed
  variant; reading whole is that item's option C).
- Alternatives: the reviewer's "a non-Form-2 file in a stream track adds no span" (fail closed) - keeps the image
  but still extracts the file cut, and is the variant the open decision governs.

## R2 Which files are examined?

- Decision: not 366's Form 2 files; on a track that stores Form 2 data; length > 0; and one of: starts in a
  Form 2 stream track, XA Form 2 bit (also mixed), first sector Form 2.
- Rationale: covers the three named shapes (C-NOXA: first sector Form 2 and in a stream; C-MIXED: Form 2 bit;
  C-F1SUB: Form 2 bit and in a stream) also in a raw .bin without a track table (plain detection, no stream
  track). A plain Mode 2 Form 1 disc (PlayStation-like, CD-ROM XA multisession) pays one 24-byte read per file -
  a scan of every sector of every file would read the whole image at every listing.
- Limit: a file outside a stream track with a Form 1 first sector and no Form 2 bit (crafted) is not examined.

## R3 What does a mixed file contain?

- Decision: the concatenation of each sector's user data - 2324 bytes of a Form 2 sector, 2048 of any other, the
  record's remainder of a last non-Form-2 sector.
- Rationale: all user data of every sector, no subheaders, no EDC/ECC (a Form 1 sector's last 288 bytes are its
  EDC/ECC); the item's Expected.

## R4 Which sectors does an examined file cover?

- Decision: the leading run of sectors read whole - Form 2, or Form 1 not cut by the record's end; it stops at the
  first unknown sector (a damaged subheader cannot tell a Form 1 sector from a Form 2 one: its 276 bytes may be
  lost).
- Rationale: fails closed (the clarification); feature 337's gap check then reads the rest of the stream - a
  damaged sector holding data marks the listing, the image is kept. A Form 1 sector's 2048 bytes are all its user
  data, so it counts as whole (C-F1SUB must not keep the image: its first sector is a valid Form 1 sector).
- Alternative: count every examined sector (as main) - would let a damaged sector's bytes go with the image.

## R5 Sector form classes

- Decision: `SalIsoSectorForm` - the 335 validity checks; valid + Form bit = Form 2, valid without = Form 1, else
  unknown. `SalIsoSectorIsForm2` keeps its exact meaning.
- Note: in a 2336-byte layout a zero-filled sector has a valid all-zero subheader (Form 1) - it reads 2048 zero
  bytes, and its uncounted payload bytes are zero too.
