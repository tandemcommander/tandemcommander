# Contract: the engine build (087, FR-001–FR-004)

## E1 — Source

`src/plugins/7zip/7za/` = a pristine subset of 7-Zip 26.03
(`7z2603-src.tar.xz`, SHA-256
`9cbde5099c6deb73691b0579063da5827522ccbbcba3f0020fd04e8c8c16c0d4`),
directories copied whole where any file is used (`C/`, `CPP/Common`,
`CPP/Windows`, `CPP/7zip/{Common,Compress,Crypto}`, `CPP/7zip/Archive/
{Common,7z,Rar}`, the `CPP/7zip/*.h` interface headers, `CPP/7zip/Archive/*.{h,cpp,def}`,
`DOC/`), plus local files under `spl/` and `TC-PATCHES.md`. Removed: every
other handler directory, `UI/`, `Bundles/`, `Asm/`. The old 16.04 tree and the
historic `src/plugins/7zip/patch/` are deleted (git history keeps them).

## E2 — What `7za.dll` compiles

The upstream `Format7z` bundle (7z read/write, LZMA/LZMA2/PPMd, BCJ/BCJ2,
branch/ARM/ARM64/RISCV/Delta, Copy, Swap, BZip2 and Deflate decoders, 7z AES,
CRC, SHA-256) **plus** `RarHandler`, `Rar5Handler`, `Rar1/2/3Decoder`,
`Rar3Vm`, `Rar5Decoder`, `RarCodecsRegister`, `Rar20Crypto`, `RarAes`,
`Rar5Aes` and their dependencies. C variants of every optimised routine; no
`.asm`. Defines: `Z7_DEFLATE_EXTRACT_ONLY`, `Z7_BZIP2_EXTRACT_ONLY`,
`TC_7ZIP_CALLSTACK` (E4). Entry points from upstream
`Archive/DllExports2.cpp`, `ArchiveExports.cpp`, `Compress/CodecExports.cpp`;
exports in `spl/7za.def`.

Check: `GetNumberOfFormats` = 3 (7z, Rar, Rar5) — the probe asserts it.

## E3 — Version resource

`spl/VersionInfo.rc`: file/product version 26.03, description "7-Zip engine
(7z, RAR) for Tandem Commander", "Modified for use by Tandem Commander".

## E4 — Call-stack tracking (`TC_7ZIP_CALLSTACK`)

`C/Threads.c` `Thread_Create`, `Thread_Create_With_Affinity`,
`Thread_Create_With_Group` start every thread through one trampoline that
calls `spl/splthread.c` `RunThreadWithCallStackObject(func, param)`; that
function finds `AddCallStackObject` in the loaded `7zip.spl` and runs the
thread function under it, or calls it directly when the plugin is not loaded.
No other thread creation exists in the compiled files (verified by `grep`
for `_beginthreadex`/`CreateThread` outside `Threads.c`).

## E5 — Patch register

`src/plugins/7zip/7za/TC-PATCHES.md` lists every changed upstream file with
the reason; each change is bracketed by `TC_7ZIP_PATCH` comments. An upgrade
diffs the tree against the next release's archive and re-applies the list.
