# Research - 319-pack-name-colon

## R1 - Where the name is checked

- Decision: in `CFilesWindow::Pack` (`src/fileswn7.cpp`), right after `SalGetFullName(fileBuf, ...,
  MAX_PATH, TRUE)`, in the refusal 317 / 318 already put there.
- Rationale: every Pack name passes it (offered or typed, relative or absolute, "Use the other
  panel" on or off) before the "packed into itself" check (119), the "add or overwrite?" question,
  Overwrite's aside (176) and `ExecutePacker` - a refusal there touches nothing, for every packer.
- Consumers enumerated (Grep `SalPackName`): `SalPackNameIsNotKeptAsTyped` is called only at
  `src/fileswn7.cpp` (Pack) and in `src/saltests/saltests.cpp` (`TestPackName318`); the new rule
  gets the same two callers. No plug-in includes `salpackname.h`.
- Alternatives: the ZIP plug-in (one packer only, a plug-in change); `SalGetFullName` (shared by
  every path entry); `SalIsValidFileNameComponent` (`src/salamdr5.cpp`, also refuses `* ? < > | "`,
  control characters and long names, which the item does not name - 318 R2 rejected it likewise).

## R2 - What "holds a colon" means

- Decision: `SalPackNameHasStreamColon(fullName)` - skip a drive prefix (an ASCII letter and `:` as
  the first two bytes), take the part after the last `\` or `/` of the rest, and return TRUE when it
  holds a `:` anywhere. FALSE for NULL, an empty name, or a name with no colon in its last part.
- Rationale: after `SalGetFullName` the name is `X:\...` or `\\server\share\...`; the only valid
  colon is the drive's at the second character. A drive-relative `C:rel.zip` is already
  `C:\<panel path>\rel.zip` when checked (measured: packed into the panel's folder). Skipping the
  prefix also keeps a bare `C:x.zip` (no separator, not reachable from Pack) from counting as a
  stream name. A `/` separates like `\` (318 R2a). A colon only in a folder part (`sub:x\a.zip`) is
  not refused (spec Clarifications) - the packer refuses it, measured.
- UTF-8: `:` is 0x3A; bytes of multi-byte UTF-8 sequences are >= 0x80, so a byte scan never sees a
  colon inside a character. The full-width colon U+FF1A (`EF BC 9A`) is not refused - a legal file
  name character.

## R3 - Existing file or stream

- Decision: refused regardless of `FileExists` (unlike 318's rule).
- Rationale: the item's *Expected* - "OK on an archive name whose last part holds a `:` is refused
  ... nothing is created or changed"; an existing file `report` makes `FileExists("...\report:zip.zip")`
  TRUE only when the stream exists, and the measured Add into such a stream changed it and left a
  stray `Sal*.tmp`. 318's exception exists because a literal `report.` is a file the panel shows;
  a stream never is.

## R4 - The message

- Decision: `IDS_PATHISINVALID` ("The path specified is invalid."), the box titled Pack, the dialog
  again - 317's / 318's route. No new string (a run cannot do the `.slt` refresh).
