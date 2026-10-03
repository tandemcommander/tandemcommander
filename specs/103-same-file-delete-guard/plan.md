# Implementation Plan: the source is never "the existing target" (feature 103)

**Branch**: `103-same-file-delete-guard` (from `102-filecomp-unicode-names`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S1 rule | `src/common/salsamefile.h` (header-only, wide API): `CSalFileIdentity` (serial + 64-bit index, 128-bit `FileIdInfo` mirrored for `_WIN32_WINNT` 0x0601, link count, size, times, attributes), `SalGetFileIdentityW` (attribute-only open, directories, the link itself for a rename), pure `SalFileIdMatch` / `SalFileMetaEqual` / `SalDecideExistingTarget`, the self-checking `SalRenameViaTempName` (template over the move function). UTF-8 facade in `salfileio.{h,cpp}`: `SalGetFileIdentity`, `SalRenameViaTempNameU8` |
| S2 core | `DoMoveFile` same-root branch: identity before the 8.3 tidy-up and the overwrite/delete branch; done -> `OPERATION_DONE`, another file -> unchanged branches, failure -> the move error (naming the temporary path if the source stayed there). `RenameFileInternal`: the same with a `keepTarget` guard over both old branches. `DoCopyFile` `CREATE_ERROR` exists: source identity from the open handle, refusal through the worker's error dialog (`IDS_ERRORCOPY`/`IDS_ERRORMOVE`, `IDS_CANNOT*TOITSELF` as UTF-8) with Retry / Skip / Skip All / Cancel |
| S3 plug-ins | Renamer `CRenamerDialog::MoveFile`, PictView `RenameFileInternal`: the same rule through `SG->SalMoveFile`; no interface change |
| S4 tests | saltests `TestSameFile103`: rule tables, a fake folding file system for the route (alias, other file, locked source, failing second step, failing way back, taken temporary names, no room), real NTFS files (hard link, 8.3 alias, directory, missing file, the route) |
| S5 probe | `probe/samefile_probe.ps1` + `probe/davnorm.py` (hidden desktop): 23 cases on both builds; regression 092/095/096/098/099/101; independent review; Release build; records |

Pre-change build: `build\tandemcommander\Debug_x64_pre103`.
