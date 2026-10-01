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
  0 failed; wrong password on 7z fails per item → the 16.04 "JRY FIX" is
  retired. *Corrected after the review*: `7zclient.cpp:512` is
  `TestArchive`; `Decompress` did **not** check `NumErrors` in this commit
  (see below).

## S1 independent review — REJECT, fixed

One blocker, three SHOULD-FIX, five NITs (reviewer: a separate agent, no
part in writing S1). Everything below is in the S2/S3 commit.

- **Blocker — a failed extraction reported success.** 26.03 returns S_OK
  from `Extract()` and reports wrong passwords / data errors per item; the
  probe shows it (`7Z encrypted with a wrong password fails`: `result
  0x00000000, errors 2`). `Decompress` mapped only the HRESULT, and its three
  callers (`UnpackArchive`, `UnpackOneFile`, `UnpackWholeArchive`) tested
  `!= OPER_CANCEL`, so even an `OPER_CONTINUE` was success → the core deletes
  the source after *Unpack and delete* or a Move out of the archive. My
  earlier working-tree fix (`NumErrors > 0` → `OPER_CONTINUE`) was therefore
  **not** enough, as the reviewer showed. Fixed on both ends: `Decompress`
  returns `OPER_OK` only for S_OK with no per-item error and no skipped link,
  the callers require `== OPER_OK`. Skip at the overwrite prompt does not
  count as an error (unchanged).
- **The engine was not loaded by its wide path.** `g_IsNT` was `false`, so
  `CLibrary::Load` took `LoadLibraryA(fs2fas(path))` — same as 16.04, but
  the S1 commit message, TC-PATCHES and research R8 claimed otherwise. Now
  `g_IsNT = true` (only `DLL.cpp` reads it), so `LoadLibraryW`.
- **The configured word size is applied now.** 0.1.8 sent it as `VT_I4`;
  the probe's new `props` command (every combination of the dialog's
  tables, 4,722) shows **both** engines reject `VT_I4` for every packing
  combination (4,710 of 4,722; only the 12 store-only ones pass) and accept
  all 4,722 as `VT_UI4`. The S1 port's `(UInt32)` cast therefore makes the
  user's *Word size* setting take effect for the first time — a behaviour
  change (changelog). `SetCompressionParams`' result is checked now: a
  rejection ends the operation with "Internal error." instead of packing with
  other settings than chosen.
- **Stale `7zwrapper.dll` in existing output trees** — S4 (T023), as
  planned; stale architecture docs and the project count — T027.
- NITs: `#include <stdlib.h>` in the `Threads.c` patch block (malloc/free had
  come only through `windows.h`); `GetStream` looks the item up with
  `find()` (operator[] allocates, and the callbacks are `throw()` since
  26.03) and has a `catch (...)` → `E_OUTOFMEMORY`; the duplicate
  `CreateObject` line in `spl/7za.def` removed; the open callback's
  `GetStream` sets `*inStream = NULL` on every path (S3). **Backslash in 7z
  names**: 26.03 maps a literal `\` stored in a 7z name to U+F05C (WSL
  scheme, `7zIn.cpp:600`). 16.04 wrote `/` as well (`MakeLegalName`,
  `7zHandlerOut.cpp:380` of the 16.04 tree), so archives made by 0.1.8 are
  unaffected; only a Unix-made archive with `\` inside a name now shows one
  name with U+F05C instead of a folder split — safe, kept.

## S2 — item names (T009–T012)

- `src/common/salarcname.h` (header-only — plugin projects cannot compile a
  shared `.cpp` with their PCH): `SalArcCleanItemPath` (contract N1–N5),
  `SalArcDetectFormat` (the two volume-name helpers written with them were
  removed after the S2/S3 review — unused); `saltests` `TestArcNames087`. A drive prefix is removed only before a
  separator or the end (`x::$DATA` would otherwise lose its `x:`).
- Names are cleaned twice: when the list is built (`AddFileDir`, so the
  panel shows what will be written) and again just before the path is
  composed in the extract callback (`GetStream`), which is the security
  boundary. Alternate-stream items are not listed.
- Link entries (`kpidSymLink`/`kpidHardLink`) are not extracted; the count
  is reported after the operation (`IDS_LINKS_SKIPPED`), and a skipped link
  makes the operation incomplete (no source deletion). The message is a
  count after a colon rather than a plural form, because it is
  machine-translated.

## S3 — RAR (T013–T020)

- Format by signature (`SalArcDetectFormat` over the first 8 bytes →
  7z / Rar / Rar5 handler); unknown → "unsupported archive".
- Volumes: `IArchiveOpenVolumeCallback` on the open callback — `GetStream`
  opens only siblings of the first part (a name with `\`, `/` or `:` is
  refused), a missing part is `S_FALSE` and the handler reports it;
  `GetProperty(kpidName)` gives the first part's name.
- Memory: `IArchiveRequestMemoryUseCallback` on the open and extract
  callbacks, limit min(4 GiB, physical memory / 2). The RAR5 handler asks
  only above 1 GiB (`Rar5Handler.cpp:2974`), so `probe/make_bigdict.py`
  rewrites the first file header of a fixture (dictionary field, header CRC
  recomputed): 128 GiB (RAR7 field) refused with E_OUTOFMEMORY, 2 GiB refused
  under a 1 GiB limit and extracted under the default one (probe `MEM`).
- Read-only: RAR handlers have no `IOutArchive` → the existing
  `IDS_UPDATE_NOT_SUPPORTED` (T017 verified by reading `Update`/`Delete`).
- Registration, configuration version 4 (`7zip.cpp` `Connect`): the custom
  unpacker mask becomes `*.7z;*.rar` once (`ConfigVersion < 4`); RAR is
  registered for **view only**, `AddPanelArchiver("rar;r##", FALSE, …)`.
  Reading the core (`plugins1.cpp` `AddPanelArchiver`) corrected the 084
  contract M2's expectation: only a **new** plug-in installation searches
  other records for an overlap — there the core's `rar;r##` record is taken
  over as unpacker and keeps WinRAR as its packer. An **installed** plug-in
  (configuration 1–3, `updateExts`) can only extend its own record, so
  `rar;r##` joins the `7z` record whose packer is the plug-in; packing into a
  RAR archive from the panel then ends with "Update operations are not
  supported". The core's own `rar;r##` record stays stored and is skipped at
  runtime (RAR's archiver cannot browse, 084 FR-017), so there is no
  duplicate claim. Owed: the GUI check on a fresh and an upgraded
  configuration.
- Password prompt: the plugin's ANSI dialog — characters outside the code
  page cannot be typed (cluster B-1). FR-010, the edge case and contract P4
  revised; the session password is now wiped on close (`Wipe_and_Empty`;
  0.1.8 assigned `L"empty"`, which left the tail of a longer password).
- **T019** `IDS_LINKS_SKIPPED` in 8 languages (`translate.merge --module
  7zip`, 824 DeepL characters, 1 gap per language, validation failures 0,
  `slt --verify` byte-exact). The module had last been regenerated at build
  185, so the merge also re-fitted 5–6 control widths per language with the
  current algorithm (all inside their dialogs, e.g. 1214: 16 + 270 < 290);
  accepted as part of the regeneration.
- Engine probe after S2/S3 (Debug 26.03): 0 failed, including the new
  `props` check; 10,000-entry listing 0.030 s.

## S4 — packaging and notices (T023, T024)

- **T023** a stale `plugins\7zip\7zwrapper.dll` is deleted on an updated
  installation from the installer's `[Code]` at `ssPostInstall`
  (`RemoveStale7zWrapper`, next to feature 080's crash-reporter cleanup —
  not `[InstallDelete]`, for the reason recorded there) and from older
  output trees by `build.cmd` (with its `.exp/.lib/.pdb` and intermediate
  folder), because the installer packages the tree recursively.
- **T024** `doc/third_party.txt`: 7-Zip 26.03, reduced to 7z and RAR,
  modified (pointer to `TC-PATCHES.md`), © 1999-2026 Igor Pavlov, GNU LGPL
  2.1+, RAR decoder under the unRAR restriction (the existing paragraph).

## T025 — every engine thread passes the trampoline

`probe/fakespl.c` is built as a stand-in `7zip.spl` (the module name the
trampoline looks up) exporting `AddCallStackObject`; it records every
thread the process starts (`DLL_THREAD_ATTACH` + start address) and every
entry through the trampoline. `7zdrive … -spl=obj\spl\7zip.spl` loads it
before the engine and fails if any thread whose start address is outside
`ntdll.dll` did not pass (the driver starts no threads of its own).

| Workload (Debug 26.03 engine) | engine threads | through the trampoline |
|---|---|---|
| create 7z, 48 MB, LZMA2 level 5 | 2 | 2 |
| create 7z, level 9 | 2 | 2 |
| extract LZMA2 with 1 MB blocks, made `-mmt=4` by 7z.exe (MtDec) | 11 | 11 |
| extract BZip2 7z | 1 | 1 |
| extract every `.rar` file of the 084 fixture folder (23, volume parts included) | 0 | 0 |
| **negative control**: create with the unmodified `7z.dll` of 7-Zip 22.01 | 2 | **0** (check fails, as it must) |

## T026 — gates

| Gate | Result |
|---|---|
| `build.cmd` (Debug x64) | succeeded; encoding guard `TOTAL: 0` |
| `build.cmd full release` | succeeded; *Reconcile: removed stale plugins\7zip\7zwrapper.dll*; runtime closure OK (218 modules) |
| saltests | see *After the S2/S3 review* below (1904 before it) |
| engine probe, Debug and Release 26.03 | 0 failed each (RAR 23 files, 7z round trips, wrong passwords, hostile names, `MEM`, `props`) |
| `7za.dll` Release | file version 26.03, *7-Zip engine (7z, RAR) - modified for use by Tandem Commander*, 3 formats |
| SC-005 listing 10,000 entries | Release 26.03 **0.022 s** = 16.04 Release baseline 0.022 s (Debug 0.030–0.032 s) |
| plugin ABI | no header under `src/plugins/shared/` changed (only the two `baseaddr_*.txt` lines of `7zwrapper`); interface 106 |
| installer | `setup\build_setup.cmd` (unsigned) compiles with `RemoveStale7zWrapper`; a real update over an installed 0.1.8 is **owed** (quickstart step 6) — not run here, because Setup ignores `/DIR` while an installation with the same AppId exists and would change the maintainer's own installation |
| `translate.slt --verify` | byte-exact, 298 files |

## S2/S3 independent review — REJECT, fixed

Reviewer: a separate agent with no part in the code. **No way for a crafted
name to leave the target folder was found** (37 hostile inputs against
`salarcname.h` in a scratch build, plus the probe's hostile archive). The
reject was for the handling of results the 26.03 engine reports and 16.04
did not, and for older defects the new paths now reach.

- **Blocker — a wrong RAR5 password.** The engine reports
  `kWrongPassword` (9) per file, *after* the output file was created; the
  plugin's result switch knew nothing of it → "Unknown error." per file, an
  empty file left behind, and the wrong password kept for the session.
  Fixed (`extract.cpp SetOperationResult`, contract P6b table): the file is
  deleted, one message, the password forgotten, the operation stops. Every
  other non-OK result with a file of its own now gets the *delete or keep*
  question (0.1.8: data error only; a CRC error kept the file silently).
  After any operation with errors that used a password the remembered
  password is forgotten (`Decompress`), and so is one an archive did not open
  with (`OpenArchive`).
- **Cancel could delete the wrong file** (older, data loss). `Cleanup`
  deleted "the last named file" whenever a stream object had ever been
  created: after *Skip* at the overwrite prompt followed by Cancel that is
  the user's own existing file; with an unselected item of a solid archive,
  the last completely unpacked one. Now only a file opened for the current
  item (`HaveOutFile`) is deleted; attributes are set only on such a file or
  a directory the callback created.
- **Multi-part RAR, *Unpack and delete*** deleted only the first part.
  The open callback records every part it opens
  (`C7zClient::OpenedVolumes`); all are handed to the core.
- **Items that were never unpacked counted as success** (older). A path too
  long for the panel listing is dropped at listing
  (`C7zClient::ListingIncomplete`) — *Unpack and delete* then keeps the
  archive; the "name too long" branch of the extract callback counts as an
  error.
- **Stack overflow in the error message** (older): three `vsprintf` into
  1,024-byte buffers in `7zip.cpp` and one in `extract.cpp` took the full
  archive path; now `_vsnprintf_s(..., _TRUNCATE, ...)`.
- NITs fixed: reserved device names (`CON .txt`, `CONIN$`, `CONOUT$`, `COM0`,
  `LPT0`, superscript digits) + tests, the weak `con.d\x` test made exact;
  `try/catch` in the open callback's `GetStream`/`GetProperty`; the unused
  helpers and `ArchiveFormat` removed; contracts P3, P6b, P8, N3 rewritten
  as built; links marked only by the Unix mode (RAR4, Unix-made 7z) are
  recognised (`IsLinkItem`; the probe now shows 1 skipped link in four RAR4
  fixtures that used to yield a small text file); the password is wiped with
  `SecureZeroMemory` (`WipeUString`); the cleaned name's scratch buffer is on
  the heap; `SetBasicPluginData` declares `7z;rar`.
- **Not fixed, recorded** (older, outside this feature's requirements):
  (1) the plugin's converters are strict UTF-8, not WTF-8 — a lone
  surrogate in an archived name becomes U+FFFD (feature 066's rule is not
  applied in this plugin); (2) updating a 7z archive matches against the
  stored names, so adding into a folder whose name had to be cleaned
  (stored `a:b`, shown `a_b`) creates a second item instead of replacing;
  (3) fresh and upgraded configurations differ for packing into RAR from
  the panel (contract P8). All three go to `specs/NEXT-WORK.md`.

### After the S2/S3 review

Full Debug build succeeded (encoding guard `TOTAL: 0`); saltests **1900
checks, 0 failed** (1904 − 14 volume-name checks + 10 reserved-name checks);
engine probe on the Debug engine 0 failed, with 1 skipped link now reported
for `test_read_format_rar.rar`, `…_rar_unicode.rar` and the RAR4
multi-volume set. The plugin's own result handling (wrong password, cancel,
keep/delete) cannot be driven without the GUI — it is in the owed pass
(`quickstart.md` steps 1 and 4b–4d).

**Verification of the fixes by the same reviewer: ACCEPT.** Every listed flow
of the extract callback was traced against the engine's call order (normal
file, directory, overwrite-Skip, unselected solid item, link, Cancel
mid-file and at the RAR5 password prompt, data error with Keep / Delete /
Cancel, the F3 path). Left open by it and fixed afterwards: `SysError` in
`7zip.cpp` still used `vsprintf`/`sprintf` (bounded now), and the
wrong-password message could name no file when testing — the callback now
keeps the current item's path (`CurrentItemName`; `InitTest` receives the
archive). Noted and accepted: a 7z made on Unix with symbolic links now ends
as incomplete (changelog), and the password is forgotten after any error of
an operation that used one.

Final state: Debug and full Release builds succeeded, saltests 1900 / 0,
engine probe 0 failed on both engines (10,000-entry listing: Release 0.024 s,
Debug 0.030 s; 16.04 Release baseline 0.022 s — within SC-005).

## T028 — what a person still has to do

`quickstart.md`, *Owed to a person*: the GUI pass (steps 1–6, 4b–4d). None of
the plugin's dialogs, the association outcome on a fresh and an upgraded
configuration, or the installer's removal of `7zwrapper.dll` over a real
0.1.8 installation was exercised in this session.

## T021 — archives made by 16.04 read by 26.03 (SC-002)

`probe/cross_version_7z.py <old 7za.dll> <new 7za.dll>`: the driver creates
five 7z variants (plain, store, non-solid, encrypted data, encrypted names)
with the **16.04** engine of the installed 0.1.8
(`C:\Program Files\Tandem Commander\plugins\7zip\7za.dll`, used read-only)
and extracts them with the 26.03 engine — all five identical to the source,
on the Debug and the Release engine. T015 as built: the prompt stays an ANSI
dialog (FR-010 revised), the engine gets UTF-16.
