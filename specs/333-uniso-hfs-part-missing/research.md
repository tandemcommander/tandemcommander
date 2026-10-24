# Research - 333-uniso-hfs-part-missing

## R1 What declares an HFS+ part

- **Decision**: the volume header read 1024 bytes into the HFS part (the place `CHFS::Open` reads it:
  the start of the last `Apple_HFS` partition of an Apple partition map, or the image start) - its
  signature "H+", or "BD" (an HFS wrapper) whose master directory block's `drEmbedSigWord` (byte 124)
  is "H+".
- **Rationale**: measured at e9f777da - `DetectTrackFS` takes "ER" at sector 0 as an HFS part, and
  Ubuntu / Debian style install images (`xorriso -isohybrid-mbr -isohybrid-apm-hfsplus`) carry "ER"
  and an `Apple_HFS` partition named "EFI" that holds the FAT EFI image - no HFS+ volume. Their HFS
  part does not open; marking on "ER" / `Apple_HFS` would make every such image's whole unpack fail.
  The volume's own signature is what only an HFS+ volume writes.
- **Alternatives considered**: the track type (`fs*_HFS`) as 330's `HasISO` / `HasUDF` - rejected
  (true for the APM install images); the `Apple_HFS` partition name ("HFSPLUS_Hybrid" from xorriso) -
  rejected (tool-specific); marking every failure - rejected (above).

## R2 Which failures after the signature mark

- **Decision**: all - the version is not 4, the wrapper's embedded header does not read or is not HFS+,
  the catalog is refused by 322's walk, empty, fragmented beyond 8 extents, cannot be read, out of
  memory.
- **Rationale**: in each case an HFS+ volume is there and none of its files is listed; fail closed
  (CLAUDE.md). A valid volume with more than 8 catalog extents would now be kept by Unpack + delete
  instead of being deleted with its files unlisted - the safe side.
- **Alternatives considered**: only "damaged" failures - rejected, the user loses the same files.

## R3 Not declared: APFS, original HFS, HFSX, destroyed signature, unreadable header

- **Decision**: unchanged (dropped without a mark).
- **Rationale**: the item reserves APFS for its own decision; original HFS ("BD" without "H+") and
  HFSX ("HX") are likewise never listed by the plug-in - marking would make every such hybrid's whole
  unpack fail, a trade-off for the maintainer (Inbox item). A destroyed signature or a header past the
  end of the image shows nothing - the same limit as 330's UDF part with a destroyed anchor.

## R4 Where the mark is set

- **Decision**: `CHFS` records `Declared` in `Open`; `CUDFISO::Open` turns a declared part that did
  not open into 330's `PartMissing`, which `ListDirectory` turns into `ListingLeftOut.SetIncomplete()`.
- **Rationale**: the same path as 330's ISO / UDF parts; the quiet open stays.

## R5 The known boxes of xorriso images

"Cannot read sector #00000020." at the open of every xorriso HFS+ hybrid (existing Inbox item) and
"Cannot read sector #00000200." for the APM install image (new, measured here - an Inbox item) are
not this feature's; the probe does not count them.
