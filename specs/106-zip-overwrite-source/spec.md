# Feature Specification: A pack never writes its archive over a file it packs

**Feature Branch**: `106-zip-overwrite-source`
**Created**: 2026-10-04
**Status**: Draft
**Input**: found by feature 103 (`specs/103-same-file-delete-guard/research.md` row 15, fix-log
"Left"), `specs/NEXT-WORK.md` item 5, the 103 entry: "the ZIP plug-in can overwrite a selected
source with the new archive's file after 'overwrite?' (another defect class)". Measured before
the work (`research.md`); the maintainer asked for autonomy.

## Clarifications

### Session 2026-10-04

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right? -> A: Yes for the ZIP plug-in's **multi-volume** packing, and the
  loss is worse than recorded; the **self-extractor** routes are unreachable (no SFX package is
  shipped - 104). And a second route the premise did not name loses the source on every packer:
  the **core's Pack dialog, "Overwrite"**. Measured on the build before (`research.md`,
  `probe/packself_result_measurement_pre106.txt`):
  - multi-volume, a selected file named like the first volume (`a.z01` for `a.zip`): "overwrite?"
    *Yes* truncates it before it is read, the read then fails (the volume is open without
    sharing) and the failure deletes the volume - **the source is gone**, also on a Copy, under
    every spelling (same name, case, the folder's 8.3 name, `\\localhost\C$`, a hard link);
  - named like a later volume (`a.z04`): the source is read first, then overwritten by volume 4 -
    Copy leaves the source **replaced by archive data**; Move deletes "the source" (= volume 4):
    the archive is broken ("Missing volume") and **the other files are deleted too**;
  - the overwrite question declined (Cancel) for a later volume of an unrelated existing file
    (`out\a.z02`, not selected): **the declined file is deleted** (the cleanup deleted the
    current volume name whether or not this operation created it);
  - the core's Pack dialog: archive name = a selected file, the core asks "Add or Overwrite?",
    *Overwrite* deletes that file before the packer runs - ZIP and 7-Zip, Copy and Move, every
    spelling: **the selected source is gone and not in the archive**.
- Q: The rule? -> A: Before any output of a pack is created or truncated - a volume, the
  self-extractor, and (core) the existing archive that "Overwrite" deletes - its identity is
  compared with the files being packed (`salsamefile.h`: volume serial + file id; where the file
  system has no usable ids, equal metadata counts as "maybe" = yes). A match is **refused before
  anything is touched**, before any overwrite question. Hard links count (a truncation reaches
  the shared data). A failed or refused multi-volume pack deletes only a volume it created
  itself. Move never runs after a refusal (it ran only on success before, too).
- Q: The core's "Overwrite" when the old archive is one of the selected files - e.g. select all
  in a folder that holds last week's `D.zip` and pack into `D.zip` with Overwrite? -> A:
  Refused ("Cannot copy a file to itself."), the Pack dialog comes back; the user deselects the
  old archive or chooses another name. The alternative - deleting the old archive as asked and
  packing the rest - is what the old code did for that one workflow, but the same branch lost a
  file the user wanted packed in every other case (a file named like the archive, any alias), and
  7-Zip itself refuses this ("It is not allowed to include archive to itself"). The same for an
  archive that lies inside a selected folder (its tree is packed). Recorded as a behaviour change.
- Q: Which comparison does the core do, and at what cost? -> A: Only on the "Overwrite" answer:
  the identity of every selected item, and of every folder above the archive (a selected folder
  that is one of them contains the archive). Links followed (a junction selected is packed
  through).
- Q: Where is the ZIP check, and what does it compare? -> A: The files are listed (the
  enumeration) before the first output exists - multi-volume and self-extractor used to create
  their first file first. At every volume creation (`CreateNextFile`) and before the
  self-extractor, an existing output file is compared with every listed file (the listed size is
  no filter: a hard link written through its other name is listed with a stale size - review
  SF-1).
- Q: The ordinary ZIP pack (an existing archive that is itself selected; Add; F5/F6 into the
  archive shown in the other panel), 7-Zip, TAR, the external archivers? -> A: Measured, no loss:
  the ZIP plug-in keeps the archive open for writing while it packs, so reading the archive as a
  source fails with a sharing violation (Skip/Cancel; a skipped file is not deleted by Move) -
  in place and with the backup copy. The 7-Zip plug-in writes a temporary archive and replaces
  the old one: the old archive ends up inside the new one, and a Move cannot delete the archive
  (it holds it open; "Delete Error" Skip). TAR does not pack. The RAR packer (WinRAR) is not
  installed here - not driven; the core's refusal runs before any packer. Unchanged, recorded.
- Q: Strings? -> A: The core reuses "Cannot copy a file to itself." / "Error Overwriting File".
  The ZIP plug-in cannot reach core strings and has none that fits, so one new string,
  `IDS_PACKEDSOURCE` (1255, a free slot of an existing bundle - no re-keying): "This file is one
  of the files being packed. The archive cannot be written over it." - translated for the 8
  enabled languages (DeepL, then pinned in `translations/ui-overrides.json`).
- Q: Interface, configuration? -> A: Plug-in interface unchanged (107), no registry change.
- Q: Partial volumes after a refusal at volume 2 or later? -> A: Volumes 1..n-1 that this
  operation wrote stay, as after any other failed multi-volume pack (disk full, Cancel) - they
  are the operation's own output, not user data; deleting them by name is unsafe on removable
  media (all volumes may carry one name). Recorded.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A multi-volume ZIP never destroys a file it packs (Priority: P1)
**Independent Test**: multi-volume `a.zip` (4 KB volumes) from a folder holding `a.z01` or
`a.z04`, Copy and Move, the archive name typed as the same name, another case, the folder's 8.3
name, `\\localhost\C$\...`; a volume name that is a hard link of a selected file.
**Acceptance**: refused before any overwrite question; every source byte-identical.

### User Story 2 - "Overwrite" in the Pack dialog never deletes a file to be packed (Priority: P1)
**Independent Test**: Pack (Alt+F5) a selection that contains the archive's name, ZIP and 7-Zip,
Copy and Move, every spelling; an archive inside a selected folder; "Overwrite" of an existing
archive that is not selected.
**Acceptance**: refused with "Cannot copy a file to itself." and the dialog again, sources
byte-identical; the unrelated archive is overwritten as before.

### User Story 3 - A declined overwrite keeps the file (Priority: P1)
**Independent Test**: multi-volume into a folder holding an unrelated `a.z02` / `a.z01`, the
question answered Cancel.
**Acceptance**: the file is byte-identical.

### Edge Cases
- A file system without file ids (WebDAV): equal size + times counts as the same file (refused).
- The output exists but cannot be read: not compared (the write then fails as before).
- Ordinary packing (no collision), plain and multi-volume, Copy and Move: works; 7-Zip tests the
  archive and holds every source byte-identical.

## Requirements *(mandatory)*
- **FR-001**: No pack route of the ZIP plug-in may create over (truncate) an existing file that
  is - under any spelling or hard link - one of the files the operation packs.
- **FR-002**: The core's Pack dialog MUST NOT delete an existing archive that is a selected file
  or lies inside a selected folder.
- **FR-003**: A refusal happens before any overwrite question and before anything is written;
  nothing is deleted after it.
- **FR-004**: A failed multi-volume pack deletes only a file the operation created.
- **FR-005**: Plug-in interface 107 and the registry format unchanged; wide file APIs.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/packself_probe.ps1` on this build: 0 FAIL, 0 loss; on the build before: the
  losses reproduced on every route of US1-US3.
- **SC-002**: saltests (13,555 before) pass with the new rule's checks; the strict encoding
  guard reports 0.
- **SC-003**: Debug + Release builds; the 094 ZIP, 099 linkmove, 097 arcwork (subset) and 103
  samefile probes give the same results as before.
