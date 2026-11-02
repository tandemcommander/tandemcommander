# Research - 399-zip-symlink-archive

## R1 Resolve or refuse

- Decision: resolve the link and update the real archive.
- Rationale: the item's *Expected* names it first; refusing needs a new string and keeps the update
  impossible; resolving keeps every guarantee of 320 (same `SalReplaceWithTempW`, only another
  target in another folder).
- Alternatives: refuse up front with a new message (rejected: worse for the user, translation work
  for nothing); add 1464 to the move fallback of `SalReplaceFailureNext` (rejected: a replacing
  rename onto the link's name makes the link a plain file - exactly the pre-320 defect).

## R2 Which names are followed

- Decision: the name itself carries `FILE_ATTRIBUTE_REPARSE_POINT`, is not a directory, and its
  reparse tag (`WIN32_FIND_DATAW.dwReserved0` from `FindFirstFileW` on the name) is a name surrogate
  (`IsReparseTagNameSurrogate`: `IO_REPARSE_TAG_SYMLINK`, `IO_REPARSE_TAG_MOUNT_POINT`).
- Rationale: only a name that redirects to another name breaks `ReplaceFileW`; a cloud placeholder,
  a deduplicated file, a WOF-compressed file are reparse points that are the file itself - they keep
  today's path. Junctions / directory links in the folder part already work (measured,
  add-junction / del-junction PASS) and are not touched.
- Alternatives: always resolve (rejected: would move SUBST / mapped-drive archives to UNC / other
  names for no gain); resolve only on 1464 after the fact (rejected: the temporary file is then on
  the wrong folder, possibly another volume).

## R3 How the final path is read

- Decision: `GetFinalPathNameByHandleW(ZipFile->File, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS)` on
  the archive handle the plug-in already has open (it is the file the operation reads), then remove
  `\\?\` (`\\?\UNC\srv\sh\x` -> `\\srv\sh\x`), as the core's `SalGetFinalPathOfHandleU8Alloc` (107)
  does - re-implemented header-only (the plug-in cannot use `salfileio.cpp`). A result without a DOS
  form (`\\?\Volume{...}`) or of any other shape -> not resolved (as today: fails safe).
- Rationale: the handle names the very file being changed (a link re-pointed meanwhile does not
  matter); the plain form is what the plug-in's UTF-8 paths and `SalGetTempFileName` expect, and
  `SplU8ToWExtAlloc` adds `\\?\` again where needed.

## R4 Attributes

- Decision: after a resolve, `ZipAttr` is re-read from the real archive (falls back to the link's
  when it cannot be read). The read-only check before the operation is unchanged (spec
  Clarifications).
- Rationale: `ZipAttr` decides NTFS compression of the new file and the attributes set after the
  replace; the link's own attributes (`ARCHIVE | REPARSE_POINT`) are wrong for the real archive.

## R5 Length

- Decision: a resolved path whose UTF-8 form does not fit `U8_MAX_PATH` (the size of the plug-in's
  path buffers) is not used (as today: fails safe with the true message). Never cut (rule 097).
