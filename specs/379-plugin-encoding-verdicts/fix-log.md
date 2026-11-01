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
CheckVer `dialogs.cpp`, TAR, UnCAB, UnMIME `parser.cpp`. `git diff main -- src`: 71 added lines
(67 + 4), all markers.
