# Feature Specification: Undelete restores files under their own names, from the volume chosen

**Feature Branch**: `114-undelete-names`
**Created**: 2026-10-05
**Status**: Implemented - GUI runs pending
**Input**: `specs/NEXT-WORK.md`, the 104 entry "Undelete applies a FAT rule (`Replace0xE5`) to UTF-8
names: a name whose first byte is 0xE5 (CJK U+5000-U+5FFF) is listed with `$` and restored under a
garbled name; its volume layer enumerates mount points with code-page calls (a mount folder named
outside ASCII fails or resolves to another volume)". Find where the FAT rule belongs and apply it
only there; convert the volume layer to the W functions; sweep the plug-in for other code-page
use on names and paths.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options. No GUI run
was possible today - the measurements are by code reading (`research.md`) and the GUI evidence is
the pending probe (`quickstart.md`).

- Q: Where does the 0xE5 rule belong? -> A: In the 11 raw bytes of a FAT **short-name** entry,
  before any conversion: byte 0 0xE5 = deleted (the first character is lost), 0x05 = a real 0xE5
  byte (Japanese OEM lead byte). Long-name entries (UTF-16), exFAT and NTFS never get it. The FAT
  parser decodes the short name itself and flags the record whose name starts with the
  placeholder; nothing downstream looks at a byte of a UTF-8 name.
- Q: What stands for the lost character? -> A: '$', as the plug-in always showed it - now in the
  name itself, and the record carries a flag (`FR_FLAGS_NAMEFIRSTCHARLOST`): only a flagged name
  opens the Damaged Filename dialog. A real name that starts with '$' (an NTFS metafile, a user
  file) is never asked for.
- Q: In which code page are short names read? -> A: The OEM code page (what FAT stores and Windows
  writes); before, the bytes were handed on as if they were UTF-8.
- Q: A deleted long name: how is the lost first byte of its short name found? -> A: The byte of
  the first character Windows KEEPS in the short name (it drops characters outside the OEM code
  page, dots and spaces; `+ , ; = [ ]` become '_' - review SF1, measured with `dir /x`), then the
  old ANSI guess (so no long name found before is lost), then '_' when the first character is not
  ASCII (what Linux writes); the first candidate whose checksum matches the long-name entries
  wins. Each candidate is a 1/256 chance of taking an unrelated orphan long name (research.md 1).
  When Windows kept nothing of the base name it wrote a hash form (`191D~1.TXT`): the long name
  cannot be linked back, the short name is shown as damaged and asked for, as before.
- Q: "All" in the Damaged Filename dialog? -> A: Remembers one UTF-8 character (1-4 bytes), so a
  non-ASCII first character works for all damaged names (before: one byte, never remembered for a
  non-ASCII character).
- Q: The NT case bits? -> A: Applied as Windows shows them: 0x08 base, 0x10 extension, A-Z only
  (before: 0x08 lowered both, 0x10 ignored).
- Q: Names with an unpaired surrogate? -> A: WTF-8 (066's rule) - restored under their own name.
- Q: The volume layer? -> A: Every volume function on the W layer with UTF-8 <-> UTF-16
  conversion; a path whose UTF-8 form does not fit is left out or refused, never cut (a cut mount
  path names another folder). The connect dialog's volume list is UTF-16; a chosen mount folder
  that does not fit the dialog's buffer is replaced by the volume's GUID path (same volume).
- Q: The sweep? -> A: Fixed what is a defect on the route of names and paths (research.md 3):
  stream-name buffer (a long stream name was merged into the default stream), several stack and
  member overruns, error texts composed in UTF-8, EFS capability on the W layer, parser bounds
  for damaged directories. Recorded: the Restore Encrypted Files long-path recursion, the
  duplicate-removal over-read, ASCII-only name identity in the restore list.
- Q: Interface, strings, configuration? -> A: No plug-in interface change (107), no new string, no
  registry change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A name of U+5000..U+5FFF is listed and restored as itself (Priority: P1)
**Independent Test**: an exFAT image with deleted files named `<U+597D>.txt`,
`<U+5F00><U+59CB>.txt`; a FAT image with `<U+5F00><U+59CB>x.txt` (short name `X76F3~1.TXT`) and an
intact `<U+5A46>.txt`; open `{All Deleted Files}`, restore all with F5.
**Acceptance**: the files are written under exactly those names with their content; no Damaged
Filename dialog.

### User Story 2 - FAT short and deleted long names are read as Windows wrote them (Priority: P1)
**Independent Test**: the FAT image: deleted `<C-caron>lanek.txt` and `<Z-caron>lu...k<u-ring><n-caron>.txt`
(short names in the OEM code page), short names with OEM characters and the 0x05 escape, NT case
bits, a deleted directory's files.
**Acceptance**: every long name recovered; short names decoded from the OEM code page; the
escaped 0xE5 is a character, not a lost one; `readme.txt` / `mixed.TXT` as the case bits say.

### User Story 3 - A really damaged name still asks, and "All" works with any character (Priority: P1)
**Independent Test**: deleted short-name-only `FOO.TXT`, `FAA.TXT`, and deleted `<U+597D>.txt`
whose short name is the hash form `191D~1.TXT`; restore; answer the first dialog with `<C-caron>`
and *All*.
**Acceptance**: one dialog (`$91D~1.TXT`), files `<C-caron>91D~1.TXT`, `<C-caron>AA.TXT` and
`<C-caron>OO.TXT`.

### User Story 4 - The volume chosen is the volume opened (Priority: P1)
**Independent Test**: (person, admin) a volume mounted at a folder named outside ASCII; connect
dialog lists the folder correctly; choose it; the panel shows that volume's deleted files.
**Acceptance**: the mount folder shown exactly; the volume opened is the mounted one, not the
parent; a panel inside the mount folder keeps its path on the right volume.

### User Story 5 - Long names never overrun (Priority: P2)
**Independent Test**: two deleted exFAT files of one 110-character CJK name; restore both.
**Acceptance**: "Target path is too long" twice, nothing written, no crash (the build before:
stack corruption).

### Edge Cases
- A deleted long name whose short name's first byte cannot be reconstructed: the short name is
  shown with '$' and flagged (asked for at restore), as before.
- A short name whose OEM bytes are not a valid sequence of a DBCS code page: decoded as the code
  page does (replacement characters), never dropped.
- An NTFS stream name of 255 characters: kept whole; an unconvertible one is left out, never
  merged into another stream.
- A mount folder whose UTF-8 path does not fit 260 bytes: not shown (the volume still listed by its
  GUID path).

## Requirements *(mandatory)*
- **FR-001**: The FAT deletion marker and the 0x05 escape MUST be applied only to the raw bytes of
  a FAT short-name entry, before conversion; no other name (FAT long names, exFAT, NTFS, UTF-8 in
  general) may be changed by them.
- **FR-002**: Only a name flagged by the FAT parser as having lost its first character MAY open the
  Damaged Filename dialog; "All" MUST remember one whole character.
- **FR-003**: FAT short names MUST be decoded from the OEM code page with the NT case bits; a deleted
  long name MUST be found when its short name was written as Windows writes it.
- **FR-004**: Names MUST convert as WTF-8; no buffer on the name / path route may be overrun or cut
  inside a character.
- **FR-005**: The volume layer MUST use the W functions; a path that does not fit MUST be left out
  or refused, never cut; the volume opened MUST be the volume chosen.
- **FR-006**: No new string, no plug-in interface change, no configuration change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/undelnames_probe.ps1` on this build: every row PASS (NOT DRIVEN rows recorded);
  on `Debug_x64_pre114` the rows marked `defect_before` FAIL (as predicted), the control rows PASS,
  the prompts and dup rows show the old behaviour.
- **SC-002**: saltests (14,327 before) pass with the new checks; the strict encoding guard reports 0.
- **SC-003**: Debug + full Release builds; the 104 probe's Undelete row (`und-image`) unchanged.
