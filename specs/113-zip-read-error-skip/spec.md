# Feature Specification: a read error answered Skip never loses the member being replaced

**Feature Branch**: `113-zip-read-error-skip`
**Created**: 2026-10-05
**Status**: Implemented - GUI runs pending
**Input**: `specs/NEXT-WORK.md` item 5, queue entry 2, the 110 note "Recorded, not fixed": in the ZIP
plug-in, when files are added into an existing archive, `DeleteFiles` removes the members being
replaced BEFORE `PackFiles` reads the new files; when reading a new file fails (I/O error, locked
file, file vanished) and the answer is *Skip* (or *Skip all*, or the error ends the operation), the
replaced member is already gone. Rule to decide and record: a member is deleted only if its
replacement is stored. Check Move, multi-volume / SFX and the 7-Zip plug-in's update path.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options. No GUI run
was possible today - the measurements are by code reading (`research.md`) and the GUI evidence is
the pending probe (`quickstart.md`).

- Q: Is the premise right? -> A: Yes, and wider than recorded (`research.md` 2). In the default
  temporary-copy mode a *Skip* (or *Skip all*) of a replacing file that cannot be opened or read
  loses the member; *Cancel* and errors leave the archive unchanged (the temporary copy is
  discarded). In the in-place mode (the "temporary copy" option off) the member is lost also on
  *Cancel* at the error, on a cancelled progress and on any error while packing.
- Q: The rule? -> A: **A member is deleted only if the file replacing it is stored.** Temporary-copy
  mode: the replaced members are still left out of the new archive first (as before - no extra
  work on the ordinary path), and when a replacing file is not stored its members are copied back
  from the original archive, which is untouched until the operation ends: byte for byte, with
  their central records moved to the new offset. In-place mode: the old bytes are overwritten when
  the archive is compacted, so the order changes - the files are packed first (after the old data),
  then the members of the files that were stored are deleted; a member whose file was not stored
  is simply not deleted. A cancel or an error while packing then leaves the archive's old content.
- Q: Rejected options? -> A: (1) Opening every replacing source before deleting: a read error in
  the middle of a file would still lose the member. (2) Always using a temporary copy when members
  are replaced: it overrides the user's setting and needs space for a whole copy of the archive.
  (3) Removing *Skip* for replacing files in the ZIP plug-in: the dialog changes, and in the
  in-place mode *Cancel* would still lose the member.
- Q: The in-place mode's cost? -> A: The compaction now also moves the added files (their
  compressed size), only when members are replaced. Until the compaction the archive needs space
  for the added files beside the members they replace (the temporary-copy mode needs a whole copy).
  The compaction after packing cannot be cancelled - every file is already stored, and stopping
  half-way would leave old members beside their replacements.
- Q: A member written as a zip64 record, or that now lies beyond 4 GiB? -> A: Put back with its
  central record byte for byte except the local header offset; when the offset newly needs 64 bits
  the record gets its zip64 block (put first, where the plug-in writes it - review S1) or extends
  it, and "version needed" 4.5; the plug-in's later updates of the offset find the zip64 block by
  its id (before: assumed first). A record that cannot take
  the offset (a malformed zip64 block, an extra field that would outgrow 64 KiB) ends the operation
  with an error - the original archive stays.
- Q: Encrypted archives? -> A: A member put back is copied as it is (ZIP 2.0 or AES, 094's forms
  untouched). Found on the same path and fixed: for a file **added** with AES encryption, the MAC
  write replaced the error of a skipped or cancelled file - a read error answered *Skip* stored the
  partly read file as complete (it cannot be extracted), a Move then deleted its source, and
  *Cancel* went on with the operation.
- Q: Move (F6)? -> A: A source is deleted only when it was stored (110 verified `CleanUpSource`); the
  AES defect above was the exception and is fixed. A member put back keeps its source on disk.
- Q: Multi-volume and self-extracting packs? -> A: They always create a new archive (no member is
  deleted before packing) - not affected; the AES fix applies to them too. SFX is unreachable in
  this build (106).
- Q: The 7-Zip plug-in? -> A: The same defect (an *Overwrite* leaves the archived item off 7-Zip's
  update plan; a *Skip* when the file cannot be opened lost the item). The plan is fixed before the
  engine runs, so the contained fix is: a file that replaces an archived item is offered *Retry* /
  *Cancel* only, also after an earlier *Skip all* (*Cancel* ends the update, the archive stays as it
  was). Also fixed: a file skipped in a Move was deleted although it was not packed.
- Q: Interface, strings, configuration? -> A: No plug-in interface change (107), no new string, no
  registry change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Skip leaves the archive's member (Priority: P1)
**Independent Test**: an archive holding `x.txt` and `y.txt`; F5 `x.txt` (locked by another program,
or unreadable from 1 MB on) and another file into it; *Yes* to the overwrite question, *Skip* / *Skip
all* to the error.
**Acceptance**: `x.txt` in the archive with its old content (byte for byte), the other file added,
`y.txt` unchanged; the same for several members replaced by one file (`ax`, `Ax`, `AX` + *All*), a
zip64 record, a member with a data descriptor / comment / extra blocks, encrypted members, a Unix
ZIP.

### User Story 2 - The in-place mode never loses a member (Priority: P1)
**Independent Test**: the "temporary copy" option off; the rows of story 1, plus *Cancel* at the
error and a cancelled progress; ordinary replacements of one and two members (no error).
**Acceptance**: skipped / cancelled: the member keeps its old content; ordinary replacements: every
member correct, the archive checks clean.

### User Story 3 - A file added with AES encryption that cannot be read is not stored (Priority: P1)
**Independent Test**: F5 / F6 with AES-256 of a file unreadable from 1 MB on; *Skip*, *Cancel*.
**Acceptance**: *Skip*: the file is not in the archive and stays on disk after a Move; *Cancel*: the
archive is unchanged.

### User Story 4 - 7-Zip: a replacing file cannot be skipped, a skipped file is not deleted (Priority: P2)
**Independent Test**: a 7z archive holding `x.txt`; F5 a locked `x.txt`: the error offers *Retry* /
*Cancel*; F6 of a locked new file with *Skip*.
**Acceptance**: no *Skip* for the replacing file, *Cancel* leaves the archive unchanged, *Retry*
after unlocking replaces it; the skipped file of the Move stays on disk.

### User Story 5 - Ordinary updates unchanged (Priority: P1)
**Independent Test**: F5 into a ZIP with *Yes* and no error (both modes); the probes of 110, 106, 094.
**Acceptance**: the same results as before.

### Edge Cases
- Several members replaced by one file (`CAddInfo::Replaced` > 1): all of them come back.
- A replacing file skipped after part of it was written: the member is copied over that part.
- *Retry* after the file was released: the file is stored as usual.
- An I/O error on the archive itself while the in-place mode compacts after packing: the directory
  of what is there is written with the added files (best effort, as the in-place mode always was;
  old members may then remain beside their replacements). Not driven.
- Low memory while recording or putting back a member: the operation ends with an error before
  anything is deleted (in-place) / with the original kept (temporary copy).

## Requirements *(mandatory)*
- **FR-001**: The ZIP plug-in MUST NOT remove a member from the archive unless the file replacing
  it is stored in the same operation - on every answer to a read or open error (*Skip*, *Skip all*,
  *Cancel*, *Retry*), on a cancelled progress, in both modes.
- **FR-002**: A member kept for that reason MUST be byte-identical to the original (local header,
  data, data descriptor; central record except its offset).
- **FR-003**: A file that is not stored MUST NOT be deleted by a Move, and a file that could not be
  read completely MUST NOT be stored (also with AES); *Cancel* MUST end the operation.
- **FR-004**: The 7-Zip plug-in MUST NOT offer *Skip* for a file that replaces an archived item, and
  MUST NOT delete a skipped file in a Move.
- **FR-005**: No new string, no plug-in interface change, no configuration change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/zipskip_probe.ps1` on this build: every row PASS (the progress rows may be
  NOT DRIVEN when the packing finishes before the cancel); on `Debug_x64_pre113` the Skip rows, the
  in-place Cancel rows, the AES rows and the 7-Zip rows FAIL, the control rows PASS.
- **SC-002**: saltests (14,236 before) pass with the new checks; the strict encoding guard reports 0.
- **SC-003**: Debug + full Release builds; the 110, 106 and 094 ZIP probes give the same results as
  before.
