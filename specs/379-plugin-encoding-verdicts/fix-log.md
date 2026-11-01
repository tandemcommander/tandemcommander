# Fix log: 379 - every finding of the plug-in encoding scan has a verdict

Backlog item `check-encoding-plugin-findings` (leftover:239). Continues the stopped feature 255
(`origin/255-plugin-encoding-findings`, record copied here as `255-fix-log.md`,
`255-verdicts.md`, `255-baseline_e849e68c.txt`).

## Measurement at 3e0da39c (main, before the feature)

`python tools/check_encoding.py --plugins` → `TOTAL: 81 finding(s)`, exit 0, none annotated
(`baseline_3e0da39c.txt`, `--format list`). Compared with 255's baseline (file + rule + text, line
numbers stripped, sorted, `diff`):

- 77 of the 78 findings are unchanged;
- gone: `plugins/ftp/ftputils.cpp` `[strict-probe-rejects-wtf8]` (255 row 41, `FTPFieldToU8`) -
  feature 269 replaced the probe by `SalFtpListingFieldIsU8` (backlog item
  `ftp-wtf8-name-listing-round-trip`, the defect 255's review 2 found);
- new: 4 × `plugins/codeview/config.cpp` `[strict-probe-rejects-wtf8]` (`CvCodePageNameToUtf8`,
  `CvUtf8ToCodePageName`, feature 262).

`BL verify` recorded "still present".

## Carry-over (SKILL.md 4.6)

`git diff --binary <merge-base> origin/255-plugin-encoding-findings -- . ':!backlog' ':!specs'
':!.specify/feature.json' ':!translations'` → `git apply -3`: 35 files, 34 clean, one conflict in
`ftp/ftputils.cpp` (row 41's marker against 269's new code) - resolved with `main`'s code and
without the marker (row 41 is fixed). The branch is 1086 commits behind `main`; the patch
(comment lines only) applied without re-implementation.

Every carried marker was re-checked against its line at HEAD in the 11 files `main` changed since
255 (`git log <merge-base>..main -- <file>`): Code Viewer `intake.cpp` (still the decoded document
text, one caller `CvAppendUtf8FromWide` ← the intake), File Comparator `mainwnd.cpp` (still
`SendMessageW`), FTP `ftputils.cpp` 2 × lenient (still after the `CP_ACP` decode), Markdown Viewer
`htmlgen.cpp` / `viewer.cpp` (callers: code segments, heading ids, the find term, the decoded
document; the URI decoder unchanged), Registry Editor `finddlg2.cpp` (`CreateDialogParamW`,
`dialogs.cpp`), UnISO `iso9660.cpp` (Joliet `tmp[2*MAX_PATH]`, a name ≤ 127 units ≤ 381 bytes <
520), `udf.cpp` (`final[4096]`, ≤ 254 units), `udfiso.cpp` (`volId[3*130+1]`, 64 units ≤ 192
bytes), ZIP `add.cpp` (still inside the `/* … */` block: last `/*` line 3480, last `*/` 3316, site
3502). All hold.

## Re-judged rows (255's review 2 open points)

- **Row 3, CheckVer `dialogs.cpp`** (`sprintf(buff, LoadStr(IDS_REMOVE_CNFRM), itemName)`, review 2
  SHOULD 1). `itemName` comes from the filter list box (`LB_GETTEXT`), filled by
  `FiltersFillListBox` from `Filters`, which `AddUniqueFilter` fills from the registry
  (`CONFIG_FILTER_KEY`, the registry facade stores UTF-8), the log window's FILTER link (module
  names of the update script, which `logwnd.cpp` treats as UTF-8 first) and the list box itself. A
  non-ASCII module name is UTF-8 bytes put through an ANSI list box and a code-page template →
  mojibake. Verdict: **real defect, latent** (plug-in off; the update server's scripts were ASCII).
  Marker dropped; new item (below).
- **Rows 67 / 68 / 75, TAR `ConvertNameToU8`, UnCAB `CabNameToU8`, UnMIME `NameToU8`** (review 2
  NOTE 1: "the WTF-8 form does not arise" unproven). The vendored 7-Zip converter
  `src/plugins/7zip/7za/CPP/Common/UTFConvert.cpp` `Utf16_To_Utf8`: an unpaired surrogate is
  written as its 3-byte form unless `Z7_UTF_FLAG_TO_UTF8_SURROGATE_ERROR` is set, and
  `g_Unicode_To_UTF8_Flags` is `0` on `_WIN32` - so a Windows packer of this family writes the
  WTF-8 form. TAR / UnMIME then read the whole name in the code page (another name), UnCAB with
  `_A_NAME_IS_UTF` refuses the entry (`!validU8` → FALSE). Verdict: **real defect, latent** for
  all three (TAR and UnCAB shipped, UnMIME off). Whether 7-Zip's TAR / CAB writers route names
  through this converter was not measured. Markers dropped; new item (below).

## New findings at HEAD

- Code Viewer `config.cpp` 4 × `strict-probe-rejects-wtf8` (feature 262): the converted text is a
  conversion table's name (`EnumConversionTables`, code-page bytes) on its way to and from the
  registry, never a file name; a name that does not convert exactly becomes `""` (callers lines
  171-174, 234-236: the system code page). Verdict: **false positive**; markers added (379).

## State after the carry-over

`python tools/check_encoding.py --plugins` → `TOTAL: 14 finding(s)`: 255's 10 real-defect sites +
CheckVer `dialogs.cpp`, TAR, UnCAB, UnMIME `parser.cpp`. `git diff main -- src`: 67 added lines
(63 carried + 4 Code Viewer), all markers.

## Items (T006, T007)

Four bugs in *Inbox*, source `measure:379`, bodies through `BL --input-json - new` (no placeholder
left, `BL check` → `TOTAL: 0`):

- `tar-wtf8-names-read-in-code-page` (bug 4, archives, shipped) - row 67;
- `uncab-wtf8-flagged-name-refused` (bug 4, archives, shipped) - row 68;
- `unmime-wtf8-name-read-in-code-page` (bug 1, other-plugins, off) - row 75;
- `checkver-filter-names-code-page` (bug 1, other-plugins, off) - row 3.

**Deviation (T007 / FR-007)**: `plugin-encoding-scan-strict-in-build` (created by 255, not by this
session) cannot get the two shipped items in its `depends-on` from an agent (`/tandem-backlog`
agent mode forbids changing another item's fields). Done instead: `BL log` on it naming
`tar-wtf8-names-read-in-code-page` and `uncab-wtf8-flagged-name-refused`; adding them to
`depends-on` is the maintainer's step (closing report, *Owed to a person*).

## Verdict table (T008, T009)

`verdicts.md` generated by a session script (scratchpad `make_verdicts.py`, not in the tree) from
`255-verdicts.md`, `255-baseline_e849e68c.txt`, `baseline_3e0da39c.txt` and the markers in the tree:
each of 255's rows matched to its line at HEAD by (file, rule, text) in order of occurrence; each
false-positive reason read from its marker (the line moved by the inserted lines above it, from
`git diff -U0 main`) and compared with 255's reason - all 63 carried reasons equal; the script exits
non-zero on any mismatch, unmarked false positive or marked real defect. Result: **82 rows - 67
false positives, 14 real defects, 1 fixed**, in 19 plug-ins + `shared/lukas`.

Check: the scan's `--format list` (file + rule) sorted = the real-defect rows (`diff`: none), 14
lines; every real-defect slug (12 items) exists in `backlog/items/`.

## Checks (T010, T011)

- Negative control 1: `void Neg379(HWND h, const char* fileName) { SetWindowText(h, fileName); }`
  appended to `src/plugins/dbviewer/dialogs.cpp` → `TOTAL: 15`, the line reported
  (`utf8-to-legacy-sink`); file restored from a copy → `TOTAL: 14`, `git status` clean.
- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`, exit 0.
- `git diff main -U0 -- src` minus marker lines → nothing; `32 files changed, 67 insertions(+)`.
- PowerShell `.\build.cmd` (Debug x64, incremental) → `BUILD SUCCEEDED`, exit 0; the plug-ins with
  markers were rebuilt (`zip.spl`, `tar.spl`, `codeview.spl` written 18:37, after the edits).
  `saltests` not run: nothing in the core or `src/common/` changed. No UI strings, dialogs or
  resources changed: no `.slt` refresh, no `build.cmd full` needed.
- Negative control 2: `tools/` and `src/plugins` copied to a temporary folder, every marker line
  ending `(255)` / `(…, 255)` / `(379)` removed → `check_encoding.py --plugins` → 81 findings,
  equal to `baseline_3e0da39c.txt` (file + rule + text, sorted `diff`: none) - every marker sits on
  its own finding and suppresses nothing else.

## Review

### Review 1 (independent agent, refute-first)

Reproduced: scan `TOTAL: 14` = the 14 real rows, 12 slugs exist; core `--strict` 0; 67 added /
0 deleted, BOM and CRLF kept; its own negative control (markers stripped in a copy → 81 =
baseline); 67/67 reasons equal their markers. Every marker in the files `main` changed since 255
re-checked and holds (N5); the re-judged rows 3, 67, 68, 75 and their items confirmed (N6).

- **MUST 1** - Automation `strconv.cpp` (rows 32-34) marked "OLE2A serves a question text and a
  trace only": false. Without `_UNICODE`, `strconv.h` defines `OLE2T(s)` as `OLE2A(s)`, used for
  window captions passed to `CreateWindowEx` (A) in `guibutton/guilabel/guichkbox/guitxtbox/
  guiform.cpp`, the `InputBox` prompt, and registry value names in `persistence.cpp`
  (`DeleteValue`, `SetValue` `REG_DWORD`). Confirmed by reading (`grep OLE2T`). **Fixed**: the three
  markers removed, rows 32-34 → real defect, item `automation-ole2t-captions-and-value-names`
  (review:379, severity 1, plug-in off); a log line on `plugin-encoding-scan-strict-in-build`.
- **SHOULD 1** - core `src/regwork.cpp` `DeleteValueAux` uses `RegDeleteValue` (A) with a UTF-8
  name (measured by the reviewer: `RegDeleteValueA` of `číslo` → error 2, the value stays);
  `CreateKeyAux` / `OpenKeyAux` / `DeleteKeyAux` use A too. Confirmed by reading. Outside the item
  (core) → item `registry-wide-deletevalue-and-key-names` (review:379, severity 2).
- **SHOULD 2** - the UnCAB item understated the effect: a refused name returns -1 from the notify
  callback, `FDICopy` aborts and the whole cabinet fails to list (`uncab.cpp` `ListArchive`).
  Confirmed by reading. **Fixed**: the item's *Problem*, title and severity 4 → 5.
- NOTE 1 - the fix-log said "71 added lines (67 + 4)". **Fixed** (67 = 63 carried + 4).
- NOTE 2 - Code Viewer markers: the `CP_ACP` probes are not about WTF-8 and the table names come
  through a core service. **Fixed**: the wording of the two `CP_ACP` markers ("a code-page probe of a
  conversion table name (convert.cfg bytes via EnumConversionTables, 262), never a file name; …").
  The verdict holds; on cp932 a non-ASCII table name drops the remembered default to "" (a
  setting, not data) - recorded here only.
- NOTE 3 - Markdown Viewer `viewer.cpp` `UriDecode` (row 48): the real limit is that it converts
  one UTF-16 unit at a time (a surrogate pair would be split); it holds because WebView2 hands over
  canonical percent-encoded URIs. Verdict kept; recorded here only.
- NOTE 4 - ZIP `common.cpp` bounds a converted entry name to `MAX_HEADER_SIZE - 1` (64 KiB) bytes,
  at a whole UTF-8 character. No Windows name reaches that length (a hostile archive's header can);
  not an encoding finding - recorded here only, no item.

After the fixes: `check_encoding.py --plugins` → `TOTAL: 17` = the 17 real rows of the regenerated
`verdicts.md` (64 false positives, 17 real defects, 1 fixed; sorted lists equal); `--strict` →
`TOTAL: 0`; `git diff main -- src` 31 files, 64 added / 0 deleted, all markers; `.\build.cmd` →
`BUILD SUCCEEDED` (`codeview.spl` rebuilt 18:50 after the marker change; Automation is off, not
built); `BL check` → `TOTAL: 0`.

### Review 2 (fresh independent agent, with review 1's findings)

No MUST. Reproduced: scan `TOTAL: 17` = the 17 real rows; core `--strict` 0; markers stripped in a
copy → 81 = baseline (the 64 markers hide exactly the 64 false-positive rows); 31 files, 64 added /
0 deleted, all markers; all 13 real-defect slugs exist; review 1's fixes in place. Every one of the
64 false positives traced to its callers and held (Automation `fileinfo.cpp`, 7-Zip static text,
ZIP self-extractor and `add.cpp` block, UnISO / UnOLE bounds, the code-page sources, Code Viewer,
Markdown Viewer, File Comparator, Registry Editor, `shared/lukas`).

- SHOULD 1 - the Automation item missed a second narrowing layer: `_bstr_t`'s `operator const
  char*` (CP_ACP, best fit) feeds the message box, dialog titles, `ProgressDialogAddText` and the
  script error texts (`salamanderaut.cpp`, `progressaut.cpp`, `aututils.cpp`). Confirmed by `grep
  _bstr_t`. **Fixed**: the item's *Problem*, *Approach* and title extended (it is this run's item).
- SHOULD 2 - Registry Editor `fs2.cpp` `GetFullFSPath`: `WStrToU8(...) >= 0` on a `DWORD` is always
  true, so a full key path that does not fit `MAX_PATH` is returned cut as success (also unchecked in
  `fs3.cpp` rename and `finddlg2.cpp`). Confirmed by reading (`utils.h` `WStrToU8` returns `DWORD`
  and terminates a failed buffer). Not a scan site, outside the item → item
  `regedt-full-path-cut-reported-as-success` (review:379, severity 5).
- NOTE 1 - PictView row 13: the marker holds for `mixed-composition`, but the path is converted with
  `CP_ACP` (best fit) for an error text; display only. Recorded here only.
- NOTE 2 - Renamer row 60: false positive by the spec's criterion; a name with an unpaired surrogate
  silently gets no case change. Recorded here only (the item `renamer-wtf8-names-shown-as-mojibake`
  belongs to 255; an agent does not change it).
- NOTE 3 - row 28's marker sits on top of a commented-out block above its line (the scanner walks the
  block). Recorded.
- NOTE 4 - ZIP `add_del.cpp` default SFX vendor `©` literal compiled in the build machine's code page
  (the ZIP project has no `/execution-charset`). Trivial; recorded here only.
- NOTE 5 - header blind spot already tracked in `check-encoding-skips-header-files`.

After the fixes: `BL check` → `TOTAL: 0`; the source tree unchanged by review 2 (no source edit).
