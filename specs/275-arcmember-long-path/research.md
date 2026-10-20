# Research: 275 - F3 / F4 of archive members with a long path inside the archive

## R1 - Is the 520-byte test still needed by the core?

- Decision: remove it in F3 and F4.
- Rationale: since feature 095 the disk-cache name (`dcFileName`) is an exact-size heap string;
  F3 copies the path inside the archive into a `CSalHeapString` (the key may get a `:0x<pointer>`
  suffix for case twins), F4 points into the key. Neither has a fixed buffer. The listing
  (`CSalamanderDirectory::AddFile` / `AddDir`) refuses a path part over `MAX_PATH - 5` bytes and a
  name over 255 UTF-16 units, so the input has at most about 1,021 bytes. The temporary copy's path
  is judged by the cache's rule (`SalCacheTmpPathFitsU8`, at most 259 units, feature 260).
- Alternatives: keep a higher limit (e.g. 3 * MAX_PATH) - rejected: the listing already bounds the
  input; a second number would only be another limit to explain. Move the limit into plug-ins -
  rejected: the shipped archivers take the path (R2).

## R2 - Which archivers take such a path? (audit by reading, an independent agent)

- ZIP: `FindFile` compares the stored name in `malloc(MAX_HEADER_SIZE)` (64 KiB); the target on the
  heap (`extract.cpp`). Works.
- 7-Zip: the member by index; `nameInArchive` only traced; target `malloc(U8_MAX_PATH)` with a
  refusing `SalPathAppend`. Works.
- tar (GNU long names up to 10,000 bytes, cpio, deb, rpm, streams): `strcmp(header.Name,
  nameInArchive)` with heap names; target `malloc`. Works. (ustar names are at most 256 bytes; PAX
  headers are ignored by the listing - another defect, an Inbox item.)
- uniso: `CU8PathBuf` (U8_MAX_PATH) heap buffers, `SalPathAppend` refusing with
  `IDS_ERR_TOO_LONG_NAME`. Works.
- uncab: `char rootDir[U8_MAX_CAB_NAME]` (769) + `lstrcpyn(rootDir, nameInArchive, ...)` - a silent
  cut at 769+ bytes; unreachable (a CAB name has at most 255 code-page bytes = 765 UTF-8 bytes) ->
  refuse with `IDS_TOOLONGNAME` instead (FR-003).
- External archivers (`PackUnpackOneFile`): `PackExpandCmdLine` into 1,040 bytes; `ExpandVarString`
  refuses with a message; heap move target. No cut.
- Disabled: unrar (`lstrcpy(justName[MAX_PATH], ...)`) and unchm (`lstrcpy(srcPath[MAX_PATH], ...)`)
  overflow at 260+ bytes already today - reachable before this feature (names of 260-519 bytes);
  unrar has an Inbox item, unchm gets one. Not shipped; not changed here.

## R3 - Third-party plug-ins

- Decision: no gate by `BuiltForVersion`.
- Rationale: every loaded plug-in is built for >= 104 (<= 103 refused at load); 104's documented
  promise (`spl_com.h`) is name components of up to 3 * 255 bytes and long paths; F5 hands such
  names to every archiver since feature 222. A gate would separate nothing (all loaded plug-ins are
  104+).

## R4 - Fixtures for the probe

- ZIP: .NET `ZipFile` (UTF-8 names), as probe 260.
- 7-Zip: `C:\Program Files\7-Zip\7z.exe a` of a folder holding the member (installed on this
  machine; a row is NOT DRIVEN when it is missing).
- tar: built by the probe as a GNU tar (a `././@LongLink` 'L' header carrying the UTF-8 name, then
  the regular header) - deterministic, independent of the tar tools' PAX choices.
- Deep folder: ZIP entry `<84 CJK letters>/<100 CJK letters>.txt` (252 + 1 + 304 = 557 bytes);
  the panel opened at `a.zip\<folder>`.
- ISO / CAB: not driven - no image tool on the machine for long Rock Ridge / UDF names; a CAB cannot
  hold such a path (by reading, R2).
