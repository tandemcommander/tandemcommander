# Implementation Plan: Undelete's leftovers (feature 115)

**Branch**: `115-undelete-leftovers` (from `114-undelete-names`, b06ff2b9) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre115` = a copy of `Debug_x64` = HEAD b06ff2b9, without `Intermediate` folders). The walk of Restore Encrypted Files, the duplicate removal, the name identity sites, the sweep by code reading (`research.md`); EFS on this machine checked read-only (cipher.exe present, no user EFS certificate, C: / D: report FILE_SUPPORTS_ENCRYPTION) |
| S1 helper | `src/common/salnameorder.h` (header-only): `SalNameOrderCompareCI` / `SalNameOrderEqualCI` = the core's `SalNameCompareOrdinalCI` / `SalNameEqualOrdinalCI` |
| S2 name identity | `library/miscstr.{h,cpp}` `String<char>::NameCmp`; `fs2.cpp` `namecmp`, `compare_items`, `RenameDuplicateFiles`; `fat.h` `compare_names`, `RenameDuplicateDirectories`, `RemoveDuplicateFiles` |
| S3 duplicates | `fat.h` `FATSameStreamData` (size + every data-runs block), `RemoveDuplicateFiles` compares every kept item of a run of equal names |
| S4 the walk | `restore.cpp` rewritten around `CWalkPath` (heap, `SAL_MAX_PATH_UTF8`), `CWalkStack` (heap stack of searches), `CDirId` (103's `CSalFileIdentity` - usable 128/64-bit ids only - plus the normalised final path; review SF1), `WalkError` (Skip / Skip all / Cancel, system text); `RestoreDir` / `GetDirSize` iterative; `RestoreEncryptedFiles` reads the panel path whole; `RestoreFileAt`: signature really read, context / source handle fixes |
| S5 sweep | `fs2.cpp`: `CopyFile` path on the heap (View: the full disk-cache name), `.bak` cleanup, `SourcePath` restored on the early returns, `AppendPath` refuses a target that does not fit, `UndeleteGetResolvedRootPath` bounded, `CloseEncryptedFileRaw` only after a successful open; `dialogs.cpp` progress labels keep the end of a long path |
| S6 tests | saltests `TestUndeleteLeftovers115` (parity with the core over a corpus incl. the 7 different-length case pairs, Kelvin / dotless i / long s, lone surrogates, legacy bytes, heap-length names, 20,000 random pairs; a sort keeps equal names together) |
| S7 probe | `probe/make_images115.py` (FAT12 with a directory cluster reached twice, two tiny files of one name, C-caron / c-caron; exFAT with C-caron / c-caron and a / A; 114's long-name image) and `probe/undelleft_probe.ps1` (fat, exfat, view, enc-deep, enc-long, enc-loop; `-Expect before`); written, GUI runs pending |
| S8 gates | Debug + full Release builds, saltests, strict guard, BOM / CRLF; records (fix-log, CHANGELOG, NEXT-WORK, proposed CLAUDE.md entry) |

No plug-in interface change (107), no configuration change, no new string.
