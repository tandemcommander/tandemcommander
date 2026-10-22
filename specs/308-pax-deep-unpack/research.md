# Research - 308-pax-deep-unpack

## R1 Where the bound acts and who calls it

- `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`) is read by every pass: `ListArchive`,
  `UnpackOneFile`, `DoUnpackArchive` (from `UnpackArchive` = Copy of a selection and
  `UnpackWholeArchive` = Alt+F9). The PAX refusal (feature 306) sets `header.Ignored` with
  `SalPaxNameFitsListingU8` in all of them; the box is shown when `ReportRefusedNames` (ListArchive,
  UnpackWholeArchive).
- `.deb` (`src/plugins/tar/deb/deb.cpp`): `CDEBArchive` holds two `CArchive` objects and calls their
  `ListArchive` / `UnpackWholeArchive` / ...; `SetListingPrefixLen` is the listing's "data\" prefix.
  `CDEBArchive::UnpackWholeArchive` combines both results with AND - a FALSE propagates.
- `CPluginInterfaceForArchiver::UnpackWholeArchive` (`src/plugins/tar/tardll.cpp`) adds the archive to
  `archiveVolumes` before the unpack and returns its result; the core (`src/fileswn7.cpp`, Alt+F9
  handler) deletes the volumes only when `ExecuteUnpacker` returned TRUE.
- cpio / rpm use `CpioDoUnpackArchive`; `NameFromPax` is set only for tar headers - not affected.

Decision: make the rule depend on the pass; leave every caller's structure as is.

## R2 The rule

- Listing pass: `SalPaxNameFitsListingU8` unchanged (the listing would fail as a whole; 306 review 1).
- Extraction pass: only `SalPaxPathHasTooLongComponentU8` (no Windows file system stores a component
  over 255 UTF-16 units). Depth is the file system's business: long paths go through
  `SafeFileCreate` (measured: 0.1.10 extracted a 299-byte folder part, 307 review 2).
- One function `SalPaxNameUsableU8(name, isDir, prefixLen, listing)` in `salpaxheader.h`, tested in
  saltests. Alternatives: two call sites in untar.cpp with an `if` - rejected, the rule is the
  decision and belongs in the header with checks (standing rule "pure decisions in src/common").

## R3 Failing the extraction

- A refused member counts only when the operation was asked for it (`found`: mask / selection /
  name). Then: the "(206)" box with the whole path (once per CArchive object), the extraction goes on
  with the other members, and the pass returns FALSE at its end (also at the stream's EOF end).
- Alternatives: abort at the refusal (extracts less, no gain); keep TRUE and only warn (the core would
  delete the archive - the defect) - rejected.
- `UnpackOneFile`: a refused member is never listed, so it cannot be asked for; if it were, it now
  returns FALSE with the box instead of TRUE with nothing extracted (cheap, consistent).

## R4 GNU long names (branch 307)

On `main` only PAX paths are refused. Branch `307-tar-long-component` adds a GNU refusal with the same
listing bound; when it is resumed it must use `SalPaxNameUsableU8` with the pass flag. Recorded in the
log of item `opening-a-tar-whose-member-name-has-a-300-letter-component` at closing.
