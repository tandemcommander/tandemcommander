# Fix log: 271 - a ZIP that holds names differing only in case is case-sensitive

From backlog item `a-zip-made-on-windows-that-holds-names-differing-only-in` (leftover:252): the
ZIP plug-in declares a listing case-sensitive only when an entry was made on Unix.

## Measured (before) - at 671ae06b

By reading:
- `src/plugins/zip/list.cpp` `CZipList::List`: `SetFlags(SALDIRFLAG_CASESENSITIVE)` only after an
  HS_UNIX entry (`dir->Clear`, restart). Otherwise the tree is built case-insensitively (folders D
  and d merged by `CSalamanderDirectory::SalDirStrCmp`).
- The plug-in's operations decide case sensitivity from the SELECTION: `CZipCommon::EnumFiles` ORs
  `CZIPFileData::Unix` of the selected items into `CZipCommon::Unix`; readers: `MatchFiles` (root
  prefix `MemICmp` / `memcmp`, folder search `BSearchName`, sort), `del.cpp` `CountFilesInRoot`,
  `extract.cpp` `UnpackOneFile` (overwrites it with the entry's flag) / `FindFile`. A folder without
  an entry of its own has `PluginData == NULL` -> no flag.
- Callers from a user action: Copy / Move out of the archive and Paste -> core ->
  `CPluginInterfaceForArchiver::UnpackArchive`; Delete / the second half of Move ->
  `DeleteFromArchive`; F3 / F4 on a file -> `UnpackOneFile`. All three receive the listing's
  `CPluginDataInterface` (created per listing in `ListArchive`).
- Other writer: `add.cpp` `CZipPack::MatchFiles` (adding into an archive) reads the headers itself.

Probe `probe/zip271_probe.ps1` (new; fixtures by .NET `ZipArchive` from Windows PowerShell 5.1 -
host byte 0 confirmed in every central header; UNIX rows patch it to 3) on the Debug build of HEAD
(`.\build.cmd` -> up to date), hidden desktop, `probe/result_before.txt`: **6 FAIL, 10 PASS**:
- ZIP-HIDE: Hide Selected Names on one twin hid both - tgt `z.txt` only;
- ZIP-GLOBAL: Store / Restore Selection of one twin restored both - tgt `a.txt, A.txt`;
- ZIP-TREE: one folder "D" shown; Copy put `D/x.txt, d/y.txt` (the archive names) into the
  case-sensitive target - PASS by the row's test (no loss on copy), the merge is visible only;
- ZIP-ONE: the one merged folder copied both files;
- ZIP-DEL: deleting it deleted both entries (archive keeps nothing);
- UNIX-ONE: Unix host byte, two folders shown; copying only "d" also extracted D/x.txt;
- UNIX-DEL: deleting only "d" **also deleted D/x.txt** - data loss in a Unix-made ZIP today;
- ZIP-CONTROL (no twins, `t.zip\DOCS` for Docs): PASS - to keep.
Registry restored, identical (SHA-256 BA9B23...DF74).

Conclusion: the listing hook alone would turn UNIX-DEL's data loss on for every Windows-made twin
ZIP - the operations must take the listing's case sensitivity (research R2).

Probe note: the first version wrote with `-Lib` pointing at the 098 library because it ran from
`%TEMP%` before the branch existed; inside `specs/271-*/probe/` the default path is used.

## Decisions

- Twins-only for Windows-made ZIPs, Unix ZIPs always (item *Expected* / *Approach*).
- The listing's decision travels in `CPluginDataInterface::CaseSensitive`; the three operations start
  `CZipCommon::Unix` from it (spec FR-004, Clarifications).

## Analyze (speckit-analyze)

No CRITICAL / HIGH. Fixed: C1 (MEDIUM, person step for Paste had no task -> T013), C2 (LOW, SC-003
check added to T008), I1 (LOW, plan wording). Second run: no findings.

## Work

- `src/plugins/zip/list.cpp` `CZipList::List`: `SetFlags(SALDIRFLAG_CASESENSITIVE)` at `START_LIST`
  (before the first entry; the Unix restart's `dir->Clear` resets it and passes here again), after
  the loop `CaseSensitive = Unix || SalDirTreeHasCaseTwins(dir)`, `SetFlags(0)` when not. No new
  read of the central directory (the existing Unix restart is the only one, unchanged - SC-003).
  `ZeroZip` returns before: flags stay 0, `CaseSensitive` FALSE.
- `src/plugins/zip/list.h`: `CZipList::CaseSensitive` (FALSE in the constructor).
- `src/plugins/zip/zipdll.h`: `CPluginDataInterface(BOOL caseSensitive = FALSE)`, member
  `CaseSensitive` (plug-in's own class, no ABI change). Only construction: `ListArchive`.
- `src/plugins/zip/main.cpp`: `ListArchive` creates it with `list.CaseSensitive`;
  `ListingIsCaseSensitive(pluginData)`; `UnpackArchive`, `UnpackOneFile`, `DeleteFromArchive` set
  `Unix = TRUE` on their `CZipUnpack` / `CZipPack` before enumerating (after the constructor, which
  sets FALSE; nothing else on these paths writes it).
- `src/plugins/zip/extract.cpp` `CZipUnpack::UnpackOneFile`: `Unix = Unix || zipFileData->Unix`
  (was an overwrite).
- Trap met: a Python edit wrote LF line ends into `main.cpp` / `extract.cpp` (CRLF files); restored
  to CRLF before the build (diff 35 lines).

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`, no `warning C` / `error C` lines; zip.spl rebuilt (23:29:12,
  after the last source edit 23:28:52).
- `saltests.exe` -> `saltests: 24816 checks, 0 failed` (no core change; the twin rule's checks are
  252's `TestCaseTwins252`).

## Measured (after)

Probe `probe/result_after.txt`: **16 PASS, 0 FAIL, 0 NOT DRIVEN** (before 6 FAIL):
- ZIP-HIDE: tgt `A.txt, z.txt`, A.txt=UPPER - the hidden twin stayed hidden;
- ZIP-GLOBAL: tgt `a.txt`, lower - only the restored twin;
- ZIP-TREE: "Copy 2 directories" - D and d shown apart; tgt `D/x.txt, d/y.txt`;
- ZIP-ONE: copying "d" -> tgt `d/y.txt` only; ZIP-DEL: deleting "d" -> archive keeps `D/x.txt`;
- UNIX-ONE / UNIX-DEL: the same for the Unix-made ZIP (the pre-existing data loss is gone);
- ZIP-CONTROL: `t.zip\DOCS` still enters Docs (no twins - unchanged, T008).
- Negative control (probe, T011): `ListingIsCaseSensitive` forced FALSE (the listing change kept) ->
  **4 FAIL** (ZIP-ONE, ZIP-DEL, UNIX-ONE, UNIX-DEL; ZIP-DEL "archive keeps: nothing" - deleting
  one shown folder deleted both), HIDE / GLOBAL / TREE / CONTROL PASS,
  `probe/result_negctl_no_listing_switch.txt`. Restored (grep NEGCTL271 -> 0), rebuilt, after-run
  repeated: 16 / 0.
- Regression probes on the final build: 110's `zipname_probe.ps1` -> `TOTAL: 42 PASS / 0 FAIL / 0
  NOT DRIVEN` (`probe/regress_zipname110_271.txt`, as its own record); 164's
  `zip_delete_cost_probe.ps1` -> `Rows: PASS 6, FAIL 0` (`probe/regress_zipdelete164_271.txt`).
- Registry restored and identical (SHA-256 BA9B23...DF74) in every run.

## Out of scope, recorded

- T012: adding INTO a twin ZIP (`add.cpp` `CZipPack::MatchFiles`, case-insensitive unless a Unix
  entry) - by reading -> Inbox `adding-a-file-into-a-zip-that-holds-names-differing-only-in`
  (measure:271); measured and corrected by review 1 (every case-insensitive match is asked and
  replaced, not only the first - see *Review*).

## Owed to a person (NOT DRIVEN)

- Clipboard Paste of a twin from a Windows-made twin ZIP (no clipboard on the hidden desktop):
  added as a log line to the existing person step
  `paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand` (T013). The mechanism (the panel's
  case sensitivity) is the one rows HIDE / GLOBAL prove.

## Review

Review 1 (independent agent, refute-first, build of 24925c60): **no MUST**. It re-ran the probe
(16 / 0, registry identical), enumerated the core callers itself (`fileswn5.cpp`, `fileswn6.cpp`,
`fileswn7.cpp`, clipboard Paste `salshlib.cpp` - all hand back the listing's own plug-in data,
Paste re-lists first), confirmed by reading that a ZIP without twins builds the same tree (252's
rule includes the legacy fold `SalDirStrCmp` merges by) and that the central directory is not read
again. Its own rows under %TEMP% (not in the repository): SUB-DEL (delete `s` inside `t.zip\d` of
D/s/x.txt + d/s/y.txt keeps D/s/x.txt) and SUB-ONE PASS; its negative control (`pack.Unix` not set
in `DeleteFromArchive`) fails SUB-DEL (D/s/x.txt deleted too) - the switch also covers a non-empty
archive root and `CountFilesInRoot`; restored with git, rebuilt.
- SHOULD 1 - adding INTO a twin ZIP still matches case-insensitively and 271 hides where the
  replaced file is. Measured by the reviewer: ADD-DIR (copy x.txt into `t.zip\d`, which since 271
  lists only y.txt; Yes to the question naming `t.zip\D\x.txt`) -> D/x.txt replaced by d/x.txt;
  ADD-FILE (add a.txt to A.txt + a.txt, two questions, Yes to both) -> A.txt lost (also before
  271). Not in the item (it names Paste, Reselect, Store / Restore, Hide Selected Names and the
  folder merge; spec Assumptions put adding out of scope; the overwrite question names the path,
  unlike the silent Delete of 271's UNIX-DEL) -> stays the Inbox item
  `adding-a-file-into-a-zip-that-holds-names-differing-only-in`, its Problem / Evidence rewritten
  with these measurements and the reviewer's recommendation to take it right after 271.
- NOTE 1 - ZIP-TREE passed before and after (the copied files alone do not show the merge). Fixed:
  the row also requires the Copy dialog to count "2 directories" (before: `Copy directory "D"` in
  `result_before.txt` -> would FAIL; the before-run is not repeated, its dialog text is recorded).
  Re-run `probe/result_after.txt` with the tightened row (below).
- NOTE 2 - T007 (`extract.cpp` OR instead of overwrite) has no observable effect: `FindFile`
  matches by item number and compares only names that already agree. Kept - otherwise the line
  would silently discard the switch `UnpackOneFile` sets in `main.cpp`; harmless.
- NOTE 3 - `ListingIsCaseSensitive` casts the plug-in data the core hands back to the ZIP class; a
  user who sets the 7-Zip plug-in to view .zip and ZIP to edit it would mix them. The same
  assumption exists since the start in `EnumFiles` (`common.cpp`, casting `fileData->PluginData`).
  Pre-existing; not changed.
- NOTE 4 - entries spelling one folder in two cases now show two folders: the known change of the
  spec's edge cases (as 252).
- NOTE 5 - Move from an archive panel (F6) did nothing in the reviewer's row: the program does not
  move out of a ZIP from this panel setup; FR-004's "moving out" is the Unpack + Delete pair both
  covered. Not a defect of 271.
- NOTE 6 - CHANGELOG / FEATURE-HISTORY / closing report: written at closing (step 8).

No MUST -> no second review (SKILL step 7).

Re-run after review 1 (`probe/result_after.txt`, label after-review, tightened ZIP-TREE row): **16 PASS, 0 FAIL, 0 NOT DRIVEN**; ZIP-TREE `Copy 2 directories`; registry identical.
