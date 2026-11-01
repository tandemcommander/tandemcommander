# Research - 366-uniso-form2-files

## R1 - How a Form 2 file is recognised

- **Decision**: by the CD-XA system-use record of its ISO 9660 directory record (14 bytes at the start of the
  system-use area: owner ids 4, attributes 2 big-endian, "XA", file number, 5 reserved): Form 2 bit 0x1000
  set, Form 1 bit 0x0800 and directory bit 0x8000 clear; confirmed by the file's first sector being a valid
  Mode 2 Form 2 sector (`SalIsoSectorIsForm2`, feature 335) on a track whose stored sector holds the Form 2
  user data at the plug-in's user-data position (header 24 in a 2352/2448-byte sector, 8 in a 2336-byte one).
- **Rationale**: measured on vcdimager's VCD / SVCD: video files 0x1555, Form 1 files 0x0D55, folders 0x8D55;
  all video sectors Form 2. The XA record is what the CD-XA standard (and Windows' CDFS, Linux isofs) uses to
  tell Form 2 files. The first-sector check keeps a wrong attribute (a Mode 1 track, a crafted record) from
  turning ECC bytes into file content.
- **Alternatives**: per-sector subheaders for every file (no XA needed) - the size would need a scan of every
  file at listing, and mixed files would get a size the core cannot know in advance; rejected for this item
  (mixed / attribute-less files unchanged, spec Assumptions). The image-wide `stMode2Form2` sector type (a
  first sector of the image that is Form 2) - applies one size to every file and folder; not used.

## R2 - What is extracted

- **Decision**: 2324 bytes of every sector of the file's extent, sectors = ceil(DataLength / 2048); the listed
  size is that product.
- **Rationale**: the SVCD file equals its source MPEG exactly; the VCD file contains its source whole with the
  disc's zero margins around (what the disc stores in the file). Tools that present Form 2 files as user data
  (IsoBuster "user data", Linux isofs with raw access) do the same; no MPEG-aware stripping.
- **Alternatives**: a RIFF/CDXA wrapper with 2352-byte raw sectors (as Windows CDFS shows them) - not the MPEG,
  and needs the sync/header which a 2336-byte NRG track does not store; rejected.

## R3 - Where the read happens

- **Decision**: `CISOImage::ReadForm2Block(block, data)` reads 2324 bytes at `GetSectorOffset(block)` of the
  open track and refuses (returns 0) when the open track does not store Form 2 data there; both
  `CISO9660::UnpackFile` and `CRawFS::UnpackFile` use it for a `CFilePos::Form2` file.
- **Rationale**: `CISOImage::UnpackFile` opens the file's track (`GetTrackFromExtent`) before the file system's
  reader runs, so the open track's parameters are the file's; the listing decided with the same track's
  record (`FileIsForm2`), so the two agree; a disagreement fails closed as a read error.

## R4 - Feature 337's coverage

- **Decision**: `SalIsoFileSectorSpan` takes the bytes a sector of the file (2048, or 2324 for a Form 2
  file): floor(size / bytes) whole sectors.
- **Rationale**: with the size now sectors x 2324, floor(size / 2048) would count 13 % more sectors than the
  file reads - stream sectors no file extracts would pass as covered, and "Delete archive after unpacking"
  would delete them.
