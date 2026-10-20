# Fix log: 255 - every finding of the plug-in encoding scan has a verdict

Backlog item `check-encoding-plugin-findings` (leftover:239).

## Measurement at e849e68c (main, before the feature)

`python tools/check_encoding.py --plugins` → `TOTAL: 78 finding(s)`, exit 0. The 78 sites (file,
rule, text) are the same as feature 239's `plugins_findings.txt` (diff of file + rule + text: no
difference; lines unchanged too). None annotated. Saved as `baseline_e849e68c.txt`
(`--format list`).

## Analyze (speckit-analyze, one run)

0 CRITICAL, 0 HIGH. LOW U1 (FR-006 lacked the *Shipped* column) fixed in spec.md. LOW I1 (the item
allows a verdict "fixed"; this feature only records false positive / real defect, by Clarification
1) and LOW C1 (`normalize.ps1` cannot run here - pwsh7 missing; the changes are comment lines)
accepted.

## Foundational facts (T002)

- Plug-ins are built without `UNICODE`: no `CharacterSet` in `src/plugins/shared/vcxproj/*.props`
  nor in any plug-in project - `SetWindowText` is `SetWindowTextA`, `ListView_SetItemText` sends
  `LVM_SETITEMTEXTA`, `CB_ADDSTRING` is the ANSI message.
- A plug-in's `LoadStr()` (`SalamanderGeneral->LoadStr`, `spl_gen.h`) returns code-page text
  (`splloadstru8.h` header comment); `LoadStrU8` (`splloadstru8.h`) is the UTF-8 form.
- Names and paths from the core are UTF-8 / WTF-8 (interface 104, `splunicode.h`, 066, 089).

## Verdicts (T003-T007)

Each site was read with its producer and its consumer (callers found with grep); the 78 rows are in
`verdicts.md`. Per rule:

| Rule | Findings | Real | Harmless - main reasons |
|---|---|---|---|
| `utf8-to-legacy-sink` | 18 | 2 (Automation folder list; DB Viewer field length) | ZIP self-extractor stub (10) is a stand-alone ANSI program fed code-page texts from ANSI edits / `LoadStr` / .sfx packages; 7-Zip's label is the core's `CStaticText` (bytes drawn as UTF-8, 131); File Comparator: `SendMessageW` already, tooltips hold digits + ASCII decimal separator; ZIP preview: code page on both sides; DB Viewer `%d` |
| `mixed-composition` | 6 | 3 (Multimedia Viewer 1, UnMIME 2 - both off; Czech templates have non-ASCII letters) | CheckVer: the name is read from an ANSI list box; PictView: the path is converted to the code page just above; ZIP `add.cpp:3374` is inside a `/* */` block (the live copy in `add_del.cpp` uses `LoadStrU8`, 130) |
| `ansi-template-number` | 2 | 0 | PictView prints with `%u` - ASCII, no grouping |
| `dead-dispinfow` | 2 | 0 | FTP sets `ListView_SetUnicodeFormat(TRUE)` (010); Registry Editor's Find is a `CreateDialogParamW` dialog |
| `strict-probe-rejects-wtf8` | 12 | 3 (Renamer preview; UnISO `EnsureU8Name` on Joliet file names; CheckVer log - the last two after review 1) | archive-name boundaries (TAR, UnCAB, UnMIME), FTP listing bytes (224), encoding labels, `shared/lukas/utildlg.cpp` is built by no project (review 1), Renamer's `ChangeCase` copies a non-UTF-8 part unchanged (208) |
| `lossy-lenient-at-intake` | 38 | 2 (UnISO HFS+ names) | display-only texts (Automation dialogs, Code Viewer / Markdown Viewer document text, media tags, registry data preview, resource and system texts), input decoded from a code page just above (FTP, ZIP, Multimedia Viewer), a fallback after `SplWToU8` that fits by construction (Joliet, UDF, UDF volume id, OLE names), case-changed strict-decoded text (Renamer), the Portables device name (converted the same way everywhere) |

Totals (after review 1): **68 false positives, 10 real defects** in 8 items. Real defects in
shipped plug-ins: DB Viewer 1, Renamer 1, UnISO 3; in plug-ins that are off: Automation 1,
CheckVer 1, Multimedia Viewer 1, UnMIME 2.

Noted, not a finding of the rules: the comments "lone surrogates and the like: fall back to a lossy
but valid UTF-8 form" in `uniso/iso9660.cpp` / `udf.cpp` are stale since 089 (`SplWToU8` is total)
- the markers now say what the fallback really covers; no behaviour depends on it.

## Markers (T008)

A script in the session's temporary folder (not part of the tree) inserted one
`// encoding-check: allow <rule> - <reason> (255)` line above each of the 68 sites (on top of an
existing `//` block where one is directly above; the checker walks the block). `git diff main --
src`: 36 files, **68 insertions, 0 deletions**, every added line a marker comment (checked by
`git diff -U0 -- src | grep '^[+-]' | grep -v marker` → nothing). BOMs and line ends kept.

## Items (T009, T010)

Six bugs (`measure:255`) and one follow-up (`leftover:255`) in *Inbox*:
`automation-script-folder-list-code-page` (3; 2 after review 1), `dbviewer-field-length-separator` (2),
`mmviewer-open-error-name-mojibake` (1), `unmime-progress-title-name-mojibake` (1),
`renamer-wtf8-names-shown-as-mojibake` (2), `uniso-hfs-names-lossy-surrogates` (2, related to
`uniso-hfs-btree-trust-and-joliet-cut`), `plugin-encoding-scan-strict-in-build` (2, depends on the
three shipped-plug-in items). `BL check` → `TOTAL: 0`.

## Checks

- T011: `python tools/check_encoding.py --plugins` → `TOTAL: 10 finding(s)`; its `--format list`
  sites equal the 10 *real defect* rows of `verdicts.md` taken from the baseline
  (`diff --strip-trailing-cr` of the sorted lists: no difference).
- T012 negative control: one line `SetWindowText(h, fileName);` appended to
  `dbviewer/dialogs.cpp` → `TOTAL: 11`, the new line reported (`utf8-to-legacy-sink`); file
  restored → `TOTAL: 10`.
- T013: `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`, exit 0;
  `--plugins --strict` → exit 0 (still report-only, 239 FR-001). `build.cmd` (Debug x64,
  incremental) → `BUILD SUCCEEDED`, exit 0 (the plug-ins that are off are not built; their changes
  are comments too). `saltests` not run: nothing in the core or `src/common/` changed.
- T014: the source diff is comments only (above).

## Review

### Review 1 (independent agent, refute-first)

Reproduced: the scan's 10 = the 10 real rows; core `--strict` 0; source diff 68 added / 0 deleted,
all markers, BOMs and line ends kept. Its negative control: `tools/` and `src/plugins` copied to a
temporary folder with the markers stripped → `TOTAL: 78`, the same sites as the baseline - every
marker sits on its line.

- **MUST 1** - UnISO `uniso.cpp` `EnsureU8Name` (row 74) was marked "archive bytes", but for
  Joliet **files** `iso9660.cpp` calls it on the WTF-8 output of `ConvJolietName`; the strict
  probe rejects the surrogate form and re-reads the name in the code page (`a<U+D800>č.txt` →
  `aí €ÄŤ.txt`, cp1250). Confirmed by reading. **Fixed**: marker removed, verdict real defect, new
  item `uniso-joliet-file-names-wtf8-garbled` (review:255).
- **MUST 2** - CheckVer `logwnd.cpp` (row 35) was marked "not names", but the log shows the script
  path (`data.cpp`, `IDS_FILE_OPENED` & co. composed with the UTF-8 path). Confirmed. **Fixed**:
  marker removed, real defect, item `checkver-log-script-path-garbled` (review:255).
- **MUST 3** - `shared/lukas/utildlg.cpp` (rows 65, 66, recorded as Renamer defects) is built by
  no project; the Renamer links its own `HistoryComboBox` (`renamer/dialogs.cpp`, `SplU8ToWAlloc`).
  Confirmed (`grep utildlg` over projects and sources: only a comment in `lcutils.h`). **Fixed**:
  rows 65/66 → false positive "not compiled" (markers added); the Renamer item reduced to the
  preview; its title corrected.
- SHOULD 1 - File Comparator tooltip markers claimed the decimal separator is always ASCII; a
  user-set decimal symbol is not. **Fixed**: the markers now say "latent, deferred like the core's
  twin (067, ledger L06)".
- SHOULD 2 - the Automation item claimed a broken round trip on cp1250; measured by the reviewer:
  single-byte code pages round-trip, cp932 does not. **Fixed**: item text, severity 3 → 2.
- SHOULD 3 - the HFS+ item named Joliet as the correct model. **Fixed**: text, linked to the new
  Joliet item.
- SHOULD 4 - the guard reads `*.cpp` only; plug-in headers hold lenient name converters
  (`regedt/utils.h`, `portables/wpdhelpers.h`). Out of the item's scope (the 78 findings) →
  item `check-encoding-skips-header-files` (review:255), linked from the strict-scan item.
- NOTE - PictView markers said `%u`, the template has `%d`: **fixed** the text. Markdown Viewer
  `UriDecode`: the verdict holds (canonical URI), a percent-encoded lone surrogate becomes U+FFFD in
  a read-only open - recorded here only. ZIP `prevsfx.cpp`: `path` uninitialised if
  `GetCurrentDirectoryA` fails (a preview, not encoding) - recorded here only.

After the fixes: `check_encoding.py --plugins` → `TOTAL: 10`, the sites = the 10 real rows (sorted
lists equal); every false-positive row's reason equals its marker text (68/68, checked by script);
`--strict` → `TOTAL: 0`, exit 0; `git diff main -- src` 68 added / 0 deleted; `build.cmd` →
`BUILD SUCCEEDED`, exit 0; `BL check` → `TOTAL: 0`.

### Review 2 (fresh independent agent, with review 1's findings)

Reproduced again: scan `TOTAL: 10` = the 10 real rows; core `--strict` 0; 68 added / 0 deleted;
markers stripped in a copy → `TOTAL: 78` = baseline; 68/68 reasons equal their markers; all review-1
fixes verified in place.

- **MUST 1** - FTP `ftputils.cpp` `FTPListingFieldToU8` (row 41) was marked "a server does not send
  the WTF-8 form", but the plug-in itself uploads WTF-8 bytes verbatim (`FTPU8NameToServer`), and
  the next listing re-reads such a name whole in the code page; by reading, a second upload's
  "target exists?" check then never matches and STOR overwrites the remote file without asking.
  Confirmed by reading `FTPU8NameToServer`. **Not fixed - the run stops** (below); recorded as item
  `ftp-wtf8-name-listing-round-trip` (review:255, severity 7, by reading) and added to the
  dependencies of `plugin-encoding-scan-strict-in-build`.
- SHOULD 1 - CheckVer `dialogs.cpp:314` (row 3): the filter names in the list box are module names
  from the update script, possibly UTF-8 - the reason "code page like the template" holds only for
  ASCII names. Open (the marker stays on the branch as written).
- SHOULD 2 - the Joliet example: `aí €ÄŤ.txt` (0x8D is Ť in cp1250), not `aí €Ä….txt`. **Fixed** in
  the item and above.
- NOTE 1 - TAR / UnCAB / UnMIME (rows 67, 68, 75): "the WTF-8 form does not arise" is unproven for
  third-party packers that might write a lone surrogate as 3 bytes. Open.
- NOTE 2 - the HFS+ root name buffer (`udfiso.cpp` `rootName[128]`) is too small for long
  non-ASCII names. **Added** to the HFS+ item.
- NOTE 3-6 (lossy `?` displays in PictView / ZIP preview; `OLE2A` also feeds the InputBox prompt;
  markers on top of an existing comment block; the file-wide `dead-dispinfow` marker in
  `ftp/dialogs6.cpp` would silence a future dead handler) - recorded here, no change.

## Stop

Stop rule §3 #3: the independent review rejected the work twice (review 1: 3 MUST, fixed; review 2:
1 MUST - an annotated "false positive" that is a real FTP defect). The work stays on this branch:
68 markers (one of them - row 41 - must be removed, SHOULD 1 and NOTE 1 re-judged), `verdicts.md`,
and the backlog items. To finish: remove the FTP marker (row 41 → real defect,
`ftp-wtf8-name-listing-round-trip`), decide CheckVer row 3 and the archive rows 67/68/75, run a fresh
review, then close the item as SKILL.md step 8 describes. The 11 items this run created are brought
to `main` (SKILL.md step 10.2a).
