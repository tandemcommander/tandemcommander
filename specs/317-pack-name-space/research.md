# Research - 317-pack-name-space

## R1 - Where the space is lost

- Decision: pass `allowRelPathWithSpaces = TRUE` at the `SalGetFullName` call of
  `CFilesWindow::Pack` (`SalGetFullName(fileBuf, &errTextID, curDir, nextFocus, NULL, MAX_PATH,
  TRUE)`).
- Rationale: the relative branch of `SalGetFullName` (`src/salamdr3.cpp`) joins `curDir` with the
  name from after its leading characters <= ' ' unless the flag is TRUE; with the flag it joins the
  whole name. Feature 316 made the same change at the Unpack call; `SalParsePath` (Copy/Move)
  already passes TRUE.
- Alternatives: change `SalGetFullName`'s default - rejected, its many callers (Change Directory,
  Create Directory, the plug-in service `CSalamanderGeneral::SalGetFullName`) rely on the trimming;
  trim in the dialog - rejected, the item asks for the name as shown.

## R2 - Unchanged branches with the flag

- A name of spaces only: the empty check runs on the pointer past the spaces before the relative
  branch - still `IDS_EMPTYNAMENOTALLOWED`. But the Pack dialog appends the extension to a name
  without one, so the entry `   ` arrives as `   .zip` (not empty); with the flag it stays
  `   .zip` (before `.zip`) - spec Clarifications.
- `  \x.zip` (spaces, then `\`): the flag applies only when the name after the spaces does not
  start with `\` - unchanged.
- `  C:\x.zip`: the drive branch trims as before - unchanged.
- `curDir == NULL` (Pack from a non-disk panel): the relative branch is not reached - unchanged.
- An empty entry: `IDS_EMPTYNAMENOTALLOWED`, the message and the dialog again - unchanged.

## R3 - Consumers of the archive name after the call (enumerated)

All in `CFilesWindow::Pack` after OK; they receive the full name with its space:

1. `PackArchiveIsSelectedSource(fileBuf, GetPath(), &data)` - identity-based (`SalGetFileIdentity`),
   works on the name as given.
2. `ScanMoveSelectionForDirLinks` - the selection, not the archive name.
3. `FileExists(fileBuf)` + the "add or overwrite?" question (the name part after the last `\` is
   shown: ` report.zip`).
4. Overwrite (176): `SalGetTempFileName(folder)` + `SalMoveFileEx(fileBuf, aside)`; put back with
   `SalMoveFileEx(aside, fileBuf)` - the name as given.
5. `PackerConfig.ExecutePacker(this, fileBuf, ...)` - plug-in packers get the name (the ZIP plug-in
   wrote ` abs.zip` for the absolute entry at d526127f); external archivers get
   `"$(ArchiveFullName)"` quoted (`src/packers.cpp`, `src/pack2.cpp`).
6. `SalGetFileAttributes(fileBuf)` after packing (176's decision), `CutDirectory(fileBuf)` +
   `PostChangeOnPathNotification` - the folder part, unaffected by the name's space.
7. `nextFocus` - filled by `SalGetFullName` before the join; its use is commented out in Pack
   (`FocusFirstNewItem` is used instead).

## R4 - ` ..` and ` .`

- Before: ` ..` was trimmed to `..` = the parent of the panel's folder (an existing folder; a
  packer cannot create a file over it). After: `<panel>\ ..` - Win32 path normalization strips the
  trailing dots and spaces of the last component, so the name resolves to the panel's folder
  itself. `FileExists` is FALSE for a folder (no question, no Overwrite), and a packer cannot
  create a file over a folder. Measured by probe rows typed-space-dots / typed-space-dot (spec
  FR-004): no new file, no file changed.
