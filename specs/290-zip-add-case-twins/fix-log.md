# Fix log: 290 - adding into a ZIP that holds names differing only in case

From backlog item `adding-a-file-into-a-zip-that-holds-names-differing-only-in` (measure:271): adding
a file into a ZIP that holds case twins matches the members ignoring case and replaces the twin the
user did not name.

## Measured (before) - at 1e402ea2

By reading:
- `src/plugins/zip/add.cpp` `CZipPack::MatchFiles`: the pre-pass over the central directory sets
  `pathFlag = 0` / `Unix = TRUE` only for an HS_UNIX entry; the match loop calls
  `SalZipMemberIs(inZip, ..., destNameBuf, ..., RootLen, pathFlag == NORM_IGNORECASE, ...)` and, for
  a folder of a Move, `SalZipMemberIsOrIsIn(...)`. Every match is asked (DialogOverwrite) and, on
  Yes, put on the delete list; on Unix the first Yes turns the item into AF_OVERWRITE (no more
  questions) and renames the added file to the member's spelling.
- `src/common/salzipname.h` `SalZipMemberIs`: `rootIgnoreCase` covers only the first `RootLen`
  bytes (the panel's folder); the rest is compared by `SalZipNameEqual(..., TRUE)` - ALWAYS ignoring
  case, also in a Unix archive. So the item's premise "as a Unix-made ZIP already does" is wrong.
- Caller chain: Copy / Move from a disk panel into the archive panel -> core ->
  `CPluginInterfaceForArchiver::PackToArchive` (`main.cpp`) -> `CZipPack` -> `MatchFiles`
  (`add.cpp` L118). The core passes no listing data (271 contract point 4).

Probe `probe/zip290_probe.ps1` (new; 271's fixtures by .NET `ZipArchive`, host 0; UNIX rows patch
it to 3; left panel a disk folder with the one item to add, right panel the archive; Home, Down,
Copy 727, OK, Yes to every overwrite question) on the Debug build of HEAD (`.\build.cmd` -> up to
date), hidden desktop, run from `%TEMP%` before the branch existed (`-Lib` -> 098's library),
`probe/result_before.txt`: **6 FAIL, 12 PASS** (9 RUN rows + 9 END rows):
- ZIP-CONTROL: `readme.txt=NEW, z.txt`, 1 question - PASS (to keep);
- ZIP-ADDDIR: `d/x.txt=NEW, d/y.txt=Y`, 1 question - **D/x.txt lost**;
- ZIP-ADDFILE: `a.txt=NEW, z.txt`, 2 questions - **A.txt lost**;
- ZIP-ADDFOLDER (folder d with x.txt added into the root): `d/x.txt=NEW, d/y.txt` - **D/x.txt lost**;
- ZIP-NEWNAME (A.txt, a.txt, b.txt=old; add B.txt): `A.txt, B.txt=NEW, a.txt`, 1 question - b.txt
  replaced (today's behaviour; the known change of 290);
- UNIX-CONTROL: `README.txt=NEW, z.txt`, 1 question - PASS (to keep; the Unix rename);
- UNIX-ADDDIR: PASS, no question (the panel's folder is compared exactly on Unix);
- UNIX-ADDFILE: `A.txt=NEW, a.txt=lower`, 1 question naming A.txt - **the wrong twin replaced**;
- UNIX-ADDFOLDER: `D/x.txt=NEW, d/y.txt` - **the wrong twin replaced**.
Registry restored, identical (SHA-256 8079B0...0CAE).

## Decisions

- A ZIP holding twins anywhere (252's rule over every folder, as 271's listing) is matched by exact
  name for adding - the panel's folder and the rest - for both hosts (item *Expected*; spec
  Clarifications). Without twins nothing changes (Windows: ignoring case; Unix: folder exact, rest
  ignoring case + rename).
- The rule for "twins somewhere in these paths" goes into `src/common/salcasetwins.h` with saltests
  checks (the ZIP plug-in compiles header-only rules).
- Low memory while collecting the names: refuse with IDS_LOWMEM (nothing changed).
