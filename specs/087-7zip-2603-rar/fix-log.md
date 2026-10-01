# Fix log: 087 7-Zip engine 26.03 and RAR out of the box

Baseline `686e88a` (`main`, after 086); branch `087-7zip-2603-rar`.
Protocol: 069 fix protocol.

## T001 — baseline

- Upstream source `7z2603-src.tar.xz`, SHA-256 `9cbde5099c6deb73691b0579063da5827522ccbbcba3f0020fd04e8c8c16c0d4`
  — computed by the author, equal to the GitHub release asset digest.
- 16.04 local patches inventoried (research R6); there was no pristine 16.04
  in the repository, so unmarked edits could not be detected — the upgrade
  replaces the whole tree, which removes them either way.
- Reference tool on the development machine: 7-Zip **22.01** `7z.exe`.

## T002 — engine driver and probe; 16.04 baseline

`probe/7zdrive.cpp` (+ `build_7zdrive.cmd`), `probe/run_engine_probe.py`.
The driver is compiled against the interface headers only, so the same exe
drives the old and the new DLL.

| Engine | Formats | Probe |
|---|---|---|
| 16.04 Release (baseline) | 53 | 28 of 29 checks pass; the failure is `rar5_unicode` (a hard link entry), see S1 |
| 26.03 Debug (S1) | **3** (7z, Rar, Rar5) | **0 failed** (all RAR fixtures, missing volume, 7z fixture, 5 created 7z variants tested by `7z.exe`, 2 wrong-password cases, hostile names, timing) |

Findings of the probe on the way:

- `test_read_format_rar5_unicode.rar` holds a **hard link** (no data of its
  own; the engine answers "unsupported") and a **symbolic link**. `7z.exe`
  creates both as links. The plugin never creates links (FR-014), so link
  entries are skipped and counted (contract P6b; spec edge case updated) —
  the same behaviour as 16.04's engine would have given had the plugin opened
  RAR, which reported the same error.
- Cancelling a password prompt (`E_ABORT`) leaves the files the engine had
  already asked streams for — the plugin must delete a half-written file on
  abort, not only on a data error (P6b).
- Fixture passwords: `encryption_data`/`encryption_header` = `12345678`,
  `*_encrypted_filenames` = `password`; `rar4_encrypted`/`rar5_encrypted` have
  no known password (libarchive tests them undecrypted) and serve as
  wrong-password cases.

## S1 — the engine (T003–T007)

- **T003** `src/plugins/7zip/7za/` replaced by the 26.03 subset (527 files,
  byte-identical); `spl/main.cpp`, `spl/splthread.cpp`, `spl/StdAfx.h`, the
  3.13-era `src/plugins/7zip/patch/` and `src/plugins/7zip/doc/{how-to-patch-7za.dll.txt,sfx.patch}`
  deleted. Read-only attributes from the tar archive cleared.
- **T004** `C/Threads.c` trampoline (`TC_7ZIP_CALLSTACK`, 3 creation
  functions, allocation freed when the thread is not created);
  `spl/splthread.c` without the removed `StdAfx.h`, `GetModuleHandleA`.
  `src/plugins/7zip/7za/TC-PATCHES.md` (source, hash, subset, patch, retired
  patches with reasons).
- **T005** `7za.dll.vcxproj` regenerated: 144 sources = `Format7z` makefile
  objects + C twins of `Aes/Crc/LzFindOpt/Sha256/Sort` + the RAR set + 9
  dependencies the linker named (`FindSignature`, `Blake2s`,
  `PropVariantUtils`, `UTFConvert`, `Ppmd7aDec`, `Sha1`, `Sha1Opt`,
  `Sha1Prepare`, `HmacSha256`); `DllExports2.cpp` replaces `spl/main.cpp`;
  one version resource instead of four; defines
  `Z7_DEFLATE_EXTRACT_ONLY;Z7_BZIP2_EXTRACT_ONLY;TC_7ZIP_CALLSTACK`;
  `mpr.lib`/`comctl32.lib` dropped (GUI helpers no longer compiled). Builds
  with no warnings.
- **T006** plugin port: callback classes on the 26.03 macros
  (`Z7_COM_UNKNOWN_IMP_n`, `Z7_IFACE_COM7_IMP`, `Z7_COM7F_IMF`; 27 method
  definitions converted by script; `EnumProperties`, never part of the
  interface, removed); `Z7_NO_UNICODE` for the plugin project; the plugin no
  longer compiles 7-Zip's `FileStreams.cpp`/`FileIO.cpp` (its own `FStreams`
  does the file I/O); engine loaded by its **wide** path, `CreateObject`
  through `GetProcAddress` (`CLibrary::GetProc` is gone); `Windows/Defs.h` →
  `WinDefs.h`, `Common/Defs.h` → `Common/Common.h`; `AString(const char*)` is
  explicit now (`CArchiveItemInfo` takes `const char*`); `CPropVariant` has
  no `operator=(int)` / `UString` constructor (casts, `.Ptr()`); a stray
  `#define INITGUID` in `7zip.cpp` produced duplicate IIDs with the 26.03
  headers — removed (the GUIDs are instantiated once, in `7zclient.cpp`).
  The open callback still exposes only the password interface (volumes come
  in S3).
- **T022 moved into S1**: `7zwrapper` (project, solution entry, plugin
  project reference, base-address lines) removed — its sources lived in the
  old tree, so the full build could not pass without removing it. Its
  shipped-file cleanup stays in S4 (T023).
- **T007** full Debug build: succeeded; saltests 1904 / 0; engine probe
  0 failed; wrong password on 7z fails per item and the plugin treats any
  per-item error as failure (`7zclient.cpp:512`) → the 16.04 "JRY FIX" is
  retired.
