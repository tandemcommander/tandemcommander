# Research: Working Archivers Only (feature 084)

Phase 0 of [plan.md](plan.md). Three independent read-only investigations were
run on 2026-10-01: RAR options and licensing, the external-archiver invocation
path, and configuration persistence and migration. Every claim below carries a
source reference. Inference is marked **[I]**.

## Verified baseline (what 0.1.8 does today)

- **External archivers never start.** Every external operation runs
  `utils\salspawn.exe`, and the helper runs the archiver: the path is built in
  `InitSpawnName` (`src/pack3.cpp:357`), the listing call is at
  `src/pack1.cpp:644`/`722`, and execution is in `PackExecute`
  (`src/pack3.cpp:1720`/`1766`). The helper project builds only in the
  `Utils (Release)` solution configuration (`salamand.sln:855-862`, with no
  `Build.0` for Debug/Release) and writes to `plugins\Intermediate\salspawn\`
  (`salspawn_base.props`). It has never been in an output tree or an
  installer.
- **Call graph.** Enter on an archive leads to `PackList` (`pack1.cpp:596`).
  F5 out of an archive, view and execute lead to `PackUncompress` /
  `PackUnpackOneFile` (`pack1.cpp:1376/1823`). F5 into an archive, delete and
  repack lead to `PackCompress` / `PackDelFromArc` (`pack2.cpp:129/603`).
  Alt+F5 / Alt+F9 lead to `CPackerConfig::ExecutePacker` /
  `CUnpackerConfig::ExecuteUnpacker` (`packers.cpp:781/1421`). Everything except
  listing goes through `PackExecute`.
- **Cancel does not exist.** The run shows a button-less modal
  `CExecuteWindow` (`pack3.cpp:39`/`1782`), and the archiver's console is
  restored only after 15 s (`PackWinTimeout`, `pack3.cpp:63`). Listing does a
  blocking `ReadFile` on the UI thread with no timeout (`pack1.cpp:740-780`).
- **Unicode is lost on the external path.** List files are written as OEM
  (`SalU8ToOEM`, with `CharToOem` as fallback; `pack1.cpp:1527-1543`,
  `pack2.cpp:329-371`). Pipe output is decoded OEM to ACP (`pack1.cpp:298-319`).
  A name outside the code page, such as `中文.txt`, becomes `__.txt`; verified
  with 7-Zip 22.01. Names from an external listing are then ACP bytes, which
  `SalCreateProcess` (UTF-8 contract, `common/salfileio.cpp:120`) refuses
  **[I]**.
- **DOS machinery.** It consists of:
  - `DOS_MAX_PATH`, the 128-character command-line checks when
    `!SupportLongNames` (`pack1.cpp:679/1586/1886`, `pack2.cpp:439/769`);
  - the `$(ArchiveDOSFullName)`, `$(ArchiveDOSFileName)`, `$(TargetDOSPath)`
    and `$(ListDOSFullName)` variables (`pack3.cpp:255-258`, expanders
    `:1216/1326/1369/1395`);
  - `PackExpExeName`, which always uses the 8.3 form of the archiver path
    (`pack3.cpp:1422`);
  - the DOS temporary-name rename (`pack2.cpp:413/495`);
  - the `RAR5AndLater` column patching and the ARJ16/ARJ32 hacks
    (`pack1.cpp:895-991`), and `PackUC2List` (`pack1.cpp:1021`).
- **Persistence.** Configuration lives in
  `HKCU\…\0.1\Packers & Unpackers\{Custom Packers, Custom Unpackers, Predefined
  Packers, Archive Association}`:
  - Save and load are at `mainwnd2.cpp:1439-1555/2836-2958`.
  - `Predefined Packers` rows are matched by `Packer UID` (`pack.h:419-430`).
    Unknown UIDs are ignored on load (`pack3.cpp:1019-1031`).
  - `Archive Association` stores **positional** packer/unpacker indices. A
    value ≥ 0 indexes `ArchiverConfig`, `PackBrowseTable`, `PackModifyTable`,
    `CustomPackers`, `CustomUnpackers` and `PackACExtensions` all at once.
  - The same numbering is hard-coded in `PACK*INDEX` (`pack.h:24-35`) and in
    `externalArchivers[]` (`plugins2.cpp:2593-2616`).
- **Configuration version.** `THIS_CONFIG_VERSION = 105` (`mainwnd2.cpp:147`).
  The only Tandem-era bump (104→105, feature 010) reset the packer sections
  wholesale. Feature 016 showed that this destroyed plug-in associations
  (`specs/016-…/research.md` R2).
- **Plug-in ABI.** Nothing in `src/plugins/shared/` exposes `PACK_EXE_*`,
  `Pack*` functions or the positional indices. Plug-ins use only
  `AddCustomPacker/Unpacker`, `AddPanelArchiver`, `ForceRemovePanelArchiver`,
  `ChangePanelPathToArchive`, `IsArchiveHandledByThisPlugin` and
  `SALCFG_ARC*` (`spl_base.h:256-280`, `spl_gen.h`). Plug-in entries are
  negative indices.

## R1 — How external archivers are started

**Decision**: remove `salspawn` (project, sources, solution and filter
entries) and start the archiver directly with `SalCreateProcess`. Each run is
placed in a **job object** with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. The
launcher returns the archiver's real exit code and the real `CreateProcess`
error. All four `SPAWN_ERR_BASE` decoding blocks (`pack1.cpp:826-849`,
`pack3.cpp:1916-1939`) and `SPAWN_EXE_*` / `SpawnExe` / `InitSpawnName` go.

**Rationale**:
- The helper does nothing the product needs. It ignores console control
  events, starts the archiver in a new process group, waits and passes back the
  exit code. It has no 16-bit-specific logic (`salspawn.cpp:20-37`).
- Starting the archiver directly removes a missing component (FR-001) and makes
  the reported error name the real program (FR-005).
- It stops exit codes ≥ 10000 from a real archiver being misread as helper
  errors.
- The job object is what makes Cancel able to end the archiver *and* its
  children (FR-006).

**Alternatives considered**:
- *Build and ship `salspawn.exe` in `utils\`.* This fixes FR-001 only. It keeps
  an extra process that antivirus engines might flag (compare `salmon.exe`,
  feature 079), keeps the error-code multiplexing, and still gives no cancel.
  Rejected.
- *Keep Ctrl+C isolation by starting with `CREATE_NEW_PROCESS_GROUP`.* Kept as
  a flag on the direct launch. It is free and preserves the one useful property
  of the helper. The console window policy (hidden for listing, minimized then
  restored for packing so the user can answer an archiver prompt) is unchanged.

## R2 — Cancel and the non-blocking wait

**Decision**:
- **One waiter for both kinds of run.** Both the listing run (piped) and the
  execution run use the same wait loop. A worker thread reads the pipe, or the
  process handle is simply waited on, while the UI thread shows a modal wait
  window with a **Cancel** button.
- **What Cancel does.** It calls `TerminateJobObject` and reports "cancelled",
  which is not an error. The partially written target is reported as
  incomplete, never as complete.
- **The window.** `CExecuteWindow` is extended in place, not replaced (UI
  consistency, constitution VI): a standard push button and the existing
  caption palette. A listing run keeps its 990-character line cap and gains a
  defined failure for an over-long line.

**Rationale**: FR-006 and the edge case "the archiver waits for keyboard input"
call for this. Today an unanswered prompt during listing hangs the UI thread
forever, because stdin is NULL and `ReadFile` blocks.

**Alternatives considered**: *a timeout without Cancel* was rejected, because a
large archive legitimately takes minutes. *Moving the archive subsystem to a
background operation* was rejected as out of scope (constitution III).

## R3 — How RAR opens out of the box

**Decision**: RAR is read by the **7zip plug-in** through its in-tree,
source-built engine, which already contains 7-Zip's RAR and RAR5 handlers,
decoders and RAR crypto (`7za.dll.vcxproj:263-265/451-461/489-493`). An
enumeration of the installed 0.1.8 `7za.dll` shows formats `Rar5` and `Rar`
among 53. **Precondition**: a separate, earlier feature upgrades the vendored
7-Zip 16.04 (`7za/c/7zVersion.h:4`) to 25.x. That feature is a dependency,
not part of 084 (maintainer decision 2026-10-01). Once it is in, 084 adds:

- RAR detection and opening in the plug-in (`7zclient.cpp:35/102` hard-code
  the 7z format), with `AddPanelArchiver("rar;r##")` and a "7-Zip (Plugin)"
  custom unpacker entry for `*.rar`, gated by the plug-in's `ConfigVersion`;
- the volume-open callback (empty stub at `open.cpp:52-56`), needed for
  multi-volume sets;
- a wide (Unicode) password prompt (ANSI at `open.cpp:43`);
- the association split for `rar;r##`: unpacker = 7zip plug-in, packer =
  external RAR (index 1) only while WinRAR is found (FR-017).

**Evidence**: libarchive's RAR test archives, run through the shipped engine
under 7-Zip 22.01:

| Case | Result |
|---|---|
| RAR4, RAR5 | OK |
| Encrypted data, RAR4 / RAR5 | OK |
| Encrypted headers, RAR4 / RAR5 | OK |
| Japanese and emoji names | OK |
| RAR5 8-volume set | OK |
| RAR4 4-volume set | OK |

The files are in the session scratchpad (`rar\`); the plan copies the needed
ones into `specs/084-…/probe/fixtures/` (see quickstart).

**Rationale**: it is the only option that satisfies every SC-004 case (RAR4 +
RAR5, encrypted, multi-volume, non-ASCII). It needs no RARLAB binary download,
no signing exemption and no new licence class. The code is already in the
shipped binary.

**Alternatives considered**:
- *Enable the `unrar` plug-in with RARLAB's `unrar.dll`.* The plug-in expects
  a file literally named `unrar.dll` (`unrar.cpp:944-946`), while RARLAB's x64
  build is `UnRAR64.dll` **[I]**. Its callback handles only the ANSI
  volume and password messages (`unrar.cpp:987-999`). The binary is downloaded,
  not built. And the GPL-incompatibility argument is stronger for it.
  Rejected.
- *Windows `tar.exe` (libarchive 3.8.8)*, tested: encrypted entries fail
  ("RAR encryption support unavailable"), and with unencrypted headers it
  leaves corrupt files behind. Unicode names give "unreadable filename" (0
  files from RAR5). It reads only the named volume. Rejected.
- *Vendoring libarchive*: it has no RAR decryption by design. Rejected.
- *Exposing RAR on the 16.04 engine*: this would make CVE-2018-10115 (RCE in
  the RAR handler, fixed in 18.05) and CVE-2025-53816 (RAR5 heap overflow,
  fixed in 25.00) reachable from any downloaded `.rar`. Rejected; this is why
  the upgrade is a precondition.

## R4 — Licence

**Decision**: the maintainer accepts (2026-10-01) shipping and exposing
7-Zip's RAR code, which is licensed "GNU LGPL + unRAR restriction"
(`src/plugins/7zip/7za/doc/License.txt:10-11/35-49`), in the GPL-2.0-or-later
product. 084 records it in three places:

- `doc/third_party.txt` gets an entry for the RAR code inside the 7-Zip engine
  with the restriction text. Today `:31-33` credits Roshal only for the unused
  UnRAR plug-in.
- `architecture/04-dependencies.md:66` and the CLAUDE.md "Missing deps" line
  are corrected. The UnRAR licence *permits* redistribution (clause 3,
  <https://spdx.org/licenses/UnRAR.html>); the actual issue is GPL
  compatibility (Fedora: "GPL-incompatible and non-free",
  <https://fedoraproject.org/wiki/Licensing:Unrar>).
- `CHANGELOG.md` mentions it.

**Rationale**: the exposure already exists since 0.1.0. The choice is between
documenting it and silently carrying it. This is not legal advice. The risk
assessment (medium for shipping `unrar.dll`, lower for the 7-Zip code) is the
research agent's reading, not a legal opinion.

**Alternative considered**: removing the RAR code from the engine. That forgoes
encrypted RAR out of the box, which contradicts the spec decision. The
maintainer declined it.

## R5 — The 7-Zip console entry (browse and unpack)

**Decision**:
- **Browse.** Listing runs `7z l -slt -sccUTF-8 -scsUTF-8 -- "<archive>"` and is
  parsed by a **new pure parser** (`src/common/sal7zlist.*`) plugged into the
  existing `FPackList SpecialList` hook, so the browse table needs no change.
  `-slt` gives key = value records (`Path`, `Size`, `Packed Size`,
  `Modified = YYYY-MM-DD hh:mm:ss[.fffffff]`, `Attributes`, `Folder`,
  `Encrypted`) separated by blank lines after a `----------` line. Lines end
  in LF.
- **Extract selected**: `7z x -y -sccUTF-8 -scsUTF-8 "<archive>"
  -o"<target>" @"<list>"`, with a **UTF-8 + BOM** list file. Verified with
  non-ASCII names and spaces.
- **Extract one**: `7z e` with the same switches.
- **No modify operations** and no default packer (clarification Q2).
- **Exit codes.** 0 is OK. 1 is a warning. 2 is a fatal error (including "Is
  not archive"). 7 is a bad command line, 8 is out of memory, 255 is a user
  stop. With stdin at EOF, encrypted headers end with 255 and no hang (verified).
- **Default extensions.** Formats no default-enabled plug-in handles and 7-Zip
  reads, minimum `arj;a##` and `lzh;lha`. The final list is fixed in
  `inventory.md` (FR-014/FR-016).
- **Password-protected archives.** Through the 7-Zip *console* they are
  reported as an error naming 7-Zip. Interactive password entry through a
  console program is out of scope, because the RAR path covers encrypted RAR.

**Rationale**:
- The column parser fails on 7-Zip's plain `l` output: the *Compressed* column
  is blank for members of a solid block, which shifts field counts (verified).
- `-slt` is stable across 7-Zip versions **[I]**.
- `-scc/-scs UTF-8` is the only way names outside the code page survive.
- A pure parser can be unit-tested in `saltests` (house pattern: `salshell`
  071, `saltabs` 078, `salcloseapp` 080).

**Observation for the maintainer (not acted on)**: after the 7-Zip upgrade the
shipped engine also reads ARJ, LZH, CAB, ISO and others. The 7zip plug-in could
therefore handle ARJ/LZH out of the box without the user installing 7-Zip,
which would make the console entry nearly redundant. Clarification Q2 chose the
console entry. Revisiting that is a separate decision, recorded in
`inventory.md`.

## R6 — The RAR packer (WinRAR console)

> **Partly superseded (final review #3)**: the switches below were replaced
> during implementation — the list file is UTF-16LE with a BOM read with
> `-scul` (R7a), so `-scfl` is not used; built: `a/m/d -scul -idq -y …
> @"$(ListUnicodeFullName)"` (`inventory.md` §4). Code 255 maps to
> `IDS_PACKRET_STOPPED`. Everything else in R6 stands.

**Decision**: one default external packer, "RAR (WinRAR)", with these
commands:

- **Add**: `rar a -scfl -idq -y "<archive>" @"<list>"`.
- **Move**: `rar m …`.
- **Delete**: `rar d -scfl …`.
- The list file is UTF-8 without a BOM, read with `-scfl` **[I]** (manual 6.02
  plus a 7.01 snippet; to verify with WinRAR 7.x).
- The browse row for RAR has no list command, because browsing is done by the
  plug-in.
- `RARErrors` gains codes 9 (create error), 10 (no files), 11 (wrong password)
  and 12 (read error).
- The text for 255 no longer mentions `salspawn.exe` (`texts.rc2:1053`).
- The "1.44MB volumes" preset is not recreated.
- `UID 2`, archiver index 1 and the `Rar32bitExecutable` variable name are kept.
  That keeps every `rar;r##` association valid without remapping, and keeps the
  stored path. The user-visible label becomes "RAR (WinRAR)".

**Rationale**: FR-003/FR-004. Keeping index and UID means old associations
stay correct without a translation table.

**Not verified**: `HKLM\SOFTWARE\WinRAR` value `exe64`, because WinRAR is not
installed on the research machine. Autoconfiguration (R8) also probes
`%ProgramFiles%\WinRAR\Rar.exe` directly, so the result does not depend on the
key.

## R7 — Encoding on the external path

> **Superseded by R7a** for the mechanism (a list-file variable and UTF-16
> list files instead of a row property and UTF-8 list files). The goal and the
> custom-entry rule stand.

**Decision**: each browse/modify table row gains a "UTF-8 I/O" property:

- **Kept rows (7-Zip, RAR)** write the list file as UTF-8 (7-Zip with a BOM,
  RAR as `-scfl` expects) and decode pipe output as UTF-8 into the panel's
  UTF-8 names. No OEM or ACP step.
- **Custom entries** keep today's OEM/ANSI behaviour unchanged, selected by
  their own *Need ANSI list* flag (FR-008).

**Rationale**: names outside the code page must survive, as in the edge case
"characters outside the system code page". The 069 note at
`pack1.cpp:298-319` explains why the generic path is ACP, so changing it for
custom entries would be a behaviour change nobody asked for.

### R7a — Amendment during implementation (2026-10-01): a list-file *variable*, UTF-16

Two facts found while implementing T006/T007 change the mechanism of R7. The
goal is unchanged.

1. **Custom entries need it too, and have no third encoding.** The default
   "RAR (WinRAR)" Alt+F5 packer and the "7-Zip" Alt+F9 unpacker are *custom
   entries*, not table rows. Their list-file encoding is today chosen only by
   the stored *Need ANSI list* flag: OEM or ANSI. A row flag cannot reach them.
2. **7-Zip 22.01 rejects 4-byte UTF-8 sequences in a list file** (emoji:
   "Incorrect item in listfile", exit 7, with or without a BOM, verified). A
   **UTF-16LE list file with a BOM** read with `-scsUTF-16LE` extracted all
   four test names, including the emoji (verified). RAR reads a UTF-16 list
   file with a BOM without any switch (manual). UTF-16 can also carry the
   lone-surrogate names of feature 066 (WTF-8 → UTF-16 via `SalU8ToW`). A UTF-8
   list cannot.

**Decision**: a new list-file variable, **`$(ListUnicodeFullName)`** ("Full Name
of List of Files (Unicode)"), in the house pattern of `$(ListDOSFullName)`.

- A command that references it gets its list file written as **UTF-16LE with
  a BOM**. The command template, not a stored flag, chooses the encoding, so no
  new registry value and no new checkbox are needed.
- Existing entries never reference it, so their behaviour is unchanged
  (FR-008).
- The kept table rows and the new default entries use it: 7-Zip with
  `-scsUTF-16LE`, RAR with `-scul`.
- The row-level "UTF-8 I/O" property shrinks to **pipe output decoding only**
  (7-Zip `-sccUTF-8` listing).

## R8 — "Found" state, hiding and Autoconfiguration

**Decision**:

- **Availability.** A per-archiver cached flag, true when the configured
  executable exists. It is recomputed at configuration load, after
  Autoconfiguration, and after the configuration dialog's OK. It is never
  checked per file: `PackIsArchive` is on the refresh hot path, at more than
  20 call sites.
- **Hiding (FR-017)** is applied in two places:
  1. In the global `PackerFormatConfig.BuildArray`, an association whose
     external unpacker is unavailable is skipped. One whose external packer is
     unavailable is built without packing.
  2. In the Pack and Unpack dialog combo boxes, which move from
     position = index to item-data mapping (`dialogs3.cpp:1887-1920/2128-2156`,
     `fileswn7.cpp:1439-1463/1727`).

  The configuration pages keep showing everything, so the user can still set a
  path.
- **Autoconfiguration (FR-009).** It looks in a fixed order:
  1. **Registry**: `HKLM` and `HKCU` `SOFTWARE\7-Zip` (`Path64`, then `Path`;
     verified present on this machine), and `HKLM\SOFTWARE\WinRAR` (`exe64`,
     then `exe32`; unverified).
  2. **Known folders**: `%ProgramFiles%\7-Zip\7z.exe`,
     `%ProgramFiles%\WinRAR\Rar.exe`, plus the `(x86)` variants.
  3. **The existing optional drive scan**, now restricted to `7z.exe` and
     `rar.exe`, accepting only 32-bit or 64-bit PE images (`MyGetBinaryType`).

  `SPackLocation` (`pack.h:51`), declared but unused, is deleted.

**Rationale**: keeps the hot path cheap and limits UI change to the two dialogs
that list entries. Users find installed programs without a full-disk scan.

## R9 — Configuration migration (THIS_CONFIG_VERSION 105 → 106)

**Decision**: a **targeted, in-place** migration runs in the configuration load
block when `!packersResetToDefaults && ConfigVersion < 106`. It runs after the
four packer sections are read and **before** `Plugins.CheckData()`
(`mainwnd2.cpp:2961`), so `CheckData` sees consistent indices. The decisions
are pure functions in `src/common/salarcmig.*`, unit-tested. The rules are in
[contracts/config-migration-106.md](contracts/config-migration-106.md). In
short:

1. Delete every external custom packer or unpacker whose command or arguments
   contain a **removed archiver variable** (case-insensitive token match, the
   same rule as `salamdr2.cpp:865`). Also delete those whose arguments equal a
   former **floppy-volume** default (`-v1440`, `-pav1440`; `packers.cpp:56-105`).
   That is the spec gap the research found: the RAR volume preset uses the
   *kept* RAR variable. `DeletePacker` keeps `Preffered` consistent
   (`packers.cpp:706`).
2. Remap association indices through a fixed old→new table. Old 1 (RAR) maps
   to new 1; every other old external index is *removed*. A removed unpacker
   deletes the record; a removed packer only clears packing. Plug-in
   (negative) indices are untouched.
3. Append 7-Zip associations for the default extensions **no record claims**.
4. `Predefined Packers` needs no code: rows with removed UIDs are ignored on
   load and drop out at the next save (`pack3.cpp:1019-1031`).

**New archiver table order**: index 0 = 7-Zip (new UID 13), index 1 = RAR
(UID 2). RAR keeps its index, so old `rar;r##` records stay valid.

**Rationale**: the targeted approach preserves plug-in associations (the
feature-016 lesson). The bump is the house's version-gate mechanism, and doing
it before `CheckData` avoids its out-of-range cleanup making the decisions
instead of the migration.

**Side effects of the bump** must be excluded from the SC-005 comparison. They
are all pre-existing behaviour of any bump:

- `Version\Configuration` changes;
- `AutoInstallStdPluginsDir` re-runs;
- `LastPluginVer` and `LastPluginVerOP` are reset;
- `ShowSLGIncomplete` returns to TRUE (`salamdr1.cpp:4543-4553`,
  `mainwnd2.cpp:3409`).

**Downgrade**: not supported. 0.1.8 reading a 106 configuration would see
index 0 as JAR for the 7-Zip records. That affects only those records and fails
as "cannot start". Documented in the changelog.

**Alternatives considered**: *reset to defaults* (feature 010 style) was
rejected because it destroys plug-in associations (016 R2). *No bump, detecting
removed variables at every load* was rejected: the cleanup has to happen once
and be saved, and a per-load scan would also delete entries a user deliberately
re-creates later.

## R10 — Strings and translations

**Decision**:

- **Deleted** IDs (≈72, from the configuration research §5): `IDS_DP_*`,
  `IDS_DU_*`, `IDS_EXT_*`, `IDS_PACK_EXE_*` (except `_BROWSE`),
  `IDS_PACK_ARC_DOS*` and `IDS_PACK_LST_DOSNAME` (menu items only — the
  variables keep expanding, FR-008), `IDS_PACKRET_SPAWN`, `IDS_PACKRET_XMSMEM`,
  `IDS_PACKRET_CHAPTERS`, `IDS_PACKRET_EXTRACT_LHA`, and the return codes only
  removed error tables use.
- **Reworded** IDs get **new, never-used IDs**: `IDS_PACKERR_PROCESS`, which
  stops pointing to Autoconfiguration (FR-005), and `IDS_PACKRET_BREAK2`. The
  merge tool matches rows by `(section, id)` and never by English text
  (`tools/translate/match.py:48-52`), so a reworded text under an old ID would
  keep its stale translation.
- **New** strings ("RAR (WinRAR)", "7-Zip", "Cancel"-state texts, new
  Autoconfiguration descriptions) also get never-used IDs.
- **Translation refresh.** Deleting the IDs empties two whole 16-ID bundles
  (`STRINGTABLE 20`/`21`, simulated against Czech), which shifts the section
  numbers of every later bundle: the feature-079 incident. The refresh
  therefore follows 079's proven procedure (`specs/079-…/fix-log.md:172-194`):
  regenerate, restore displaced rows from HEAD by script, and check that the
  dry run reports exactly as many gaps as strings actually added, per language.
- Formal register pins go in `ui-overrides.json` under `_feature_084`.

**Rationale**: FR-013. This is the second occurrence of the bundle-ordinal
defect. Fixing the matcher is recommended as a follow-up and recorded in
`fix-log.md`, but stays out of scope here (constitution III, one concern).

## R11 — What else changes and what does not

- **Removed code** (FR-003, clarification Q1): browse and modify rows and error
  tables for JAR, ARJ, ACE, LHA, UC2, PKZIP and all DOS rows; `PackUC2List`;
  the ARJ hacks; `RAR5AndLater` patching (RAR is no longer listed by
  `rar.exe`); `PACK*INDEX`; the 13 `PACK_EXE_*` variables except
  `Rar32bitExecutable` and the new `SevenZipExecutable`; the `PACK_EXE_*`
  entries in `CmdCustomPackers`; `PackConversionTable` rows; `CustomOrder`
  rows; the DOS-temporary-name rename. `externalArchivers[]`
  (`plugins2.cpp:2593`) is rewritten for the new indices.
- **Kept** (FR-008): expansion of the `*DOS*` variables and the short-name
  conversion for **custom** entries, and the custom-entry flags *Support long
  names* / *Need list of files in ANSI charset*. Their labels mention neither
  DOS nor Win32 (`lang.rc:1066-1090`), so SC-002 holds.
- **Unchanged**: the plug-in interface, version 106 (FR-011). The zip, 7zip
  (except the RAR exposure), tar, uncab and uniso plug-ins (FR-010). The
  `unrar` plug-in stays `off`.
- **Help** (FR-012): the pages that change are basicwork_pack,
  configuration_archi, configuration_assoc, configuration_locat,
  configuration_packr\*, configuration_unpck\*, customize_arccfg,
  dlgboxes_arcac, dlgboxes_arcacdrv, dlgboxes_pack, dlgboxes_unpck,
  glossary_a/d/p/u, introduction_news (`help/src/hh/salamand/`). Incidental
  mentions are in customize_usrmn, othertask_cmdline and plugins_using.
- **`PRIVACY.md`** (FR-015): no trigger. There is no network change, no
  newly enabled plug-in (RAR goes through the already-enabled 7zip plug-in), no
  change to what is stored (archiver paths were stored before), and no
  installer change. The validity line still moves with the release, as on every
  release. This must be re-checked at the end in case the scope changed.
- **Build**: `salspawn` leaves `salamand.sln` and the generated filter.
  `build.cmd` gets no stale-output cleanup, because `utils\salspawn.exe` never
  existed in an output tree (verified in the local Release tree).
