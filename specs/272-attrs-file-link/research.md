# Research: 272

## R1 - Can a file link's own compression and times be set?

- Decision: yes - open the link with `FILE_FLAG_OPEN_REPARSE_POINT`.
- Rationale: measured at 8b08f1da (fix-log *Measured* 1): `FSCTL_SET_COMPRESSION` through such a
  handle compressed / uncompressed the link itself, the target untouched; `SetFileTime` set the
  link's times. `FILE_FLAG_BACKUP_SEMANTICS` added does not change it (the compression helpers
  keep it).
- Alternatives: refuse compression / times of a file link - rejected, the item asks to change
  "only the link" and the OS allows it.

## R2 - Encryption of a file link

- Decision: refused like 253's directory link (`ERROR_NOT_SUPPORTED` under `IDS_ERRORENCRYPTING`).
- Rationale: `EncryptFileW` / `DecryptFileW` take a path and follow the link; the item: "refuses
  what a link cannot take". Not `ERROR_INVALID_FUNCTION` (it would switch encryption off for the
  rest of the operation).
- Alternatives: `FSCTL_SET_ENCRYPTION` on the link's handle - undocumented for links, not
  drivable here (no EFS certificate may be created); rejected.

## R3 - Which reparse files are links?

- Decision: the fail-closed rule of 197 / 213 / 253 (`DeleteAsDirLink`), asked for every entry
  listed with the reparse bit, files included.
- Rationale: one rule across Delete, walks and Change Attributes; non-surrogate readable tags
  (cloud placeholders, dedup, third-party) stay on the old way - the item's note. Measured: a file
  with tag `0x00000123` - `GetReparsePointDestination` fails (not a mount point / symlink tag),
  the tag is read and is not a name surrogate -> not a link (probe row NONLINK keeps its old
  "Error Changing Compression" 1920).
- An unreadable tag counts as a link (fail closed): the change stays on the entry itself, never
  reaches a possible target.

## R4 - Read-only, hidden, system, archive

- Decision: no change - `SetFileAttributesW` on a link sets the link's own bits (measured).
