# Plan: 153 - the Archive Update dialog's warning

**Spec**: [spec.md](spec.md) · **Log**: [fix-log.md](fix-log.md)

## Technical context

- `CFilesWindow::ExecuteFromArchive` (`fileswn6.cpp`) - the F4; `CFileTimeStamps` (`fileswnd.h`,
  `salamdr3.cpp`) - the edited copies, `CheckAndPackAndClear`, `AddFilesToListBox`;
  `CArchiveUpdateDlg` (`dialogs5.cpp`) unchanged.
- `PackList` (`pack1.cpp`) lists an archive into a `CSalamanderDirectory`; the plug-in data of a
  successful listing are released like `CSalShExtPastedData::ReleaseStoredArchiveData`.
- Pure rules: `src/common/salarcedit.h` (+ saltests).

## Constitution check

I no dependency. II no interface / registry change; one string in a free slot of an existing
bundle (12174), translated through the pipeline (`translate.merge`). III additive. IV Windows API
only. V plug-ins unchanged. VI the dialog unchanged, its list text longer (scrolls). PASS.

## Design

F4 stores `CFileTimeStampsArcStamp`. `MarkChangedInArchive` before the dialog: the archive's stamp
now; equal to the F4's = plain; otherwise one new listing for all items, the member compared.
