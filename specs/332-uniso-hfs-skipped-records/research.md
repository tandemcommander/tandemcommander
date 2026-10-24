# Research - 332-uniso-hfs-skipped-records

## R1 - Is the UDF part of the item still open?

- Decision: no; no UDF change.
- Rationale: feature 330 (`10e18e27`) made `CUDF::ListDirectory` mark any walk result other than
  `ERR_OK`; a file whose `MapICB` fails returns `ADD_FAILED` from `AddFileDir`, `ScanDir` returns
  `ERR_TERMINATE` (a nested one becomes `ERR_CONTINUE`), so the top result is not OK. Measured at
  6070ac51: probe row U-FILE (a/side.txt's identifier points its file entry past the end) keeps the
  image. FEATURE-HISTORY 330: "A UDF file whose entry cannot be read is now marked too".
- Alternatives: a separate mark at `AddFileDir` - redundant.

## R2 - Which HFS+ catalog leaf records are not entries?

- Decision: thread records (empty name; types 3 folder thread / 4 file thread), the root folder's
  record (parent ID 1) when it is used as the volume label (`bSkipRootParent`), an empty-named root
  folder record (parent ID 1), and a folder / file record whose name starts with U+0000.
- Rationale: TN1150 - thread keys have an empty name; the root folder's parent is 1 and its name is
  the volume name; the metadata folder for hard links is "\0\0\0\0HFS+ Private Data" (macOS creates it).
  The xorriso catalog (img332.py dump): root folder (parent 1, "TC332"), threads with key length 6 and
  types 3 / 4, then folders and files. The metadata folder's contents (iNode files) are listed at the
  HFS+ root today (their parent is not a listed folder), so not marking the folder loses nothing.
- Alternatives: mark the U+0000 name too (fails closed) - rejected: every Mac-made image with hard
  links would then never be deleted after an unpack although nothing is missing.

## R3 - Which records are damaged (marked)?

- Decision: a key / name / record type that does not fit the record (`SalHfsCatalogKeyView` false), a
  name over 255 units, a folder record under 88 bytes or a file record under 248 bytes of data, a
  folder / file / unknown-type record with an empty name that is not a thread and not the root
  folder, and (in `hfs.cpp`) a name that does not convert to UTF-8.
- Rationale: each is a record that may hold an entry the listing then lacks (the item's *Expected*).
  88 / 248 = `sizeof(HFSPlusCatalogFolder)` / `sizeof(HFSPlusCatalogFile)` (TN1150; `static_assert` in
  `hfs.cpp` ties them).

## R4 - A record of a type the reader does not handle

- Decision: UNKNOWN - marked; the listing still ends there (`return FALSE`, the caller ignores it).
  A thread type that carries a name is UNKNOWN too (a thread key has no name). An unknown-type record
  whose name starts with U+0000 is DAMAGED (skipped, as today, and marked).
- Rationale: conservative (spec Clarifications); the mark alone is what the item asks for.

## R5 - Where does the rule live?

- Decision: `src/common/salhfscatalog.h`, next to `SalHfsCatalogKeyView` (feature 322), checked in
  `saltests` with 322's `Hfs322Record` builder.
- Rationale: CLAUDE.md "pure decisions in a header under `src/common/` with `saltests` checks";
  plug-ins use header-only shared rules.
