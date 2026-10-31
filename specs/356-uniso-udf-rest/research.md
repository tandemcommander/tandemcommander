# Research - 356-uniso-udf-rest

The measurement table is in `fix-log.md` (*Where a UDF volume ends*) and the spec's *Background*.

## R1 - Which structures give the end of a UDF volume

- **Decision**: the file's end, when its last whole sector (or the one 256 before it) is an anchor of
  this volume, or - a volume with a virtual partition map - its last whole sector is a (extended) file
  entry of this volume; otherwise the sector after the last of the anchor at 256, the main and reserve
  descriptor sequences and the partitions of the main sequence.
- **Rationale**: ECMA-167 / UDF place anchors at 256, N-256 and N (N = the volume's last sector) on
  closed media; a later volume's anchors name its own sequences, so "same extents as the anchor at 256"
  tells this volume's closing anchor from another's. Every measured non-VAT image (IMAPI2FS 1.02 - 2.50,
  mkudffs hd / dvd / dvdrw / cdrw / cd / closed cdr) closes with such an anchor; open VAT images close with
  the VAT (UDF: the VAT ICB is the last recorded sector), whose tag location is partition-relative.
- **Alternatives**: the descriptors' end alone - marks every measured plain image (rests of 128 - 272
  non-zero sectors: anchors, sparing tables) - rejected; the partition end alone - VAT volumes claim the
  whole medium, IMAPI2FS's reserve sequence lies past its partition - rejected.

## R2 - What counts as an empty rest

- **Decision**: zero bytes only, or an anchor of this volume (valid tag at its own location, the same
  extents).
- **Rationale**: IMAPI2FS fills the rest past its reserve sequence with the volume's own anchors; they
  hold neither data nor another volume. Other structures (sparing tables) are not recognised - fails
  closed (spec *Clarifications*).

## R3 - Descriptor validation

- **Decision**: tag identifier, tag location = the sector it is read from (partition-relative for a
  file entry: + the partition's start), tag checksum (byte 4 = sum of bytes 0-3 and 5-15, mod 256). The
  CRC is not checked (as the plug-in's `CUDF` reader, which checks only the location).
- **Rationale**: location + checksum reject random data and descriptors of a joined image at another
  offset; a crafted copy can still pass (accepted, as 353 - 355).

## R4 - Bounds

- **Decision**: the main sequence is read for at most 64 sectors (UDF minimum 16; mkudffs cdrw 32); a
  partition descriptor not found there → the end is not known → marked. The rest uses 354's limits.
- **Rationale**: bounded open cost; fails closed.
