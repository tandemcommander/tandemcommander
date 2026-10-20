# Research: 271 - ZIP case twins

## R1 - Where the listing decides

- Decision: `CZipList::List` sets `SALDIRFLAG_CASESENSITIVE` before the first entry; after the loop
  it clears it (`SetFlags(0)`) unless `Unix` (an HS_UNIX entry was seen - the existing restart path
  `dir->Clear` + `SetFlags(CS)` + `goto START_LIST` stays) or `SalDirTreeHasCaseTwins(dir)`.
- Rationale: 252's trap - deciding after a case-insensitive build is too late (the merge hides the
  folder twins). Without twins the case-sensitive tree equals the case-insensitive one (252
  contracts/case-twins.md guarantee 1, confirmed by 252's review reading `src/zip.cpp`).
  `CSalamanderDirectory::Clear` resets the flags (`src/zip.cpp`), so the Unix restart sets them
  again as today.
- Alternatives: a second read of the central directory with twins in mind (rejected: not needed,
  the built tree answers); always case-sensitive (rejected: changes ordinary ZIPs - typed paths in
  another case, item *Expected*).

## R2 - The operations must follow the listing (measured)

- Finding (reading + probe rows UNIX-ONE / UNIX-DEL before): the plug-in's operations compare the
  archive root (`ZipRoot`) and folder names case-insensitively unless `CZipCommon::Unix` is set;
  `EnumFiles` sets it from the `CZIPFileData::Unix` of the SELECTED items. A folder without its own
  entry has `PluginData == NULL` (the core made its `CFileData`), so selecting only it leaves the
  switch FALSE even in a Unix ZIP: copy of "d" also extracted D/x.txt, delete of "d" also deleted
  D/x.txt. The same would happen to every twin ZIP once the listing shows D and d apart.
- Decision: `CPluginDataInterface` (created once per listing in `ListArchive`, handed back by the
  core with every operation on that listing) carries `CaseSensitive` = the listing's flag;
  `UnpackArchive`, `UnpackOneFile` and `DeleteFromArchive` set `Unix = TRUE` on their `CZipUnpack` /
  `CZipPack` before enumerating when it is set. `EnumFiles` keeps OR-ing; `UnpackOneFile` ORs the
  entry's flag instead of overwriting the switch.
- Rationale: one decision per listing, shared by the panel and the plug-in - what the user sees
  split is matched split. No ABI change (the class is the plug-in's own).
- Alternatives: set `CZIPFileData::Unix` on every entry of a twin listing (rejected: folders without
  an entry still have no data - the measured defect stays); re-derive twins from the central
  directory in `MatchFiles` (rejected: a second copy of the rule, and a different answer than the
  panel's for names the core folds).

## R3 - Consumers enumerated (fix protocol)

`CZipCommon::Unix` readers: `common.cpp` `EnumFiles` (OR), `MatchFiles` (root prefix, folder search,
sort), `del.cpp` `CountFilesInRoot`, `extract.cpp` `UnpackOneFile` / `FindFile`. Writers:
`list.cpp` (listing), `add.cpp` `CZipPack::MatchFiles` (adding into an archive - its own read of the
headers, no listing; out of scope, spec Assumptions), constructor (FALSE). `CPluginDataInterface`
users: `main.cpp` (`ListArchive` creates it, `ReleasePluginDataInterface` deletes it), `SetupView`
columns - unaffected. `UnpackWholeArchive` matches by mask only, no folder test - unaffected.
