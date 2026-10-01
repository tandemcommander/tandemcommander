# Research: 7-Zip engine 26.03 and RAR out of the box (087)

Two independent read-only sweeps (the integration inventory and the upstream
research) plus the author's checks of the 26.03 tree. Baseline: `main` at
`686e88a` (after feature 086). Upstream tree extracted to the session
scratchpad from `7z2603-src.tar.xz`, **SHA-256 verified by the author**:
`9cbde5099c6deb73691b0579063da5827522ccbbcba3f0020fd04e8c8c16c0d4` (= GitHub
asset digest of `ip7z/7zip` release `26.03`, commit `0766b73`).

## R1 — Version

**Decision**: 7-Zip **26.03** (2026-09-03), the latest stable. 25.01 still
carries the 2026 handler CVEs below. (Maintainer, 2026-10-01.)

## R2 — Security fixes that reach our engine

Our DLL contains format handlers and codecs only; 7-Zip's extraction layer
(`UI/Common/ArchiveExtractCallback`, Mark-of-the-Web, link creation) is not
built — the plugin does that work itself (R9).

| CVE | Fixed | Component | In the new engine |
|---|---|---|---|
| CVE-2017-17969 | 18.00 | ZIP Shrink | handler not built (R4) |
| CVE-2018-5996 | 18.00 | RAR3 / PPMd | **yes — fixed** |
| CVE-2018-10115 | 18.05 | RAR decoder, uninitialised memory, RCE | **yes — fixed** |
| CVE-2023-31102 | 23.00 | `Ppmd7.c` integer underflow (7z PPMd too) | **yes — fixed** |
| CVE-2023-40481 / 2023-52168/9 / 2026-48092/101/102/103/104/111/112 / 2026-48095 | 23.00–26.01 | SquashFS, NTFS, UEFI, UDF, WIM, Ar | handlers not built (R4) |
| CVE-2024-11612 | 24.08 | `CopyCoder` infinite loop | **yes — fixed** |
| CVE-2025-53816 | 25.00 | RAR5 heap write | **yes — fixed** |
| CVE-2025-53817 | 25.00 | Compound null pointer | handler not built |
| CVE-2026-14266 | 26.02 | XZ decoder heap overflow | XZ not built (R4) |
| CVE-2025-0411, -11001/2, -55188, CVE-2026-58052 | 24.09–26.03 | extraction layer (MotW, symlinks, ADS names) | not built — **but the same class exists in our plugin**: R9 |

## R3 — 7z AES randomness

26.03 `Crypto/RandGen.cpp` seeds its SHA-256 generator with 32 bytes of
`RtlGenRandom` (since 19.00; IV 16 bytes instead of 8). The upgrade fixes the
weak IV generation of 16.04 without a patch. 7z AES has no salt by format
design (`ResetSalt` disabled upstream in both versions) — unchanged.
**Decision**: no patch; if `RtlGenRandom` fails, upstream falls back to the
time-based seed — acceptable (same outcome as our 085/086 fallbacks) and
recorded.

## R4 — What the engine contains

**Decision** (maintainer): only what the plugin uses. Build = upstream
`CPP/7zip/Bundles/Format7z` (the official **7z-only 7za.dll**: 7z read/write,
LZMA/LZMA2/PPMd/BCJ/BCJ2/ARM/Delta/Copy/Swap, BZip2 and Deflate *decoders*,
7z AES, `-DZ7_DEFLATE_EXTRACT_ONLY -DZ7_BZIP2_EXTRACT_ONLY`) **plus** the RAR
set of `Format7zF/Arc.mak`: `RarHandler`, `Rar5Handler`, `Rar1/2/3Decoder`,
`Rar3Vm`, `Rar5Decoder`, `RarCodecsRegister`, `Rar20Crypto`, `RarAes`,
`Rar5Aes`, and their dependencies (SHA-1, SHA-256, HMAC, BLAKE2s,
`FindSignature`, `ItemNameUtils`, `OutStreamWithCRC`, `HandlerCont`, …;
resolved by the linker, listed in `contracts/engine-build.md`).
Assembler: none — every `Asm/x86/*.asm` has a C twin (`AesOpt.c`,
`7zCrcOpt.c`, `LzFindOpt.c`, `Sha256Opt.c`, `Sort.c`); `Z7_LZMA_DEC_OPT` stays
undefined. No BSD-licensed file (Zstd, LZFSE, XXH64) is compiled, so no new
licence notice beyond LGPL + unRAR.

## R5 — The vendored tree

**Decision**: replace `src/plugins/7zip/7za/` with a **pristine subset** of
26.03 (only directories the engine and the plugin compile, plus `DOC/`),
then apply the local patches below, each marked `TC_7ZIP_PATCH` and listed in
a new `src/plugins/7zip/7za/TC-PATCHES.md` together with the archive name and
SHA-256 — so the next upgrade can diff against upstream (today impossible:
there is no pristine 16.04 in the repo, inventory §2).

## R6 — Local patches of 16.04, carried or retired

| 16.04 patch | 26.03 | Decision |
|---|---|---|
| thread wrappers in `LzFindMt.c`, `VirtThread.cpp` (call-stack tracking) | all engine threads start in `C/Threads.c` (`Thread_Create`, `_With_Affinity`, `_With_Group`); `BZip2Decoder`/`MtCoder`/`MtDec` use them | **re-apply once in `Threads.c`**: a trampoline runs the thread function through `spl/splthread.c` `RunThreadWithCallStackObject` (covers the threads the old patch missed: `MtCoder`, `MtDec`, BZip2, Zip — FR-003) |
| `spl/main.cpp` (`DllMain`, `CreateObject` dispatch, `g_IsNT`) | upstream `Archive/DllExports2.cpp` provides `DllMain`, `CreateObject` (coder/hasher/archiver dispatch), `SetLargePageMode2`, … | **retire**; compile upstream `DllExports2.cpp`; keep `spl/7za.def` (adds `GetModuleProp`, `SetLargePageMode2` as upstream) |
| `CpuArch.c` SSE check, `NtCheck.h` via `VerifyVersionInfoW` | rewritten upstream (no `GetVersionEx`) | **retire** (verify no `GetVersionEx` in built files) |
| `MyString.h` `USE_UNICODE_FSTRING` commented out | `FString` is `UString` on Windows | **retire** — the plugin moves to wide paths (R8) |
| `C_FileIO.cpp` `_CRT_SECURE_NO_WARNINGS` | file not in the build | **retire** |
| `7zExtract.cpp` "JRY FIX" (decode error returns the error so a wrong password fails) | its own comment says upstream fixed it in 19.0 | **verify with a wrong-password test**, retire if upstream behaves (FR-007) |
| `NewHandler.h` `operator new/delete` commented out | — | decide at build time (keep upstream unless the plugin's leak-tracking `new` conflicts) |
| `spl/VersionInfo.rc` ("Modified for use by Tandem Commander") | — | **keep**, version 26.03 |

## R7 — Interface compatibility (plugin ↔ engine)

Binary compatibility holds: interface IDs `23170F69-40C1-278A-0000-00gg00ii0000`,
handler CLSIDs `…-1000-000110xx0000` (7z `07`, RAR `03`, RAR5 `CC` —
`RarHandler.cpp:1768`, `Rar5Handler.cpp:3399`), method order and `kpid*`
values unchanged; `PropID.h` only appended. Source compatibility does not:
23.01 replaced `MY_UNKNOWN_IMP*`, `STDMETHOD` overrides and `INTERFACE_*`
with `Z7_IFACES_IMP_UNK_n`, `Z7_IFACE_COM7_IMP`, `Z7_COM7F_IMF` and every
interface method is `throw()`. **Decision**: port the plugin's five callback
classes to the upstream macros, exactly as `UI/Client7z/Client7z.cpp` 26.03
does. Timestamps: 22.00 stores a precision in `PROPVARIANT.wReserved*` —
the plugin uses `CPropVariant` everywhere it passes times in.

## R8 — The plugin's own copy of 7-Zip helpers

The plugin compiles `FileStreams`, `IntToString`, `MyString`, `MyVector`,
`StringConvert`, `Windows/DLL`, `FileIO`, `PropVariant`, `PropVariantConv`
from the vendored tree. With 26.03, `C/Precomp.h` (pulled in by every 7-Zip
`StdAfx.h`) defines `UNICODE`/`_UNICODE` unless `_MBCS` or `Z7_NO_UNICODE`
is set, while the plugin's own files are ANSI (`/J`, `TCHAR`=`char`). Mixing
would give the plugin's TUs and the 7-Zip TUs different `CSysString`/`TCHAR`.
**Decision**: define `Z7_NO_UNICODE` for the whole plugin project (one
setting, both kinds of TU agree; `FString` is wide anyway); paths to the
engine and to files become wide (`CLibrary::Load(FString)`, file streams with
`FString`) — the plugin already holds names as UTF-8 and converts them.

## R9 — Item names are not cleaned (pre-existing defect, both formats)

`extract.cpp:199-200`: target = `TargetDir` + `NameInArchive` through
`SalPathAppend` (`salamdr3.cpp:22`, plain concatenation); the name comes
from `kpidPath` (`7zclient.cpp:210`). No component check: `..\` climbs out of
the target, `C:\…`/`\\…` is taken as given after the first backslash is
dropped, `name:stream` writes an NTFS alternate data stream, links
(`kpidSymLink`/`kpidHardLink`) and alternate streams (`kpidIsAltStream`,
reported by RAR5 and 7z handlers) are not looked at. **Decision**: a pure,
header-only cleaning function `src/common/salarcname.h` (header-only for the
same reason as 086's `salrandom.h`: plugins cannot compile a shared `.cpp`
from `src/common` with their PCH), unit-tested in `saltests`, applied where
the plugin turns `kpidPath` into a panel name (listing) — so every name the
core later passes back for extraction is already clean — and again at
`GetStream` (defence in depth). Rules in `contracts/item-names.md`. Entries
with `kpidIsAltStream` = true are not listed; link entries are extracted as
the plain data the handler returns (never created as links — the plugin has
no link creation).

## R10 — RAR in the plugin (feature 084 S7, T047–T051)

- **Format selection**: by registered extension, confirmed by signature —
  RAR4 `52 61 72 21 1A 07 00`, RAR5 `52 61 72 21 1A 07 01 00`, 7z
  `37 7A BC AF 27 1C`; CLSID chosen accordingly. Pure function in
  `src/common/salarcname.h` (`SalArcDetectFormat`), unit-tested.
- **Volumes**: `IArchiveOpenVolumeCallback` exposed (today a stub that is never
  reached and would return S_OK with no stream — inventory §3):
  `GetProperty(kpidName)` returns the current volume name, `GetStream(name)`
  opens a sibling in the archive's folder (wide path), `S_FALSE` when missing.
- **Password**: `ICryptoGetTextPassword` returns the password as UTF-16; the
  prompt reads it as wide text (`SalGetWindowTextU8`/wide edit) — today it
  is ANSI (`open.cpp:43`).
- **Memory**: the extract and open callbacks implement
  `IArchiveRequestMemoryUseCallback`; requests above 4 GiB (upstream's RAR7
  default) or above half of physical memory are refused, so the operation
  fails with a "not enough memory" error rather than allocating unbounded
  memory (FR-015). (RAR5 handler without the callback allocates without a
  limit — `Rar5Handler.cpp:2975-2990`.)
- **Registration** (`7zip.cpp:600-652`, `CURRENT_CONFIG_VERSION` 3 → 4):
  `AddPanelArchiver("7z;rar", …)` and the unpacker mask `*.7z;*.rar` added,
  gated on `ConfigVersion < 4`; the core's overlap takeover keeps feature
  084's WinRAR packer as the RAR packer (084 contract M2) — verified on an
  upgraded configuration (owed GUI step + code reading).
- **Read-only RAR**: update/delete on a RAR archive → the plugin's existing
  "operation not supported" path.

## R11 — 7zwrapper.dll

No caller in the repository (inventory §1); ships today. **Decision**
(maintainer): remove `src/plugins/7zip/vcxproj/7zwrapper/`,
`7za/cpp/7zip/UI/7zwrapper/`, its `salamand.sln` entry, the project reference
in `7zip.vcxproj`, the `baseaddr_*.txt` lines; delete a stale copy from an
updated installation in the installer's `[Code]` at `ssPostInstall` (feature
080's rule: never `[InstallDelete]`) and from an old build output tree in
`build.cmd` (feature 079's pattern for `salmon.exe`).

## R12 — Verification without the GUI

- `saltests`: name cleaning, format detection, volume naming.
- **Engine driver** `specs/087-.../probe/7zdrive` — a console program using the
  built `7za.dll` through the same interfaces the plugin uses (list, extract
  to a folder, test, with password, volumes), run over the 084 RAR fixtures
  and a 7z corpus, compared with the output of an independent 7-Zip (`7z.exe` 22.01 is
  installed on the development machine; it reads RAR4/RAR5 and 7z).
- Plugin-level GUI behaviour (panel, dialogs, migration, a clean machine) →
  owed, `quickstart.md`.
