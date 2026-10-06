# Fix log: feature 114 - Undelete restores files under their own names, from the volume chosen

Branch `114-undelete-names` (from `113-zip-read-error-skip`, HEAD 508e9910). Pre-change build
preserved as `build\tandemcommander\Debug_x64_pre114` (a copy of `Debug_x64` = HEAD, made before the
first build). `Debug_x64_111` / `_112` / `_113` not touched. Not committed.

**Working constraint today**: the maintainer used the installed program during the day, and it
shares `HKCU\Software\Tandem Commander` with every GUI probe - so **no GUI run** was made: no
`tandemcommander.exe` started, no registry import/export. The research is by code reading; the
pure rules are proven by saltests; the probe is written and its runs are pending (`quickstart.md`,
on the maintainer's copy `Debug_x64_114`). The only probe invocation made was a check that it
refuses while a `tandemcommander.exe` runs (exit 99, nothing started).

## T001 - measured first (code reading)

Details and every site: `research.md`. In short:

- **The 0xE5 rule ran on UTF-8 names of every file system.** `fs2.cpp Replace0xE5` turned a first
  byte 0xE5 into '$' in the listing (name and DOS name), the progress text and `FixDamagedName`;
  `namecmp` equated '$' with 0xE5; `FixDamagedName` treated every name whose first BYTE was 0xE5 as
  damaged. Every name starting with U+5000..U+5FFF (4,096 CJK characters) on NTFS / exFAT / a FAT
  long name was listed as '$' + two stray bytes and restored, after a Damaged Filename dialog full
  of mojibake, under a name that was not its own.
- **FAT short names were never decoded**: OEM bytes handed on as UTF-8; the 0x05 escape converted
  to 0xE5 in `ConvertFATName` and then to '$' by `Replace0xE5` (an intact name asked for); NT case
  bit 0x08 lowered the extension too, bit 0x10 ignored.
- **Deleted FAT long names were lost** unless the first character was ASCII: the lost first byte
  of the short name was reconstructed in the ANSI code page (best fit, one byte), Windows writes the
  OEM byte of the first character it keeps (it drops what is outside the OEM code page - corrected
  after review SF1) - on a Czech system 0xC8 vs 0xAC for C-caron.
- **Unpaired surrogates** became U+FFFD (`WideCharToMultiByte(CP_UTF8, 0)`).
- **Volume layer**: `GetVolumePathNamesForVolumeNameA` (connect dialog mount column: code-page bytes
  or a best-fit look-alike in a UTF-8 string), `GetVolumePathNameA` on UTF-8 paths in
  `RootPathFromFull` (a mount folder outside ASCII "does not exist" -> the volume of the nearest
  existing parent is opened: **another volume**) and in `OnDialogOK` (both paths resolving to the
  parent -> the panel path replaced the chosen volume); the volume list A messages (mojibake, the
  mount folder read back through the code page). `FindFirstVolumeMountPointA` is on a route that
  runs only without `GetVolumePathNamesForVolumeName` (pre-XP) - dead, converted anyway.
- Sweep: NTFS stream names over 259 bytes of UTF-8 converted to "" and **matched the default
  stream** (their data runs joined the unnamed stream's list); stack overruns (`text[200]` with the
  226-byte Ukrainian `IDS_TEMPDIR`, `AddNumberSuffix temp[MAX_PATH + 50]` for two equal 300+ byte
  names, the FAT LFN loop without a bound, exFAT name entries past `name[256]`), member overruns
  (`SrcName` / `DestName` `strcpy`, `SourcePath` `.bak`); error texts composed of code-page format
  + UTF-8 name; EFS capability via `GetVolumeInformationA`.
- Not reproduced in the GUI on the build before (no GUI today) - the pending pre-114 run is the
  measurement; the predictions per row are in `quickstart.md` and `expected.json` (`defect_before`).

## Decisions (spec.md Clarifications)

- The rule lives in the FAT parser, on the 11 raw bytes of a short-name entry; '$' stays the
  placeholder but is put into the name there, with a record flag `FR_FLAGS_NAMEFIRSTCHARLOST`;
  only a flagged record is asked for. Rejected: keeping 0xE5 in-band and testing "not valid
  UTF-8" (a placeholder byte inside names is the defect's root; a flag cannot collide).
- Lost-byte candidates: the byte of the first character Windows keeps -> the old ANSI guess ->
  '_' (Linux) when the first character is not ASCII; first checksum match wins; a hash form has no
  Windows candidate (damaged, asked for). Rejected: trying all 256 bytes (the checksum is a
  bijection of the first byte - every orphan long name would match).
- "All" remembers one UTF-8 character.
- Volume functions W, UTF-8 at the plug-in's boundary; a result that does not fit is left out or
  refused, never cut; a chosen mount folder that does not fit `Volume` -> its GUID path.
- Error texts: UTF-8 format from the UTF-16 resource (`String<wchar_t>::LoadStr`), system text
  `FormatMessageW`, bounded, cut at a whole character; captions stay code-page resource text (a
  separate parameter, decoded on its own).

## T003 - helpers (header-only, BOM + CRLF)

- `src/common/salfatname.h`: `SalFatShortNameToW(name11, ntRes, applyCase, oemCp, out, cap,
  &firstCharLost)`, `SalFatShortNameChecksum`, `SalFatLostFirstByteCandidates(lfn13, 13, oemCp,
  acp, cand, max)`. Case mapping with `LCMapStringEx(LOCALE_NAME_INVARIANT)` (the file system's
  tables are not linguistic - `CharUpperW` would follow the Turkish i). OEM code page 65001
  handled (no `WC_NO_BEST_FIT_CHARS` / used-default for UTF-8).
- `src/common/salvolpaths.h`: `SalVolumePathsWToU8` (multi-string; a path that does not fit or is
  not valid UTF-16 is left out), `SalVolumePathWToU8` (refused, never cut).

## T004 - FAT parser (`library/fat.h`, `fat.cpp`, `library/undelete.h`)

`DecodeDirectoryClusters`: for a deleted entry with a long name the candidates are tried against
the long entries' checksum (`sumKnown`); the long-name loop stops at 63 entries; the short name is
decoded by `SalFatShortNameToW` (case bits only when it is the name shown) and stored with
`NewFromUnicode` (WTF-8) as `FNName` or `DOSName`; `FR_FLAGS_NAMEFIRSTCHARLOST` (0x01000000) when
the shown name lost its first character. `ConvertFATName` / `ChkSum` removed.

## T005 - listing, path, restore (`fs2.cpp`, `undelete.h`)

`Replace0xE5` removed (listing name and DOS name, progress in `CopyFile` / `CopyDir`); `namecmp`
plain `_stricmp`; `FixDamagedName(record, name)` asks only for a flagged record whose name starts
with '$'; `AllSubstPrefix[8]` holds one UTF-8 character (`IsOneUtf8Char`), applied as
prefix + rest.

## T006 - conversions and messages (`library/miscstr.cpp`)

`NewFromUnicode` / `CopyFromUnicode` via `SplUnicodeDetail::WToWtf8` (byte-identical to UTF-8 for
valid Unicode), `CopyToUnicode` via `SplU8ToW`; `Error` / `SysError` / `PartialRestore` via
`FormatResU8` + `TrimTornUtf8Tail`, `FormatMessageW`; `AddNumberSuffix` allocates `len + 32`.

## T007 - volume layer (`library/os.h`, `os.cpp`, `fs2.cpp`, `dialogs.cpp`, `restore.cpp`)

The A function pointers and their typedefs are gone; the `...Exists()` functions return TRUE (all
present since Windows XP / Vista; the product needs Windows 10 2004); explicit specialisations for
`CHAR = char` declared in `os.h`, defined in `os.cpp` on the W functions (UTF-8 in and out; mount
points skipped / left out when they do not fit). `UndGetVolumePathNameU8` (heap UTF-16 buffer of
path length + MAX_PATH) serves `RootPathFromFull` (whose "append a backslash" overwrote the last
character - fixed, never triggered) and `OnDialogOK`. The volume list: `LVITEMW` / `LVM_INSERTITEMW`
/ `LVM_SETITEMW` (text UTF-8, else code page), `LVM_GETITEMW` + `SplWToU8` with the GUID path as
the fallback. Drive icon `SHGetFileInfoW`. EFS capability: `OS_GetVolumeInfo` / `OS_GetVolumeType`
(W wrappers of 104) in `UndeleteGetResolvedRootPath`, `PrepareRawAPI`, `RestoreEncryptedFiles`.

## T008 - sweep fixes

`ntfs.h` stream name `3 x MAX_PATH`, an unconvertible named stream left out; `fs2.cpp CopyFile`
path `MAX_PATH + 3 x MAX_PATH`, stream name copied whole, `.bak` bounded; `IDS_TEMPDIR` into 1024
with `_snprintf_s`; `dialogs.{h,cpp}` `SrcName` / `DestName` 4 x MAX_PATH with `lstrcpyn`;
`exfat.h` entry set bounded by the directory buffer, name entries by `name[255]`, `namelen` by
what was read; `os.h` the unused `tsz[100]` copy removed (unreachable).

## T009 - saltests `TestUndeleteNames114` (14,327 -> 14,375; 14,383 after the review - see there)

Checksum against an independent rotate-add loop for all 256 first bytes of two names, and the
checksum is a bijection of the first byte (256 distinct sums); short names: marker, escape on
CP852 (n-caron) and CP437 (sigma), OEM letters, case bits 0x08 / 0x10 / 0x18 (also beyond ASCII:
C-caron -> c-caron), not applied next to a long name, no extension, embedded / trailing spaces,
empty base, small buffers; every first byte 1..255 x 8 OEM code pages (437, 850, 852, 866, 932, 936,
949, 950) against `MultiByteToWideChar` - 0 mismatches; candidates (as revised after review SF1):
C-caron CP852 0xAC, CP437 dropped -> 'L', U+597D CP852 a hash form (old guess '?', then '_'),
CP936 0xBA, U+4E55 CP932 -> 0x05 (escape), dots and spaces skipped, '+' -> '_', a supplementary
character dropped, empty name, `max` 1, no duplicates, the whole chain (deleted entry
found again); volume paths: multi-string with `voil<U+00E0>`, a path that does not fit left out (not
cut), a lone surrogate left out, empty / NULL input, exact buffer sizes.

## T010 - the probe (written, not run)

`probe/make_images.py` (standard library; `--selftest`; checked: 7-Zip lists the FAT image - label
TC114, `KEEP.TXT`): FAT12 1.44 MB with 13 deleted files as Windows writes them (OEM short names,
LFN ordinals 0xE5, a deleted directory's files deleted too) plus a deleted directory left intact;
exFAT 4 MB with six deleted files (set checksums as the plug-in computes them); an exFAT image with
two deleted files of one 110-character CJK name. `expected.json`: names as UTF-16 units, contents,
`defect_before`, the damaged-name prompts.

`probe/undelnames_probe.ps1` (ASCII; refuses on the Default desktop and while any
`tandemcommander.exe` runs; registry backup / restore / SHA-256 via the 098 library): per image,
Change Directory `del:<image>\{All Deleted Files}`, select all, F5 into an empty folder of the
other panel, Damaged Filename answered `<C-caron>` + rest (All on the first), "too long" answered
Skip; rows per file (name exact incl. case and lone surrogate, content), PROMPTS, EXTRA, dup
NUMBER, END. `-Expect before` = the control.

## Gates

| Gate | Result |
|---|---|
| Debug x64 build | OK (0 errors; the one undelete warning, C4267 at `fs2.cpp` `fd.NameLen = strlen(...)`, is the unchanged line of the build before) |
| full Release x64 build | OK (`undelete.spl` 10:18:22; plugins.ver 20 registered; runtime closure OK) |
| saltests | 14,375 / 0 (was 14,327); 14,383 / 0 after the review changes |
| `tools\check_encoding.py --strict` | TOTAL 0 |
| touched sources | BOM + CRLF kept (C++); new headers BOM + CRLF; saltests.cpp / .vcxproj no BOM + CRLF as before; probe files ASCII + CRLF; no control characters |

## Hostile re-read of the diff

- A real name starting with '$' (NTFS `$MFT`, a user's `$x.txt`): no flag -> never asked (before:
  never asked either, it was not 0xE5). A FAT deleted short name now shares '$' with an existing
  short name `$OO.TXT` in the same folder: `RenameDuplicateDirectories` numbers the deleted one
  (before both were shown as `$OO.TXT`).
- The flag is per record; FAT records have one name; `{All Deleted Files}` shares the records.
  A numbered name (`$OO (1).TXT`) still starts with '$' and "All" keeps the suffix (prefix + rest).
- Candidates: `ncand == 0` (no usable first character) -> no long name (no uninitialised read).
- `SalFatShortNameToW` returns 0 for an empty base (as `ConvertFATName`); embedded spaces are kept
  (before: dropped) - Windows treats only trailing spaces as padding.
- `NewFromUnicode` stops at an embedded NUL - the old conversion produced the NUL and the C string
  ended there too.
- `os.cpp` specialisations: declared in `os.h` before any use (the generic bodies removed), so no
  translation unit can instantiate an A-pointer version; `OS_FindNextVolumeMountPoint` defined
  before `OS_FindFirstVolumeMountPoint` uses it.
- `FormatResU8`: the only `%s` arguments of these functions are names (UTF-8) - checked every call.
- The probe's prompt policy: `<C-caron>` is outside ASCII on purpose (the old "All" could not keep
  it); the first prompt in the restore order is `$91D~1.TXT` (`_stricmp`, digits < letters).

## Code-only review: ACCEPT pending GUI - SF1, NIT 2, NIT 3 and the recorded items applied

- **SF1** - Windows DROPS a character it cannot put into a short name (fastfat
  `RtlGenerate8dot3Name(name, TRUE, ...)`, ReactOS `dos8dot3.c`); only `+ , ; = [ ]` become `_`;
  0-2 kept base characters get a hash; nothing kept -> a hash form whose first byte is unrelated
  (measured by the reviewer with `dir /x`: `<C-caron>l<a-acute>nek dlouh<y-acute>.txt` ->
  `LNEKDL~1`, `<C-caron>X.txt` -> `X76F3~1`, `<C-caron>.txt` -> `80E2~1`, `<U+597D>.txt` ->
  `191D~1`). `SalFatLostFirstByteCandidates` now takes the first character Windows keeps
  (`SalFatNameDetail::ShortNameByte`: > space, not '.', ASCII or an OEM character that converts
  back to itself after upper-casing; a kept character after the last dot of a complete name = a
  hash form -> no Windows candidate; a leading dot is not an extension dot); then the old ANSI
  guess; then '_' only when the first visible character is not ASCII (Linux vfat writes '_'). A
  hash form keeps the old behaviour: no link, the damaged short name is asked for. saltests from
  the measured examples (CP437 models NTFS's "no extended characters"), a hash-form chain that
  must NOT link, `.gitignore`, a dot inside the base. `make_images.py`: `win_keep` / `win_sfn`
  make the short names the Windows way (self-test asserts the measured examples); the root
  `<U+597D>.txt` now has the hash form `191D~1` (expected: damaged, `<C-caron>91D~1.TXT`, the
  first prompt), the deleted-dir CJK file is `<U+5F00><U+59CB>x.txt` -> `X76F3~1` (a dropped
  character, recovered), `a<U+597D>.txt` -> `A0B1C~1`, `<U+5A46>.txt` -> `8A6F~1`.
- **NIT 2** - the NT case bits lower A-Z only (fastfat `Fat8dot3ToString`): `<C-caron>AJ.TXT` with
  0x18 -> `<C-caron>aj.txt` (saltests updated, extension case added).
- **NIT 3** - recorded as a deliberate change (research.md 3): embedded spaces / an extension
  starting with a space are kept as fastfat shows them; the old `ConvertFATName` dropped them.
- `CVolume::Open`: the `"\\.\" + rootPath` fallback is refused when it does not fit `diskVolume`
  (`volume.h`). The `.bak` append: verified once per file (the stream loop breaks for encrypted
  files) - no change.
- Gates after the changes: Debug build OK, saltests 14,383 / 0, strict guard 0, full Release build
  OK (`undelete.spl` 10:38:33).

## Targeted re-check of the SF1 fix: ACCEPT (pending GUI)

saltests 14,383/0; ASan harness over the new salfatname.h 400,000 cases clean. ShortNameByte follows
fastfat/ReactOS; hash-form detection works from the long name (the right approach); case bits A-Z
only; CVolume::Open refuses a path that does not fit.

**Risk of linking a wrong orphan long name, stated exactly:** it needs a deleted short-name entry
directly preceded by long-name entries of ANOTHER file whose checksum matches one candidate first
byte. The restored file then has the correct data (clusters and size come from the short-name
entry) under the other file's long name - no data mixing, nothing overwritten. The checksum is a
one-to-one function of the first byte, so at most one candidate can match and the order does not
matter for safety; each distinct candidate adds about 1/256 when an orphan really sits in front.
The old ANSI guess is still a candidate for every name, so a hash-form name keeps the same ~1/256
chance every build before 114 had (not a regression - "a hash form must not link" holds only for
the Windows candidate). The `_` candidate adds one more ~1/256 only for names whose first visible
character is not ASCII and recovers Linux-written media - kept. Possible later hardening (not done):
link only when the short name's extension equals the first three kept characters of the long
name's extension.

Committed after this check with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_114` (undelete.spl 10:38). Results follow in a separate commit.

## Found on the way (recorded, not fixed)

1. `restore.cpp RestoreDir` / `GetDirSize` (Restore Encrypted Files): `SalPathAppend` results are
   ignored - a source path over 519 / 259 bytes recurses into the same folder until the stack
   overflows, and restores the parent folder's files into the target. Long paths, not names.
2. `fat.h RemoveDuplicateFiles`: `memcmp(r1->Streams->Ptrs, r2->Streams->Ptrs, DSSize)` compares
   DSSize bytes of a 44-byte structure (an over-read; the different `Runs` pointers stop it early,
   so the duplicates it should remove from {All Deleted Files} are never removed).
3. Name identity in the restore list and the FAT duplicate numbering is `_stricmp` (ASCII only):
   deleted `<C-caron>.txt` and `<c-caron>.txt` from one folder are not numbered - the second
   restore asks to overwrite the first (092's rule would apply).
4. `os.h OS_GetDriveFormFactor`: a mount folder path `C:\mnt\x\` opens `\\.\C:` (display only;
   unreachable - callers pass `X:\`).
5. Debug-only: exFAT / FAT trace paths `CHAR tracePath[MAX_PATH]` with `StrCat_s` (a deep tree ends
   in the invalid-parameter handler), `TestUndeleteOnExistingFile` stream names cut at MAX_PATH.

## GUI results (2026-10-06, 04:31-04:37, hidden desktop)

Builds: the preserved trees `build\tandemcommander\Debug_x64_114` (undelete.spl 2026-10-05 10:38:11)
and `Debug_x64_pre114` (09:51:50); nothing built. ACP 1250, OEM 852; no `tandemcommander.exe` running
before or after any run; registry SHA-256 prefix `9BD42518403B7EDF` before and after every run (each
probe also restored and verified the key itself: identical); fixtures removed; no bug report created
(`%LOCALAPPDATA%\Tandem Commander\TC*.TXT` compared before / after the crashing run - none new).

| Run | Result | File |
|---|---|---|
| `undelnames_probe.ps1 -Exe Debug_x64_114 -Expect fixed` | **30 PASS / 0 FAIL / 4 NOT DRIVEN** | `probe/undelnames_result.txt` |
| `undelnames_probe.ps1 -Exe Debug_x64_pre114 -Expect before` | 27 PASS / 1 FAIL (dup END - the control) / 4 NOT DRIVEN | `probe/undelnames_result_pre114.txt` |
| `plugnames_probe.ps1 -Exe Debug_x64_114 -Only und-image` (104) | 3 PASS / 0 FAIL | `probe/regress_plugnames104_114.txt` |

- **This build**: FAT - all 13 files under exactly their names and contents (incl. `<C-caron>lanek.txt`
  whose long name was recovered through the OEM byte, `<U+5F00><U+59CB>x.txt` through the dropped
  characters - short name `X76F3~1`, the Zlutoucky name, `<U+5A46>.txt`, the 0x05 escape `<n-caron>BC.TXT`,
  the OEM short name, `readme.txt` / `mixed.TXT` by the case bits, the lone surrogate); ONE Damaged
  Filename dialog (`$91D~1.TXT` - the hash form), "All" with `<C-caron>` named `$AA.TXT` / `$OO.TXT`;
  no extra file. exFAT - all 6 under their names, no dialog. dup - "Target path is too long" twice
  (Skip), nothing written, no fatal window, clean exit.
- **The build before** (every predicted defect shown): FAT - `<C-caron>lanek.txt`,
  `<U+5F00><U+59CB>x.txt` and the Zlutoucky name lost their long names (restored as
  `<C-caron>LANEK~1.TXT`, `<C-caron>76F3~1.TXT`, `<C-caron>LU<U+203A>OU~1.TXT` - the OEM bytes read in
  the ANSI code page), `<U+5A46>.txt` listed `$` + mojibake and restored as `<C-caron><U+00A9><U+2020>.txt`,
  the 0x05 escape asked for (`<C-caron>BC.TXT`), the OEM short name `<C-caron>L<A-acute>NEK2.TXT` not
  restored ("Error Creating File" (123) - the OEM bytes as a UTF-8 name), `mixed.txt` instead of
  `mixed.TXT`, `lone<U+FFFD>y.txt`; 8 Damaged Filename dialogs ("All" never remembered `<C-caron>`).
  exFAT - `<U+597D>.txt` and `<U+5F00><U+59CB>.txt` asked for and restored as mojibake,
  `lone<U+FFFD>x.txt`. dup - a fatal window: Debug CRT assertion "Buffer is too small"
  (`corecrt_internal_string_templates.h` line 218) during the numbering, not the predicted "Stack
  around the variable 'temp'" - the same overrun, caught one call earlier; 280 stray windows; the
  probe ended the process (no process left, no report). Its END row FAILs as predicted.
- **Probe defect found and fixed (probe only)**: the first pair of runs used PowerShell `@{}` maps,
  which ignore case - the build before's `mixed.txt` matched the expected `mixed.TXT` (a FAIL in
  the `-Expect before` run, and the fixed run's case rows proved nothing). The name maps are
  ordinal now; both runs were repeated (the results above). The first pair's results are kept in
  `probe/run1/` (fixed 30 / 0, before 26 / 2).
- No defect of the 114 code found. Not driven (recorded): NTFS, volume mount points (person step,
  T016), the connect dialog's volume list, Restore Encrypted Files.

## Pending (person)

- T016: a mount folder outside ASCII (administrator; `quickstart.md` "By hand").

## Pending (GUI, after 18:00 - exact commands in `quickstart.md`) - DONE 2026-10-06, see "GUI results"

1. `undelnames_probe.ps1` on `Debug_x64_114` (expected: every row PASS, 4 NOT DRIVEN) and on
   `Debug_x64_pre114` with `-Expect before` (predictions in `quickstart.md`).
2. Regression on `Debug_x64_114`: 104 `plugnames_probe.ps1 -Only und-image`.
3. Registry SHA-256 prefix `1AB614304771DBE0` before / after each run.
4. Person, admin: a mount folder outside ASCII (`quickstart.md` "By hand").

## CLAUDE.md entry

Proposed for "Recent Changes" (plain text):

- 114-undelete-names: **Undelete restores files under their own names, from
  the volume chosen.** The 104 note, measured by code reading (no GUI that
  day) and wider.
  - **The FAT rule ran on UTF-8 names of every file system**: `Replace0xE5`
    turned a first BYTE 0xE5 into '$' and `FixDamagedName` asked for every
    such name - every name starting with U+5000..U+5FFF (NTFS, exFAT, FAT
    long names) was listed as '$' + mojibake and restored under another name.
    The rule now lives on the 11 raw bytes of a FAT short-name entry
    (`src/common/salfatname.h`, `SalFatShortNameToW`: 0xE5 -> '$' + record
    flag `FR_FLAGS_NAMEFIRSTCHARLOST`, 0x05 -> the real 0xE5, OEM code page,
    NT case bits 0x08 / 0x10 on A-Z as Windows shows them); only a flagged record
    opens the Damaged Filename dialog; "All" keeps one UTF-8 character.
  - Also on the FAT route: short names were OEM bytes handed on as UTF-8;
    deleted long names were lost unless the first character was ASCII (the
    lost byte was guessed in the ANSI code page - Windows writes the OEM
    byte of the first character it KEEPS and DROPS what it cannot write;
    nothing kept = a hash form `191D~1.TXT` that cannot be linked back; now
    `SalFatLostFirstByteCandidates`, first checksum match wins - the checksum
    is a bijection of the first byte, so never all 256); unpaired surrogates
    became U+FFFD (now WTF-8).
  - **Volume layer W** (`os.cpp`, `salvolpaths.h`): `GetVolumePathNameA` on a
    UTF-8 path through a mount folder outside ASCII returned the parent's
    volume - **another volume was opened**; the mount column was code page /
    best fit. A path that does not fit is left out or refused, never cut.
  - Sweep: an NTFS stream name over 259 UTF-8 bytes matched the default
    stream (its runs joined the unnamed stream); stack overruns
    (`IDS_TEMPDIR` 226 bytes in Ukrainian into 200, `AddNumberSuffix` for two
    equal 300+ byte names, FAT LFN loop, exFAT name entries); error texts in
    UTF-8; EFS capability on W.
  - saltests 14,327 -> 14,383. Interface stays 107, no string, no registry
    change. Probe `probe/undelnames_probe.ps1` + `make_images.py` (FAT12,
    exFAT and a duplicate-name exFAT image written byte by byte - no admin,
    no volume opened) written, **GUI runs pending**; mount points need admin
    (person step). Records: `specs/114-undelete-names/fix-log.md`.
