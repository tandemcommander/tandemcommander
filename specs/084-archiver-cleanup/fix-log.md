# Fix Log: Working Archivers Only (feature 084)

Running record, one dated entry per task group. Verdicts of the independent
reviews are recorded with the group they reviewed.

## 2026-10-01 — Setup (T001–T005)

### T001 Baseline

- HEAD `83038b0f` ("[083] Privacy statement for the winget catalogue"), branch
  `084-archiver-cleanup`.
- `build.cmd full` (Debug x64) on HEAD: OK. 20 plug-ins registered,
  189 language modules. Output `build\tandemcommander\Debug_x64\`
  (`OPENSAL_BUILD_DIR` unset, so the default `.\build\` applies).
- `saltests.exe`: **1527 checks, 0 failed**.
- `Debug_x64\utils\` contains `sqlite.*` only. **No `salspawn.exe`**,
  confirming research finding 1: the helper is not produced by the normal
  build.
- `git grep -i -E "salspawn|MS-DOS|External DOS|External Win32|1\.44 ?MB"`:
  src 116 lines, help 20, translations 171.
- `THIS_CONFIG_VERSION` = 105 (`src/mainwnd2.cpp:147`).
- Trap: `cmd /c "build.cmd …"` launched from PowerShell reports "'build.cmd'
  is not recognized". The script has to be called by its full path.

### T002

`specs/NEXT-WORK.md` gained item 8: "Upgrade the vendored 7-Zip 16.04 → 25.x".
It is the prerequisite of stage S7, with the CVEs and the licence decision.

### T003 / T004 Fixtures

All under `probe/fixtures/`; see its `README.md`.

- **RAR**: the 22 libarchive RAR test archives used by the research agent,
  plus `damaged_rar5.rar` (16 bytes XOR-ed in the middle of
  `test_read_format_rar5_compressed.rar`).
- **LZH**: six libarchive LZH tests, decoded from `.uu`. They include
  `filename_utf16` (Unicode names) and `filename_cp932`.
- **ARJ**: libarchive has **no ARJ test data** and 7-Zip cannot create ARJ.
  `probe/make_arj.py` therefore writes a stored-method ARJ directly:
  `fixtures/arj/sample.arj`, with an ASCII name, a CP852 Czech name, a
  sub-directory with a space, and an empty file. `7z t` reports "Everything is
  Ok"; `7z l -slt -sccUTF-8` returns the Czech name as correct UTF-8 (bytes
  checked with `od`).
- **7z**: `fixtures/7z/unicode.7z` (solid) holds Czech, Chinese and emoji
  names, an empty file and a `sub dir`. The members of the solid block have an
  **empty `Packed Size =`**, the case the parser must accept.
- **`-slt` captures**: `fixtures/slt/*.txt`, raw UTF-8, from 7-Zip **22.01
  x64**. Observation for the parser: the archive-properties block before the
  `----------` separator also has a `Path =` line (the archive's own absolute
  path). The parser must start items only after the separator.

### T005 — deferred

`probe/make_cfg_fixtures.ps1` is written: back up `HKCU\Software\Tandem
Commander`, run 0.1.8 on a fresh key, export, restore, and verify the restore
value by value. It refused to run because the maintainer's own
`tandemcommander.exe` (0.1.8, PID 19184) was running. The probe never touches a
process it did not start, and a concurrent instance would also write the key.
Deferred to the batched GUI session. Fixtures (b) and (c) are derived from (a)
by text edits once (a) exists.

## 2026-10-01 — Foundational (T006, T007)

### T006 String IDs

Every new or reworded text gets an ID that has never existed. Checked with
`git log -G '\b<id>\b' -- src/texts.rh2 src/lang/texts.rc2` and a search of
`translations/*/salamand.slt`.

- **11120–11151** (two whole 16-ID bundles): never used. They hold the texts
  shown as arguments, not through the error handler:

  | ID | Name |
  |---|---|
  | 11122 | `IDS_PACKRET_STOPPED` |
  | 11124 | `IDS_DP_RAR_WINRAR` "RAR (WinRAR)" |
  | 11125 | `IDS_DU_7ZIP` "7-Zip" |
  | 11126 | `IDS_EXT_7ZIP` |
  | 11127 | `IDS_EXT_RAR` |
  | 11128 | `IDS_PACK_EXE_7ZIP` |
  | 11129 | `IDS_PACK_EXE_RAR` |
  | 11130–11133 | the RAR exit codes 9–12 |
  | 11134 | `IDS_PACK_LST_UNINAME` |

- **11072–11087**: also never used. They hold the three messages shown through
  `PackErrorHandler`: `IDS_PACKERR_STARTFAIL` 11072, `IDS_PACKERR_EXEMISSING`
  11073, `IDS_PACKERR_CANCELLED_ARC` 11074.
- **Trap found here**: `PackErrorHandler` (`salamdr1.cpp:3146`) shows every ID
  `>= IDS_PACKQRY_PREFIX` (11101) as an **OK/Cancel question**, not an error.
  The first allocation put the error messages at 11120+, which would have turned
  them into questions. Recorded in a `texts.rh2` comment.
- `IDS_BUTTON_CANCEL` (10841, "Cancel") is reused for the new button, so no new
  caption string is needed.

### T007 Migration constants

The 0.1.8 data is frozen into `src/common/salarcmig.cpp` from
`git show v0.1.8:src/packers.cpp`:

- the 12 removed `$(…Executable)` variables;
- the 14 floppy-volume argument strings;
- the RAR default packer and unpacker arguments, in both forms: with `-scol`
  (0.1.8) and without (pre-RAR-5).

**Finding**: the 0.1.8 default RAR packer and unpacker carry stored titles such
as "RAR (External Win32, tested with v2.50)", user-visible in the Pack dialog
and forbidden by SC-002, and OEM list files. The migration therefore gains two
rules beyond contract M1 (the contract is amended):

- the untouched default RAR packer becomes the new default ("RAR (WinRAR)",
  UTF-16 list);
- the untouched default RAR unpacker is removed, because RAR is unpacked by the
  7zip plug-in.

User-edited RAR entries are kept byte for byte.

## 2026-10-01 — Implementation of stages S1–S5 (T008–T040)

### Design changes found while implementing (research and contracts amended)

1. **List-file encoding is chosen by a variable, not a row flag.** See research
   R7a: `$(ListUnicodeFullName)` gives a UTF-16LE list file with a BOM.
   - 7-Zip 22.01 rejects 4-byte UTF-8 (emoji) in a UTF-8 list file but accepts
     UTF-16LE with `-scsUTF-16LE`. Both were verified with the fixtures.
   - The default entries are custom entries and could not see a row flag.
2. **The OEM column parser is deleted outright.** `PackGetField`,
   `PackScanLine`, `PackUC2List`, the ARJ hacks and `RAR5AndLater` all go.
   - After 084 the only browse row is 7-Zip, with its own UTF-8 parser.
   - `FPackList` now receives the whole output, so the feature-069 F-P1-05 note
     ("the listing must stay in one encoding") is satisfied by construction:
     a 7-Zip listing is UTF-8 end to end.
3. **`*.*` becomes `*` in a Unicode list.** 7-Zip reads `*.*` as "names with a
   dot", while the Unpack dialog's default mask is `*.*`.
4. **Runner without a thread.** `PackRunArchiver` drains the pipe with
   `PeekNamedPipe` inside the existing `MsgWaitForMultipleObjects` loop, which
   is 50 ms during a listing.
   - The listing's wait window appears only after 500 ms.
   - The main window is disabled for the whole run, as `PackExecute` always did.
     Disabling it is also what makes pumping messages during a listing safe.
5. **Cancel.** `CExecuteWindow` gains a push button. A cancelled run is silent;
   only after packing or deleting does the user get the message that the
   archive may be incomplete. Contract C3's "closing the main window behaves
   like Cancel" is moot, because the main window is disabled during a run.
   Kill-on-close covers the process ending.
6. **Hiding (FR-017).**
   - `CArchiverConfig::RefreshAvailability()` looks up each configured program:
     a path must exist; a bare name is found through `SearchPathW`, because
     `CreateProcess` searches the same way.
   - `CanBrowse()` filters `BuildArray`, and the new `CPackerFormatConfig::CanPack()`
     replaces `GetUsePacker()` at the four runtime "can I pack into this
     archive" sites (`fileswn6/8/9`, `mainwnd1`) and in `pack2.cpp`. The stored
     value is unchanged for the configuration pages and plug-in registration.
   - The refresh runs at the start of `CPlugins::CheckData()` (both start-up
     paths), on the External Archivers Locations page's OK, and after
     Autoconfiguration.
7. **Pack/Unpack dialogs** use combo item data. `IsPackerOffered` /
   `IsUnpackerOffered` hide an entry only when its command is exactly the
   variable of an archiver whose program is missing. The preferred-entry
   fallback in `fileswn7.cpp` skips hidden entries.
8. **Autoconfiguration.**
   - 7-Zip enters the search table as `Packer_Unpacker`, so it never becomes an
     association's packer.
   - For single-program archivers both paths are set.
   - Availability is refreshed between the remove pass and the add pass:
     `AddToExtensions` finds records with `PackIsArchive`, which would not see
     hidden records and would duplicate them.
   - `ProbeKnownLocations()` reads the registry first (7-Zip `Path64`/`Path`,
     WinRAR `exe64`/`exe32`, HKLM and HKCU, 64- and 32-bit views), then the
     Program Files folders.
   - Duplicate paths are compared case-insensitively.
9. **Migration 106** (`PackMigrateArchiversTo106`, `packers.cpp`, called in the
   load block before `CheckData`).
   - It adds the 7-Zip default unpacker itself when no entry calls 7-Zip. An
     `AddDefault` `case 105:` would have added it a second time to fresh
     configurations, because `case 0` falls through.
   - M3 adds `arj` and `lzh;lha` records where unclaimed. ARJ volumes (`a##`)
     are no longer claimed. Whether 7-Zip opens a multi-volume ARJ set has not
     been verified; it is recorded in `inventory.md`.

### Results

- `build.cmd` (Debug x64): OK, no new warnings in touched files.
- `check_encoding.py --strict`: `TOTAL: 0`.
- `saltests`: **1646 checks, 0 failed** (1527 + 49 for the `-slt` parser + 70
  for the migration decisions).
- `salspawn` is gone from the solution, the generated filter and the base
  address tables. `git grep -i salspawn src` shows only historical comments.
- Trap: Python string escaping turned one `'\'` into `''` in a generated C++
  line (`pack3.cpp` `RefreshAvailability`). The compiler caught it. Generated
  C++ goes through the Write/Edit tools from now on.

## 2026-10-01 — Independent review #1 of S1–S5: REJECTED, fixed

A reviewer that did not write the code reviewed the whole working-tree diff,
refute-first, with experiments using 7-Zip 22.01 and the real `sal7zlist.cpp`
in a harness.

**Verdict: REJECT** — one blocker, four SHOULD-FIX, three NIT, five suspicions.

| # | Severity | Finding | Fix |
|---|---|---|---|
| 1 | **BLOCKER** | The default 7-Zip **unpacker** (Alt+F9) had `x -y` without `-o`. A custom unpacker runs with the real target as its current directory, so 7-Zip extracted straight into the target and `-y` overwrote existing files silently. Demonstrated: a file "PRECIOUS USER DATA" was overwritten. A Cancel also left partial files there. | `-o"$(TargetPath)"`: `$(TargetPath)` is the empty temporary folder `PackUniversalUncompress` creates. Files reach the target through `MoveFiles` (`COperations`), which asks before overwriting, and a Cancel leaves the target untouched. Test string and `inventory.md` updated. |
| 2 | SHOULD-FIX | **Archive-comment injection.** Without `-ba`, 7-Zip prints a multi-line archive comment verbatim before the item list. A comment with ten `-` and `Path = fake_entry.txt` produced a fake item (crafted ARJ, demonstrated). | The listing uses **`-ba`** (bare). The parser refuses any input that contains a separator (`SAL7Z_NOT_BARE`). Empty output is an empty archive; `PackList` no longer reports "no output". New saltests: the injected text is refused, and a flattened item comment gives no phantom item. |
| 3 | SHOULD-FIX | Every Autoconfiguration run with `Rar.exe` found added another `rar;r##` record. `AddToExtensions` looked records up through `PackIsArchive`, which never sees the non-browsable RAR record. | Records are now looked up in the **stored** extension lists (`SalArcMigListHasExt`). |
| 4 | SHOULD-FIX | On a volume without 8.3 names, `SalGetShortPathName` returns the long path and it went into the command line **unquoted**. `D:\Program Files\7-Zip\7z.exe` started `D:\Program.exe`, and error messages named the wrong program. | The 8.3 branch (a DOS-era need) is removed; the archiver path is always quoted. The quoting loop's possible one-byte overrun is bounded as well. |
| 5 | SHOULD-FIX | `shellsup.cpp:272/577` drop targets still used `GetUsePacker`: a copy cursor, then a failure. | `CanPack`. |
| 6 | NIT | The templates (`-scsUTF-8`, `--`, `e`) were verified correct, as was `*.*`→`*`. An Unpack mask such as `*.txt` matches root files only, unlike the plug-ins. | Documented here; no change, because `-r` would break the exact-name lists. |
| 7 | NIT | 7-Zip exit 255 on a listing with encrypted names (stdin = NUL) maps to `IDS_PACKRET_STOPPED`. It does not hang (0.04 s). | No change. |
| 8 | NIT | The contract's idempotence claim versus index 0. | Contract M0 amended. |

Suspicions and what was done about them:

- **Two overlapping wait windows during a listing.** The caller already shows
  "Reading list of files…" (`CreateSafeWaitWindow`, 2 s). A listing now
  creates **no** window of its own and honours that window: Esc, or its Close
  button, through `UserWantsToCancelSafeWaitWindow()`.
- **No keyboard Cancel.** Esc now cancels both kinds of run. A stale Esc press
  is cleared before the loop, and the loop wakes every 50/100 ms to notice it.
- **Start-up stall on a UNC archiver path.** `RefreshAvailability` does not
  probe `\server\…` paths. They are offered, and a failed start names them.
- **Entries the user made with exactly `$(Rar32bitExecutable)` /
  `$(SevenZipExecutable)` are hidden with their archiver.** Kept: such an
  entry cannot run while the program is missing. Spec FR-017 is clarified.
- **Message pumping during a listing.** Accepted: `ChangePathToArchive`
  brackets the run with `BeginStopRefresh`, and the main window is disabled.
  Recorded for the GUI pass.

After the fixes: Debug build OK, `saltests` **1647/0**, guard `TOTAL: 0`. Line
endings: `pack3.cpp` and the new files had become LF in the working tree
(Git Bash `sed -i`) and were restored to CRLF. The index is LF anyway
(`text=auto`).

## 2026-10-01 — Translations (T055, T056 partly, T057 n/a)

- **Templates.** `build.cmd full`, then
  `src\vcxproj\build_langs.cmd --export-templates --module salamand`. Only
  `salamand` changed; the 7zip plug-in strings belong to stage S7, which is
  blocked.
  - Before the refresh, `build.cmd full` **fails** on purpose: the committed
    `salamand.slt` files no longer match the new layout, and `translator.exe`
    sits on an error box, killed after 30 s ×8. This is expected and the
    reason for the refresh.
- **Bundle-ordinal hazard: avoided, not repaired afterwards.**
  - The first dry run reported **456 gaps per language**. The removal emptied
    two 16-ID bundles and the new IDs added two, so 46 later bundles changed
    their ordinal, and the matcher's identity
    (`tools/translate/match.py` `entry_key`) includes that ordinal.
  - 079 paid DeepL for the displaced rows and restored them from HEAD
    afterwards. This time `probe/rekey_stringtables.py` re-keyed the
    **committed input** first. Each `[STRINGTABLE n]` header and each
    `STRINGTABLE:n:id` key in the `.origin` sidecar was mapped to the template
    section holding the same bundle (base ID = ID // 16); the 2 vanished
    bundles were dropped.
  - Result: 46 sections renumbered per language; the dry run then reported
    **15 gaps per language**, exactly the new strings.
- **Merge.**
  - `python -m translate.merge --module salamand` sent **5,696 DeepL
    characters** (quota remaining 494,304).
  - Trap: Python's TLS verification failed with "certificate has expired" (an
    expired certificate in the chain Python built from the Windows store; the
    DeepL leaf is valid until 2026-12-19, issuer YE1). It runs with
    `SSL_CERT_FILE` set to the `certifi` bundle.
- **Pins** (`translations/ui-overrides.json`, `_feature_084`):
  - `IDS_PACKERR_EXEMISSING` in all 8 languages. DeepL returned the informal
    register in de/fr/es (du/tu) and invented names for the configuration page
    and the menu command it quotes. The pins use each language's real UI
    names: dialog 2340's caption, `IDS_MENU_OPT_ARCHAUTOCFG`, `IDS_MENU_OPT`.
  - German also keeps the corpus term "Packprogramm" in `STARTFAIL`,
    `CANCELLED_ARC` and `STOPPED`; DeepL mixed "Archiver" and "Archivierer".
  - A second merge run sent 0 characters.
- **Verification** (script, per language, against HEAD):
  - 0 changed string rows; exactly the 74 removed IDs removed; exactly the 15
    new IDs added;
  - dialog and menu sections byte-identical;
  - 0 validation failures;
  - `build.cmd full` OK, 189 language modules.
- **Not done, with reasons.**
  - The 3 disabled languages (Simplified Chinese, Russian, Ukrainian) were not
    refreshed: it would cost DeepL characters for languages that do not ship.
    Their `salamand.slt` stays on the old layout, and re-enabling one needs the
    same re-key and merge (the opt-in `--language`). This is the same situation
    as after any resource change.
  - The visual pass in English and Czech (T056) is owed to a person (GUI
    probes skipped at the maintainer's request).
- **Help pages (T054)** were updated by an agent; its report is in the session.
  - 11 pages: `basicwork_pack`, `dlgboxes_pack`, `dlgboxes_unpck`,
    `configuration_locat`, `configuration_packr`, `configuration_unpck`,
    `configuration_assoc`, `customize_arccfg`, `dlgboxes_arcac`,
    `dlgboxes_arcacdrv`, `plugins_using`.
  - Each page keeps its BOM and CRLF, has the post-rebrand footer, and makes no
    RAR-reading claim.
  - `introduction_news` (historical release notes) and generic glossary pages
    were left unchanged.

## 2026-10-01 — Independent review #2 (re-review of the fixes): ACCEPT WITH FIXES

The re-reviewer verified all four SHOULD-FIX fixes and the blocker fix, by
tracing the code and by running 7-Zip.

- **Blocker fix**: the exact unpacker command was run with the target as the
  current directory. The target's `a.txt` "PRECIOUS USER DATA" and `sub\a.txt`
  were untouched; 7-Zip wrote only into `-o`.
- **`-ba`**:
  - review #1's `cmt.arj` and `cmt.zip` list only their real items;
  - an empty ARJ gives an empty listing;
  - all fixtures parse;
  - crafted tar names, ZIP item comments and ARJ file comments containing LF,
    CR, `----------` and `Path = …` are flattened by 7-Zip (LF → `_`), so
    there is neither an injection nor a false refusal;
  - stderr text only ever came with a non-zero exit code.

Findings:

1. **SHOULD-FIX, verified.** A user command written as
   `"$(Rar32bitExecutable)"` worked in 0.1.8, where the variable expanded to
   an unquoted 8.3 name. It now expands to `""C:\…\Rar.exe""`, and
   `CreateProcess` fails (error 87). **Fixed**: `PackNormalizeProgramQuotes`
   (`pack3.cpp`) reduces doubled quotes around the program to single ones.
   It is used by `PackRunArchiver` and by `PackGetProgramName`, so error
   messages name the program too.
2. **NIT**: the contract and fix-log still described the 500 ms listing
   window, and review #1's entry said the caller's window has a Close button.
   It has none (`fileswn2.cpp:2220`, `salshlib.cpp:721`); only Esc works.
   **Fixed**: contract C3 amended; this entry corrects the fix-log.
3. **NIT**: `AddToExtensions` adds a record when the group's *last* token is
   unclaimed (existing logic). With only `arj` stored it adds `arj;lzh;lha`,
   so `arj` is claimed twice; the first record wins. Recorded, not changed.
4. **NIT, suspected**: Autoconfiguration can switch a *hand-made* `rar`
   association whose viewer is 7-Zip over to RAR, which cannot browse.
   Recorded.
5. **NIT, suspected**: the Esc that cancels a listing might also reach the
   focused panel. The main window is disabled during the run, so input should
   not reach it. Recorded for the GUI pass.
6. **NIT**: `\?\` paths are treated as network paths and not probed; a
   disconnected *mapped* drive letter is still probed at start-up. Recorded.

## 2026-10-01 — PRIVACY.md re-check (T059)

Verdict against the final diff, trigger by trigger (house rule in CLAUDE.md):

- **Network**: no new communication. The archivers are local programs; no URL
  is opened; `7z.exe`/`Rar.exe` are run only on the user's own archives.
- **Plug-ins**: no plug-in enabled or newly shipped (`plugins.cfg` unchanged).
- **Storage / credentials**: nothing new stored. Autoconfiguration *reads*
  the 7-Zip and WinRAR registry entries and Program Files folders; it writes
  only the existing archiver paths. The migration removes stored entries.
- **Crash reporting, installer**: unchanged.

No trigger fired. The existing external-archivers sentence named RAR and ARJ
as examples; it was corrected to the programs actually supported, with one
sentence on the Autoconfiguration lookup. Because that describes unreleased
behaviour while the winget `PrivacyUrl` points at `main`, the validity line
now says it covers 0.1.8 *and the unreleased changes after it*; the release
bumps that line as usual (final review #3, finding 3).

## 2026-10-01 — Independent review #3 (final truthfulness review): ACCEPT WITH FIXES

A read-only reviewer compared every user-facing text and record with the code.
It confirmed the code matches the user-facing claims on almost every point
(project counts, the 74 removed and 15 new IDs in all 8 languages, help-page
encoding, the RAR licence claims, the CLAUDE.md entry). Findings and what was
done:

1. **SHOULD-FIX, CHANGELOG silent on RAR.** A `.rar` still does not open (the
   RAR browse row is empty, `BuildArray` skips it, the migration removes the
   old RAR unpacker). **Fixed**: the lead now says RAR archives cannot be
   opened or unpacked yet.
2. **SHOULD-FIX, "a cancelled unpack leaves nothing"**: true for the panel and
   the built-in 7-Zip unpacker (temporary `PACK*` folder removed); a custom
   unpacker that does not use `$(TargetPath)` runs in the target. **Fixed**:
   sentence narrowed.
3. **SHOULD-FIX, PRIVACY.md validity line and the missing T059 verdict.**
   **Fixed**: see the entry above.
4. **SHOULD-FIX, `inventory.md` §4** omitted `-ba`, the safety switch of
   review #1 finding 2. **Fixed**; the tested versions are now recorded there
   too.
5. **NIT, CHANGELOG wording**: Esc added; "7-Zip and WinRAR are kept"
   corrected (7-Zip is new); the floppy-preset exception to "own-path entries
   are kept" stated. The emoji claim was narrowed to "names outside the system
   code page", because the default 7-Zip formats (ARJ, LZH) cannot prove
   emoji (reviewer's suspicion).
6. **Help**: `configuration_unpck` (the long-names flag only limits the command
   line for unpackers), `configuration_assoc` (RAR cannot be opened; RAR is
   created only from the Pack dialog), `configuration_packr`/`_unpck`
   (`$(TargetDOSPath)` was never in the menu), `configuration_locat` (listing:
   Esc, no window), `salamand.hhc` and `dlgboxes_arcacdrv` title ("Search
   Paths"), `introduction_intro` (RAR dropped from the format list). **Fixed**.
7. **Contracts**: `7z-slt-listing` P3/P4 (a separator is refused, not
   required), `archiver-launch` (an "as built" block supersedes C2's
   `IDS_PACKERR_PROCESS`, C3's worker thread and 990-byte cap — the real limit
   is 512 MB → `IDS_PACKERR_NOMEM` — and C4's number for an unknown code, which
   shows *Unknown error*), `config-migration-106` (M1 preference wording, M3
   groups `{"arj","lzh;lha"}`). **Fixed**.
8. **Spec, plan, data model, research**: FR-007 gained an "as built" note for
   M1b–M1d and the floppy rule; FR-003's version clause is recorded as **not
   met** (only the tested 7-Zip 22.01 is recorded; WinRAR never ran);
   `plan.md` no longer claims RAR out of the box for the CHANGELOG;
   `data-model.md` §1/§2/§4 and `research.md` R6/R7 carry superseded marks.
   **Fixed**.
9. **Tasks marked done that were not done as written** (T011, T016, T021,
   T022, T024, T025, T027, T028, T029, T040, T041, T054, T059, T061): each now
   carries an "As built, review #3" note; `quickstart.md` names `gui_probe.ps1`
   instead of the probe files that were never written. **Fixed** (records).
10. **Closing report** claimed Unicode with RAR, which never ran. **Fixed**.
11. **Dead strings**: `IDS_PACKERR_ARCCFG` (11017) and `IDS_PACKERR_DATETIME`
    (11018) became unused with the deleted column parser, besides
    `IDS_PACKERR_NOOUTPUT` (11019). **Recorded, not removed**: removing them
    is another template/merge/build cycle for no user-visible gain; listed in
    the closing report's follow-ups.
12. **Translations, terminology**: Spanish "archivador" (absent from the
    corpus) → "compresor" in all four messages including the pinned 11073;
    Dutch one term ("archiveringsprogramma", the corpus majority) and „“
    quotes; Hungarian "archiváló" (typo in 11122, "archívumkezelő" in 11072,
    "törölve" = deleted in 11074 → "megszakadt"); Slovak "archivačný
    program" in 11072/11074/11122; French straight apostrophes (the corpus
    form, 452 vs 7) and "Programme console" for both console programs. All
    as pins under `_feature_084` in `ui-overrides.json`. The merge sent
    **0 DeepL characters**; the per-language comparison against HEAD is still
    0 changed rows, 74 removed, 15 added, other sections identical;
    `build.cmd full` OK (8 salamand modules rebuilt, 189 total).

Suspected and left open: RAR packing has never run against a real `Rar.exe`
(owed WinRAR test, closing report).
