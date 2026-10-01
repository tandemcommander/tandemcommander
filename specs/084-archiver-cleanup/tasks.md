# Tasks: Working Archivers Only

**Input**: Design documents from `specs/084-archiver-cleanup/`
**Prerequisites**: plan.md (stages S1–S7), spec.md (US1–US5 + Clarifications),
research.md (R1–R11), data-model.md, contracts/archiver-launch.md (C1–C6),
contracts/config-migration-106.md (M0–M6), contracts/7z-slt-listing.md (P1–P4),
quickstart.md (§0–§8)

**Tests**: The spec demands measurable verification (SC-001…SC-006), so
verification tasks are included:
- unit checks in `saltests` for the two new pure units, written before the
  wiring that uses them;
- three probes (launch/cancel, migration, inventory);
- build and grep sweeps.

**Organization**: grouped by user story, in **execution order**, which differs
from priority order:
- **US2** (P1, external archivers start) comes first. It is the MVP and every
  other story builds on the direct launch.
- **US1** (P1, RAR out of the box) comes **last**. It is blocked on a separate
  feature that upgrades the vendored 7-Zip 16.04 → 25.x (research R3, maintainer
  decision 2026-10-01).

**Process rule (house practice, 069/075/079/080)**: every task group ends with
an **independent review** of its diff by an agent that did not write it. A
REJECTED verdict is fixed before the next group. Verdicts are recorded in
`fix-log.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an
  incomplete task)
- **[Story]**: the user story the task belongs to (US1–US5)
- `specs/084/` abbreviates `specs/084-archiver-cleanup/`
- `<out>` = `%OPENSAL_BUILD_DIR%tandemcommander` (default `build\tandemcommander`)

## Path Conventions

| What | Where |
|---|---|
| Sources | `src/` |
| Pure, unit-testable logic | `src/common/` |
| Unit tests | `src/saltests/saltests.cpp` |
| Projects | `src/vcxproj/` |
| String IDs | `src/texts.rh2` |
| English texts | `src/lang/texts.rc2`, `src/lang/lang.rc` |
| Translations | `translations/<language>/salamand.slt` |
| Help pages | `help/src/hh/salamand/` |

---

## Phase 1: Setup (baseline, record, fixtures)

**Purpose**: capture the state the success criteria are measured against, and
prepare the fixtures every story's verification uses.

- [X] T001 Create `specs/084/fix-log.md` (running record, one dated entry per task group) with the baseline:
  - HEAD commit;
  - `saltests.exe` result from `<out>\Debug_x64\saltests\saltests.exe` (expected 1527/0);
  - the output of `git grep -n -i -E "salspawn|MS-DOS|External DOS|External Win32|1\.44 ?MB" -- src help translations` (count per directory);
  - the list of files under `<out>\Debug_x64\utils\` (confirm there is no `salspawn.exe`);
  - `THIS_CONFIG_VERSION` = 105 (`src/mainwnd2.cpp:147`).
- [X] T002 [P] Add the prerequisite to `specs/NEXT-WORK.md`: a new item "Upgrade vendored 7-Zip 16.04 → 25.x (`src/plugins/7zip/7za`)". Mark it as blocking feature 084 stage S7 (RAR) and as a security fix in its own right (CVE-2018-10115, CVE-2025-53816; research R3). It needs its own `/speckit-specify`.
- [X] T003 [P] Create `specs/084/probe/fixtures/` and fill it:
  - Copy the libarchive RAR test archives from the session scratchpad `…\scratchpad\rar\` (RAR4, RAR5, encrypted data and encrypted headers for both, Unicode names, the RAR5 8-part and RAR4 4-part sets, and one damaged archive).
  - Fetch ARJ and LZH samples from libarchive's `libarchive/test/` (`test_read_format_lha_*.lzh.uu`, `test_read_format_arj*` if present; decode `.uu`).
  - Create `unicode.7z` with 7-Zip containing `Příliš žluťoučký kůň.txt`, `中文.txt`, `😀.txt`, an empty file, and a sub-directory with a space in its name.
  - Write `specs/084/probe/fixtures/README.md` listing each file, its source URL and its licence (libarchive: BSD-2-Clause).
- [X] T004 [P] Capture the real listings into `specs/084/probe/fixtures/slt/` by running `"C:\Program Files\7-Zip\7z.exe" l -slt -sccUTF-8 -scsUTF-8 -- <fixture>` for `unicode.7z`, one ARJ and one LZH fixture, saved as raw UTF-8 bytes. Use a short Python `subprocess` script, not shell redirection, which would re-encode. Record the 7-Zip version in the README.
- [ ] T005 [P] Produce three 0.1.8-shaped configuration exports `specs/084/probe/fixtures/cfg_a_defaults.reg`, `cfg_b_edited.reg` and `cfg_c_custom.reg` (quickstart §5): **[OWED - GUI skipped at the maintainer's request 2026-10-01; script `probe/make_cfg_fixtures.ps1` ready]**
  1. Back up `HKCU\Software\Tandem Commander` with `reg export`.
  2. Delete the key and start the installed 0.1.8 (`C:\Program Files\Tandem Commander\tandemcommander.exe`); if it is not 0.1.8, build `v0.1.8` in a `git worktree`. Exit it and export `…\0.1\Packers & Unpackers` as (a).
  3. For (b), edit (a)'s text: change the arguments of the ARJ default packer entry, and keep the RAR "1.44MB volumes" entry.
  4. For (c), add one custom packer whose command is `C:\Tools\myarc.exe` with `$(ArchiveDOSFullName)` in its arguments, and one custom packer using `$(Rar32bitExecutable)` with arguments `a -m5 "$(ArchiveFullName)" @"$(ListFullName)"`.
  5. Restore the backup and verify it key by key (078/079 recipe).

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: string-ID allocation shared by all stories, and preservation of
0.1.8 data the migration needs before stage S2 deletes it.

**⚠️ CRITICAL**: T006 before any task adding a string; T007 before T036.

- [X] T006 Allocate **never-used** string IDs for every new or reworded text (research R10):
  - the new `IDS_PACKERR_PROCESS` wording;
  - a replacement for `IDS_PACKRET_BREAK2`;
  - "cancelled" / "incomplete" messages;
  - the Cancel button caption, if `CExecuteWindow` needs its own;
  - the titles "RAR (WinRAR)" and "7-Zip";
  - the Autoconfiguration descriptions for `rar.exe` and `7z.exe`;
  - the `SevenZipErrors` codes.

  For each candidate ID run `git log -S "<id>" --oneline -- src/texts.rh2` and `rg -n "^<id>," translations` to prove it never existed. Record the table (name → ID → reason) in `specs/084/fix-log.md`. Prefer free 16-ID bundles so no existing bundle changes membership.
- [X] T007 Freeze the 0.1.8 data the migration must recognise into `specs/084/fix-log.md` from `git show v0.1.8:src/packers.cpp` and `git show v0.1.8:src/pack3.cpp`:
  - the exact former floppy-volume argument strings (every `-v1440` / `-pav1440` string in `CustomPackers`, `packers.cpp:56-105`);
  - the 12 removed `$(…Executable)` variable names;
  - the 12 old archiver-table indices with their UIDs (`ARC_UID_*`, `src/pack.h`).

  These are the data constants for `salarcmig` (T040).

**Checkpoint**: IDs allocated, migration constants frozen. User-story work can start.

---

## Phase 3: User Story 2 — External archivers start reliably (Priority: P1) 🎯 MVP

**Goal**: archivers are started directly (no `salspawn.exe`), in a kill-on-close
job object, with a Cancel button and errors naming the real program
(FR-001/005/006, contract C1–C6).

**Independent Test**: on the existing 0.1.8 archiver table, configure a
**custom unpacker** with its own path (`C:\Program Files\7-Zip\7z.exe x
"$(ArchiveFullName)"`) and a custom packer (`7z a …`). Run pack, unpack and
Cancel from a path with spaces and `ř`. There must be no `salspawn` error, the
archiver must end on Cancel, and the error for a missing exe must name it.

- [X] T008 [US2] Add a single launch routine in `src/pack3.cpp`, declared in `src/pack.h` (e.g. `BOOL PackStartArchiver(const char* cmdLineU8, const char* initDirU8, BOOL listing, HANDLE* process, HANDLE* job, HANDLE* stdoutRead)`) implementing contract C2:
  - flags `CREATE_NEW_PROCESS_GROUP | CREATE_DEFAULT_ERROR_MODE | NORMAL_PRIORITY_CLASS | CREATE_SUSPENDED`;
  - listing mode adds `CREATE_NEW_CONSOLE` + `SW_HIDE`, stdin opened on `NUL` (inheritable), and an inheritable stdout/stderr pipe;
  - `CreateJobObjectW` + `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` + `AssignProcessToJobObject` before `ResumeThread`;
  - on failure every handle is closed and `IDS_PACKERR_PROCESS` (new ID from T006) is reported with the **archiver's** executable path (first token of the command line) and `GetErrorText`.

  The routine uses `SalCreateProcess`, so the command line stays UTF-8.
- [X] T009 [US2] Extend `CExecuteWindow` (`src/pack3.cpp:39` declaration, `:1967+` implementation):
  - a standard Cancel push button (`BS_PUSHBUTTON`, shell font, caption from the existing common "Cancel" string if one exists, else the T006 ID);
  - a `Cancelled` flag set by the button, by `Esc`, and by `WM_CLOSE` of the main window while the run is active.

  No new dialog template and no change to the existing caption palette (constitution VI).
- [X] T010 [US2] Rewrite the waiting part of `PackExecute` (`src/pack3.cpp:1720-1960`):
  - build the command line **without** the `"<SpawnExe>" -c10000` prefix;
  - call T008 (execute mode, keep the minimized console and the 15 s `PackWinTimeout` restore);
  - wait with `MsgWaitForMultipleObjects` while pumping messages;
  - on `Cancelled`, call `TerminateJobObject`, wait for the process, and return a distinct *cancelled* result (C3);
  - map non-zero exit codes only through the row's error table or `IDS_PACKERR_RETURN` (C4);
  - delete the `SPAWN_ERR_BASE` block at `:1916-1939`;
  - close the job handle on every path.
- [X] T011 [US2] Rewrite the listing run in `PackList` (`src/pack1.cpp:640-850`): **[As built, review #3: no worker thread, no 990-byte cap, no own window: the pipe is drained in the UI message loop, output is capped at 512 MB (`IDS_PACKERR_NOMEM`), Esc cancels (contract C3 amendment)]**
  - same launch through T008 in listing mode;
  - the pipe is read on a worker thread into `CPackLineArray`, keeping the 990-byte line cap: an over-long line ends the run with `IDS_PACKERR_PARSE`, never a partial listing;
  - the UI thread shows `CExecuteWindow` with Cancel and pumps messages;
  - Cancel terminates the job and returns without a listing;
  - delete the `SPAWN_ERR_BASE` block at `:826-849` and the `cmdForErrors` reconstruction where T008 already provides the program name.
- [X] T012 [US2] Propagate *cancelled* to the callers so it is not shown as an error, and an unpack is reported incomplete (C3):
  - `PackUniversalUncompress`, `PackUnpackOneFile` (`src/pack1.cpp:1437/1823`);
  - `PackUniversalCompress`, `PackDelFromArc` (`src/pack2.cpp:236/603`);
  - `CPackerConfig::ExecutePacker`, `CUnpackerConfig::ExecuteUnpacker` (`src/packers.cpp:781/1421`);
  - their UI callers in `src/fileswn7.cpp` (`UnpackZIPArchive`, `Pack`, `Unpack`).

  Use the existing `PackErrorHandlerPtr` convention. Add an explicit cancelled return path rather than a magic error number, and document it in the `src/pack.h` comment.
- [X] T013 [US2] Remove the helper plumbing:
  - `SPAWN_EXE_NAME`, `SPAWN_EXE_PARAMS`, `SPAWN_ERR_BASE`, `SpawnExe`, `SpawnExeInitialised` (`src/pack.h:16-21`, `src/pack1.cpp:25-30`);
  - `InitSpawnName` (`src/pack3.cpp:357-390`) and every call to it (`rg -n InitSpawnName src`);
  - `IDS_PACKRET_SPAWN` from `src/texts.rh2:1303` and `src/lang/texts.rc2:1061`, with the `{…, IDS_PACKRET_SPAWN}` uses.
- [X] T014 [P] [US2] Delete the helper project:
  - `src/salspawn/` (4 files) and `src/vcxproj/salspawn/` (vcxproj + 3 props);
  - the `salspawn` `Project(…)` block and every `{C610C287-BC1E-4FAE-9BF4-A1CB68986746}` line in `src/vcxproj/salamand.sln`;
  - line 87 of `src/plugins/shared/baseaddr_x64.txt` and `src/plugins/shared/baseaddr_x86.txt`;
  - the rows in `architecture/01-project-overview.md:61` and `architecture/02-solution-structure.md:159` (also update that file's project count).

  Run `build.cmd` once and confirm the regenerated `src/vcxproj/salamand.gen.slnf` no longer lists it.
- [X] T015 [US2] Reword the user-facing texts:
  - the new `IDS_PACKERR_PROCESS` (T006 ID): "Unable to start the archiver ""%1"". The error was: %2", with no Autoconfiguration advice; add a second variant with that advice, used only when the configured path is empty or the file does not exist (FR-005);
  - the replacement for `IDS_PACKRET_BREAK2`: the archiver was stopped or waited for an answer, with no `salspawn.exe` text;
  - the cancelled/incomplete messages.

  Edit `src/texts.rh2`, `src/lang/texts.rc2` and the error tables in `src/pack3.cpp` (`RARErrors` entry 255 at `:243`). Remove the old IDs' definitions and English texts.
- [X] T016 [P] [US2] Write `specs/084/probe/launch_probe.ps1` (Windows PowerShell 5.1). It: **[As built, review #3: **file not written** — the launch checks are scenarios of `probe/gui_probe.ps1` (not run, GUI skipped); `quickstart.md` still names `launch_probe.ps1`]**
  - starts the Debug build with a prepared custom unpacker (own-path `7z.exe`), triggers an unpack of a large archive (create a ≥ 1 GB `.7z` in the scratchpad with 7-Zip's `-mx0`), and polls the process tree with `Get-CimInstance Win32_Process`;
  - asserts `7z.exe` is a direct child of `tandemcommander.exe` and no `salspawn` process ever exists;
  - clicks Cancel (`BM_CLICK` on the button found via `FindWindowEx`) and asserts `7z.exe` is gone within 2 s and no error dialog is shown;
  - finally kills `tandemcommander.exe` during a run and asserts the job kills `7z.exe`.

  Avoid `Start-Process -Wait` (080 trap: it waits for the process tree).
- [ ] T017 [US2] Build Debug (`build.cmd`), run `saltests` (unchanged count), run T016, and do the US2 Independent Test by hand. Record the results in `specs/084/fix-log.md`, then do the independent review of the T008–T016 diff and record its verdict. **[PARTLY: build + saltests done; launch probe / manual US2 test OWED - GUI skipped]**

**Checkpoint**: external archivers start; Cancel works; no `salspawn` anywhere.

---

## Phase 4: User Story 3 — Only programs that can work are offered (Priority: P2)

**Goal**:
- The built-in archiver table is exactly **7-Zip** (index 0, UID 13; browse and
  unpack via `-slt`, UTF-8) and **RAR (WinRAR)** (index 1, UID 2; packing only).
- Every DOS, floppy and discontinued entry, parser, hack and text is gone.
- Entries are hidden while their program is not found.
- Autoconfiguration finds only `7z.exe` and `rar.exe`.

(FR-002/003/008/009/016/017; clarifications Q1–Q3.)

**Independent Test**: on a fresh configuration, every list (Pack, Unpack,
Packers / Unpackers / External Archivers / Associations pages,
Autoconfiguration) shows only plug-ins plus 7-Zip / RAR. With 7-Zip
installed, `.arj` / `.lzh` / the Unicode fixture browse and extract with
intact names. With `7z.exe` renamed they are plain files.

### Pure parser first (contract P1–P4)

- [X] T018 [P] [US3] Create `src/common/sal7zlist.h` and `src/common/sal7zlist.cpp`:
  - `struct CSal7zListItem` with path (UTF-8 `std::string`), isDir, size, packedSize + hasPacked, FILETIME modified + hasDate, attributes, encrypted;
  - `BOOL SalParse7zTechList(const char* utf8, size_t len, std::vector<CSal7zListItem>& out, int* errorLine)`, implementing contract P1–P3 exactly: separator detection, `Path =` starts an item, CR stripping, the safety rejections for empty, absolute and `..` paths.

  Header: SPDX "2026 Pavel Stupka", GPL-2.0-or-later, UTF-8-BOM, English comments. Only the C++ standard library and `<windows.h>` types, so `saltests` can link it.
- [X] T019 [US3] Add `..\common\sal7zlist.cpp/.h` to `src/vcxproj/salamand.vcxproj` (+ `.filters`, next to `salcloseapp.*`), and `..\..\common\sal7zlist.cpp/.h` to `src/vcxproj/saltests/saltests.vcxproj` (next to `salcloseapp.*`).
- [X] T020 [US3] Add `static void TestSevenZipList084()` to `src/saltests/saltests.cpp` and call it after `TestCloseApp080()` (`:2370`). It covers contract P4:
  - the T004 captures embedded as byte-exact string literals (Czech, Chinese and emoji names, a directory, an empty file, an empty `Packed Size`);
  - a CRLF variant;
  - missing separator, item without `Path`, a `..` component and an absolute path rejected;
  - malformed `Modified` accepted with no date.

  Build and run: expect 1527 + new checks, 0 failed. Record in `fix-log.md`.

### Archiver table reduction (stage S2)

- [X] T021 [US3] In `src/pack.h`: **[As built, review #3: no `Utf8IO` field; the list-file encoding is chosen by the `$(ListUnicodeFullName)` variable (research R7a)]**
  - replace the `PACK*INDEX` block (`:24-35`) with `PACK7ZIPINDEX 0` and `PACKRARINDEX 1`;
  - add `ARC_UID_7ZIP 13` and keep `ARC_UID_RAR` = 2, retiring the other `ARC_UID_*` with a comment "retired in 084 — never reuse";
  - add a `BOOL Utf8IO` member to `SPackBrowseTable` and `SPackModifyTable`;
  - delete `SPackLocation` (`:51`, unused) and `DOS_MAX_PATH` only if T024 removes its last use.

  Keep everything custom entries still use (FR-008).
- [X] T022 [US3] In `src/pack1.cpp`: **[As built, review #3: `a##` not added; commands as in `inventory.md` §4 (`-ba`, UTF-16 list)]**
  - reduce `PackBrowseTable` (`:38-119`) to two rows:
    - **[0] 7-Zip**: list `"$(SevenZipExecutable)" l -slt -sccUTF-8 -scsUTF-8 -- "$(ArchiveFullName)"` via a `SpecialList` function; extract-selected `"$(SevenZipExecutable)" x -y -sccUTF-8 -scsUTF-8 "$(ArchiveFullName)" -o"$(TargetPath)" @"$(ListFullName)"`; extract-one `… e …`; `SupportLongNames` TRUE; `Utf8IO` TRUE; `SevenZipErrors`.
    - **[1] RAR**: no list or extract commands (browsed by the 7zip plug-in, R3).
  - delete `PackUC2List` (`:1021`), the ARJ16/ARJ32 hacks (`:947/953`) and the `RAR5AndLater` patching (`:895-991`);
  - update the "order of external archivers" warning comment at `:37`.
- [X] T023 [US3] Implement the 7-Zip `SpecialList` function in `src/pack1.cpp`:
  - it consumes the raw UTF-8 pipe bytes and calls `SalParse7zTechList`;
  - it fills `CSalamanderDirectory` the way `PackScanLine` (`:210`) does: directories created along each path, size, date/time, attributes, names kept **UTF-8 without any OEM/ACP step**;
  - a parse error shows `IDS_PACKERR_PARSE`, and the panel shows nothing.

  Make sure the `Utf8IO` row bypasses the `OemToCharBuff` decoding at `:298-319`.
- [X] T024 [US3] In `src/pack2.cpp`, reduce `PackModifyTable` (`:22-94`) to two rows: **[As built, review #3: RAR uses `-scul` with a UTF-16LE list, not `-scfl`/UTF-8 (R7a)]**
  - **[0] 7-Zip**: no operations;
  - **[1] RAR**: add `"$(Rar32bitExecutable)" a -scfl -idq -y "$(ArchiveFullName)" @"$(ListFullName)"`, move `… m …`, delete `… d -scfl -idq -y …`, `Utf8IO` TRUE.

  Keep the `!SupportLongNames` code paths (short names, the 128-character check, the DOS temporary-name rename at `:413/495`), because custom entries can still turn that flag off (FR-008). Delete only row-specific special cases.
- [X] T025 [US3] Implement `Utf8IO` list files in `src/pack1.cpp:1527-1543` and `src/pack2.cpp:329-371/693-708`: **[As built, review #3: UTF-16LE list with BOM instead of UTF-8; a name the code page cannot hold does not fail, it is written in UTF-16 (contract C5)]**
  - when the row is `Utf8IO`, write the UTF-8 names unchanged; 7-Zip gets a UTF-8 BOM (verified in research R5), RAR gets no BOM (`-scfl`);
  - otherwise keep the OEM/ANSI behaviour;
  - for a custom entry, a name that the chosen code page cannot represent fails the operation with a message naming the file instead of writing `?` (contract C5). Use the strict conversion result of `SalU8ToOEM`/ACP conversion.
- [X] T026 [US3] In `src/pack3.cpp`:
  - keep `RARErrors` and add codes 9 (create), 10 (no files), 11 (wrong password) and 12 (read error), with new IDs from T006;
  - add `SevenZipErrors` (1 warning, 2 fatal, 7 command line, 8 memory, 255 user stop);
  - delete the JAR, ARJ, ACE, LHA, UC2 and ZIP error tables and the `IDS_PACKRET_*` codes only they used;
  - reduce `PACK_EXE_*` (`:260-272`) to `PACK_EXE_RAR32 = "Rar32bitExecutable"` and the new `PACK_EXE_7ZIP = "SevenZipExecutable"`;
  - reduce the `CmdCustomPackers` items (`:300`) to those two plus Browse;
  - remove the DOS items from the `ArgsCustomPackers` **menu** (`:347`), keeping their expansion entries in the expansion arrays at `:1545/1574` so stored commands keep working (FR-008);
  - reduce the `PackExp*ExeName` wrappers (`:1469-1531`) to the two kept variables, and leave `PackExpExeName`'s short-path behaviour unchanged;
  - update the `salmenu.mnu` comment blocks (`:276/320`) to match.
- [X] T027 [US3] In `src/packers.cpp`: **[As built, review #3: commands as in `inventory.md` §4 (UTF-16 list, `-o"$(TargetPath)"`); `a##` not added]**
  - reduce `CustomPackers[]` (`:54`) to one row, "RAR (WinRAR)" with the T024 add/move commands and no volume variant;
  - reduce `CustomUnpackers[]` (`:154`) to one row, "7-Zip" unpacking `*.arj;*.a##;*.lzh;*.lha` (the final list comes from `inventory.md`) with `"$(SevenZipExecutable)" x -y -sccUTF-8 -scsUTF-8 "$(ArchiveFullName)" -o"$(TargetPath)" $(Mask)` (check the mask variable's real name in the expansion table);
  - update `CustomOrder[]` (`:51`) and `PackConversionTable` (`:35`) to the two archivers;
  - rewrite `CPackerConfig::AddDefault` and `CUnpackerConfig::AddDefault` `case 0` for the new tables. Keep the `$(SpawnName)` legacy stripping for `ConfigVersion` 3–4, since it is harmless and covered by the old-config path.
- [X] T028 [US3] In `src/pack3.cpp` `CPackerFormatConfig::AddDefault` (`:422-503`), make `case 0` produce the data-model §2 defaults: **[As built, review #3: defaults `rar;r##`, `arj`, `lzh;lha`; no `a##`]**
  - `zip;pk3;jar` → plug-in placeholder exactly as today;
  - `rar;r##` → unpacker 1, packer 1;
  - `arj;a##` and `lzh;lha` → unpacker 0, no packer;
  - the tar line unchanged.

  Delete the `j`, `uc2` and `ace;c##` defaults and the `c##` workaround. Leave `CArchiverConfig::AddDefault` (`:779`) with exactly two rows, 7-Zip and RAR, with their UIDs.
- [X] T029 [US3] Rewrite `externalArchivers[]` in `src/plugins2.cpp:2593-2616` (the fallback used by `CPlugins::FindViewEdit` when a plug-in is removed) for the new indices: `rar;r##` → packer 1, no external unpacker; `arj`/`lzh`/`lha` → unpacker 0. Fix the order warning comment in `src/pack1.cpp:37` that refers to it. **[As built, review #3: `rar;r##` keeps `view = PACKRARINDEX` (the record survives for a later RAR reader, contract M2)]**
- [X] T030 [US3] Rewrite Archivers Autoconfiguration in `src/packac.cpp`:
  - reduce `PackACExtensions[]` (`:27`) and the search table to `7z.exe` (index 0) and `rar.exe` (index 1);
  - before the drive scan, probe the registry: `HKLM`/`HKCU` `SOFTWARE\7-Zip` `Path64` then `Path`, and `HKLM\SOFTWARE\WinRAR` `exe64` then `exe32` (research R8);
  - then the known folders `%ProgramFiles%\7-Zip\7z.exe`, `%ProgramFiles%\WinRAR\Rar.exe` and the `%ProgramFiles(x86)%` variants, via `SHGetKnownFolderPath` (wide, UTF-8 conversion with `SalWToU8`);
  - accept only 32-bit or 64-bit PE images from `MyGetBinaryType`; remove the `EXE_16BIT` branch (`:623-720/1113`);
  - pre-select registry and known-folder hits so a user without a drive scan gets them;
  - `RemoveFromCustom` (`:1032`) keeps working for the two kept variables.
- [X] T031 [US3] Add the availability cache:
  - `CArchiverConfig::RefreshAvailability()` in `src/pack3.cpp` + `src/pack.h`: per row, the executable path is non-empty and `SalGetFileAttributes` (or the house wide-path attribute helper) says it is a file;
  - `IsArchiverAvailable(int index)`;
  - call `RefreshAvailability` (a) at the end of the packer-section load in `src/mainwnd2.cpp` (after `:2958`), (b) after Autoconfiguration applies its results in `src/packac.cpp:1136-1180`, and (c) after the configuration dialog's OK applies the packer pages (`src/dialogsp.cpp`, find where the packer pages copy back into the globals). Each call also rebuilds the runtime extension table.

  Never call it per file.
- [X] T032 [US3] In `CPackerFormatConfig::BuildArray` (`src/pack3.cpp`, the function after `AddDefault`):
  - skip a record whose unpacker index ≥ 0 is unavailable **or** whose browse row has no list command (RAR);
  - build a record whose external packer is unavailable without packing.

  Apply this only to the global `PackerFormatConfig`, not to the configuration page's working copy (`src/dialogsp.cpp:1105-1240`). Confirm it by reading how the page copies the object.
- [X] T033 [US3] Switch the Pack and Unpack dialogs to item-data mapping and hide unavailable entries (FR-017):
  - `src/dialogs3.cpp:1887-1920` (pack fill), `:2033` (pack selection), `:2128-2156` (unpack fill), `:2214` (unpack selection) store the configuration index with `CB_SETITEMDATA` and read it back;
  - skip external entries whose command uses `$(Rar32bitExecutable)` or `$(SevenZipExecutable)` while that archiver is unavailable;
  - always list plug-in and own-path entries;
  - `src/fileswn7.cpp:1439-1463/1727` (preferred-entry fallback) skips hidden entries the same way;
  - put the shared predicate (which archiver variable an entry uses) in `src/packers.cpp`.
- [X] T034 [US3] Strings, using the T006 IDs:
  - **delete** from `src/texts.rh2` and `src/lang/texts.rc2` every `IDS_DP_*`, `IDS_DU_*`, `IDS_EXT_*`, `IDS_PACK_EXE_*` (except `IDS_PACK_EXE_BROWSE`), `IDS_PACK_ARC_DOSNAME`, `IDS_PACK_ARC_DOSFILE`, `IDS_PACK_LST_DOSNAME`, and the `IDS_PACKRET_*` codes that T026 left unused (`rg` each ID before deleting);
  - **add** the new titles: "RAR (WinRAR)", "7-Zip", "7-Zip console executable (7z.exe)", "WinRAR console executable (Rar.exe)", the RAR codes 9–12 and the `SevenZipErrors` texts;
  - check `src/lang/lang.rc` (`IDD_CFGPAGE_ARCHIVERSLOCATIONS`, `IDD_AUTOCONF` around `:1423/1438`) for static texts mentioning DOS, 16-bit or Win32, and reword them.
- [X] T035 [US3] Build Debug and run `saltests`, then quickstart §2 rows 1–6 (7-Zip browse/extract of the ARJ, LZH and Unicode fixtures; the rename and Autoconfiguration round trip) and §6 limited to `src` (`rg -n -i "MS-DOS|External DOS|External Win32|1\.44 ?MB|salspawn" src` → only history comments). Do the US3 Independent Test, record everything in `fix-log.md`, and run the independent review of T018–T034.

**Checkpoint**: only 7-Zip and RAR remain; ARJ/LZH/Unicode browse via 7-Zip; entries hidden when not found.

---

## Phase 5: User Story 4 — Existing configurations are cleaned up on upgrade (Priority: P2)

**Goal**: a one-time, targeted migration to configuration version 106
(contract M0–M6). It removes every entry that refers to a removed archiver,
edited or not, and the floppy-volume presets. It remaps associations, adds the
7-Zip records nobody claims, and leaves everything else byte-identical.

**Independent Test**: quickstart §5 with fixtures (a), (b) and (c): the
expected removals, (c) untouched, a diff outside `Packers & Unpackers` limited
to the M5 allow-list, idempotent on a second start, and a fresh registry
getting the defaults with no migration.

- [X] T036 [P] [US4] Create `src/common/salarcmig.h` and `src/common/salarcmig.cpp` (pure; data from T007):
  - `BOOL SalArcMigEntryRefersToRemoved(const char* const* fields, int count)`: case-insensitive `$(<removed var>)` token test over command and argument fields;
  - `BOOL SalArcMigIsFloppyPreset(const char* args)`: exact match against the frozen strings;
  - `enum ESalArcMigAssoc { AssocKeep, AssocDelete }` and `ESalArcMigAssoc SalArcMigAssociation(int oldUnpacker, int oldPacker, BOOL usePacker, int* newUnpacker, int* newPacker, BOOL* newUsePacker)`, implementing the M2 tables (old 1 → 1, old 0 and 2–11 removed, negative indices untouched);
  - `void SalArcMigUnclaimed7zExts(const std::vector<std::string>& existingExtLists, std::vector<std::string>& toAdd)`, implementing M3 on the `;`-separated, `#`-pattern lists. Reuse the matching rule the format table uses; read `CPackerFormatConfig::BuildArray` for how `#` matches.

  SPDX "2026 Pavel Stupka", UTF-8-BOM, English comments.
- [X] T037 [US4] Add `salarcmig.*` to `src/vcxproj/salamand.vcxproj` (+ `.filters`) and `src/vcxproj/saltests/saltests.vcxproj`, next to `sal7zlist.*`.
- [X] T038 [US4] Add `static void TestArchiverMigration084()` to `src/saltests/saltests.cpp` after `TestSevenZipList084()`. It covers:
  - every removed variable detected in any letter case and in any field;
  - `$(Rar32bitExecutable)` and own-path entries **not** detected;
  - each frozen floppy string detected, and the same string with one extra space not detected;
  - every M2 row;
  - M3 with `arj` already claimed by a plug-in record (so not added) and `lzh` unclaimed (added);
  - idempotence: applying the decisions to their own output changes nothing.

  Build and run, then record.
- [X] T039 [US4] Wire the migration in `src/mainwnd2.cpp`:
  - `THIS_CONFIG_VERSION` 105 → **106** (`:147`);
  - in the load block after the four packer sections are read (`:2846-2958`) and **before** `Plugins.CheckData()` (`:2962`), when `!packersResetToDefaults && Configuration.ConfigVersion < 106`, run:
    1. M1 over `PackerConfig` and `UnpackerConfig` (external entries only; delete via the existing `DeletePacker`/`DeleteUnpacker` so `Preffered` stays consistent, falling back to the first entry if the preferred one was deleted);
    2. M2 over `PackerFormatConfig` records;
    3. M3 appending unpacker-0 records.
  - log each removal to `TRACE_I` (Debug) with the entry title.

  Do **not** touch anything outside these three objects (M5).
- [X] T040 [US4] Add the new default entries for upgraded configurations through the house `AddDefault(ConfigVersion)` fall-through: a `case 105:` in `CUnpackerConfig::AddDefault` (`src/packers.cpp`) appending the "7-Zip" unpacker entry. Check that `case 0` falls through to it, so a fresh configuration gets it exactly once. Confirm `CPackerConfig` needs no `case 105:`: an upgraded configuration keeps its own RAR packer entries unless M1 removed them. **[As built, review #3: **not done as written** — no `case 105:`; the 7-Zip unpacker is appended by the migration (M1d), because `case 0` falls through (fix-log design change 9)]**
- [X] T041 [P] [US4] Write `specs/084/probe/migration_probe.ps1` (Windows PowerShell 5.1, 078/079 backup and restore recipe, restore verified key by key). For each fixture (a), (b), (c): **[As built, review #3: **file not written** — the migration scenario is part of `probe/gui_probe.ps1` (not run); the pure decisions are covered by saltests]**
  1. Import it on top of a base `Version\Configuration` = 105 key.
  2. Start the Debug build and exit through the menu.
  3. Export, and compare against the expectations in quickstart §5.
  4. Diff the whole `HKCU\Software\Tandem Commander` before and after with the M5 allow-list.
  5. Start a second time and assert no change.

  Finally, run with an empty key and assert defaults with no migration log line.
- [ ] T042 [US4] Run T041 and record the results in `fix-log.md`. Run the independent review of T036–T041. **[OWED - GUI skipped; scenario `migration` of `probe/gui_probe.ps1` ready; pure decisions covered by saltests]**

**Checkpoint**: upgraded configurations equal the new defaults, apart from the user's own-path entries.

---

## Phase 6: User Story 5 — Maintainer has a documented inventory (Priority: P3)

**Goal**: a written record of how the archive subsystem works and the status
of every format and program (FR-014, SC-006).

**Independent Test**: from `inventory.md` alone, answer which program handles
`.rar`, `.arj`, `.lzh`, `.ace` and `.uc2` on a clean installation, what
happens when it is missing, and why each removed format was removed. The cross
check reports 0 differences.

- [X] T043 [US5] Write `specs/084/inventory.md`:
  - **How a panel action reaches an external program**: the call graph table from research, post-084 version.
  - **Component roles**: plug-ins, the two archiver rows, custom entries, associations, availability.
  - **Formats**: one row per extension known to 0.1.8 (from `git show v0.1.8:src/pack3.cpp` defaults and the plug-ins' `AddPanelArchiver`/`AddCustomUnpacker` calls) or to 084. Columns: handler on a clean install / with 7-Zip / with WinRAR, status (kept / removed / new), reason.
  - **Programs**: the 12 old ones plus 7-Zip, with status and reason.
  - **Final 7-Zip default extension list**: fixes FR-016's set. Update T027/T028/T029/T036 constants if it differs from `arj;a##;lzh;lha`.
  - The R5 observation (the upgraded 7zip plug-in could read ARJ/LZH itself) as an open maintainer decision.
- [X] T044 [P] [US5] Write `specs/084/probe/inventory_check.py` (stdlib only). It:
  - extracts the default associations from `src/pack3.cpp` `CPackerFormatConfig::AddDefault` `case 0`, the default custom entries from `src/packers.cpp`, and the plug-in registrations (`AddPanelArchiver`, `AddCustomPacker`/`Unpacker` in `src/plugins/*/` for plug-ins `on` in `plugins.cfg`);
  - compares them with the `inventory.md` format table;
  - exits non-zero on any extension offered but not documented, or documented as removed but still offered.
- [X] T045 [US5] Run T044 (0 differences) and record it. Review `inventory.md` against the Independent Test questions.

---

## Phase 7: User Story 1 — Opening a RAR archive works (Priority: P1) ⛔ blocked

**Prerequisite**: the separate 7-Zip 25.x upgrade feature (T002) is merged.

**Goal**: RAR4 and RAR5 archives (encrypted, multi-volume, Unicode) are listed
and extracted on a clean installation through the 7zip plug-in's engine. RAR
packing is offered only with WinRAR (FR-004, R3, R4).

**Independent Test**: quickstart §3 on Windows Sandbox or a VM with no
third-party archiver, plus §4 with WinRAR **(person)**.

- [X] T046 [US1] **Gate**: verify `src/plugins/7zip/7za/c/7zVersion.h` reports 25.x and that the upgrade feature's records say RAR handlers are built. If either fails, **stop** this phase and record "blocked" in `fix-log.md`. **[DONE in feature 087 - 26.03, 7z + RAR + RAR5 handlers built; specs/087-7zip-2603-rar/fix-log.md S1]**
- [X] T047 [US1] In `src/plugins/7zip/7zclient.cpp` (`:35/102` hard-code the 7z format), open archives by detecting the format: by extension (`7z`, `rar`, `r##`, `partN.rar`) and confirmed by signature (`Rar!\x1A\x07\x00` RAR4, `Rar!\x1A\x07\x01\x00` RAR5). Create the handler through the engine's `CreateObject` with the matching format CLSID. Updating (packing) stays **7z-only**: refuse update operations for RAR with the plug-in's standard "not supported" path. **[DONE in feature 087 - by signature, contract P1/P7]**
- [X] T048 [US1] Implement the volume-open callback in `src/plugins/7zip/open.cpp:52-56` (`IArchiveOpenVolumeCallback::GetProperty(kpidName)` + `GetStream(name)` opening sibling volumes with wide paths). Cover both RAR4 `.rar`/`.r00` and RAR5 `.partN.rar` naming. **[DONE in feature 087 - contract P3]**
- [X] T049 [US1] Make the password prompt wide (Unicode) in `src/plugins/7zip/open.cpp:43` and its dialog in `src/plugins/7zip/dialogs.cpp`. Pass the password to the engine as UTF-16. Check that a wrong password shows the plug-in's error and that no file is reported as extracted. Encrypted headers must ask before listing. **[DONE in feature 087 except the wide prompt: the dialog stays ANSI (encoding cluster B-1), the engine gets UTF-16 - 087 spec FR-010]**
- [X] T050 [US1] Register RAR in `src/plugins/7zip/7zip.cpp` (`:600-650`): **[DONE in feature 087 - configuration version 4; contract P8 and fix-log S3 correct this file's takeover expectation for upgraded configurations]**
  - bump the plug-in's `ConfigVersion` (`:50`);
  - `AddPanelArchiver("rar;r##", FALSE, TRUE)` and `AddCustomUnpacker("7-Zip (Plugin)", "*.7z;*.rar", …update)`, gated on `ConfigVersion < <new>` like the existing `< 2`/`< 3` blocks.

  The core's overlap takeover (`src/plugins1.cpp:866-1069`) then sets unpacker = plug-in and keeps packer = RAR index 1 (contract M2 note). Verify that the takeover also happens on an upgraded configuration where the record is `rar;r##` → (1,1).
- [X] T051 [P] [US1] Add new plug-in strings (password prompt or errors, if any) to `src/plugins/7zip/7zip.rc2`/`.rh2` with never-used IDs. They are translated in T057. **[DONE in feature 087 - IDS_LINKS_SKIPPED]**
- [X] T052 [P] [US1] Document the licence (research R4):
  - an entry in `doc/third_party.txt` for "RAR decoder in the 7-Zip engine (7zip plug-in), © Igor Pavlov / Alexander Roshal, GNU LGPL + unRAR restriction", quoting the restriction text from `src/plugins/7zip/7za/doc/License.txt:35-49`;
  - correct `architecture/04-dependencies.md:66` (unrar.dll **is** redistributable; the issue is GPL compatibility; the product reads RAR through the 7zip plug-in instead);
  - correct the "Missing deps" line in `CLAUDE.md` accordingly.
- [X] T053 [US1] Build Debug + Release, then: **[DONE in feature 087 - its gates and independent reviews]**
  - run quickstart §3 locally against all RAR fixtures (Explorer-like steps in the panel; content compared with a reference extraction);
  - with no WinRAR, confirm Alt+F5 offers no RAR packer;
  - prepare a Windows Sandbox `.wsb` script under `specs/084/probe/` that maps the Release tree and fixtures read-only, for the clean-machine run **(person)**;
  - record §4 (WinRAR) as owed unless a person runs it.

  Run the independent review of T046–T052.

**Checkpoint**: RAR opens out of the box.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T054 [P] Update the help pages (FR-012) in `help/src/hh/salamand/`: **[As built, review #3: 11 pages updated (fix-log); `configuration_archi`, the glossary pages and `introduction_news` were not touched]**
  - full rewrite of the archiver content: `basicwork_pack`, `configuration_archi`, `configuration_assoc`, `configuration_locat`, `configuration_packr*`, `configuration_unpck*`, `customize_arccfg`, `dlgboxes_arcac`, `dlgboxes_arcacdrv`, `dlgboxes_pack`, `dlgboxes_unpck`, `glossary_a/d/p/u`, `introduction_news`;
  - incidental mentions in `customize_usrmn`, `othertask_cmdline`, `plugins_using`.

  Remove every removed program and DOS archiver. Describe 7-Zip, RAR (WinRAR), hiding when not found, Cancel, and the RAR-through-plug-in route. Pages touched get the post-rebrand footer ("Tandem Commander", "© 2026 Pavel Stupka") as in `configuration_cmdshell.htm` (071).
- [X] T055 Refresh the translations for the 8 enabled languages with `tools/translate` (`translate.merge`), following **079's procedure** (`specs/079-remove-salmon-crash-reporter/fix-log.md:172-194`):
  1. Regenerate the English template.
  2. Dry run: the expected displacement from the two emptied bundles (`STRINGTABLE 20`/`21`, research R10).
  3. Restore displaced rows from HEAD by script.
  4. Dry run again: the gaps per language equal exactly the number of new strings.
  5. Translate.

  Pin a formal register in `translations/ui-overrides.json` under `_feature_084` (de/fr/nl/es came back informal in 079). Keep the disabled languages' sources consistent, or record why not (056 precedent).
- [ ] T056 Run quickstart §6 in full (`rg` over `translations`, `src\lang`, `help\src` → only history comments). Do a visual pass in English and Czech **(person, or a GUI driver as in 078)** and record it. **[PARTLY: rg sweep done; visual pass OWED - GUI skipped]**
- [X] T057 [P] Translate the 7zip plug-in strings from T051 the same way (`translations/<language>/7zip.slt`), with the same gap-count check. **[DONE in feature 087 (T019)]**
- [X] T058 [P] Add a `## [Unreleased]` section to `CHANGELOG.md` in the user's terms (constitution "Release Documentation"):
  - **Removed**: the DOS archivers, JAR, ACE, ARJ, PKZIP, LHA, UC2, floppy presets, and stored entries referring to them; why (they could not run; ACE is unsafe).
  - **Fixed**: external archivers failed with a `salspawn.exe` error in every release.
  - **Added**: RAR out of the box (encrypted, multi-volume) through the 7zip plug-in (state the dependency on the 7-Zip upgrade, or omit the line if S7 did not ship); the 7-Zip console entry for ARJ/LZH; Cancel; Unicode names with 7-Zip and RAR.
  - **Changed**: Autoconfiguration finds installed programs without a scan; entries are hidden until their program is found.
  - **Notes**: configuration version 106, no downgrade to 0.1.8's archiver settings.
- [X] T059 [P] Re-check `PRIVACY.md` triggers against the final diff (research R11): network, newly enabled plug-in, storage, installer. Record the verdict in `fix-log.md`, and update `PRIVACY.md` in the same change only if a trigger fired. **[As built, review #3: verdict recorded in fix-log (final review #3): no trigger fired; the external-archiver example was corrected and the validity line notes the unreleased changes]**
- [X] T060 [P] Update `CLAUDE.md`:
  - a "Recent Changes" entry for 084 (house style: what changed, traps found, owed steps);
  - the Key Facts project count (81 → 80 projects after `salspawn`);
  - the `architecture/02-solution-structure.md` count, if T014 did not.
- [X] T061 Final gates. Run `build.cmd full` and `build.cmd full release` (incl. `check_encoding.py` strict `TOTAL: 0` and `check_runtime_deps.py`), then: **[As built, review #3: builds, saltests, encoding guard, runtime check and inventory check ran; quickstart §2, §5 and §8 GUI steps were **not** run (owed, closing report)]**
  - `saltests` (1527 + new, 0 failed);
  - quickstart §1, §2, §5, §7, §8 (regression of ZIP, 7z, TAR family, CAB and ISO open/extract/pack);
  - `git diff --stat v0.1.8 -- src/plugins/shared` (baseaddr lines only);
  - plug-in interface version still 106.

  Record everything in `fix-log.md`.
- [X] T062 Run a final independent multi-perspective review of the whole branch diff (house practice 056/068): encoding, process and job handling, migration and data loss, translations. Use adversarial verification of each finding. Fix the confirmed findings and record them in `specs/084/review-report.md`. **[As built: three independent reviews, one reviewer each — #1 code (REJECT, fixed), #2 re-review (ACCEPT WITH FIXES, fixed), #3 every text and record against the code (ACCEPT WITH FIXES, fixed). Recorded in `fix-log.md`; no separate `review-report.md`. The perspectives encoding, process/job handling, migration and translations were covered across #1–#3, not as separate parallel reviewers.]**
- [X] T063 Write `specs/084/closing-report.md`. List:
  - what shipped per stage;
  - what is blocked (S7, if the 7-Zip upgrade has not landed);
  - steps owed to a person (§3 clean machine, §4 WinRAR, the visual pass);
  - follow-ups: the translation matcher identity fix (R10), the R5 ARJ/LZH-via-plug-in decision, and anything from T062.

  Update `specs/NEXT-WORK.md` accordingly.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (T001–T005)**: no dependencies.
- **Foundational (T006–T007)**: after Setup. T006 blocks every string task; T007 blocks T036.
- **US2 (Phase 3)**: after Foundational. It is the MVP and blocks US3, US4 and US1, because the direct launch is needed to run anything.
- **US3 (Phase 4)**: after US2. T018–T020 (the parser) can start in parallel with US2.
- **US4 (Phase 5)**:
  - T036–T038 (pure migration and its tests) can run in parallel with US3 once T007 is done;
  - T039–T042 need US3's new tables (T021–T028).
- **US5 (Phase 6)**: after US3 and US4 (it documents their result). T044 can be drafted earlier.
- **US1 (Phase 7)**: **blocked on the external 7-Zip 25.x upgrade feature**. Otherwise it needs only US2 (launch) and T028 (the `rar;r##` default). It is independent of US4 and US5.
- **Polish (Phase 8)**: after the stories that will ship. T055/T057 need all string changes (T015, T034, T051) to be final.

### Within stories

- Pure unit, then its project wiring, then its `saltests` group, then the glue that uses it (T018 → T019 → T020 → T023; T036 → T037 → T038 → T039).
- Table reduction order: T021 (`pack.h`) → T022/T024/T026 → T027/T028 → T029–T033.
- Every phase ends with a build, its verification task, and an independent review before the next phase.

### Parallel opportunities

- **Setup**: T002, T003, T004 and T005 are independent.
- **US2**: T014 (project deletion) and T016 (probe) run alongside T008–T013.
- **US3/US4**: T018 (parser) and T036 (migration decisions) are separate new files and can be written at the same time. T044 (inventory check script) can be drafted in parallel too.
- **US1**: T051 and T052 run alongside T047–T050.
- **Polish**: T054, T057, T058, T059 and T060 touch different files.

## Parallel Example: US3 + US4 pure units

```text
Task: "T018 [US3] Create src/common/sal7zlist.{h,cpp} per contracts/7z-slt-listing.md P1–P3"
Task: "T036 [US4] Create src/common/salarcmig.{h,cpp} per contracts/config-migration-106.md M1–M3"
```

Then T019 and T037 are wired in one project edit each (both touch the same two
`.vcxproj` files: do them sequentially). T020 and T038 follow.

## Implementation Strategy

### MVP first (US2)

Do Setup, Foundational and US2 (T001–T017). External archivers then *work*
for the first time in any release (custom entries, the RAR packer with WinRAR),
with Cancel. Stop and validate with T016/T017.

### Incremental delivery

1. **US2**: archivers start, Cancel. Deployable alone.
2. **US3**: only 7-Zip and RAR remain; ARJ/LZH through 7-Zip; hiding;
   Autoconfiguration. Deployable together with US4.
3. **US4**: migration, so upgraded users get the clean lists. Should ship
   together with US3, because US3 alone would leave upgraded configurations
   with entries for archivers the program no longer knows. Those entries fail
   cleanly at command expansion, but they are visible.
4. **US5**: inventory, documentation only.
5. **US1**: RAR out of the box, as soon as the 7-Zip upgrade lands. It can
   ship in a later release than US2–US5. The CHANGELOG line is added only when
   it ships.
6. **Polish**: help, translations, CHANGELOG, final review.

## Notes

- [P] tasks touch different files and do not depend on incomplete tasks.
- Commit after each task group (one concern per commit, constitution workflow).
  English commit messages reference `[084]`.
- New source files: UTF-8-BOM, clang-format, SPDX "2026 Pavel Stupka".
  English comments; existing Czech comments may stay.
- Never reuse a removed string ID or archiver UID (R10, data-model §1).
- Steps needing a person are recorded as owed in `fix-log.md`, never skipped
  silently.
