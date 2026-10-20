# Research: 253 - Change Attributes on a link's own entry

## R1 - Can compression and times stay on a junction?

- Decision: yes - open the link with `FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT`.
- Rationale: measured on NTFS (PowerShell P/Invoke on a junction under %TEMP%, 2026-10-20):
  `FSCTL_SET_COMPRESSION` without the flag compressed / uncompressed the TARGET folder, with it the
  junction itself (error 0 both ways); `SetFileTime` without the flag re-timed the target, with it
  the junction.
- Alternatives: refuse compression of a link (needless - the link can take it; the item says
  "changes only the link").

## R2 - Can encryption stay on a junction?

- Decision: no - refuse an encryption change of a directory link with `ERROR_NOT_SUPPORTED` under
  the existing `IDS_ERRORENCRYPTING` dialog.
- Rationale: `EncryptFileW` / `DecryptFileW` take a path and offer no "do not follow" flag; the
  only alternatives are undocumented EFS control codes. Not driven: the machine has no EFS
  certificate and encrypting would create one in the user's store.
- Alternatives: (a) silently skip the encryption part and change the rest - rejected, "refuses
  rather than guesses"; (b) the existing "encryption not supported" branch
  (`ERROR_INVALID_FUNCTION` -> `showEncryptErr`) - rejected, it turns encryption off for every
  later entry of the operation; (c) a new message - would need a new UI string.

## R3 - Which entries are links?

- Decision: `DeleteAsDirLink` (197, used by 213 for the same operation): a junction, a volume mount
  point, a directory symbolic link, any name surrogate, or a tag that cannot be read; a cloud
  placeholder is not a link. Asked only for an entry listed with both `FILE_ATTRIBUTE_DIRECTORY`
  and `FILE_ATTRIBUTE_REPARSE_POINT` (`op->Attr`), at the time the entry is processed.
- Rationale: one rule for Delete, the Change Attributes walk and the link's own entry; fails closed.
- Alternatives: file symbolic links - not named by the item; recorded as a backlog item.

## R4 - Callers of the four helpers

`CompressFile`, `UncompressFile`, `MyEncryptFile`, `MyDecryptFile` are defined and used only in
`src/worker.cpp`: `DoChangeAttrs` (this feature), the directory creation of Copy / Move (~6898 -
6959, folders the program created) and the file copy (~7600 - 7623, the temporary target file).
The latter keep the default `ownEntry = FALSE` = today's flags.
