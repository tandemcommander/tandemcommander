# Research - 339-uniso-hfs-fork-content

## R1 Extract the content or refuse

- Decision: refuse - count as not extracted, no file written.
- Rationale: HFS+ compression (decmpfs) has several methods (zlib types 3/4, LZVN 7/8, LZFSE 11/12, ...),
  stores small files inline in the `com.apple.decmpfs` extended attribute (the attributes B-tree, which the
  reader does not load) and large ones in a `cmpf` resource of the resource fork; implementing it is a
  feature of its own. A resource-fork-only file ("Icon\r", classic Mac resources) has no Windows content of
  its own - writing the resource fork as the data would be a different file. The item allows either answer.
- Alternatives: decompress zlib types only (partial: modern macOS writes LZVN/LZFSE); write the resource fork
  to an NTFS alternate stream (no reader of that content on Windows, and Copy to non-NTFS loses it).

## R2 How "compressed" is recognised

- Decision: `UF_COMPRESSED` (0x20) in `ownerFlags` (byte 41 of `HFSPlusCatalogFile`: permissions at 32 =
  ownerID 4, groupID 4, adminFlags 1, ownerFlags 1, fileMode 2, special 4), honoured only when the file mode's
  type bits (`fileMode & 0xF000`) are not 0.
- Rationale: macOS decompresses a file only when `UF_COMPRESSED` is set; the item's *Notes* name the flag as
  the cheaper sign. TN1150 (*HFS Plus Permissions*): "If the S_IFMT field (upper 4 bits) of the fileMode field
  is zero, then Mac OS X assumes that the permissions structure is uninitialized, and internally uses default
  values for all of the fields" - Mac OS 9 wrote such records; a stray byte there is not a flag.
- Alternatives: read the attributes B-tree for `com.apple.decmpfs` (not loaded today; the flag decides for
  macOS anyway).

## R3 What the user sees

- Decision: the readers' read-error box (`DialogError`, `BUTTONS_SKIPCANCEL`: Skip / Skip all / Cancel) with
  the file name and one of two texts; `silent != 0` (after Skip all, or an "All" answer of the same operation
  - 338) shows no box; Skip / Skip all / silent -> `UNPACK_ERROR`, Cancel -> `UNPACK_CANCEL`.
- Rationale: the same reader refuses a fragmented file with a box; the box lets a whole unpack of many such
  files be answered once (Skip all). 338's tally counts `UNPACK_ERROR` and `UNPACK_CANCEL` as not complete.
- Alternatives: a plain OK box as the fragmented case (one per file, no Skip all); no box (a single-file Copy
  would end with no file and no word).

## R4 Where the check runs

- Decision: in `CHFS::UnpackFile` after the record checks (`SalHfsCatalogKeyView`, file record of at least
  248 bytes, type file) and before the name, the buffer and `SafeFileCreate`.
- Rationale: FR-003 (no empty file, an existing target untouched); no buffer allocated, so 327's leak item is
  not widened. All extraction routes (whole unpack, Copy F5, view) go through `UnpackFile`.

## R5 Both forks, listing size

- Decision: unchanged (spec *Clarifications*); the dropped resource fork of a file with data goes to the
  Inbox.
