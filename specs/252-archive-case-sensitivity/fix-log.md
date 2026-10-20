# Fix log: 252 - 7-Zip, TAR and SFTP listings declare case sensitivity

From backlog item `archive-plugins-declare-case-sensitivity` (review:230): only ZIP (Unix-made
archives) and FTP declare `SALDIRFLAG_CASESENSITIVE`; 7-Zip, TAR and SFTP do not.

## Measured (before) - at 1cc16d0e

By reading (step 3 of the run):
- `SetFlags(SALDIRFLAG_CASESENSITIVE)` only in `src/plugins/zip/list.cpp` (host OS Unix),
  `src/plugins/ftp/fs2.cpp`, demoplug. 7-Zip (`C7zClient::ListArchive`) and TAR
  (`CArchive::ListArchive`) never call `SetFlags`; SFTP (`fs.cpp`) sets only `IGNOREDUPDIRS`.
- `CFilesWindow::IsCaseSensitive()` is the flag for archives / FS. Consumers: the paste lookup
  (`CSalShExtPastedData::SetData` / `DoPasteOperation`, `CNames` = `SalNameCompareOrdinalCI`, the
  first match wins), Reselect / Store / Restore Selection / Hide Selected Names / tabs (`CNames`),
  the refresh selection merge; `CSalamanderDirectory::SalDirStrCmp` (`StrICmp`, legacy byte fold)
  builds the archive tree and compares archive paths.
- Extraction is exact: 7-Zip by item index, TAR by a byte-exact name tree.

Probe `probe/arc252_probe.ps1` on the build of HEAD (`.\build.cmd` -> BUILD SUCCEEDED, nothing to
rebuild), `probe/result_before.txt`: **6 FAIL, 10 PASS** (END rows + controls):
- TAR-HIDE / 7Z-HIDE: Hide Selected Names on one twin hid **both** - tgt got only z.txt;
- TAR-GLOBAL / 7Z-GLOBAL: Store / Restore Selection of one twin restored **both** (a.txt, A.txt);
- TAR-TREE: entries D/x.txt and d/y.txt were merged into one folder "d"; copying it extracted only
  d/y.txt - **D/x.txt silently not extracted** (TAR matches the exact bytes "d\");
- 7Z-TREE: merged into "d" - both files land in d/ (x.txt in the wrong folder);
- TAR-CONTROL / 7Z-CONTROL (no twins; opened at `<archive>\DOCS` for folder Docs): PASS - the
  case-insensitive behaviour the fix must keep.

Probe fixes on the way (no product defect): -Log and -OutFile named the same file (the write at the
end failed - now -Log only); 7-Zip refuses "a.txt" + "A.txt" without `-ssc` ("Duplicate filename on
disk") - the fixture uses `-ssc`.

## Decisions

- Archives: case-sensitive only when the listing holds case twins (conservative, spec
  Clarifications); built with the flag set, the flag cleared after the listing when no folder holds
  twins - equal to today's listing then (contracts/case-twins.md, guarantee 1).
- Twins = byte-different names equal by `SalNameOrderCompareCI` or the legacy fold (both rules are
  used on archive names by the core).
- SFTP: always (as FTP).

## Analyze (speckit-analyze)

No CRITICAL / HIGH. Accepted: C1 (MEDIUM) - the clipboard Paste route and SFTP are not drivable here
(owed to a person); U1, I1, S1 (LOW) - no change needed (see the report in the session).

## Work

- `src/common/salcasetwins.h` (new, header-only): `SalNamesHaveCaseTwins` (sorted by
  `SalNameOrderCompareCI` and by the legacy fold, neighbours equal by the rule with different bytes),
  `SalDirTreeHasCaseTwins<TDir>` (heap stack, folders and files of each folder together). Low memory
  -> TRUE (keeps the exact listing).
- `src/plugins/7zip/7zclient.cpp` `C7zClient::ListArchive`: `SetFlags(SALDIRFLAG_CASESENSITIVE)`
  before the items, `SetFlags(0)` after unless twins (panel listing, paste re-listing, Unpack whole
  archive).
- `src/plugins/tar/tardll.cpp` `CPluginInterfaceForArchiver::ListArchive`: the same around
  `archive->ListArchive(NULL, dir)` (tar, cpio, rpm, deb, single streams).
- `src/plugins/sftp/fs.cpp`: `SetFlags(SALDIRFLAG_CASESENSITIVE | SALDIRFLAG_IGNOREDUPDIRS)`.
- `src/saltests/saltests.cpp` `TestCaseTwins252` (+ `ClInclude` in `saltests.vcxproj`).

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`, 0 `warning C` / `error C` lines; tar.spl, 7zip.spl, sftp.spl
  rebuilt.
- `saltests.exe` -> `saltests: 24375 checks, 0 failed` (stable over two runs; a first run printed
  24352 - the binary before the new checks were linked).
- Negative control (unit): the legacy half of the rule removed -> `1 failed` (the cp1250 pair
  C3 8A / C3 9A, `saltests.cpp` `Twins252({n1, n2})`); restored.

## Measured (after)

Probe `probe/result_after.txt`: **16 PASS, 0 FAIL, 0 NOT DRIVEN** (before 6 FAIL):
- TAR-HIDE / 7Z-HIDE: tgt `A.txt, z.txt` - the hidden twin stayed hidden, the other copied;
- TAR-GLOBAL / 7Z-GLOBAL: tgt `a.txt` - only the restored twin;
- TAR-TREE / 7Z-TREE: tgt `D/x.txt, d/y.txt` - two folders, nothing left behind;
- TAR-CONTROL / 7Z-CONTROL: `<archive>\DOCS` still enters Docs (no twins - unchanged).
- Negative control (probe): TAR's flag left set without twins (always case-sensitive) ->
  TAR-CONTROL **FAIL** (panel at the archive root, `probe/result_negctl_tar_always_cs.txt`) - the
  control row detects the regression it guards; restored, rebuilt, after-run repeated: 16 / 0.
- Registry restored and identical (SHA-256 98A536...24D4) in every run.

## Owed to a person (NOT DRIVEN)

- The clipboard route of the item's *Expected*: Ctrl+C on a.txt in a 7z / TAR archive holding a.txt
  and A.txt, Ctrl+V in an Explorer / panel folder -> a.txt arrives (content "lower"). Not drivable:
  no clipboard and no shell extension copy hook on the hidden desktop. The mechanism (the panel's
  case sensitivity handed to `CSalShExtPastedData::SetData`) is the one the probe's rows prove.
- SFTP: the test container `tandem-sftp` was not running (Docker Desktop down). On a server folder
  holding a.txt and A.txt: select a.txt, Hide Selected Names -> A.txt stays. One-line declaration as
  FTP's; by reading.
