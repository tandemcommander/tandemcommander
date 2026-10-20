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
  entry; the first match is overwritten) - by reading, not measured -> Inbox
  `adding-a-file-into-a-zip-that-holds-names-differing-only-in` (measure:271).

## Owed to a person (NOT DRIVEN)

- Clipboard Paste of a twin from a Windows-made twin ZIP (no clipboard on the hidden desktop):
  added as a log line to the existing person step
  `paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand` (T013). The mechanism (the panel's
  case sensitivity) is the one rows HIDE / GLOBAL prove.
