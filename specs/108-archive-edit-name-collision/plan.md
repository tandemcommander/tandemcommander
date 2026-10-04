# Implementation Plan: every edited archive member is packed back as itself (feature 108)

**Branch**: `108-archive-edit-name-collision` (from `107-folder-alias-move`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | collision set computed on this machine's code page (`CharLowerA` table of `str.cpp` + `CompareStringOrdinal`); `probe/namecoll_probe.ps1` (+ `probe/arcfix.py`, which makes and reads the archives) on `Debug_x64_pre108`: six pair kinds that fold together, single edits of a pair, NFC/NFD, three kinds of pairs equal by the file system's rule, one member twice, one member through a typed folder spelling, the 096 single accented edit - each in ZIP and 7z (`research.md`) |
| S1 rule | `src/common/salarcedit.h` (pure, header-only on 092's helpers): `SalEditedCopyIsSame` (the same temporary copy: folder by `SalPathEqualOrdinalCI`, name by `SalNameEqualOrdinalCI`), `SalEditedCopiesPackTogether` (one packer call: the folder in the archive byte for byte, the folder on disk by the rule) |
| S2 core | `salamdr3.cpp`: `CFileTimeStamps::AddFile` "already present" by `SalEditedCopyIsSame`; `CheckAndPackAndClear` grouping by `SalEditedCopiesPackTogether`. `fileswn6.cpp`: `GetZIPPathAsStored108` (the panel's archive path in the listing's stored spelling, component by component through `CSalamanderDirectory::GetUpperDir`) used by `ExecuteFromArchive` for the disk-cache name, the archiver's name and `AddFile`'s folder |
| S3 tests | saltests `TestArchiveEdit108`: the pair tables against the rule and against NTFS (two files or one), the legacy fold's collisions on CP1250, folder spellings, grouping |
| S4 probe | `namecoll_probe.ps1` on this build and on `Debug_x64_pre108`; regression 096 archedit, 097 arcwork subset, 092 focus, 106 packself (`probe/regress_*_108.txt`); full Release build; records |

Not touched (recorded): the ZIP plug-in's name matching on update (`zip/add.cpp`), the disk-cache
keys, `CSalamanderDirectory`'s byte-fold folder merging, the F3 viewer's cache name.

Pre-change build: `build\tandemcommander\Debug_x64_pre108`.
