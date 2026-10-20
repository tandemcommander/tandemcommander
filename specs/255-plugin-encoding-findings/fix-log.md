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
| `strict-probe-rejects-wtf8` | 12 | 3 (Renamer preview; `shared/lukas` history combo - used by the Renamer only) | archive-name boundaries (TAR, UnCAB, UnISO, UnMIME), FTP listing bytes (224), encoding labels, CheckVer log texts, Renamer's `ChangeCase` copies a non-UTF-8 part unchanged (208) |
| `lossy-lenient-at-intake` | 38 | 2 (UnISO HFS+ names) | display-only texts (Automation dialogs, Code Viewer / Markdown Viewer document text, media tags, registry data preview, resource and system texts), input decoded from a code page just above (FTP, ZIP, Multimedia Viewer), a fallback after `SplWToU8` that fits by construction (Joliet, UDF, UDF volume id, OLE names), case-changed strict-decoded text (Renamer), the Portables device name (converted the same way everywhere) |

Totals: **68 false positives, 10 real defects**. Real defects in shipped plug-ins: DB Viewer 1,
Renamer 3 (with `shared/lukas`), UnISO 2; in plug-ins that are off: Automation 1, Multimedia
Viewer 1, UnMIME 2.

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
`automation-script-folder-list-code-page` (3), `dbviewer-field-length-separator` (2),
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
