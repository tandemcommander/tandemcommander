# Implementation Plan: Undelete restores files under their own names, from the volume chosen (feature 114)

**Branch**: `114-undelete-names` (from `113-zip-read-error-skip`, 508e9910) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre114`, copy of `Debug_x64` = HEAD). The FAT rule, the short / long name route, the volume layer and the sweep by code reading (`research.md` 1-3); GUI measurements of the build before: pending (the maintainer's day - no GUI) |
| S1 helpers | `src/common/salfatname.h` (header-only, pure): `SalFatShortNameToW` (0xE5 -> '$' + lost flag, 0x05 escape, OEM code page, NT case bits on A-Z), `SalFatShortNameChecksum`, `SalFatLostFirstByteCandidates` (the first character Windows keeps; hash form = no link); `src/common/salvolpaths.h`: `SalVolumePathsWToU8`, `SalVolumePathWToU8` (left out / refused, never cut) |
| S2 FAT parser | `fat.h DecodeDirectoryClusters`: candidates for the lost byte, LFN loop bounded (63 entries), names from `SalFatShortNameToW` (`NewFromUnicode`), `FR_FLAGS_NAMEFIRSTCHARLOST` (`library/undelete.h`); `ConvertFATName` / `ChkSum` removed (`fat.cpp`) |
| S3 listing and restore | `fs2.cpp`: `Replace0xE5` removed (listing, progress), `namecmp` plain, `FixDamagedName(record, name)` by the flag, "All" = one UTF-8 character (`AllSubstPrefix`, `undelete.h`) |
| S4 conversions | `miscstr.cpp`: `NewFromUnicode` / `CopyFromUnicode` / `CopyToUnicode` WTF-8; error texts UTF-8 (`FormatResU8`, `FormatMessageW`, bounded, whole characters); `AddNumberSuffix` sized by the name |
| S5 volume layer | `os.h` / `os.cpp`: A pointers removed, W specialisations (`OS_GetVolumeNameForVolumeMountPoint`, volume and mount-point enumeration, `OS_GetVolumePathNamesForVolumeName`, `OS_GetDiskFreeSpaceEx`), `UndGetVolumePathNameU8`, drive icon W; `fs2.cpp RootPathFromFull`, `dialogs.cpp OnDialogOK` on it; the volume list UTF-16 (`LVM_*W`); EFS capability via `OS_GetVolumeInfo` / `OS_GetVolumeType` (`fs2.cpp`, `restore.cpp`) |
| S6 sweep fixes | NTFS stream-name buffer (`ntfs.h`), `CopyFile` stream path, `.bak` append, progress names (`dialogs.{h,cpp}`), `IDS_TEMPDIR` buffer, exFAT entry-set bounds (`exfat.h`), the unused `tsz[100]` copy (`os.h`), `RootPathFromFull` backslash |
| S7 tests | saltests `TestUndeleteNames114` (checksum vs an independent loop, every first byte x 8 OEM code pages, escape / marker / case bits, candidates incl. CP932 0x05 escape, volume multi-strings) |
| S8 probe | `probe/make_images.py` (FAT12 + exFAT + dup images, expected.json; self-test; FAT image checked by 7-Zip) and `probe/undelnames_probe.ps1` (fat, exfat, dup rows; `-Expect before`); written, GUI runs pending |
| S9 gates | Debug + full Release builds, saltests, strict encoding guard, sources' BOM / CRLF; records (fix-log, CHANGELOG, NEXT-WORK, the proposed CLAUDE.md entry) |

No plug-in interface change (107), no configuration change, no new string.
