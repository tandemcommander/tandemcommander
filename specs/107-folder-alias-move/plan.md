# Implementation Plan: a folder is never copied or moved onto another path of itself (feature 107)

**Branch**: `107-folder-alias-move` (from `106-zip-overwrite-source`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | `probe/folderalias_probe.ps1` on `Debug_x64_pre107`: every route x alias x shape (a: into itself, b: the same place, c: into its subfolder), hard links through an alias, controls (`research.md`) |
| S1 rules | `src/common/salsamefile.h` (pure, header-only): `SalDirIsSame` (snapshot tags differ -> no; ids - on FAT only with equal times; without ids equal kind + times + the path below the server name up to case/NFC; fail-closed parameter), `SalSnapshotTagFromPath`, `SalFsNameHasWeakIds`, `SalGetFileIdentityW(..., volumeTraits)`, `SalDirChainHolds` (the target folder or a folder above it is the source), `SalSameDirEntry` + `CSalSameEntry` (one hard link or two), `SalDecideExistingTargetEx` / `SalDecideNeedsSameEntry` (103's copy rule with the entry answer; `SalDecideExistingTarget` = `Ex(sseNo)` for the plug-ins). UTF-8 facade in `salfileio.{h,cpp}`: `SalSameDirEntryU8` (holding folders' identities + `FindFirstFile`'s stored names), `SalGetFinalPathU8Alloc` (`GetFinalPathNameByHandleW`, prefix stripped), `SalNamesLooselyEqualU8` |
| S2 script build | `fileswn6.cpp`: `DirTargetIsSource107` called from `BuildScriptDir` for the top-level folder of a copy/move whose path differs by name from the target: (1) `T\name` exists and is the source -> refuse (copy "Cannot copy a file to itself.", move "Cannot move a directory to itself."); (2) a move: `T` or a folder above it is the source -> refuse. `CDirTargetChain107` reads `T`'s chain once per operation (as written + resolved), reset in `BuildScriptMain`, `BuildScriptMain2`, `MoveFiles` |
| S3 worker | `worker.cpp DoCreateDir`, "directory overwrite": the existing folder is the source folder -> refuse (Retry / Skip / Skip All via `SkipAllSameFile` / Cancel) before the overwrite question; a move refuses when it cannot tell. `DoCopyFile` (103's refusal): `sameEntry` for a hard-linked source |
| S4 tests | saltests `TestFolderAlias107`: rule tables + real NTFS folders (case, 8.3, `\\localhost\C$`, the chain of `F\sub`, final path) and hard links (same folder, another folder, case, 8.3, UNC) |
| S5 probe | `probe/folderalias_probe.ps1 -Expect107` on this build; regression 103 (`-Expect103`), 099, 098, 106; independent review; Release build; records |

Pre-change build: `build\tandemcommander\Debug_x64_pre107`.
