# Research - 289-drive-list-wide-texts

## R1 Where the code-page texts enter (measured at cf860604)

- Decision: fix exactly the sources that feed the drive list and the folder type names:
  `ReadDirectoryIconAndTypeAux` (`icncache.cpp`), `UpDirTypeName` (`salamdr1.cpp`),
  `GetDisplayNameFromSystem` and `ReadCDVolNameThreadFBody` (`drivelst.cpp`), the `LoadStr` /
  `PrintDiskSize` texts of `BuildData`, `AddToDrives`, the OneDrive items and `GetDriveBarToolTip`.
- Rationale: fix-log *Measurement before*: `SHGetFileInfoA` gives "???" for a name outside the
  code page; the type name is stored as cp1250 bytes. All sinks (panel `fileswn2/4.cpp`, menu,
  `tooltip.cpp`) decode UTF-8 first and fall back to the code page only for invalid UTF-8, so
  UTF-8 sources render the same where they render right today.
- Alternatives: converting at the sinks - rejected, the '?' is produced by Windows before the
  program sees the text; nothing downstream can recover it.

## R2 Retry the ANSI call when the wide one fails?

- Decision: no (clarification 2). Failure -> the same fallback text as today.
- Rationale: feature 069 (`GetVolumeInformationU8Menu`) set this precedent for fixed drives;
  an ANSI retry would answer with '?' again.

## R3 Buffer sizes

- Decision: `SAL_DRIVE_TEXT_U8_MAX = 3 * MAX_PATH + 1`; `FolderTypeName[3 * 80 + 1]`;
  `ReadCDVolNameBuffer[SAL_DRIVE_TEXT_U8_MAX]`; caller buffers `2 * SAL_DRIVE_TEXT_U8_MAX + 100`.
- Rationale: one UTF-16 unit is at most 3 UTF-8 bytes (BMP), a pair of units 4 bytes; the
  longest answers are `szDisplayName[260]`, a label buffer of `MAX_PATH + 1`, `szTypeName[80]`.
  CLAUDE.md: never cut a text mid-character; here no cut is needed at all.
  `TransferBuffer` is 1024 bytes (`TRANSFER_BUFFER_MAX`), so 240 bytes fit.
  `ReadCDVolNameBuffer` is also the IN buffer of the root ("D:\") - larger is harmless.
- Alternatives: whole-character cut into the old sizes - rejected, unnecessary loss.

## R4 Where the pure rule lives

- Decision: `src/common/saldrivetext.h` (header-only): the size bound and
  `SalDriveNameTrimLetterSuffixW` (cut at the last '(' and the spaces before it - the existing
  rule of `GetDisplayNameFromSystem`, kept identical, now on UTF-16).
- Rationale: standing rule "pure decisions in a header under `src/common/` with `saltests`".

## R5 How to observe the result without the end-to-end symptom

- Decision: extend the Debug-only seam of feature 246 (`TC_PROBE_DRIVES_DUMP`): `TYPES` line,
  `TIP` for every drive. Probe in English and Czech: on this machine the unlabelled C: shows
  "Local Drive" / "Místní jednotka", the Documents item "Dokumenty", the Network item "Síť", and
  the folder type name is "Složka souborů" (Czech display language) - in Czech the bytes are
  cp1250 today (negative control fails), UTF-8 after.
- Alternatives: screenshot OCR - rejected, it cannot tell the encodings apart (the sinks render
  both right).
