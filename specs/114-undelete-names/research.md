# Research: feature 114 - Undelete names and volumes

Measured by code reading on HEAD 508e9910 (113) - no GUI run was possible today (the maintainer
used the installed program, which shares `HKCU\Software\Tandem Commander` with every probe). The
GUI evidence is the pending probe (`quickstart.md`); the pure rules are proven by saltests.

## 1. Where the 0xE5 rule belongs

FAT directory entries (FAT specification, "Directory entry"): `DIR_Name[0] == 0xE5` marks a
**deleted** entry; a short name whose real first byte is 0xE5 (a lead byte of the Japanese OEM
code page 932) is stored as **0x05**. The rule is about the 11 raw bytes of a **short-name** entry,
in the OEM code page. Long-name (LFN) entries carry UTF-16 and mark deletion in their ordinal byte
(`LDIR_Ord = 0xE5`), which is not part of the name. exFAT marks a deleted entry set by clearing the
InUse bit of the entry type (0x85 -> 0x05). NTFS has no such byte.

### The build before (code reading)

| Site | What it did |
|---|---|
| `library/fat.cpp ConvertFATName` | 8.3 bytes -> "NAME.EXT"; byte 0 0x05 -> 0xE5; bytes copied as they are (OEM code page bytes into a string the plug-in treats as UTF-8) |
| `library/fat.h DecodeDirectoryClusters` | `FNName = NewFromASCII(name8_3)` (raw OEM bytes, the deletion marker 0xE5 still in byte 0); NT case bit 0x08 lowered **base and extension** with `_strlwr` (bit 0x10 ignored); long name `NewFromUnicode` (UTF-8, lone surrogate -> U+FFFD) |
| `library/fat.h` (deleted entry with LFN) | first letter reconstructed with `WideCharToMultiByte(CP_ACP, 0, ..., 1 byte)` + `CharUpperA` - the ANSI code page, best fit, one byte; Windows writes the OEM byte of the first character it KEEPS (upper case; characters outside the OEM code page are DROPPED - see "How Windows makes a short name" below) |
| `fs2.cpp Replace0xE5` | byte 0 0xE5 -> '$', 0x05 -> 0xE5 - applied to the **UTF-8** name of every file system: the panel listing (`fd.Name`, `fd.DosName`), the progress text, `FixDamagedName` |
| `fs2.cpp namecmp` | path components: '$' equal to a first byte 0xE5 |
| `fs2.cpp FixDamagedName` | a name whose first **byte** is 0xE5 is "damaged": the Damaged Filename dialog asks for the first character; "All" remembers ONE byte (`AllSubstChar`) |

### Consequences (by code reading; the probe measures them on `Debug_x64_pre114`)

- **Every file system**: a name whose UTF-8 form begins with the byte 0xE5 - every name starting
  with a character of U+5000..U+5FFF (4,096 CJK characters, e.g. U+597D, U+5A46, U+5F00) - is
  listed with '$' and two stray bytes (invalid UTF-8, shown as code-page mojibake). Restoring it
  opens the Damaged Filename dialog with that mojibake; whatever is answered, the file is restored
  under a name that is not its own. NTFS (the common case) and exFAT: deleted and existing files
  alike; FAT: long names of existing entries and of entries in a deleted directory left intact.
- FAT, **deleted** long names: the reconstruction from the ANSI code page matches the stored
  checksum only when the ANSI and OEM bytes of the upper-cased first character are equal - for
  ASCII. On a Czech system (ACP 1250, OEM 852) `\u010Clanek.txt` (0xC8 vs 0xAC) and any name
  whose first character is dropped by Windows (outside the OEM code page - the short name starts
  with the next kept character, e.g. `X` for `<U+5F00><U+59CB>x.txt`; the old code guessed '?')
  lose their long name: the short name is shown instead.
- FAT **short names** outside ASCII: OEM bytes handed on as UTF-8 - shown as mojibake, restored
  under whatever the core makes of invalid UTF-8; a short name stored with the 0x05 escape was
  listed with '$' (0x05 -> 0xE5 in `ConvertFATName`, then 0xE5 -> '$' in `Replace0xE5`) and asked
  for although nothing was lost.
- NT case bits: bit 0x10 (extension in lower case) ignored, bit 0x08 lowered the extension too:
  `README.txt` was listed `README.TXT`, `readme.TXT` was listed `readme.txt`. Windows lowers A-Z
  only (fastfat `Fat8dot3ToString`): a short name `<C-caron>AJ.TXT` with both bits is shown as
  `<C-caron>aj.txt` (such short names come from Linux; Windows writes a long name then).
- Long names with an unpaired surrogate (legal in UTF-16 names): converted with
  `WideCharToMultiByte(CP_UTF8, 0)` - U+FFFD, the file restored under another name (066's rule
  is WTF-8).

### How Windows makes a short name (review SF1 - the first version of 114 got this wrong)

fastfat calls `RtlGenerate8dot3Name(name, TRUE, ...)` (extended characters allowed); ReactOS
`dos8dot3.c` keeps a character only if it is > space, not '.', and ASCII (< 127) or an OEM character
that converts back to itself after upper-casing; only `+ , ; = [ ]` become `_`. A character Windows
cannot put into a short name is **dropped, not replaced**. A base of 0-2 kept characters gets a
4-hex-digit hash before the tail. Measured with `dir /x` (NTFS - the same generator, with extended
characters NOT allowed by default, so every non-ASCII character is dropped there):
`<C-caron>l<a-acute>nek dlouh<y-acute>.txt` -> `LNEKDL~1.TXT`, `<C-caron>X.txt` -> `X76F3~1.TXT`,
`<C-caron>.txt` -> `80E2~1.TXT`, `<U+597D>.txt` -> `191D~1.TXT`. When nothing of the base name is
kept the short name is a hash form and its first byte says nothing about the long name: a
DELETED entry's long name cannot be linked back - the short name is shown as damaged and asked
for, as before 114. The first version of 114 assumed '_' for such a character (that is what the
Linux vfat driver writes - kept as the last candidate for media written by Linux / cameras /
Android).

### Where the rule is now

`src/common/salfatname.h` (header-only, saltests): `SalFatShortNameToW` decodes the 11 raw bytes
(0xE5 -> '$' + "first character lost", 0x05 -> the OEM 0xE5, OEM code page, NT case bits 0x08 /
0x10 on A-Z, trailing spaces only), `SalFatShortNameChecksum`, `SalFatLostFirstByteCandidates`
(the byte of the first character Windows keeps -> the old ANSI guess -> '_' (Linux vfat) when the
first visible character is not ASCII). The FAT
parser calls it on the raw entry and sets `FR_FLAGS_NAMEFIRSTCHARLOST` on the record when the name
it produced starts with the placeholder. Nothing else applies a FAT rule: `Replace0xE5` is gone,
`namecmp` compares names as listed, `FixDamagedName` asks only for a flagged record and remembers
"All" as one UTF-8 character.

Why the first byte is tried in that order: the checksum is a bijection of the first byte (saltests:
256 distinct sums), so every candidate is a 1/256 chance of taking an unrelated orphan long name -
three ordered candidates instead of one; the old guess is kept so no long name found before is lost.

## 2. The volume layer

| Site | Before | Live? | Effect |
|---|---|---|---|
| `os.cpp` `GetVolumePathNamesForVolumeNameA` (via `volenum.h GetVolumePathForVolumeName`) | the connect dialog's mount-point column | yes | a mount folder outside ASCII: code-page bytes (inside the code page) or a **best-fit look-alike** ("voila" for "voil<U+00E0>") put into a string used as UTF-8 |
| `fs2.cpp RootPathFromFull` `GetVolumePathNameA(userPart)` | the volume opened for a panel path | yes | the UTF-8 path read in the code page "does not exist" -> GetVolumePathName returns the volume of the **nearest existing parent** (e.g. `C:\`): **another volume is opened** and the panel shows the parent volume's deleted files under the mount folder's path |
| `dialogs.cpp OnDialogOK` `GetVolumePathNameA` x2 | "append the panel path when it is on the chosen volume" | yes | both paths can resolve to the parent volume -> the panel path (on another volume) replaces the chosen one |
| `dialogs.cpp AddVolumeDetails` / `OnDialogOK` `LVM_INSERTITEMA` / `LVM_GETITEMA` | the volume list | yes | UTF-8 labels and mount folders shown as mojibake; the mount folder read back through the code page |
| `os.cpp` `FindFirstVolumeMountPointA` / `FindNextVolumeMountPointA` (`EnumerateAllVolumes`) | mount points of each volume | **no** - only when `GetVolumePathNamesForVolumeName` is missing (pre-XP) | converted for consistency |
| `os.cpp` `FindFirstVolumeA`, `GetVolumeNameForVolumeMountPointA`, `GetLogicalDriveStringsA` | GUID paths, drive roots | yes | ASCII in practice; `GetVolumeNameForVolumeMountPointA` also on mount folders (`CVolume::Open` of "X:\..."), converted |
| `os.cpp` `GetDiskFreeSpaceExA`, `SHGetFileInfoA` (drive icon) | sizes, icon | yes | GUID paths / drive roots; converted (W) |
| `fs2.cpp UndeleteGetResolvedRootPath` `GetDriveType` A, `PrepareRawAPI` / `restore.cpp` `GetVolumeInformation` A | EFS support of the restore target | yes | a share named outside ASCII: "no EFS" -> encrypted files written as backups; converted to the plug-in's W wrappers |

All W now (`os.cpp`, `os.h`); the pure parts (UTF-16 multi-string -> UTF-8, a path that does not
fit is **left out, never cut**) in `src/common/salvolpaths.h` under saltests. `RootPathFromFull`
and `OnDialogOK` use `UndGetVolumePathNameU8`; a mount folder whose UTF-8 form does not fit the
dialog's buffer is replaced by the volume's GUID path (same volume).

Mount points cannot be created without admin rights (`mountvol`, `SetVolumeMountPoint`), and
opening a real volume needs admin rights too - the volume rows are verified by code reading and
saltests, not driven.

## 3. The sweep - other code-page and buffer sites (names, paths, messages)

| Site | Class | Decision |
|---|---|---|
| `miscstr.cpp` `NewFromUnicode` / `CopyFromUnicode` / `CopyToUnicode` | lone surrogate -> U+FFFD (another name) | fixed: WTF-8 (`SplUnicodeDetail::WToWtf8`, `SplU8ToW`) |
| `ntfs.h` stream name `CHAR streamname[MAX_PATH]` | a stream name of 87+ CJK characters converted to "" and matched the **default stream** - its data runs were added to the unnamed stream's list | fixed: 3 x MAX_PATH; an unconvertible named stream is left out |
| `fs2.cpp CopyFile` `path[2 x MAX_PATH]`, `lstrcpyn(..., MAX_PATH - 1)` | a long stream name cut inside a character | fixed: room for 765 bytes |
| `fs2.cpp` `strcat(SourcePath, ".bak")` | 4-byte overrun of a member (SourcePath near 259 bytes) | fixed: bounded |
| `dialogs.cpp` `strcpy(SrcName / DestName [MAX_PATH])` | overrun: restore source up to 2 x MAX_PATH, target + stream up to ~1 KB | fixed: 4 x MAX_PATH, `lstrcpyn` |
| `fs2.cpp` `char text[200]` + `sprintf(IDS_TEMPDIR)` | overrun: the Ukrainian text is 226 bytes | fixed: 1024, `_snprintf_s` |
| `miscstr.cpp AddNumberSuffix` `char temp[MAX_PATH + 50]` | overrun: two equal names of 300+ bytes (FAT duplicates, restore list) | fixed: sized by the name |
| `miscstr.cpp Error` / `SysError` / `PartialRestore` | code-page format (`LoadStringA`) + UTF-8 name: in a translated UI the name shown as mojibake; `vsprintf` unbounded; `FormatMessageA` appended code-page text | fixed: UTF-8 format from the UTF-16 resource, `FormatMessageW`, bounded, cut at a whole character |
| `fat.h` LFN collection loop | no bound: more than 63 entries with one checksum (deleted runs, damaged directory) overran `long_name[820]` on the stack | fixed: 63 entries at most |
| `exfat.h` entry set | `SecondaryCount` up to 255: name entries written past `name[256]` on the stack; entries read past the directory buffer | fixed: both bounded |
| `os.h OS_GetDriveFormFactor` `CHAR tsz[100]` + `StrCpy` | overrun for a path of 100+ bytes; **unreachable** (callers pass "X:\") and the copy was unused | removed |
| `fs2.cpp RootPathFromFull` trailing backslash | overwrote the last character instead of appending (never triggered: the API adds one) | fixed |
| `volume.h CVolume::Open` fallback `"\\.\" + rootPath` into `diskVolume[MAX_PATH]` | up to 4 bytes over when `GetVolumeNameForVolumeMountPointW` fails on an `X:\...` path of 256+ bytes (review) | fixed: refused (`ERROR_FILENAME_EXCED_RANGE`) |
| `fs2.cpp CopyFile` encrypted backup `.bak` on `SourcePath` | the review asked whether it is appended once per stream | verified: once per file - the stream loop breaks after the first stream of an encrypted file |
| `SalFatShortNameToW` vs the old `ConvertFATName` | an ASCII short name with an embedded space (`A B     TXT`) or an extension starting with a space was listed without the spaces before; now as fastfat shows it (trailing padding only) | deliberate change (review NIT 3) |
| `restore.cpp RestoreDir` / `GetDirSize` | `SalPathAppend` results ignored: a source path over 519 / 259 bytes recurses into the same folder forever (stack overflow) and restores the parent's files into the target | **recorded** (NEXT-WORK) - Restore Encrypted Files only, long paths, not names |
| `fat.h RemoveDuplicateFiles` | `memcmp(Ptrs, Ptrs, DSSize)` compares DSSize bytes of a 44-byte struct (over-read; the duplicates in {All Deleted Files} are never removed) | **recorded** |
| `fs2.cpp RenameDuplicateFiles`, `fat.h compare_names` / `RenameDuplicateDirectories`, `namecmp` | `_stricmp` on UTF-8 folds ASCII only: deleted `\u010C.txt` and `\u010D.txt` in one folder are not numbered -> the second restore asks to overwrite the first | **recorded** (092's rule would apply) |
| `os.h OS_GetDriveFormFactor` first branch | a mount folder `C:\mnt\x\` opens `\\.\C:` (the parent's drive) - display only; unreachable (callers pass "X:\") | recorded |
| `exfat.h` / `fat.h` Debug traces (`tracePath[MAX_PATH]`, `StrCat_s`), `fs2.cpp TestUndeleteOnExistingFile` | Debug-only | recorded |
| `fs2.cpp` restore target writing | `SafeFileCreate` (UTF-8, core) | already W (104) |
| `fs2.cpp` temp folders, `dialogs.cpp` image / target / temp pickers | | already W (104) |
| `dialogs.cpp` progress labels / captions | code-page resource text through A calls | consistent, unchanged |

## 4. Fixtures without admin rights

Undelete opens a path that does not end with a backslash as a **disk image** (`CVolume::Open`,
`IsImage`): a plain file read with `ReadFile`. `probe/make_images.py` writes the images byte by
byte - FAT12 (1.44 MB geometry; 7-Zip lists it: `KEEP.TXT`, label TC114) and exFAT (512-byte
clusters, bitmap, up-case table, entry sets with the plug-in's set checksum) - so no volume is
touched. NTFS: no image without a formatter or admin rights; NTFS names take the same fixed
listing / restore path and the same WTF-8 conversion, NOT DRIVEN.

The FAT image is written as Windows writes (short names in the OEM code page of the machine,
characters outside it dropped, a hash form when 0-2 base characters are left - `make_images.py
win_sfn`, checked against the measured examples - LFN ordinals 0xE5 for deleted sets, contents of
a deleted directory deleted too), plus one deleted directory whose entries were left intact (a delete that did not
recurse - valid on disk, and the only FAT route on which the old 0xE5 rule hit a long name of the
U+5000..U+5FFF range directly).
