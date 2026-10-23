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

- Before: ` ..` was trimmed to `..` = the parent of the panel's folder (an existing folder; the ZIP
  plug-in failed: "Cannot open or create file. Access denied."), ` .` to the panel's folder - no
  archive was made.
- Expected at planning: `<panel>\ ..` resolves to the panel's folder by Win32 normalization (trailing
  dots and spaces stripped). **Measured wrong**: the first after-run (only R1) created files
  literally named ` ..` and ` .` in the panel's folder - the ZIP plug-in opens the archive through a
  `\\?\` path, where no normalization happens. Such names are not addressable by ordinary Windows
  tools.
- Decision: refuse an archive name whose last part is only spaces and dots, after `SalGetFullName`,
  through the existing error path (`errTextID = IDS_PATHISINVALID`, "The path specified is
  invalid.", the dialog again) - no new string. Pure rule `SalPackNameIsOnlyDotsAndSpaces` in
  `src/common/salpackname.h`, saltests `TestPackName317`. It also refuses such a last part given in
  an absolute name (`<folder>\ ..`), which before created the literal file the same way - strictly
  safer, nothing else changes.
- Alternatives: `SalIsValidFileNameComponent` on the archive's name - rejected here: it also refuses
  names ending in a dot or space and reserved names (`CON.zip`), cases the item does not name
  (recorded as an Inbox item instead).
