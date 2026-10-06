# Feature Specification: the leftovers of the packing fixes

**Feature Branch**: `119-packing-leftovers`
**Created**: 2026-10-06
**Status**: Implemented - GUI runs done (fix-log "GUI results"); by-hand drag & drop / paste owed
**Input**: `specs/NEXT-WORK.md`, the findings of feature 106 ("Found by 106, not fixed (small, no
loss)"): a failed multi-volume pack leaves the volumes it already wrote; multi-volume into
`name.zip` that exists (Add) leaves the last volume as `name.z0N` silently; the 7-Zip plug-in packs
a selected archive into itself and Move then shows "Delete Error (32)"; the ZIP plug-in's *Add* of
a selected archive reports a sharing violation instead of a clear text; the Pack dialog's refusal
"Cannot copy a file to itself." names no file and does not say that deselecting helps.

## Clarifications

### Session 2026-10-06

The maintainer asked for autonomy; the decisions are the author's. No GUI run was possible (other
agents ran GUI probes on the hidden desktop, the maintainer used the installed program): the
research is code reading (`research.md`), the GUI evidence is the pending probe (`quickstart.md`).
No plug-in interface change (107), no registry change, no new string.

- Q: Which volumes may a failed multi-volume pack delete? -> A: **Those this operation created,
  and only while their name still holds the very file it created.** Each volume is recorded when
  `CreateNextFile` creates it, with the file system's identity read from the creating handle
  (volume serial + file id); at a failure each recorded name is checked again and deleted only for
  the same id (another id = another file took the name: never deleted). **Keep it whenever unsure**
  (code review SF1): without usable ids (a server without file ids, or an identity that could not
  be read when the volume was created - then it is re-read by name at once) the volume is deleted
  only if it is a file whose creation time is known and unchanged and whose size is the size this
  operation wrote (recorded when the volume was closed); otherwise kept. A file this operation did not create is
  never touched - an unrelated `name.z09` beyond the failure point, a declined or refused name
  (106), the reopened volume of a self-extractor's second pass (106 N3).
- Q: A pre-existing `name.z01` that the user agreed to overwrite ("Overwrite?" *Yes* / *All*) and
  the pack then fails? -> A: **Deleted with the set.** Its old content was destroyed by the
  overwrite the user confirmed; what the name holds from then on is this operation's partial volume
  data - keeping it would leave exactly the stray volume this item removes. 106 already counted it
  as "ours" (`TempNameOurs`) for the current volume; 119 applies the same rule to every volume.
- Q: Removable media? -> A: **Only the volume still being written, and only while it is the very
  file this operation created.** The earlier volumes are on other disks; with sequential names off
  every disk holds `name.zip`, and with them on the disk in the drive is not the one written
  earlier (106's reason for not deleting by name). Code review SF2: `NextDisk` closed volume n and
  showed "insert the next disk" while the volume still counted as "ours" - *Cancel* there deleted
  `TempName` on the NEW disk (the user's `name.zip` with sequential names off). Now the closed
  volume stops being "ours" before the disk can change, and the identity check runs here too
  (another disk = another volume serial: kept). Deleting all recorded volumes on removable media
  (safe with the identity check) is not done - untestable here, recorded.
- Q: When is it too late to delete? -> A: **Once the archive is complete** (the last volume written
  and renamed, a self-extractor's directory written). A Move's source clean-up runs after that
  point; its failure (low memory, after some sources were deleted) must never delete the archive
  that holds them - before 119 it deleted the current volume when the last volume had not been
  renamed (WinZip names off).
- Q: Multi-volume into `name.zip` that exists - ask "overwrite?" or refuse? -> A: **Refuse before
  anything is created**, with the plug-in's own existing text `IDS_CANTMULTIVOL` ("Archive of the
  same file name already exists. The multi-volume archives can be created only like a new
  archive.") and the archive's name - the original authors' rule (commented out in
  `PackToArchive`), applied only where the last volume will really be renamed to `name.zip`: a
  fixed disk, sequential names, WinZip names, no self-extractor. Asking again would contradict the
  *Add* the user just chose in the core's question, and would need a replace-at-the-end logic. The
  user chooses *Overwrite* (the core deletes the old archive, the set is created) or another name.
- Q: And when the final rename fails anyway (the name appeared during the pack, removable media,
  access denied)? -> A: **A failed pack**: the error names the archive (`IDS_CANTMULTIVOL` for
  "exists", else "Cannot open or create file." with the system's text), a Move deletes no source,
  and the volumes this operation created are deleted (fixed disk). Before 119 it was silent and a
  Move deleted the sources.
- Q: Where to refuse a pack into an archive that is one of its own sources (items 3, 4)? -> A: **In
  the core, before any packer, on every route** - the Pack dialog (any answer), F5 / F6 into the
  archive panel, drag & drop and cut + paste - with 106's identity rule
  (`PackArchiveIsSelectedSource`: the archive is a selected file under any spelling or a hard link,
  or lies inside a selected folder). One check covers ZIP, 7-Zip and the external RAR packer and
  uses the core's existing texts; a check in each plug-in would need a new text in each. Nothing is
  touched (also not the zero-size archive the F5 route deletes before packing).
- Q: The Pack dialog's "Add or Overwrite?" question when the archive is selected? -> A: **Not asked
  any more**: every answer would be refused (106 refused *Overwrite*; 119 refuses *Add*), so the
  refusal comes first. 106's check inside the *Overwrite* branch stays as a guard.
- Q: Behaviour change acceptable? -> A: Yes, recorded: packing into an archive that is itself
  selected (or inside a selected folder) is refused as a whole - deselect it. Before, ZIP added the
  other files after the user skipped the archive's sharing violation, and 7-Zip put the old archive
  inside the new one.
- Q: Item 5, the text? -> A: **The refusal names the archive** with the core's `CFileErrorDlg`
  (template `IDD_ERROR3`: "Name:" + "Error:" + OK) and the existing "Cannot copy a file to itself."
  / "Cannot move a file to itself." (Move); captions "Pack", "Copy Error", "Move Error". No core
  string with a `%s` exists; "deselecting helps" in words would need a new string in 8 languages -
  not added (no new strings unless clearly needed), recorded.

## User Scenarios & Testing

### User Story 1 - A failed multi-volume pack leaves nothing behind (Priority: P1)

A user packs a folder into `out\m.zip` as a multi-volume archive; a file cannot be read (it is
open in another program) and the user cancels. Nothing of the abandoned set remains in `out`; files
in `out` that the pack did not create are untouched; with Move every source is still there.

**Acceptance Scenarios**:

1. **Given** sources `a1.bin` (12 KB) and `z9.bin` (held open by another program), **When** packed
   as multi-volume `out\m.zip` with 4 KB volumes and the error is answered *Cancel*, **Then** no
   `m.*` file was created and left in `out`, and both sources are unchanged (Copy and Move).
2. **Given** `out\m.z09` and `out\m.txt` exist, **When** the same pack fails, **Then** both are
   byte-identical afterwards.
3. **Given** `out\m.z01` exists and "Overwrite?" is answered *Yes*, **When** the pack then fails,
   **Then** `out\m.z01` is gone with the rest of the set.
4. **Given** 106's refusal at volume 4 (a selected source is named `a.z04`) or a declined
   "Overwrite a.z02?", **When** the operation ends, **Then** volumes 1..3 (1) are gone and the
   refused / declined file is unchanged.

### User Story 2 - A multi-volume pack never ends with a misnamed set (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `out\k.zip` exists (not selected), **When** the user packs into it with *Add* (or the
   question switched off) and chooses multi-volume, **Then** the ZIP plug-in says "Archive of the
   same file name already exists. The multi-volume archives can be created only like a new
   archive." for `k.zip`, nothing is created, `k.zip` and the sources are unchanged (also Move).
2. **Given** the same, **When** the user answers *Overwrite*, **Then** the set is created and its
   last volume is `k.zip`; 7-Zip tests it OK.

### User Story 3 - Packing an archive into itself is refused, with its name (Priority: P2)

**Acceptance Scenarios**:

1. **Given** `src.zip` (or `src.7z`) and `b.bin` selected, **When** packed into `src.zip` with
   the Pack dialog, **Then** before any question a box "Pack" shows `Name: ...\src.zip` and
   "Cannot copy a file to itself." (Move: "move"), the Pack dialog comes back, nothing changed.
2. **Given** the archive shown in the other panel is one of the selected items (or inside a
   selected folder), **When** F5 / F6 (or drag & drop, paste) into it, **Then** "Copy Error" /
   "Move Error" names it, nothing is packed or deleted.
3. **Given** an existing archive that is not selected, **When** packed into, **Then** the "Add or
   Overwrite?" question and both answers work as before.

### Edge Cases

- A volume recorded by the operation whose name was meanwhile taken by another file: not deleted.
- A file system without file ids: a recorded volume is deleted only while its creation time and
  size are unchanged, else kept; a selected item with the archive's size and times is a "maybe" and
  refused.
- Low memory while recording a volume: the volume just created is deleted and the pack fails
  (never an unrecorded volume).
- Czech (CP1250) and any other names: identities, not names, decide; all names are UTF-8 / wide.
- Self-extractor routes: unreachable (no SFX package); its exe is not recorded (unchanged).

## Requirements

- **FR-001**: A multi-volume ZIP pack that ends without a complete archive (error, refusal, Cancel,
  a failed final rename) MUST delete, on a fixed or network disk, every volume this operation
  created whose name still holds the file it created, and nothing else.
- **FR-002**: On removable media only the volume still being written is deleted, and only while
  the name on the disk in the drive still holds that file (never after the disk may have changed).
- **FR-003**: Once the archive is complete, nothing is deleted, whatever fails later.
- **FR-004**: With sequential + WinZip names on a fixed disk, a multi-volume pack into an existing
  `name.zip` MUST be refused before anything is created, with `IDS_CANTMULTIVOL` and the name.
- **FR-005**: A failed rename of the last volume MUST be reported and treated as a failed pack.
- **FR-006**: The core MUST refuse a pack into an existing archive that is one of the selected
  sources (any spelling, a hard link, or inside a selected folder) on the Pack dialog, F5 / F6 and
  drag & drop / paste routes, before any question, deletion or packer.
- **FR-007**: The refusal MUST name the archive (`CFileErrorDlg`, `IDD_ERROR3`) with the existing
  copy / move "to itself" text.
- **FR-007a**: The check MUST NOT open every selected plain file when it is certain none can be the
  archive (usable ids, one link, the archive's folder known); folders, links and uncertain cases are
  checked one by one (code review SF5).
- **FR-008**: A Move MUST NOT delete any source after a refused or failed pack.
- **FR-009**: No plug-in interface change, no registry change, no new string.

## Success Criteria

- **SC-001**: `probe/packleft_probe.ps1` on this build: every RUN/END row PASS, loss 0; on the build
  before 119 the D, E-decline-vol2, L, K-add, B, H and A (question) rows fail.
- **SC-002**: saltests 14,576 -> 14,655, 0 failed; strict encoding guard `TOTAL: 0`; Debug and
  full Release builds succeed.
