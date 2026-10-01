# 7-Zip engine in the 7zip plugin — source and local patches

This directory is a **pristine subset of 7-Zip 26.03** plus the files under
`spl/`. Every change to an upstream file is listed here and bracketed by
`TC_7ZIP_PATCH` comments in the file. An upgrade extracts the next release,
copies the same subset over this tree (`specs/087-7zip-2603-rar/contracts/engine-build.md` E1),
diffs, and re-applies this list.

## Source

| | |
|---|---|
| Version | 7-Zip **26.03** (2026-09-03), Igor Pavlov |
| Archive | `7z2603-src.tar.xz` — <https://github.com/ip7z/7zip/releases/download/26.03/7z2603-src.tar.xz> |
| SHA-256 | `9cbde5099c6deb73691b0579063da5827522ccbbcba3f0020fd04e8c8c16c0d4` (verified 2026-10-01, equal to the GitHub asset digest; tag `26.03`, commit `0766b733fe3e06dd2a7f9a3cfbf2108ac73abd17`) |
| Licence | GNU LGPL 2.1+; the RAR decoder (`CPP/7zip/Compress/Rar*`, `CPP/7zip/Archive/Rar/*`, `CPP/7zip/Crypto/Rar*`) with the unRAR licence restriction — see `DOC/License.txt`, `DOC/unRarLicense.txt`. No BSD-licensed file is compiled (Zstd, LZFSE and XXH64 sources are present but not built). |

## Subset

`C/` (no `Util/`, no `*.mak`), `CPP/Common/`, `CPP/Windows/` (no `Control/`),
the interface headers and resources of `CPP/7zip/`,
`CPP/7zip/{Common,Compress,Crypto}/`, `CPP/7zip/Archive/{Common,7z,Rar}/`,
`CPP/7zip/Archive/{IArchive.h,StdAfx.h,ArchiveExports.cpp,DllExports2.cpp,HandlerCont.*,Archive2.def}`,
`CPP/7zip/Bundles/Format7z/` (the upstream build list this DLL starts from),
`DOC/`. Files are byte-identical to the archive except the patches below.

What `7za.dll` compiles is `src/plugins/7zip/vcxproj/7ZA/7za.dll.vcxproj`:
the `Format7z` bundle (7z read/write) + the RAR/RAR5 handlers, codecs and
crypto + their dependencies, C variants of every optimised routine (no
assembler). The DLL reports exactly three formats: 7z, Rar, Rar5.

## Local patches (applied)

| File | Patch | Why |
|---|---|---|
| `C/Threads.c` | `Thread_Create`, `Thread_Create_With_Affinity`, `Thread_Create_With_Group` start every thread through a trampoline that calls `spl/splthread.c` `RunThreadWithCallStackObject` (under `TC_7ZIP_CALLSTACK`, defined by the project) | engine threads run under the plugin's call-stack tracking, so a crash in one is reported with a call stack. All engine threads start here in 26.03; the 16.04 patch wrapped individual thread functions and missed MtCoder, MtDec, BZip2 and Zip threads |

## Local files

| File | Purpose |
|---|---|
| `spl/splthread.c` | `RunThreadWithCallStackObject`: finds `AddCallStackObject` in the loaded `7zip.spl` and runs the thread body under it; runs it directly when the plugin is not loaded (a test driver) |
| `spl/7za.def` | exports `CreateObject`, `GetHandlerProperty`, `GetNumberOfFormats`, `GetHandlerProperty2`, `GetNumberOfMethods`, `GetMethodProperty` |
| `spl/VersionInfo.rc` | version resource (version 26.03 from `CPP/7zip/MyVersion.h`), description "7-Zip engine (7z, RAR) - modified for use by Tandem Commander" |

## 16.04 patches retired in the upgrade (feature 087)

| 16.04 patch | Reason it is gone |
|---|---|
| `spl/main.cpp` (`DllMain`, `CreateObject` dispatch, `g_IsNT`) | upstream `Archive/DllExports2.cpp` provides the same entry points |
| thread wrappers in `C/LzFindMt.c`, `CPP/7zip/Common/VirtThread.cpp` | replaced by the single `Threads.c` patch above |
| `C/CpuArch.c` SSE check and `CPP/Windows/NtCheck.h` through `VerifyVersionInfoW` | upstream no longer calls `GetVersionEx` in these paths |
| `CPP/Common/MyString.h`: `USE_UNICODE_FSTRING` commented out | the engine is wide now (`FString` = `UString`); the plugin loads it by its wide path and never used 7-Zip's file layer for archive data |
| `CPP/Common/C_FileIO.cpp` `_CRT_SECURE_NO_WARNINGS` | the file is not compiled |
| `CPP/7zip/Archive/7z/7zExtract.cpp` "JRY FIX" (return the decode error so a wrong password fails the operation) | replaced in the plugin: the engine reports a wrong password per item (measured by `specs/087-7zip-2603-rar/probe`, "7Z encrypted with a wrong password fails") and `Extract()` returns S_OK; `C7zClient::Decompress` now treats any per-item error (`NumErrors > 0`) as failure, as `TestArchive` always did, and its three callers in `7zip.cpp` report success only for `OPER_OK` (they had tested `!= OPER_CANCEL`) — without both, "unpack and delete" and Move out of an archive could delete the source after a failed extraction (independent review of S1, blocker) |
| `CPP/Common/NewHandler.h` `operator new/delete` commented out | upstream's declarations compile with the engine project; the engine does not use the plugin's leak-tracking `new` |
| `spl/StdAfx.h`, `spl/splthread.cpp` | unused |
| `src/plugins/7zip/patch/` (3.13-era patch set) and `src/plugins/7zip/doc/how-to-patch-7za.dll.txt` | historical; this file replaces them |
